extends Node3D
## Núcleo do jogo: estado, economia, missões, interações, menus e save (v2).

const SAVE_PATH := "user://savegame.json"
const CADINHO_PRICE := 300
const MERCHANT_POS := Vector3(-6.0, 0.0, 66.0)
const BOARD_POS := Vector3(-12.0, 0.0, 64.0)
const GATE_XS := [-30.0, 0.0, 30.0, 55.0]
const HOUSE_OFFSETS := [Vector3(-18, 0, 62), Vector3(-2, 0, 74), Vector3(8, 0, 62), Vector3(-16, 0, 74), Vector3(2, 0, 60), Vector3(11, 0, 70), Vector3(-8, 0, 76), Vector3(6, 0, 76)]
const HOUSE_LEVELS := [0, 0, 0, 1, 2, 2, 3, 4]

var terrain: Node3D
var player: Node3D
var hud: CanvasLayer
var machines: Node3D

var money := 50
var pa_tier := 0
var brush_tier := 0
var bucket_terra := 0
var bucket_water := 0.0

var pocket_ores := {}
var pocket_bars := {}
var pocket_gems_raw := {}
var pocket_gems := {}
var joias: Array = []
var artefatos: Array = []

var quest_index := 0
var completed_orders := 0
var active_order := {}
var village_level := 1
var unlocked: Array = [true, false, false, false, false]

var stats_ores := 0
var stats_harvester := 0
var drills_watered := false
var met_merchant := false
var bars_heated := 0.0

var placing := ""
var placing_tier := 0
var menu_open := false
var dig_cooldown := 0.0
var brush_progress := 0.0
var brush_needed := 4.0

var _aim := Vector3.ZERO
var _aim_valid := false
var _anvil_item := ""
var _anvil_base := ""
var _anvil_blade := ""
var _menu_machine := {}
var _autosave := 0.0
var _quest_timer := 0.5
var _pickup_timer := 0.0
var _pickups: Array = []
var _houses: Array = []
var _gate_labels: Array = []


func _ready() -> void:
	randomize()
	_setup_input()
	_build_environment()
	terrain = preload("res://scripts/terrain.gd").new()
	terrain.game = self
	add_child(terrain)
	machines = preload("res://scripts/machines.gd").new()
	machines.game = self
	machines.terrain = terrain
	add_child(machines)
	_build_village()
	_build_gates()
	player = preload("res://scripts/player.gd").new()
	player.terrain = terrain
	player.game = self
	add_child(player)
	player.global_position = Vector3(-40.0, terrain.height_at(-40.0, 0.0) + 1.0, 0.0)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	var loaded := load_game()
	if not loaded:
		var bp := Vector3(-36.0, terrain.height_at(-36.0, 4.0), 4.0)
		machines.add_machine("bacia", 0, bp)
		hud.flash("Bem-vindo às terras do seu avô!")
	_rebuild_village()
	_update_gate_labels()
	hud.show_intro()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _process(delta: float) -> void:
	dig_cooldown = maxf(0.0, dig_cooldown - delta)
	bars_heated = maxf(0.0, bars_heated - delta)
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_pickup_timer = 0.15
		_collect_pickups()
	_quest_timer -= delta
	if _quest_timer <= 0.0:
		_quest_timer = 0.5
		_check_quests()
	_autosave += delta
	if _autosave >= 30.0:
		_autosave = 0.0
		save_game()
	hud.refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if hud.intro_visible():
		var pressed := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
		if pressed:
			hud.hide_intro()
		return
	if event.is_action_pressed("interact"):
		if menu_open:
			close_menu()
		else:
			interact()
	elif event.is_action_pressed("build"):
		if menu_open:
			close_menu()
		else:
			open_build_menu()
	elif event.is_action_pressed("demolish"):
		demolish_nearby()
	elif event.is_action_pressed("save_game"):
		save_game()
		hud.flash("Jogo salvo!")
	elif event.is_action_pressed("reset_game"):
		reset_game()
	elif event.is_action_pressed("ui_cancel"):
		if menu_open:
			close_menu()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func zone_unlocked(zone: int) -> bool:
	if zone < 0 or zone >= unlocked.size():
		return false
	return bool(unlocked[zone])


func roll_ore(zone: int) -> String:
	if zone < 0 or zone >= GameData.ORE_WEIGHTS.size():
		return ""
	var weights: Array = GameData.ORE_WEIGHTS[zone]
	var idx := GameData.pick_weighted(weights)
	if idx < 0:
		return ""
	return String(GameData.ORE_ORDER[idx])


func roll_gem(zone: int) -> String:
	if zone < 0 or zone >= GameData.GEM_WEIGHTS.size():
		return ""
	var weights: Array = GameData.GEM_WEIGHTS[zone]
	var idx := GameData.pick_weighted(weights)
	if idx < 0:
		return ""
	return String(GameData.GEM_ORDER[idx])


func on_drill_watered() -> void:
	drills_watered = true


func on_harvester_ore() -> void:
	stats_harvester += 1


func update_aim(hit: Vector3, valid: bool) -> void:
	_aim = hit
	_aim_valid = valid
	if placing != "":
		if valid:
			machines.set_ghost(hit)
		else:
			machines.hide_ghost()


func on_click() -> void:
	if menu_open:
		return
	if placing != "":
		try_place()


func tool_hold(delta: float) -> void:
	if menu_open or not _aim_valid:
		return
	var bacia: Dictionary = machines.nearest_of_type(_aim, "bacia", 4.0)
	if not bacia.is_empty() and float(bacia["dirt"]) > 0.0 and float(bacia["water"]) > 0.2:
		brush_needed = float(GameData.BRUSH_TIERS[brush_tier]["time"])
		brush_progress += delta
		if brush_progress >= brush_needed:
			brush_progress = 0.0
			_finish_brush(bacia)
	else:
		brush_progress = 0.0
		try_dig(_aim)


func try_dig(hit: Vector3) -> void:
	if dig_cooldown > 0.0:
		return
	if hit.distance_to(player.global_position) > 9.0:
		return
	var pa: Dictionary = GameData.PA_TIERS[pa_tier]
	if bucket_terra >= int(pa["bucket"]):
		hud.flash("Balde cheio de terra! Despeje numa bacia (E).")
		dig_cooldown = 0.5
		return
	dig_cooldown = float(pa["cooldown"])
	var removed: float = terrain.dig(hit, float(pa["radius"]), float(pa["power"]))
	if removed < 0.0:
		hud.flash("Terras trancadas! Progrida na história para abrir.")
		return
	if removed <= 0.0:
		return
	bucket_terra += 1
	if randf() < 0.005:
		_add_artefato(GameData.zone_at(hit.x))


func _finish_brush(bacia: Dictionary) -> void:
	bacia["dirt"] = float(bacia["dirt"]) - 1.0
	var zone := GameData.zone_at(bacia["pos"].x)
	var count := 3 + (randi() % 4) + zone
	for i in count:
		var ore: String = roll_ore(zone)
		if ore != "":
			_spawn_pickup(bacia["pos"], "ore", ore)
	if randf() < 0.12 + 0.04 * float(zone):
		var gem: String = roll_gem(zone)
		if gem != "":
			_spawn_pickup(bacia["pos"], "gem", gem)
	if randf() < 0.02:
		_add_artefato(zone)


func _add_artefato(zone: int) -> void:
	var nome: String = GameData.ARTEFACT_NAMES[randi() % GameData.ARTEFACT_NAMES.size()]
	var valor := (20 + randi() % 80) * (zone + 1)
	artefatos.append({"name": nome, "valor": valor})
	hud.flash("Você encontrou um artefato: %s! ($%d)" % [nome, valor])


func _spawn_pickup(pos: Vector3, kind: String, id: String) -> void:
	if _pickups.size() >= 80:
		var old: Node3D = _pickups[0]
		if is_instance_valid(old):
			old.queue_free()
		_pickups.remove_at(0)
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	if kind == "ore":
		var ore: Dictionary = GameData.ORES[id]
		mat.albedo_color = ore["color"]
		mat.metallic = 0.7
		mat.roughness = 0.35
	else:
		var gem: Dictionary = GameData.GEMS[id]
		mat.albedo_color = gem["color"]
		mat.emission_enabled = true
		mat.emission = gem["color"] * 0.4
		mat.roughness = 0.1
	m.material_override = mat
	var p := pos
	p.x += randf_range(-1.0, 1.0)
	p.z += randf_range(-1.0, 1.0)
	p.y = terrain.height_at(p.x, p.z) + 0.15
	m.position = p
	m.set_meta("kind", kind)
	m.set_meta("id", id)
	add_child(m)
	_pickups.append(m)


func _collect_pickups() -> void:
	var i := _pickups.size() - 1
	while i >= 0:
		var n: Node3D = _pickups[i]
		if not is_instance_valid(n):
			_pickups.remove_at(i)
		elif n.global_position.distance_to(player.global_position) < 1.8:
			var kind: String = n.get_meta("kind")
			var id: String = n.get_meta("id")
			if kind == "ore":
				pocket_ores[id] = int(pocket_ores.get(id, 0)) + 1
				stats_ores += 1
			else:
				pocket_gems_raw[id] = int(pocket_gems_raw.get(id, 0)) + 1
			n.queue_free()
			_pickups.remove_at(i)
		i -= 1


func interact() -> void:
	if menu_open:
		return
	var pp: Vector3 = player.global_position
	if Vector2(pp.x, pp.z).distance_to(terrain.LAKE_POS) < 11.0:
		bucket_water = 1.0
		hud.flash("Balde cheio de água!")
		return
	var m: Dictionary = machines.nearest(pp, 3.5)
	if not m.is_empty():
		_interact_machine(m)
		return
	if pp.distance_to(MERCHANT_POS) < 4.0:
		met_merchant = true
		open_merchant_menu()
		return
	if pp.distance_to(BOARD_POS) < 4.0:
		open_board_menu()
		return
	hud.flash("Nada por perto para interagir.")


func _interact_machine(m: Dictionary) -> void:
	var type: String = m["type"]
	match type:
		"bacia":
			if bucket_terra > 0:
				m["dirt"] = float(m["dirt"]) + float(bucket_terra)
				hud.flash("Despejou %d carga(s) de terra na bacia." % bucket_terra)
				bucket_terra = 0
			elif bucket_water > 0.0:
				m["water"] = float(m["water"]) + 1.0
				bucket_water = 0.0
				hud.flash("Água na bacia! Mire na bacia e segure o clique para escovar.")
			else:
				hud.flash("Bacia: traga terra (pá) ou água (balde no lago).")
		"drill":
			if bucket_water > 0.0:
				m["water_time"] = 30.0
				bucket_water = 0.0
				hud.flash("Drill com água por 30s! Ligue canos ao lago para água infinita.")
			else:
				hud.flash("Drill precisa de água: despeje um balde ou ligue canos ao lago.")
		"harvester":
			var caixa: Dictionary = m["caixa"]
			var cg: Dictionary = m["caixa_gems"]
			var total := 0
			for k in caixa:
				pocket_ores[k] = int(pocket_ores.get(k, 0)) + int(caixa[k])
				total += int(caixa[k])
			for k in cg:
				pocket_gems_raw[k] = int(pocket_gems_raw.get(k, 0)) + int(cg[k])
				total += int(cg[k])
			caixa.clear()
			cg.clear()
			hud.flash("Coletou %d item(ns) da caixa!" % total)
		"cadinho":
			open_cadinho_menu(m)
		"forja":
			bars_heated = 60.0
			hud.flash("Barras aquecidas! Corra para a bigorna (60s).")
		"bigorna":
			open_anvil_menu()
		"polidora":
			_polish_gems()
		"prensa":
			open_prensa_menu()
		_:
			hud.flash("Máquina: %s" % type)


func _open_menu(title: String, options: Array) -> void:
	menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_menu(title, options)


func close_menu() -> void:
	menu_open = false
	_menu_machine = {}
	hud.close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _noop() -> void:
	pass


func _pocket_ores_value() -> int:
	var v := 0
	for k in pocket_ores:
		v += int(pocket_ores[k]) * int(GameData.ORES[String(k)]["value"])
	return v


func _pocket_bars_value() -> int:
	var v := 0
	for k in pocket_bars:
		v += int(floor(float(pocket_bars[k]) * float(GameData.bar_value(String(k)))))
	return v


func _pocket_gems_value(raw: bool) -> int:
	var v := 0
	var src: Dictionary = pocket_gems_raw if raw else pocket_gems
	for k in src:
		v += int(src[k]) * int(float(GameData.GEMS[String(k)]["value"]) * 2.2)
	return v


func _joias_value() -> int:
	var v := 0
	for j in joias:
		v += int(j["valor"])
	return v


func _artefatos_value() -> int:
	var v := 0
	for a in artefatos:
		v += int(a["valor"])
	return v


func sell_all_ores() -> void:
	var v := _pocket_ores_value()
	if v <= 0:
		return
	pocket_ores.clear()
	money += v
	hud.flash("Vendeu os minérios por $%d!" % v)
	open_merchant_menu()


func sell_all_bars() -> void:
	var v := _pocket_bars_value()
	if v <= 0:
		return
	pocket_bars.clear()
	money += v
	hud.flash("Vendeu as barras por $%d!" % v)
	open_merchant_menu()


func sell_all_gems_raw() -> void:
	var v := _pocket_gems_value(true)
	if v <= 0:
		return
	pocket_gems_raw.clear()
	money += v
	hud.flash("Vendeu as gemas brutas por $%d!" % v)
	open_merchant_menu()


func sell_all_gems_polished() -> void:
	var v := _pocket_gems_value(false)
	if v <= 0:
		return
	pocket_gems.clear()
	money += v
	hud.flash("Vendeu as gemas polidas por $%d!" % v)
	open_merchant_menu()


func sell_all_joias() -> void:
	var v := _joias_value()
	if v <= 0:
		return
	joias.clear()
	money += v
	hud.flash("Vendeu as jóias por $%d!" % v)
	open_merchant_menu()


func sell_all_artefatos() -> void:
	var v := _artefatos_value()
	if v <= 0:
		return
	artefatos.clear()
	money += v
	hud.flash("Vendeu os artefatos por $%d!" % v)
	open_merchant_menu()


func buy_pa() -> void:
	if pa_tier >= GameData.PA_TIERS.size() - 1:
		return
	var price := int(GameData.PA_TIERS[pa_tier + 1]["price"])
	if money < price:
		return
	money -= price
	pa_tier += 1
	hud.flash("Nova pá: %s!" % String(GameData.PA_TIERS[pa_tier]["name"]))
	open_merchant_menu()


func buy_brush() -> void:
	if brush_tier >= GameData.BRUSH_TIERS.size() - 1:
		return
	var price := int(GameData.BRUSH_TIERS[brush_tier + 1]["price"])
	if money < price:
		return
	money -= price
	brush_tier += 1
	hud.flash("Nova escova: %s!" % String(GameData.BRUSH_TIERS[brush_tier]["name"]))
	open_merchant_menu()


func open_merchant_menu() -> void:
	var opts: Array = []
	var v_ores := _pocket_ores_value()
	opts.append({"label": "Vender todos os minérios — $%d" % v_ores, "disabled": v_ores <= 0, "action": sell_all_ores})
	var v_bars := _pocket_bars_value()
	opts.append({"label": "Vender todas as barras — $%d" % v_bars, "disabled": v_bars <= 0, "action": sell_all_bars})
	var v_raw := _pocket_gems_value(true)
	opts.append({"label": "Vender gemas brutas — $%d" % v_raw, "disabled": v_raw <= 0, "action": sell_all_gems_raw})
	var v_pol := _pocket_gems_value(false)
	opts.append({"label": "Vender gemas polidas — $%d" % v_pol, "disabled": v_pol <= 0, "action": sell_all_gems_polished})
	var v_joias := _joias_value()
	opts.append({"label": "Vender jóias — $%d" % v_joias, "disabled": v_joias <= 0, "action": sell_all_joias})
	var v_art := _artefatos_value()
	opts.append({"label": "Vender artefatos — $%d" % v_art, "disabled": v_art <= 0, "action": sell_all_artefatos})
	if pa_tier < GameData.PA_TIERS.size() - 1:
		var nxt: Dictionary = GameData.PA_TIERS[pa_tier + 1]
		opts.append({"label": "Comprar %s — $%d" % [String(nxt["name"]), int(nxt["price"])], "disabled": money < int(nxt["price"]), "action": buy_pa})
	if brush_tier < GameData.BRUSH_TIERS.size() - 1:
		var nxtb: Dictionary = GameData.BRUSH_TIERS[brush_tier + 1]
		opts.append({"label": "Comprar %s — $%d" % [String(nxtb["name"]), int(nxtb["price"])], "disabled": money < int(nxtb["price"]), "action": buy_brush})
	_open_menu("MERCADOR — bem-vindo, herdeiro!", opts)


func open_build_menu() -> void:
	if placing != "":
		placing = ""
		machines.hide_ghost()
		hud.flash("Construção cancelada.")
		return
	var opts: Array = []
	opts.append({"label": "Bacia — $%d" % GameData.BACIA_PRICE, "disabled": money < GameData.BACIA_PRICE, "action": start_placing.bind("bacia", 0)})
	opts.append({"label": "Cano — $%d (ligue ao lago; pode colocar vários)" % GameData.PIPE_PRICE, "disabled": money < GameData.PIPE_PRICE, "action": start_placing.bind("cano", 0)})
	opts.append({"label": "Cadinho — $%d (funde 10 minérios em 1 barra)" % CADINHO_PRICE, "disabled": money < CADINHO_PRICE, "action": start_placing.bind("cadinho", 0)})
	opts.append({"label": "Forja — $%d (aquece barras para a bigorna)" % GameData.FORJA_PRICE, "disabled": money < GameData.FORJA_PRICE, "action": start_placing.bind("forja", 0)})
	opts.append({"label": "Bigorna — $%d (forja anéis, adagas, espadas)" % GameData.BIGORNA_PRICE, "disabled": money < GameData.BIGORNA_PRICE, "action": start_placing.bind("bigorna", 0)})
	opts.append({"label": "Polidora — $%d (polidora de gemas brutas)" % GameData.POLIDORA_PRICE, "disabled": money < GameData.POLIDORA_PRICE, "action": start_placing.bind("polidora", 0)})
	opts.append({"label": "Prensa — $%d (combina gemas em jóias)" % GameData.PRENSA_PRICE, "disabled": money < GameData.PRENSA_PRICE, "action": start_placing.bind("prensa", 0)})
	for t in 5:
		var d: Dictionary = GameData.DRILL_TIERS[t]
		var label := "%s — $%d %s" % [String(d["name"]), int(d["money"]), _bars_cost_text(d["bars"])]
		opts.append({"label": label, "disabled": not can_afford(int(d["money"]), d["bars"]), "action": start_placing.bind("drill", t)})
	for t in 5:
		var hv: Dictionary = GameData.HARVESTER_TIERS[t]
		var label2 := "%s — $%d %s" % [String(hv["name"]), int(hv["money"]), _bars_cost_text(hv["bars"])]
		opts.append({"label": label2, "disabled": not can_afford(int(hv["money"]), hv["bars"]), "action": start_placing.bind("harvester", t)})
	_open_menu("CONSTRUÍR — escolha e posicione com o clique esquerdo", opts)


func start_placing(type: String, tier: int) -> void:
	placing = type
	placing_tier = tier
	close_menu()
	if type == "cano":
		hud.flash("Modo cano: clique para colocar vários. T para sair.")
	else:
		hud.flash("Clique esquerdo para posicionar. T para cancelar.")


func cancel_placing() -> void:
	placing = ""
	machines.hide_ghost()


func can_afford(cost: int, bars: Dictionary) -> bool:
	if money < cost:
		return false
	for k in bars:
		if float(pocket_bars.get(k, 0.0)) < float(bars[k]):
			return false
	return true


func _pay(cost: int, bars: Dictionary) -> void:
	money -= cost
	for k in bars:
		pocket_bars[k] = float(pocket_bars.get(k, 0.0)) - float(bars[k])


func _machine_cost(type: String, tier: int) -> int:
	match type:
		"drill":
			return int(GameData.DRILL_TIERS[tier]["money"])
		"harvester":
			return int(GameData.HARVESTER_TIERS[tier]["money"])
		"bacia":
			return GameData.BACIA_PRICE
		"cano":
			return GameData.PIPE_PRICE
		"forja":
			return GameData.FORJA_PRICE
		"bigorna":
			return GameData.BIGORNA_PRICE
		"polidora":
			return GameData.POLIDORA_PRICE
		"prensa":
			return GameData.PRENSA_PRICE
		"cadinho":
			return CADINHO_PRICE
	return 0


func _machine_bars(type: String, tier: int) -> Dictionary:
	if type == "drill":
		return GameData.DRILL_TIERS[tier]["bars"]
	if type == "harvester":
		return GameData.HARVESTER_TIERS[tier]["bars"]
	return {}


func _machine_name(type: String, tier: int) -> String:
	match type:
		"drill":
			return String(GameData.DRILL_TIERS[tier]["name"])
		"harvester":
			return String(GameData.HARVESTER_TIERS[tier]["name"])
		"bacia":
			return "Bacia"
		"cadinho":
			return "Cadinho"
		"forja":
			return "Forja"
		"bigorna":
			return "Bigorna"
		"polidora":
			return "Polidora"
		"prensa":
			return "Prensa"
		"cano":
			return "Cano"
	return type


func _bars_cost_text(bars: Dictionary) -> String:
	if bars.is_empty():
		return ""
	var parts: Array = []
	for k in bars:
		parts.append("%d barra(s) de %s" % [int(bars[k]), String(GameData.ORES[String(k)]["name"])])
	return "(" + " + ".join(PackedStringArray(parts)) + ")"


func try_place() -> void:
	if placing == "" or not _aim_valid:
		return
	var pos: Vector3 = _aim
	var zone := GameData.zone_at(pos.x)
	if not zone_unlocked(zone):
		hud.flash("Terreno trancado!")
		return
	if pos.x > terrain.VILLAGE_MIN.x - 2.0 and pos.x < terrain.VILLAGE_MAX.x + 2.0 and pos.z > terrain.VILLAGE_MIN.y - 2.0 and pos.z < terrain.VILLAGE_MAX.y + 2.0:
		hud.flash("Não dá para construir no vilarejo!")
		return
	if not machines.nearest(pos, 1.6).is_empty():
		hud.flash("Espaço ocupado!")
		return
	var pos3 := Vector3(pos.x, terrain.height_at(pos.x, pos.z), pos.z)
	if placing == "cano":
		if money < GameData.PIPE_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.PIPE_PRICE
		machines.add_pipe(pos3 + Vector3(0.0, 0.4, 0.0))
		hud.flash("Cano instalado! (%d canos) T para sair." % machines.pipes.size())
		return
	var cost := _machine_cost(placing, placing_tier)
	var bars := _machine_bars(placing, placing_tier)
	if not can_afford(cost, bars):
		hud.flash("Recursos insuficientes!")
		return
	_pay(cost, bars)
	machines.add_machine(placing, placing_tier, pos3)
	hud.flash("%s construída!" % _machine_name(placing, placing_tier))
	cancel_placing()


func demolish_nearby() -> void:
	var m: Dictionary = machines.nearest(player.global_position, 3.5)
	if m.is_empty():
		hud.flash("Nenhuma máquina por perto para desmontar (X).")
		return
	var refund := int(float(_machine_cost(String(m["type"]), int(m["tier"]))) * 0.5)
	machines.remove_machine(int(m["id"]))
	money += refund
	hud.flash("Máquina desmontada: +$%d" % refund)


func open_cadinho_menu(m: Dictionary) -> void:
	_menu_machine = m
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		var have := int(pocket_ores.get(ore_id, 0))
		if have >= 10:
			var ore: Dictionary = GameData.ORES[ore_id]
			var label := "Fundir 10 %s → 1 barra (vale $%d)" % [String(ore["name"]), GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _melt.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Junte 10 minérios iguais no bolso para fundir", "disabled": true, "action": _noop})
	_open_menu("CADINHO — fundir minérios em barras", opts)


func _melt(ore_id: String) -> void:
	if int(pocket_ores.get(ore_id, 0)) < 10:
		return
	pocket_ores[ore_id] = int(pocket_ores[ore_id]) - 10
	pocket_bars[ore_id] = float(pocket_bars.get(ore_id, 0.0)) + 1.0
	hud.flash("1 barra de %s pronta!" % String(GameData.ORES[ore_id]["name"]))
	if not _menu_machine.is_empty():
		open_cadinho_menu(_menu_machine)


func open_anvil_menu() -> void:
	_anvil_item = ""
	_anvil_base = ""
	_anvil_blade = ""
	if bars_heated <= 0.0:
		_open_menu("BIGORNA", [{"label": "As barras estão frias! Aqueça na forja primeiro (E na forja).", "disabled": true, "action": _noop}])
		return
	var opts: Array = []
	for item in GameData.ANVIL_ITEMS:
		var label := "%s (%d barra(s)) — bônus +%d%%" % [String(item["name"]), int(item["bars"]), int(float(item["bonus"]) * 100.0)]
		opts.append({"label": label, "action": _anvil_select_item.bind(String(item["id"]))})
	_open_menu("BIGORNA — escolha o item (barras precisam estar aquecidas!)", opts)


func _anvil_bars_needed() -> int:
	for item in GameData.ANVIL_ITEMS:
		if String(item["id"]) == _anvil_item:
			return int(item["bars"])
	return 1


func _anvil_select_item(id: String) -> void:
	_anvil_item = id
	_anvil_base = ""
	_anvil_blade = ""
	_anvil_pick_base()


func _anvil_pick_base() -> void:
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		if float(pocket_bars.get(ore_id, 0.0)) >= 1.0:
			var label := "Punho/base: barra de %s ($%d)" % [String(GameData.ORES[ore_id]["name"]), GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _anvil_set_base.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Você não tem barras! Funda minérios no cadinho.", "disabled": true, "action": _noop})
	_open_menu("BIGORNA — %s: escolha a barra do punho/base" % String(_anvil_item), opts)


func _anvil_set_base(ore_id: String) -> void:
	_anvil_base = ore_id
	if _anvil_bars_needed() >= 2:
		_anvil_pick_blade()
	else:
		_anvil_gem_step()


func _anvil_pick_blade() -> void:
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		var disponivel := float(pocket_bars.get(ore_id, 0.0))
		if ore_id == _anvil_base:
			disponivel -= 1.0
		if disponivel >= 1.0:
			var label := "Lâmina/topo: barra de %s ($%d)" % [String(GameData.ORES[ore_id]["name"]), GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _anvil_set_blade.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Faltam barras para a lâmina (precisa de 2 no total).", "disabled": true, "action": _noop})
	_open_menu("BIGORNA — %s: escolha a barra da lâmina/topo" % String(_anvil_item), opts)


func _anvil_set_blade(ore_id: String) -> void:
	_anvil_blade = ore_id
	_anvil_gem_step()


func _anvil_gem_step() -> void:
	var best_gem := ""
	var best_val := 0
	for g in GameData.GEM_ORDER:
		if int(pocket_gems.get(g, 0)) > 0:
			var val := int(float(GameData.GEMS[g]["value"]) * 2.2)
			if val > best_val:
				best_val = val
				best_gem = g
	var opts: Array = []
	if best_gem != "":
		var label := "Encrubar %s polida (valor final ×1.2)" % String(GameData.GEMS[best_gem]["name"])
		opts.append({"label": label, "action": _anvil_craft.bind(true)})
	opts.append({"label": "Forjar sem gema", "action": _anvil_craft.bind(false)})
	_open_menu("BIGORNA — gema opcional", opts)


func _anvil_craft(encrust: bool) -> void:
	var need := _anvil_bars_needed()
	var bars_used: Array = [_anvil_base]
	if need >= 2:
		bars_used.append(_anvil_blade)
	for b in bars_used:
		if float(pocket_bars.get(b, 0.0)) < 1.0:
			hud.flash("Barras insuficientes!")
			return
	var total := 0
	for b in bars_used:
		pocket_bars[b] = float(pocket_bars[b]) - 1.0
		total += GameData.bar_value(String(b))
	var item: Dictionary = {}
	for it in GameData.ANVIL_ITEMS:
		if String(it["id"]) == _anvil_item:
			item = it
	var value := int(float(total) * (1.0 + float(item["bonus"])))
	if encrust:
		var bg := ""
		var bv := 0
		for g in GameData.GEM_ORDER:
			if int(pocket_gems.get(g, 0)) > 0:
				var val := int(float(GameData.GEMS[g]["value"]) * 2.2)
				if val > bv:
					bv = val
					bg = g
		if bg != "":
			pocket_gems[bg] = int(pocket_gems[bg]) - 1
			value = int(float(value) * 1.2)
	joias.append({"valor": value, "lagrima": false})
	hud.flash("Forjou %s no valor de $%d!" % [String(item["name"]), value])
	close_menu()


func _polish_gems() -> void:
	var total := 0
	for g in GameData.GEM_ORDER:
		var n := int(pocket_gems_raw.get(g, 0))
		if n > 0:
			pocket_gems_raw[g] = 0
			pocket_gems[g] = int(pocket_gems.get(g, 0)) + n
			total += n
	if total > 0:
		hud.flash("A polidora lapidou %d gema(s)! Leve à prensa." % total)
	else:
		hud.flash("Sem gemas brutas para polir.")


func open_prensa_menu() -> void:
	var opts: Array = []
	for g in GameData.GEM_ORDER:
		var n := int(pocket_gems.get(g, 0))
		var min_n := 1
		if g != "lagrima":
			min_n = 2
		if n >= min_n:
			var total := 0
			for i in n:
				total += int(float(GameData.GEMS[g]["value"]) * 2.2)
			var jv := int(float(total) * 1.3)
			var label := "Fundir %d %s polida(s) → 1 JÓIA ($%d)" % [n, String(GameData.GEMS[g]["name"]), jv]
			opts.append({"label": label, "action": _press.bind(g)})
	if opts.is_empty():
		opts.append({"label": "Passe as gemas brutas na polidora; depois junte 2 polidas iguais (a Lágrima Divina vale sozinha).", "disabled": true, "action": _noop})
	_open_menu("PRENSA — combinar gemas em jóias", opts)


func _press(g: String) -> void:
	var n := int(pocket_gems.get(g, 0))
	if n <= 0:
		return
	var total := 0
	for i in n:
		total += int(float(GameData.GEMS[g]["value"]) * 2.2)
	pocket_gems[g] = 0
	var jv := int(float(total) * 1.3)
	joias.append({"valor": jv, "lagrima": g == "lagrima"})
	hud.flash("Jóia criada no valor de $%d!" % jv)
	open_prensa_menu()


func open_board_menu() -> void:
	var opts: Array = []
	if active_order.is_empty():
		var order := _make_order()
		var label := "Aceitar encomenda: %d barra(s) de %s — $%d" % [int(order["bars"]), String(GameData.ORES[String(order["ore"])]["name"]), int(order["reward"])]
		opts.append({"label": label, "action": _accept_order.bind(order)})
	else:
		var have := float(pocket_bars.get(String(active_order["ore"]), 0.0))
		var need := int(float(active_order["bars"]))
		var label2 := "Entregar encomenda: %d/%d barra(s) de %s" % [int(minf(have, float(need))), need, String(GameData.ORES[String(active_order["ore"])]["name"])]
		opts.append({"label": label2, "disabled": have < float(need), "action": _deliver_order})
		opts.append({"label": "Cancelar encomenda", "action": _cancel_order})
	_open_menu("QUADRO DE ENCOMENDAS DO VILAREJO", opts)


func _make_order() -> Dictionary:
	var pool: Array = []
	for z in 5:
		if not zone_unlocked(z):
			continue
		for oi in 7:
			if float(GameData.ORE_WEIGHTS[z][oi]) > 0.0:
				pool.append(String(GameData.ORE_ORDER[oi]))
	var ore_id: String = pool[randi() % pool.size()]
	var n := 3 + (randi() % 6)
	var reward := int(float(n) * float(GameData.bar_value(ore_id)) * 1.6)
	return {"ore": ore_id, "bars": n, "reward": reward}


func _accept_order(order: Dictionary) -> void:
	active_order = order
	hud.flash("Encomenda aceita! Veja no canto superior esquerdo.")
	close_menu()


func _deliver_order() -> void:
	if active_order.is_empty():
		return
	var ore_id: String = String(active_order["ore"])
	var need := int(float(active_order["bars"]))
	if float(pocket_bars.get(ore_id, 0.0)) < float(need):
		return
	pocket_bars[ore_id] = float(pocket_bars[ore_id]) - float(need)
	var reward := int(float(active_order["reward"]))
	money += reward
	completed_orders += 1
	active_order = {}
	hud.flash("Encomenda entregue! +$%d" % reward)
	open_board_menu()


func _cancel_order() -> void:
	active_order = {}
	hud.flash("Encomenda cancelada.")
	close_menu()


func _check_quests() -> void:
	while quest_index < GameData.MAIN_QUESTS.size() and _quest_done(quest_index):
		var q: Dictionary = GameData.MAIN_QUESTS[quest_index]
		_consume_quest(quest_index)
		if q.has("reward"):
			money += int(q["reward"])
		if q.has("village"):
			village_level = int(q["village"])
			_rebuild_village()
		if q.has("unlock"):
			var zi := int(q["unlock"])
			unlocked[zi] = true
			_update_gate_labels()
		quest_index += 1
		hud.flash("Missão concluída! (%s)" % String(q["text"]))
		save_game()


func _quest_done(i: int) -> bool:
	match i:
		0:
			return met_merchant
		1:
			return stats_ores >= 10
		2:
			return float(pocket_bars.get("ferro", 0.0)) >= 5.0
		3:
			return drills_watered
		4:
			return stats_harvester >= 50
		5:
			return money >= 10000
		6:
			return float(pocket_bars.get("ouro", 0.0)) >= 10.0
		7:
			return money >= 50000 and float(pocket_bars.get("mithril", 0.0)) >= 15.0
		8:
			return completed_orders >= 10
		9:
			return _has_lagrima_jewel()
	return true


func _consume_quest(i: int) -> void:
	match i:
		2:
			pocket_bars["ferro"] = float(pocket_bars.get("ferro", 0.0)) - 5.0
		5:
			money -= 10000
		6:
			pocket_bars["ouro"] = float(pocket_bars.get("ouro", 0.0)) - 10.0
		7:
			money -= 50000
			pocket_bars["mithril"] = float(pocket_bars.get("mithril", 0.0)) - 15.0


func _has_lagrima_jewel() -> bool:
	for j in joias:
		if bool(j["lagrima"]):
			return true
	return false


func get_prompt() -> String:
	if menu_open:
		return ""
	if placing != "":
		return "Clique esquerdo: posicionar %s | T: cancelar" % _machine_name(placing, placing_tier)
	var pp: Vector3 = player.global_position
	if Vector2(pp.x, pp.z).distance_to(terrain.LAKE_POS) < 11.0:
		return "E: encher o balde de água no lago"
	if _aim_valid:
		var b: Dictionary = machines.nearest_of_type(_aim, "bacia", 4.0)
		if not b.is_empty() and float(b["dirt"]) > 0.0 and float(b["water"]) > 0.2:
			return "Segure o clique esquerdo para ESCOVAR a terra"
	var m: Dictionary = machines.nearest(pp, 3.5)
	if not m.is_empty():
		return "E: usar %s | X: desmontar" % _machine_name(String(m["type"]), int(m["tier"]))
	if pp.distance_to(MERCHANT_POS) < 4.0:
		return "E: falar com o Mercador"
	if pp.distance_to(BOARD_POS) < 4.0:
		return "E: ver o quadro de encomendas"
	return ""


func _build_village() -> void:
	for i in HOUSE_OFFSETS.size():
		var off: Vector3 = HOUSE_OFFSETS[i]
		var wx: float = off.x
		var wz: float = off.z
		var y: float = terrain.height_at(wx, wz)
		var root := Node3D.new()
		root.position = Vector3(wx, y, wz)
		add_child(root)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3, 2.2, 3)
		body.mesh = bm
		body.position = Vector3(0, 1.1, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.7, 0.55)
		body.material_override = mat
		root.add_child(body)
		var roof := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(3.6, 0.8, 3.6)
		roof.mesh = rm
		roof.position = Vector3(0, 2.6, 0)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.6, 0.25, 0.2)
		roof.material_override = rmat
		root.add_child(roof)
		_houses.append(root)
	_merchant_node()
	_board_node()
	_rebuild_village()


func _merchant_node() -> void:
	var root := Node3D.new()
	root.position = Vector3(MERCHANT_POS.x, terrain.height_at(MERCHANT_POS.x, MERCHANT_POS.z), MERCHANT_POS.z)
	add_child(root)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	body.mesh = cm
	body.position = Vector3(0, 0.85, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.5, 0.8)
	body.material_override = mat
	root.add_child(body)
	var label := Label3D.new()
	label.text = "MERCADOR — E para falar"
	label.font_size = 96
	label.pixel_size = 0.01
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.3, 0)
	root.add_child(label)


func _board_node() -> void:
	var root := Node3D.new()
	root.position = Vector3(BOARD_POS.x, terrain.height_at(BOARD_POS.x, BOARD_POS.z), BOARD_POS.z)
	add_child(root)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.2, 1.4, 0.15)
	panel.mesh = pm
	panel.position = Vector3(0, 1.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.35, 0.2)
	panel.material_override = mat
	root.add_child(panel)
	var label := Label3D.new()
	label.text = "QUADRO DE ENCOMENDAS — E"
	label.font_size = 72
	label.pixel_size = 0.01
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.9, 0)
	root.add_child(label)


func _rebuild_village() -> void:
	for i in _houses.size():
		var h: Node3D = _houses[i]
		var threshold := 0
		if i < HOUSE_LEVELS.size():
			threshold = HOUSE_LEVELS[i]
		h.visible = village_level > threshold
		var s := 1.0 + 0.06 * minf(float(village_level), 10.0)
		h.scale = Vector3(s, s, s)


func _build_gates() -> void:
	for gx in GATE_XS:
		var zone := GameData.zone_at(float(gx) + 1.0)
		var z: float = terrain.height_at(float(gx), 20.0)
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 4.0, 10.0)
		post.mesh = bm
		post.position = Vector3(float(gx), z + 2.0, 20.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.3, 0.22)
		post.material_override = mat
		add_child(post)
		var lab := Label3D.new()
		lab.font_size = 96
		lab.pixel_size = 0.01
		lab.outline_size = 16
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = Vector3(float(gx), z + 4.8, 20.0)
		add_child(lab)
		_gate_labels.append(lab)


func _update_gate_labels() -> void:
	for i in GATE_XS.size():
		var zone := GameData.zone_at(float(GATE_XS[i]) + 1.0)
		var lab: Label3D = _gate_labels[i]
		if zone_unlocked(zone):
			lab.text = "ABERTO — %s" % String(GameData.ZONE_NAMES[zone])
			lab.modulate = Color(0.4, 1.0, 0.4)
		else:
			lab.text = "TRANCADO — %s" % String(GameData.ZONE_NAMES[zone])
			lab.modulate = Color(1.0, 0.4, 0.4)


func save_game() -> void:
	var mach: Array = []
	for m in machines.list:
		if bool(m.get("dead", false)):
			continue
		mach.append([String(m["type"]), int(m["tier"]), m["pos"].x, m["pos"].y, m["pos"].z, float(m["dirt"]), float(m["water"]), float(m["water_time"]), m["caixa"], m["caixa_gems"]])
	var pipe_arr: Array = []
	for p in machines.pipes:
		pipe_arr.append([p.x, p.y, p.z])
	var data := {
		"v": 2,
		"money": money,
		"pa_tier": pa_tier,
		"brush_tier": brush_tier,
		"bucket_terra": bucket_terra,
		"bucket_water": bucket_water,
		"pocket_ores": pocket_ores,
		"pocket_bars": pocket_bars,
		"pocket_gems_raw": pocket_gems_raw,
		"pocket_gems": pocket_gems,
		"joias": joias,
		"artefatos": artefatos,
		"quest_index": quest_index,
		"completed_orders": completed_orders,
		"active_order": active_order,
		"village_level": village_level,
		"unlocked": unlocked,
		"stats_ores": stats_ores,
		"stats_harvester": stats_harvester,
		"drills_watered": drills_watered,
		"met_merchant": met_merchant,
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"machines": mach,
		"pipes": pipe_arr,
		"heights": Array(terrain.heights),
		"water": Array(terrain.water),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if int(parsed.get("v", 0)) < 2:
		return false
	money = int(parsed.get("money", money))
	pa_tier = int(parsed.get("pa_tier", 0))
	brush_tier = int(parsed.get("brush_tier", 0))
	bucket_terra = int(parsed.get("bucket_terra", 0))
	bucket_water = float(parsed.get("bucket_water", 0.0))
	var po = parsed.get("pocket_ores", {})
	if typeof(po) == TYPE_DICTIONARY:
		pocket_ores = po
	var pb = parsed.get("pocket_bars", {})
	if typeof(pb) == TYPE_DICTIONARY:
		pocket_bars = pb
	var pgr = parsed.get("pocket_gems_raw", {})
	if typeof(pgr) == TYPE_DICTIONARY:
		pocket_gems_raw = pgr
	var pg = parsed.get("pocket_gems", {})
	if typeof(pg) == TYPE_DICTIONARY:
		pocket_gems = pg
	var jz = parsed.get("joias", [])
	if typeof(jz) == TYPE_ARRAY:
		joias = jz
	var ar = parsed.get("artefatos", [])
	if typeof(ar) == TYPE_ARRAY:
		artefatos = ar
	quest_index = int(parsed.get("quest_index", 0))
	completed_orders = int(parsed.get("completed_orders", 0))
	var ao = parsed.get("active_order", {})
	if typeof(ao) == TYPE_DICTIONARY:
		active_order = ao
	village_level = int(parsed.get("village_level", 1))
	var ul = parsed.get("unlocked", [])
	if typeof(ul) == TYPE_ARRAY and ul.size() == 5:
		unlocked = ul
	stats_ores = int(parsed.get("stats_ores", 0))
	stats_harvester = int(parsed.get("stats_harvester", 0))
	drills_watered = bool(parsed.get("drills_watered", false))
	met_merchant = bool(parsed.get("met_merchant", false))
	var h = parsed.get("heights", [])
	if typeof(h) == TYPE_ARRAY and h.size() == terrain.heights.size():
		terrain.heights = PackedFloat32Array(h)
		terrain.rebuild_all()
	var w = parsed.get("water", [])
	if typeof(w) == TYPE_ARRAY and w.size() == terrain.water.size():
		terrain.water = PackedFloat32Array(w)
		terrain.rebuild_water_mesh()
	var mach = parsed.get("machines", [])
	if typeof(mach) == TYPE_ARRAY:
		for e in mach:
			if typeof(e) == TYPE_ARRAY and e.size() >= 10:
				var pos := Vector3(float(e[2]), float(e[3]), float(e[4]))
				var id: int = machines.add_machine(String(e[0]), int(e[1]), pos)
				if id >= 0:
					var m: Dictionary = machines.list[id]
					m["dirt"] = float(e[5])
					m["water"] = float(e[6])
					m["water_time"] = float(e[7])
					if typeof(e[8]) == TYPE_DICTIONARY:
						m["caixa"] = e[8]
					if typeof(e[9]) == TYPE_DICTIONARY:
						m["caixa_gems"] = e[9]
	var pipe_arr = parsed.get("pipes", [])
	if typeof(pipe_arr) == TYPE_ARRAY:
		for p in pipe_arr:
			if typeof(p) == TYPE_ARRAY and p.size() == 3:
				machines.add_pipe(Vector3(float(p[0]), float(p[1]), float(p[2])))
	var pp = parsed.get("player", [])
	if typeof(pp) == TYPE_ARRAY and pp.size() == 3:
		player.global_position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
	return true


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("build", KEY_T)
	_add_key("demolish", KEY_X)
	_add_key("save_game", KEY_F5)
	_add_key("reset_game", KEY_F9)
	if not InputMap.has_action("dig"):
		InputMap.add_action("dig")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("dig", mb)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.6, 0.9)
	sky_mat.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sky_mat.ground_horizon_color = Color(0.75, 0.85, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

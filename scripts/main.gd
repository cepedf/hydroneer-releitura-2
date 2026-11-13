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
var sound: Node

var money := 5000
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
var has_picareta := false
var has_rastelo := false
var debt := 0
var total_earned := 0
var _debt_timer := 0.0
var stress_level := 0

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
var _esteira_prev := -1
var _esteira_yaw := 0.0
var _placing_yaw := 0.0
var _scatter_timer := 0.5
var _trees: Array = []
var _rocks: Array = []
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
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	_build_village()
	_build_gates()
	_build_trees()
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
		var bp := Vector3(-36.0, _ground_y(-36.0, 4.0), 4.0)
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
	_scatter_timer -= delta
	if _scatter_timer <= 0.0:
		_scatter_timer = 0.5
		_settle_scatter()
	_autosave += delta
	if _autosave >= 30.0:
		_autosave = 0.0
		save_game()
	if debt > 0:
		_debt_timer += delta
		if _debt_timer >= 30.0:
			_debt_timer = 0.0
			var parcela := mini(debt, maxi(50, int(debt * 0.05)))
			if money >= parcela:
				money -= parcela
				debt -= parcela
				if debt <= 0:
					debt = 0
					hud.flash("Dívida quitada! O banco liberou seu nome.")
	hud.refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if hud.intro_visible():
		var pressed := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
		if pressed:
			hud.hide_intro()
		return
	if placing != "" and not menu_open:
		if event.is_action_pressed("rotate_cw"):
			_placing_yaw += PI * 0.25
			return
		if event.is_action_pressed("rotate_ccw"):
			_placing_yaw -= PI * 0.25
			return
		if event is InputEventMouseButton and event.is_pressed():
			var mb2 := event as InputEventMouseButton
			if mb2.button_index == MOUSE_BUTTON_WHEEL_UP:
				_placing_yaw += PI * 0.25
				return
			if mb2.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_placing_yaw -= PI * 0.25
				return
	if event.is_action_pressed("interact"):
		if menu_open:
			close_menu()
		else:
			interact()
	elif event.is_action_pressed("dump_bucket"):
		if not menu_open:
			_dump_bucket()
	elif event.is_action_pressed("build"):
		if menu_open:
			close_menu()
		else:
			open_build_menu()
	elif event.is_action_pressed("demolish"):
		demolish_nearby()
	elif event.is_action_pressed("diagnose"):
		_diagnose()
	elif event.is_action_pressed("stress"):
		_stress_test()
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
	if placing == "":
		return
	if not valid:
		machines.hide_ghost()
		return
	if placing == "cano":
		var snap: Dictionary = machines.snap_pipe(hit)
		_aim = snap["pos"]
		machines.set_pipe_ghost(_aim, snap["from"], bool(snap["linked"]))
	elif placing == "registro":
		var snap_r: Dictionary = machines.snap_pipe(hit)
		_aim = snap_r["pos"]
		machines.set_pipe_ghost(_aim, snap_r["from"], bool(snap_r["linked"]))
	elif placing == "cabo":
		var snap_c: Dictionary = machines.snap_cabo(hit)
		_aim = snap_c["pos"]
		machines.set_wire_ghost(_aim, snap_c["from"], bool(snap_c["linked"]))
	elif placing == "esteira" or placing == "filtro":
		var se: Dictionary = machines.snap_esteira(hit)
		_aim = se["pos"]
		_esteira_prev = int(se["prev_id"])
		_esteira_yaw = float(se["yaw"])
		machines.set_belt_ghost(_aim, _esteira_yaw, se["from"], bool(se["linked"]))
	elif placing == "drill":
		machines.set_drill_ghost(_aim, _placing_yaw)
	else:
		machines.set_ghost(_aim)


func on_click() -> void:
	if menu_open:
		return
	if placing != "":
		try_place()


func tool_hold(delta: float) -> void:
	if menu_open or not _aim_valid or placing != "":
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


func _dump_bucket() -> void:
	if bucket_terra == 0 and bucket_water <= 0.0:
		hud.flash("O balde já está vazio.")
		return
	bucket_terra = 0
	bucket_water = 0.0
	sound.play("water")
	hud.flash("Balde esvaziado no chão.")


func _ground_y(x: float, z: float) -> float:
	var gy: float = terrain.height_at(x, z)
	var corners: Array[Vector2] = [Vector2(1.1, 0.8), Vector2(-1.1, 0.8), Vector2(1.1, -0.8), Vector2(-1.1, -0.8)]
	for off in corners:
		gy = maxf(gy, terrain.height_at(x + off.x, z + off.y))
	return gy - 0.05


func try_dig(hit: Vector3) -> void:
	if dig_cooldown > 0.0:
		return
	if hit.distance_to(player.global_position) > 9.0:
		return
	if hit.x > terrain.VILLAGE_MIN.x - 2.0 and hit.x < terrain.VILLAGE_MAX.x + 2.0 and hit.z > terrain.VILLAGE_MIN.y - 2.0 and hit.z < terrain.VILLAGE_MAX.y + 2.0:
		hud.flash("Não cave no vilarejo!")
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
	sound.play("dig")
	if has_picareta and player.global_position.y - hit.y > 1.5 and randf() < 0.25:
		var oid: String = roll_ore(GameData.zone_at(hit.x))
		if oid != "":
			_spawn_pickup(hit, "ore", oid)
	if randf() < 0.005:
		_add_artefato(GameData.zone_at(hit.x))


func _finish_brush(bacia: Dictionary) -> void:
	sound.play("reveal")
	bacia["dirt"] = float(bacia["dirt"]) - 1.0
	var zone := GameData.zone_at(bacia["pos"].x)
	var count := 3 + (randi() % 4) + zone
	if has_rastelo:
		count += 1
	for i in count:
		var ore: String = roll_ore(zone)
		if ore != "":
			_spawn_pickup(bacia["pos"], "ore", ore)
	var gem_chance := 0.12 + 0.04 * float(zone)
	if has_rastelo:
		gem_chance += 0.08
	if randf() < gem_chance:
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
	var got := false
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
			got = true
		i -= 1
	if got:
		sound.play("ding")


func interact() -> void:
	if menu_open:
		return
	var pp: Vector3 = player.global_position
	if Vector2(pp.x, pp.z).distance_to(terrain.LAKE_POS) < 11.0:
		bucket_water = 1.0
		sound.play("water")
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
				sound.play("dig")
			elif bucket_water > 0.0:
				m["water"] = float(m["water"]) + 1.0
				bucket_water = 0.0
				sound.play("water")
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
		"filtro":
			open_filtro_menu(m)
		"bau":
			_collect_bau(m)
		"silo":
			hud.flash("Silo: %d/800 de terra. O harvester puxa dele se estiver a 3,5m." % int(float(m["dirt"])))
		"registro":
			_toggle_registro(m)
		"gerador":
			var pstats: Dictionary = machines.power_stats()
			hud.flash("Gerador ligado: fornece %d de energia | consumo da rede: %d" % [int(pstats["supply"]), int(pstats["demand"])])
		"polidora":
			if not machines.is_power_connected_at(m["pos"]):
				hud.flash("SEM ENERGIA — ligue cabos da polidora a um gerador.")
			elif not machines.power_ok():
				hud.flash("REDE SOBRECARREGADA — a soma dos geradores não cobre todas as máquinas.")
			else:
				_polish_gems()
		"prensa":
			if not machines.is_power_connected_at(m["pos"]):
				hud.flash("SEM ENERGIA — ligue cabos da prensa a um gerador.")
			elif not machines.power_ok():
				hud.flash("REDE SOBRECARREGADA — a soma dos geradores não cobre todas as máquinas.")
			else:
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
	total_earned += v
	hud.flash("Vendeu os minérios por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_bars() -> void:
	var v := _pocket_bars_value()
	if v <= 0:
		return
	pocket_bars.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as barras por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_gems_raw() -> void:
	var v := _pocket_gems_value(true)
	if v <= 0:
		return
	pocket_gems_raw.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as gemas brutas por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_gems_polished() -> void:
	var v := _pocket_gems_value(false)
	if v <= 0:
		return
	pocket_gems.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as gemas polidas por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_joias() -> void:
	var v := _joias_value()
	if v <= 0:
		return
	joias.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as jóias por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_artefatos() -> void:
	var v := _artefatos_value()
	if v <= 0:
		return
	artefatos.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu os artefatos por $%d!" % v)
	sound.play("coins")
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
	sound.play("coins")
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
	sound.play("coins")
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
	if not has_picareta:
		opts.append({"label": "Comprar Picareta — $%d (cavar fundo rende minério extra)" % GameData.PICARETA_PRICE, "disabled": money < GameData.PICARETA_PRICE, "action": buy_picareta})
	if not has_rastelo:
		opts.append({"label": "Comprar Rastelo — $%d (escovar rende +1 minério e mais gemas)" % GameData.RASTELO_PRICE, "disabled": money < GameData.RASTELO_PRICE, "action": buy_rastelo})
	var limite := 2000 + int(total_earned * 0.5)
	if debt > 0:
		opts.append({"label": "— BANCO — dívida atual: $%d (juros de 1%%/min; desconto automático de $%d a cada 30s) —" % [debt, mini(debt, maxi(50, int(debt * 0.05)))], "disabled": true, "action": _noop})
		opts.append({"label": "Pagar a dívida inteira agora — $%d" % debt, "disabled": money < debt, "action": bank_repay})
	else:
		var max_emp := maxi(0, limite - debt)
		if max_emp >= 500:
			opts.append({"label": "— BANCO — pegar empréstimo de $%d (limite: $%d, conforme seus ganhos) —" % [max_emp, limite], "action": bank_borrow})
	_open_menu("MERCADOR — bem-vindo, herdeiro!", opts)


func bank_borrow() -> void:
	var emp := maxi(0, (2000 + int(total_earned * 0.5)) - debt)
	if emp < 500:
		return
	money += emp
	debt += emp
	hud.flash("Empréstimo de $%d aceito! Juros de 1%%/min; pague no mercador para evitar o desconto automático." % emp)
	sound.play("coins")
	open_merchant_menu()


func bank_repay() -> void:
	if debt <= 0 or money < debt:
		return
	money -= debt
	debt = 0
	_debt_timer = 0.0
	hud.flash("Dívida quitada! O banco liberou seu nome.")
	sound.play("coins")
	open_merchant_menu()


func open_build_menu() -> void:
	if placing != "":
		placing = ""
		machines.hide_ghost()
		hud.flash("Construção cancelada.")
		return
	var opts: Array = []
	opts.append({"label": "Bacia — $%d" % GameData.BACIA_PRICE, "disabled": money < GameData.BACIA_PRICE, "action": start_placing.bind("bacia", 0)})
	opts.append({"label": "Cano — $%d (aponte perto de outro cano ou da drill para encaixar)" % GameData.PIPE_PRICE, "disabled": money < GameData.PIPE_PRICE, "action": start_placing.bind("cano", 0)})
	opts.append({"label": "Esteira — $%d (encaixa na drill/outra esteira; leva a terra ao harvester)" % GameData.ESTEIRA_PRICE, "disabled": money < GameData.ESTEIRA_PRICE, "action": start_placing.bind("esteira", 0)})
	opts.append({"label": "Filtro — $%d (na linha de esteiras: o minério escolhido sai para o cadinho do lado)" % GameData.FILTRO_PRICE, "disabled": money < GameData.FILTRO_PRICE, "action": start_placing.bind("filtro", 0)})
	opts.append({"label": "Registro — $%d (na linha de canos: E nele abre/fecha a água)" % GameData.REGISTRO_PRICE, "disabled": money < GameData.REGISTRO_PRICE, "action": start_placing.bind("registro", 0)})
	opts.append({"label": "Baú — $%d (guarda os minérios que chegam pela esteira)" % GameData.BAU_PRICE, "disabled": money < GameData.BAU_PRICE, "action": start_placing.bind("bau", 0)})
	opts.append({"label": "Silo — $%d (armazena terra da linha; o harvester puxa dele)" % GameData.SILO_PRICE, "disabled": money < GameData.SILO_PRICE, "action": start_placing.bind("silo", 0)})
	opts.append({"label": "— ENERGIA — a polidora e a prensa precisam de eletricidade —", "disabled": true, "action": _noop})
	opts.append({"label": "Cabo — $%d (encaixa no gerador ou em outro cabo; ligue até a máquina)" % GameData.CABO_PRICE, "disabled": money < GameData.CABO_PRICE, "action": start_placing.bind("cabo", 0)})
	for t in 5:
		var gt: Dictionary = GameData.GERADOR_TIERS[t]
		var glabel := "%s — $%d %s (fornece %d de energia)" % [String(gt["name"]), int(gt["money"]), _bars_cost_text(gt["bars"]), int(gt["power"])]
		opts.append({"label": glabel, "disabled": not can_afford(int(gt["money"]), gt["bars"]), "action": start_placing.bind("gerador", t)})
	opts.append({"label": "— ESTRUTURAS —", "disabled": true, "action": _noop})
	for st_key in ["fundacao", "piso", "parede", "escada", "cerca"]:
		var st_price: int = int(GameData.STRUCT_PRICES[st_key])
		var st_label := "%s — $%d (Q/E ou roda gira a peça)" % [_machine_name(st_key, 0), st_price]
		opts.append({"label": st_label, "disabled": money < st_price, "action": start_placing.bind(st_key, 0)})
	opts.append({"label": "Cadinho — $%d (funde 10 minérios em 1 barra)" % CADINHO_PRICE, "disabled": money < CADINHO_PRICE, "action": start_placing.bind("cadinho", 0)})
	opts.append({"label": "Forja — $%d (aquece barras para a bigorna)" % GameData.FORJA_PRICE, "disabled": money < GameData.FORJA_PRICE, "action": start_placing.bind("forja", 0)})
	opts.append({"label": "Bigorna — $%d (forja anéis, adagas, espadas)" % GameData.BIGORNA_PRICE, "disabled": money < GameData.BIGORNA_PRICE, "action": start_placing.bind("bigorna", 0)})
	opts.append({"label": "Polidora — $%d (polidor de gemas brutas)" % GameData.POLIDORA_PRICE, "disabled": money < GameData.POLIDORA_PRICE, "action": start_placing.bind("polidora", 0)})
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
		hud.flash("Modo cano: aproxime da drill ou de outro cano e ele ENCAIXA sozinho. T para sair.")
	elif type == "esteira":
		hud.flash("Modo esteira: encaixa na drill, em outra esteira ou no harvester. T para sair.")
	elif type == "filtro":
		hud.flash("Modo filtro: encaixe na linha de esteiras com um cadinho do lado. Aperte E no filtro para escolher o minério. T para sair.")
	elif type == "registro":
		hud.flash("Modo registro: encaixa na linha de canos. E nele abre/fecha a água. T para sair.")
	elif type == "cabo":
		hud.flash("Modo cabo: comece no gerador e vá encaixando até a polidora/prensa. T para sair.")
	elif type == "gerador":
		hud.flash("Modo gerador: posicione perto das máquinas elétricas e ligue cabos. T para sair.")
	elif type == "bau":
		hud.flash("Modo baú: encoste numa esteira com minério (até 3m) e ele guarda tudo. T para sair.")
	elif type == "silo":
		hud.flash("Modo silo: encoste numa esteira ou drill; o harvester puxa terra dele (3,5m). T para sair.")
	elif type == "fundacao" or type == "piso" or type == "parede" or type == "escada" or type == "cerca":
		hud.flash("Q/E ou roda do mouse giram a peça. Clique para posicionar. T para sair.")
	elif type == "drill":
		hud.flash("Modo drill: Q/E ou roda do mouse GIRA — a seta mostra para onde ela cospe a terra. T para sair.")
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
		"esteira":
			return GameData.ESTEIRA_PRICE
		"filtro":
			return GameData.FILTRO_PRICE
		"bau":
			return GameData.BAU_PRICE
		"silo":
			return GameData.SILO_PRICE
		"registro":
			return GameData.REGISTRO_PRICE
		"cabo":
			return GameData.CABO_PRICE
		"gerador":
			return int(GameData.GERADOR_TIERS[tier]["money"])
		"fundacao", "piso", "parede", "escada", "cerca":
			return int(GameData.STRUCT_PRICES[type])
	return 0


func _machine_bars(type: String, tier: int) -> Dictionary:
	if type == "drill":
		return GameData.DRILL_TIERS[tier]["bars"]
	if type == "harvester":
		return GameData.HARVESTER_TIERS[tier]["bars"]
	if type == "gerador":
		return GameData.GERADOR_TIERS[tier]["bars"]
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
		"esteira":
			return "Esteira"
		"filtro":
			return "Filtro"
		"bau":
			return "Baú"
		"silo":
			return "Silo"
		"registro":
			return "Registro"
		"cabo":
			return "Cabo"
		"gerador":
			return String(GameData.GERADOR_TIERS[tier]["name"])
		"fundacao":
			return "Fundação"
		"piso":
			return "Piso"
		"parede":
			return "Parede"
		"escada":
			return "Escada"
		"cerca":
			return "Cerca"
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
	var pos3 := Vector3(pos.x, _ground_y(pos.x, pos.z), pos.z)
	if placing == "cano":
		if money < GameData.PIPE_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.PIPE_PRICE
		machines.add_pipe(pos3 + Vector3(0.0, 0.4, 0.0))
		hud.flash("Cano instalado! (%d canos) T para sair." % machines.pipes.size())
		return
	if placing == "registro":
		if money < GameData.REGISTRO_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.REGISTRO_PRICE
		machines.add_machine("registro", 0, _aim)
		hud.flash("Registro instalado! E nele para abrir/fechar. T para sair.")
		return
	if placing == "cabo":
		if money < GameData.CABO_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.CABO_PRICE
		machines.add_wire(_aim)
		hud.flash("Cabo instalado! (%d cabos) T para sair." % machines.wires.size())
		return
	if placing == "esteira" or placing == "filtro":
		var price: int = GameData.ESTEIRA_PRICE if placing == "esteira" else GameData.FILTRO_PRICE
		if money < price:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= price
		var eid: int = machines.add_machine(placing, 0, pos3, _esteira_yaw)
		if eid >= 0 and _esteira_prev >= 0:
			machines.set_prev(eid, _esteira_prev)
		hud.flash("%s instalado! T para sair." % _machine_name(placing, 0))
		return
	if placing == "fundacao" or placing == "piso" or placing == "parede" or placing == "escada" or placing == "cerca":
		var st_price: int = int(GameData.STRUCT_PRICES[placing])
		if money < st_price:
			hud.flash("Dinheiro insuficiente!")
			return
		if not machines.nearest_of_type(pos3, placing, 1.0).is_empty():
			hud.flash("Já tem uma peça igual aqui!")
			return
		money -= st_price
		machines.add_machine(placing, 0, pos3, _placing_yaw)
		return
	if not machines.nearest(pos, 1.6, false).is_empty():
		hud.flash("Espaço ocupado!")
		return
	var cost := _machine_cost(placing, placing_tier)
	var bars := _machine_bars(placing, placing_tier)
	if not can_afford(cost, bars):
		hud.flash("Recursos insuficientes!")
		return
	_pay(cost, bars)
	machines.add_machine(placing, placing_tier, pos3, _placing_yaw)
	if placing == "gerador":
		machines.recompute_wires()
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
	machines.recompute_wires()
	hud.flash("Máquina desmontada: +$%d" % refund)


func open_cadinho_menu(m: Dictionary) -> void:
	_menu_machine = m
	var box: Dictionary = m.get("orebox", {})
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		var in_bolso := int(pocket_ores.get(ore_id, 0))
		var in_cadinho := int(box.get(ore_id, 0))
		var have := in_bolso + in_cadinho
		if have >= 10:
			var ore: Dictionary = GameData.ORES[ore_id]
			var label := "Fundir 10 %s (bolso %d + cadinho %d) → 1 barra (vale $%d)" % [String(ore["name"]), in_bolso, in_cadinho, GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _melt.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Junte 10 minérios iguais (no bolso ou mandados pelo filtro) para fundir", "disabled": true, "action": _noop})
	_open_menu("CADINHO — fundir minérios em barras", opts)


func _melt(ore_id: String) -> void:
	var need := 10
	var box: Dictionary = {}
	if not _menu_machine.is_empty():
		box = _menu_machine.get("orebox", {})
	var from_box: int = mini(int(box.get(ore_id, 0)), need)
	if from_box > 0:
		box[ore_id] = int(box[ore_id]) - from_box
		if int(box[ore_id]) <= 0:
			box.erase(ore_id)
		need -= from_box
	if need > 0:
		if int(pocket_ores.get(ore_id, 0)) < need:
			return
		pocket_ores[ore_id] = int(pocket_ores[ore_id]) - need
	pocket_bars[ore_id] = float(pocket_bars.get(ore_id, 0.0)) + 1.0
	sound.play("craft")
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
	sound.play("craft")
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
		sound.play("craft")
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
	sound.play("craft")
	open_prensa_menu()


func open_filtro_menu(m: Dictionary) -> void:
	_menu_machine = m
	var opts: Array = []
	var sel: String = String(m.get("filter", ""))
	for ore_id in GameData.ORE_ORDER:
		var ore: Dictionary = GameData.ORES[ore_id]
		var mark := ""
		if sel == ore_id:
			mark = "  <"
		opts.append({"label": "Desviar: %s%s" % [String(ore["name"]), mark], "action": _set_filter.bind(m, ore_id)})
	opts.append({"label": "Desativar filtro (tudo passa reto)", "action": _set_filter.bind(m, "")})
	_open_menu("FILTRO — o minério escolhido sai da linha para o cadinho do lado", opts)


func _set_filter(m: Dictionary, ore_id: String) -> void:
	m["filter"] = ore_id
	var lamp: MeshInstance3D = m.get("lamp", null)
	if lamp != null and is_instance_valid(lamp):
		var lmat: StandardMaterial3D = lamp.material_override
		if ore_id != "":
			var oc: Color = GameData.ORES[ore_id]["color"]
			lmat.albedo_color = oc
			lmat.emission = oc * 0.5
		else:
			lmat.albedo_color = Color(0.6, 0.6, 0.6)
			lmat.emission = Color(0.15, 0.15, 0.15)
	hud.flash("Filtro ajustado!")
	close_menu()


func buy_picareta() -> void:
	if has_picareta or money < GameData.PICARETA_PRICE:
		return
	money -= GameData.PICARETA_PRICE
	has_picareta = true
	hud.flash("Picareta comprada! Cavar mirando mais de 1,5m abaixo dos pés pode soltar minério extra.")
	sound.play("coins")
	open_merchant_menu()


func buy_rastelo() -> void:
	if has_rastelo or money < GameData.RASTELO_PRICE:
		return
	money -= GameData.RASTELO_PRICE
	has_rastelo = true
	hud.flash("Rastelo comprado! A escovação na bacia rende +1 minério e mais gemas.")
	sound.play("coins")
	open_merchant_menu()


func _collect_bau(m: Dictionary) -> void:
	var store: Dictionary = m["store"]
	var total := 0
	for k in store:
		pocket_ores[k] = int(pocket_ores.get(k, 0)) + int(store[k])
		total += int(store[k])
	store.clear()
	if total > 0:
		hud.flash("Pegou %d minério(s) do baú!" % total)
		sound.play("ding")
	else:
		hud.flash("Baú vazio — encoste numa esteira com minério (até 3m).")


func _toggle_registro(m: Dictionary) -> void:
	m["open"] = not bool(m.get("open", true))
	machines.recompute_water()
	if bool(m["open"]):
		hud.flash("Registro ABERTO — a água volta a passar.")
	else:
		hud.flash("Registro FECHADO — a água parou nesta linha.")
	sound.play("craft")


func _diagnose() -> void:
	if menu_open:
		return
	var target: Dictionary = {}
	if _aim_valid:
		target = machines.nearest(_aim, 5.0)
	if target.is_empty():
		target = machines.nearest(player.global_position, 3.5)
	if target.is_empty():
		hud.show_diag("Nada por perto para diagnosticar.")
		return
	hud.show_diag(_diagnose_text(target))


func _diagnose_text(m: Dictionary) -> String:
	var type: String = m["type"]
	var lines: Array = []
	match type:
		"drill":
			if float(m["water_time"]) > 0.0 or machines.is_pipe_connected_at(m["pos"]):
				lines.append("Água: OK")
			else:
				lines.append("SEM ÁGUA — despeje um balde (E) ou ligue canos até o lago")
			var cap := int(40.0 + 20.0 * float(m["tier"]))
			lines.append("Pilha de terra: %d/%d" % [int(float(m["dirt"])), cap])
			if float(m["dirt"]) >= float(cap) - 1.0:
				lines.append("Pilha cheia! Encoste uma esteira na frente da seta de saída.")
		"esteira", "filtro":
			if int(m["prev"]) >= 0:
				lines.append("Recebe carga da peça anterior (link OK)")
			else:
				lines.append("Cabeça de linha: puxa terra da drill encostada na frente dela")
			var carg: Dictionary = m["cargo"]
			lines.append("Terra: %d | Minério: %d" % [int(float(m["dirt"])), machines.cargo_total(carg)])
			if float(m["dirt"]) <= 0.05 and machines.cargo_total(carg) == 0:
				lines.append("Parada: nada está chegando — verifique a drill ou a peça anterior")
			if type == "filtro":
				var sel: String = String(m.get("filter", ""))
				if sel == "":
					lines.append("Filtro desativado — aperte E nele para escolher o minério")
				else:
					var tem_cad: bool = not machines.nearest_of_type(m["pos"], "cadinho", 3.0).is_empty()
					lines.append("Desviando: %s | cadinho do lado: %s" % [String(GameData.ORES[sel]["name"]), "sim" if tem_cad else "NÃO — coloque um a até 3m"])
		"harvester":
			var caixa: Dictionary = m["caixa"]
			var cg: Dictionary = m["caixa_gems"]
			var total := 0
			for k in caixa:
				total += int(caixa[k])
			for k in cg:
				total += int(cg[k])
			lines.append("Caixa: %d item(ns) (E coleta)" % total)
			if bool(m["active"]):
				lines.append("Recebendo terra: OK")
			else:
				lines.append("Sem terra chegando — drill a até 10m, esteira/silo a até 3,5m")
			var out_b: Dictionary = machines.find_belt_output(m["pos"], 2.6)
			if out_b.is_empty():
				lines.append("Saída: NENHUMA esteira nova por perto — o minério vai para a caixa")
			else:
				lines.append("Saída: esteira conectada")
		"bacia":
			var water_txt := "sim"
			if float(m["water"]) <= 0.2:
				water_txt = "não — despeje um balde (E)"
			lines.append("Terra: %d | Água: %s" % [int(float(m["dirt"])), water_txt])
		"cadinho":
			var box: Dictionary = m.get("orebox", {})
			var parts: Array = []
			for k in box:
				parts.append("%dx %s" % [int(box[k]), String(GameData.ORES[String(k)]["name"])])
			if parts.is_empty():
				lines.append("Cadinho vazio — o filtro manda minério se estiver a 3m")
			else:
				lines.append("No cadinho: " + ", ".join(PackedStringArray(parts)))
		"bau":
			var store: Dictionary = m["store"]
			lines.append("Minério guardado: %d/150 (E para pegar)" % machines.cargo_total(store))
		"silo":
			lines.append("Terra: %d/800" % int(float(m["dirt"])))
		"registro":
			if bool(m.get("open", true)):
				lines.append("ABERTO — água passando (E para fechar)")
			else:
				lines.append("FECHADO — água bloqueada (E para abrir)")
			if machines.is_pipe_connected_at(m["pos"]):
				lines.append("Linha com água até aqui: sim")
			else:
				lines.append("Linha com água até aqui: NÃO — verifique os canos até o lago")
		"gerador":
			var pstats_d: Dictionary = machines.power_stats()
			lines.append("Energia fornecida: %d | Consumo da rede: %d" % [int(pstats_d["supply"]), int(pstats_d["demand"])])
			if machines.is_power_connected_at(m["pos"]):
				lines.append("Cabos ligados neste gerador: sim")
			else:
				lines.append("Cabos ligados neste gerador: NÃO — nenhum cabo a até 2,5m")
			if int(pstats_d["supply"]) < int(pstats_d["demand"]):
				lines.append("REDE SOBRECARREGADA — compre outro gerador e ligue na mesma rede")
		"polidora", "prensa":
			if not machines.is_power_connected_at(m["pos"]):
				lines.append("SEM ENERGIA — leve um cabo do gerador até 2,5m desta máquina")
			elif not machines.power_ok():
				lines.append("REDE SOBRECARREGADA — a soma dos geradores não cobre todas as máquinas elétricas")
			else:
				lines.append("Energia: OK")
		_:
			lines.append("Sem diagnóstico detalhado para esta peça.")
	var titulo := _machine_name(type, int(m["tier"]))
	return "%s\n%s" % [titulo, "\n".join(PackedStringArray(lines))]


func _stress_test() -> void:
	for m in machines.list:
		if bool(m.get("stress", false)) and not bool(m.get("dead", false)):
			machines.remove_machine(int(m["id"]))
	stress_level = (stress_level + 1) % 4
	var n: int = [0, 100, 500, 1000][stress_level]
	if n == 0:
		hud.flash("Teste de estresse: máquinas de teste removidas.")
		return
	var cols := 18
	var spacing := 2.6
	var placed := 0
	for i in n:
		var cx: int = i % cols
		var cz: int = int(float(i) / float(cols))
		var sx: float = -76.0 + float(cx) * spacing
		var sz: float = -70.0 + float(cz) * spacing
		var gy: float = terrain.height_at(sx, sz)
		if gy < -2.0:
			continue
		var sid: int = machines.add_machine("drill", 0, Vector3(sx, gy - 0.05, sz), 0.0)
		if sid < 0:
			break
		machines.list[sid]["stress"] = true
		machines.list[sid]["water_time"] = 1.0e9
		placed += 1
	hud.flash("TESTE DE ESTRESSE: %d drills (F10 avança: 100 → 500 → 1000 → limpar)" % placed)


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
		sound.play("quest")
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
		if placing == "drill":
			return "Clique: posicionar drill | Q/E ou roda do mouse: girar | T: cancelar"
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
		var roof1 := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(3.9, 0.16, 2.1)
		roof1.mesh = rm
		roof1.position = Vector3(0, 2.9, 0.75)
		roof1.rotation.x = deg_to_rad(33.0)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.68, 0.28, 0.2)
		roof1.material_override = rmat
		root.add_child(roof1)
		var roof2 := MeshInstance3D.new()
		var rm2 := BoxMesh.new()
		rm2.size = Vector3(3.9, 0.16, 2.1)
		roof2.mesh = rm2
		roof2.position = Vector3(0, 2.9, -0.75)
		roof2.rotation.x = deg_to_rad(-33.0)
		roof2.material_override = rmat
		root.add_child(roof2)
		_part(root, Vector3(0.35, 0.9, 0.35), Color(0.5, 0.34, 0.28), Vector3(0.9, 3.1, -0.3))
		_part(root, Vector3(0.7, 1.3, 0.1), Color(0.3, 0.2, 0.12), Vector3(0, 0.65, 1.52))
		_part(root, Vector3(0.5, 0.5, 0.08), Color(0.7, 0.85, 0.95), Vector3(-0.9, 1.4, 1.52))
		_part(root, Vector3(0.5, 0.5, 0.08), Color(0.7, 0.85, 0.95), Vector3(0.9, 1.4, 1.52))
		_houses.append(root)
	_merchant_node()
	_board_node()
	_rebuild_village()


func _merchant_node() -> void:
	var root := Node3D.new()
	root.position = Vector3(MERCHANT_POS.x, terrain.height_at(MERCHANT_POS.x, MERCHANT_POS.z), MERCHANT_POS.z)
	add_child(root)
	var wood := Color(0.45, 0.3, 0.18)
	var wood_dark := Color(0.36, 0.24, 0.14)
	_part(root, Vector3(0.1, 2.4, 0.1), wood_dark, Vector3(-1.3, 1.2, -0.9))
	_part(root, Vector3(0.1, 2.4, 0.1), wood_dark, Vector3(1.3, 1.2, -0.9))
	_part(root, Vector3(0.1, 2.4, 0.1), wood_dark, Vector3(-1.3, 1.2, 0.9))
	_part(root, Vector3(0.1, 2.4, 0.1), wood_dark, Vector3(1.3, 1.2, 0.9))
	_part(root, Vector3(3.1, 0.08, 2.1), Color(0.72, 0.22, 0.18), Vector3(0, 2.5, 0))
	_part(root, Vector3(3.1, 0.08, 0.5), Color(0.92, 0.9, 0.84), Vector3(0, 2.58, -0.75))
	_part(root, Vector3(3.1, 0.08, 0.5), Color(0.92, 0.9, 0.84), Vector3(0, 2.58, 0.0))
	_part(root, Vector3(3.1, 0.08, 0.5), Color(0.92, 0.9, 0.84), Vector3(0, 2.58, 0.75))
	_part(root, Vector3(2.7, 0.12, 0.7), Color(0.58, 0.42, 0.26), Vector3(0, 0.95, -1.0))
	_part(root, Vector3(2.7, 0.8, 0.12), Color(0.5, 0.36, 0.22), Vector3(0, 0.45, -1.32))
	_part(root, Vector3(0.5, 0.35, 0.5), Color(0.6, 0.44, 0.26), Vector3(-0.85, 1.18, -1.0))
	_part(root, Vector3(0.4, 0.28, 0.4), Color(0.6, 0.44, 0.26), Vector3(0.75, 1.15, -1.0))
	_part(root, Vector3(0.3, 0.18, 0.3), Color(1.0, 0.78, 0.15), Vector3(-0.85, 1.44, -1.0))
	_part(root, Vector3(0.26, 0.14, 0.26), Color(0.72, 0.45, 0.3), Vector3(0.75, 1.36, -1.0))
	_part(root, Vector3(0.18, 0.75, 0.18), Color(0.22, 0.2, 0.25), Vector3(-0.14, 0.38, 0.15))
	_part(root, Vector3(0.18, 0.75, 0.18), Color(0.22, 0.2, 0.25), Vector3(0.14, 0.38, 0.15))
	_part(root, Vector3(0.54, 0.72, 0.34), Color(0.32, 0.48, 0.72), Vector3(0, 1.12, 0.15))
	_part(root, Vector3(0.42, 0.58, 0.06), Color(0.5, 0.36, 0.22), Vector3(0, 0.98, -0.05))
	_part(root, Vector3(0.56, 0.08, 0.36), Color(0.2, 0.16, 0.12), Vector3(0, 0.82, 0.15))
	_part(root, Vector3(0.14, 0.6, 0.14), Color(0.32, 0.48, 0.72), Vector3(-0.36, 1.1, 0.15))
	_part(root, Vector3(0.14, 0.6, 0.14), Color(0.32, 0.48, 0.72), Vector3(0.36, 1.1, 0.15))
	_part(root, Vector3(0.13, 0.13, 0.13), Color(0.85, 0.65, 0.5), Vector3(-0.36, 0.74, 0.15))
	_part(root, Vector3(0.13, 0.13, 0.13), Color(0.85, 0.65, 0.5), Vector3(0.36, 0.74, 0.15))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.18
	hm.height = 0.36
	head.mesh = hm
	head.position = Vector3(0, 1.7, 0.15)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.85, 0.65, 0.5)
	head.material_override = hmat
	root.add_child(head)
	_part(root, Vector3(0.05, 0.06, 0.03), Color(0.12, 0.1, 0.1), Vector3(-0.07, 1.74, -0.02))
	_part(root, Vector3(0.05, 0.06, 0.03), Color(0.12, 0.1, 0.1), Vector3(0.07, 1.74, -0.02))
	_part(root, Vector3(0.06, 0.1, 0.07), Color(0.78, 0.58, 0.44), Vector3(0, 1.69, -0.03))
	_part(root, Vector3(0.2, 0.15, 0.08), Color(0.78, 0.78, 0.8), Vector3(0, 1.57, -0.02))
	_part(root, Vector3(0.46, 0.05, 0.46), Color(0.28, 0.18, 0.1), Vector3(0, 1.88, 0.15))
	_part(root, Vector3(0.28, 0.18, 0.28), Color(0.28, 0.18, 0.1), Vector3(0, 1.97, 0.15))
	var label := Label3D.new()
	label.text = "MERCADOR — E para falar"
	label.font_size = 96
	label.pixel_size = 0.01
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.0, 0)
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
		var x := float(gx)
		var z: float = terrain.height_at(x, 20.0)
		var wood := Color(0.42, 0.3, 0.18)
		_part(self, Vector3(0.3, 3.0, 0.3), wood, Vector3(x, z + 1.5, 16.0))
		_part(self, Vector3(0.3, 3.0, 0.3), wood, Vector3(x, z + 1.5, 24.0))
		_part(self, Vector3(0.12, 0.18, 8.0), wood, Vector3(x, z + 1.0, 20.0))
		_part(self, Vector3(0.12, 0.18, 8.0), wood, Vector3(x, z + 2.2, 20.0))
		var lab := Label3D.new()
		lab.font_size = 96
		lab.pixel_size = 0.01
		lab.outline_size = 16
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = Vector3(x, z + 3.6, 20.0)
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


func _part(root: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for i in 40:
		var tx := rng.randf_range(-78.0, 78.0)
		var tz := rng.randf_range(-78.0, 78.0)
		if tx > terrain.VILLAGE_MIN.x - 4.0 and tx < terrain.VILLAGE_MAX.x + 4.0 and tz > terrain.VILLAGE_MIN.y - 4.0 and tz < terrain.VILLAGE_MAX.y + 4.0:
			continue
		if Vector2(tx, tz).distance_to(terrain.LAKE_POS) < 13.0:
			continue
		if Vector2(tx, tz).distance_to(Vector2(-40.0, 0.0)) < 8.0:
			continue
		var y: float = terrain.height_at(tx, tz)
		if y < 0.2:
			continue
		var root := Node3D.new()
		root.position = Vector3(tx, y, tz)
		add_child(root)
		_trees.append(root)
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.15
		tm.bottom_radius = 0.22
		tm.height = 2.2
		trunk.mesh = tm
		trunk.position = Vector3(0, 1.1, 0)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.4, 0.28, 0.18)
		trunk.material_override = tmat
		root.add_child(trunk)
		for k in 3:
			var crown := MeshInstance3D.new()
			var cm := SphereMesh.new()
			var r := rng.randf_range(0.85, 1.25)
			cm.radius = r
			cm.height = r * 2.0
			crown.mesh = cm
			crown.position = Vector3(rng.randf_range(-0.6, 0.6), 2.6 + rng.randf_range(0.0, 1.0), rng.randf_range(-0.6, 0.6))
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.22, rng.randf_range(0.38, 0.58), 0.18)
			cmat.roughness = 1.0
			crown.material_override = cmat
			root.add_child(crown)
	for i in 25:
		var rx := rng.randf_range(-78.0, 78.0)
		var rz := rng.randf_range(-78.0, 78.0)
		if rx > terrain.VILLAGE_MIN.x - 3.0 and rx < terrain.VILLAGE_MAX.x + 3.0 and rz > terrain.VILLAGE_MIN.y - 3.0 and rz < terrain.VILLAGE_MAX.y + 3.0:
			continue
		if Vector2(rx, rz).distance_to(terrain.LAKE_POS) < 11.0:
			continue
		var ry: float = terrain.height_at(rx, rz)
		if ry < -1.0:
			continue
		var rock := MeshInstance3D.new()
		var km := SphereMesh.new()
		var kr := rng.randf_range(0.25, 0.7)
		km.radius = kr
		km.height = kr * 2.0
		rock.mesh = km
		rock.position = Vector3(rx, ry + kr * 0.3, rz)
		rock.scale = Vector3(1.0, 0.6, rng.randf_range(0.8, 1.2))
		_rocks.append([rock, kr * 0.3])
		var kmat := StandardMaterial3D.new()
		var kg := rng.randf_range(0.35, 0.55)
		kmat.albedo_color = Color(kg, kg, kg * 1.05)
		kmat.roughness = 0.95
		rock.material_override = kmat
		add_child(rock)


func _settle_scatter() -> void:
	if terrain == null:
		return
	for t in _trees:
		var n: Node3D = t
		if is_instance_valid(n):
			var g: float = terrain.height_at(n.position.x, n.position.z)
			if n.position.y > g + 0.02:
				n.position.y = g
	for r in _rocks:
		var pair: Array = r
		var n2: Node3D = pair[0]
		if is_instance_valid(n2):
			n2.position.y = terrain.height_at(n2.position.x, n2.position.z) + float(pair[1])


func save_game() -> void:
	var mach: Array = []
	for m in machines.list:
		if bool(m.get("dead", false)):
			continue
		var prev_pos := Vector2(1.0e30, 1.0e30)
		if int(m.get("prev", -1)) >= 0:
			var pm: Dictionary = machines.list[int(m["prev"])]
			prev_pos = Vector2(pm["pos"].x, pm["pos"].z)
		if bool(m.get("stress", false)):
			continue
		mach.append([String(m["type"]), int(m["tier"]), m["pos"].x, m["pos"].y, m["pos"].z, float(m["dirt"]), float(m["water"]), float(m["water_time"]), m["caixa"], m["caixa_gems"], float(m.get("yaw", 0.0)), prev_pos.x, prev_pos.y, m.get("cargo", {}), String(m.get("filter", "")), m.get("orebox", {}), bool(m.get("open", true)), m.get("store", {})])
	var pipe_arr: Array = []
	for p in machines.pipes:
		pipe_arr.append([p.x, p.y, p.z])
	var wire_arr: Array = []
	for p in machines.wires:
		wire_arr.append([p.x, p.y, p.z])
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
		"has_picareta": has_picareta,
		"has_rastelo": has_rastelo,
		"debt": debt,
		"total_earned": total_earned,
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"machines": mach,
		"pipes": pipe_arr,
		"wires": wire_arr,
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
	has_picareta = bool(parsed.get("has_picareta", false))
	has_rastelo = bool(parsed.get("has_rastelo", false))
	debt = int(parsed.get("debt", 0))
	total_earned = int(parsed.get("total_earned", 0))
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
		var prev_links: Array = []
		for e in mach:
			if typeof(e) == TYPE_ARRAY and e.size() >= 10:
				var pos := Vector3(float(e[2]), float(e[3]), float(e[4]))
				var yaw := 0.0
				if e.size() >= 11:
					yaw = float(e[10])
				var id: int = machines.add_machine(String(e[0]), int(e[1]), pos, yaw)
				if id >= 0:
					var m: Dictionary = machines.list[id]
					m["dirt"] = float(e[5])
					m["water"] = float(e[6])
					m["water_time"] = float(e[7])
					if typeof(e[8]) == TYPE_DICTIONARY:
						m["caixa"] = e[8]
					if typeof(e[9]) == TYPE_DICTIONARY:
						m["caixa_gems"] = e[9]
					if e.size() >= 14 and typeof(e[13]) == TYPE_DICTIONARY:
						m["cargo"] = e[13]
					if e.size() >= 15:
						m["filter"] = String(e[14])
					if e.size() >= 16 and typeof(e[15]) == TYPE_DICTIONARY:
						m["orebox"] = e[15]
					if e.size() >= 17:
						m["open"] = bool(e[16])
					if e.size() >= 18 and typeof(e[17]) == TYPE_DICTIONARY:
						m["store"] = e[17]
					if e.size() >= 13 and float(e[11]) < 1.0e30:
						prev_links.append([id, float(e[11]), float(e[12])])
		for link in prev_links:
			var lpos := Vector3(float(link[1]), 0.0, float(link[2]))
			var target: Dictionary = machines.find_machine_2d(lpos, "esteira", 0.3)
			if target.is_empty():
				target = machines.find_machine_2d(lpos, "filtro", 0.3)
			if not target.is_empty():
				machines.set_prev(int(link[0]), int(target["id"]))
	var pipe_arr = parsed.get("pipes", [])
	if typeof(pipe_arr) == TYPE_ARRAY:
		for p in pipe_arr:
			if typeof(p) == TYPE_ARRAY and p.size() == 3:
				machines.add_pipe(Vector3(float(p[0]), float(p[1]), float(p[2])))
	var wire_arr = parsed.get("wires", [])
	if typeof(wire_arr) == TYPE_ARRAY:
		for p in wire_arr:
			if typeof(p) == TYPE_ARRAY and p.size() == 3:
				machines.add_wire(Vector3(float(p[0]), float(p[1]), float(p[2])))
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
	_add_key("dump_bucket", KEY_R)
	_add_key("rotate_ccw", KEY_Q)
	_add_key("rotate_cw", KEY_E)
	_add_key("diagnose", KEY_H)
	_add_key("stress", KEY_F10)
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
	sky_mat.sky_top_color = Color(0.22, 0.46, 0.82)
	sky_mat.sky_horizon_color = Color(0.83, 0.88, 0.94)
	sky_mat.ground_bottom_color = Color(0.35, 0.32, 0.28)
	sky_mat.ground_horizon_color = Color(0.78, 0.84, 0.9)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.84, 0.93)
	env.fog_density = 0.0012
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 142, 0)
	fill.light_color = Color(0.6, 0.7, 0.95)
	fill.light_energy = 0.3
	add_child(fill)

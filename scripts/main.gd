extends Node3D
## Núcleo do jogo: monta o mundo, economia, upgrades, objetivos e save.

const SAVE_PATH := "user://savegame.json"
const NUGGET_PRICE := 12

const SHOP_ITEMS := [
	{"id": "shovel2", "name": "Pá de Ferro", "price": 250, "desc": "Cava mais largo, mais fundo e mais rápido."},
	{"id": "shovel3", "name": "Pá de Diamante", "price": 1200, "desc": "Escavação pesada.", "req": "shovel2"},
	{"id": "bucket2", "name": "Balde Grande", "price": 400, "desc": "Carrega 40 pepitas."},
	{"id": "bucket3", "name": "Carreta", "price": 1500, "desc": "Carrega 120 pepitas.", "req": "bucket2"},
	{"id": "pump", "name": "Bomba d'Água", "price": 800, "desc": "Enche de água onde você cava (lavar dobra o ouro)."},
	{"id": "magnet", "name": "Ímã de Pepitas", "price": 1000, "desc": "Coleta pepitas num raio de 7m automaticamente."},
	{"id": "conveyor", "name": "Esteira de Venda", "price": 2000, "desc": "Vende 1 pepita a cada 2s automaticamente."},
]

const OBJECTIVES := [
	{"text": "Colete 10 pepitas de ouro", "reward": 100},
	{"text": "Venda $500 em ouro no total", "reward": 150},
	{"text": "Compre a Pá de Ferro", "reward": 100},
	{"text": "Cave até 5 metros de profundidade", "reward": 250},
	{"text": "Compre a Bomba d'Água", "reward": 300},
	{"text": "Venda $3.000 em ouro no total", "reward": 500},
	{"text": "Cave até 9 metros de profundidade", "reward": 800},
	{"text": "Venda $10.000 em ouro no total", "reward": 2000},
]

var terrain: Node3D
var player: Node3D
var hud: CanvasLayer
var stall_pos := Vector3.ZERO

var money := 30
var bucket := 0
var bucket_cap := 15
var total_collected := 0
var total_sold := 0
var deepest := 0.0
var objective_index := 0
var owned := {}
var dig_cooldown := 0.0
var shop_open := false

var _nuggets: Array[Node3D] = []
var _nugget_material: StandardMaterial3D
var _collect_timer := 0.0
var _conveyor_timer := 0.0
var _autosave_timer := 0.0


func _ready() -> void:
	_setup_input()
	_build_environment()
	terrain = preload("res://scripts/terrain.gd").new()
	add_child(terrain)
	_build_props()
	player = preload("res://scripts/player.gd").new()
	player.terrain = terrain
	player.game = self
	add_child(player)
	player.global_position = Vector3(0, terrain.height_at(0, 20) + 1.0, 20)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	_nugget_material = StandardMaterial3D.new()
	_nugget_material.albedo_color = Color(1.0, 0.78, 0.15)
	_nugget_material.metallic = 0.8
	_nugget_material.roughness = 0.3
	load_game()


func _process(delta: float) -> void:
	dig_cooldown = maxf(0.0, dig_cooldown - delta)
	_collect_timer -= delta
	if _collect_timer <= 0.0:
		_collect_timer = 0.15
		var got := _collect_nuggets(1.6)
		if owned.has("magnet"):
			got += _collect_nuggets(7.0)
		if got > 0:
			_check_objectives()
	if owned.has("conveyor"):
		_conveyor_timer -= delta
		if _conveyor_timer <= 0.0:
			_conveyor_timer = 2.0
			if bucket > 0:
				bucket -= 1
				_sell(1)
	_autosave_timer += delta
	if _autosave_timer >= 30.0:
		_autosave_timer = 0.0
		save_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop"):
		_toggle_shop()
	elif event.is_action_pressed("sell"):
		if not shop_open and near_stall() and bucket > 0:
			var amount := bucket
			bucket = 0
			_sell(amount)
			hud.flash("Vendeu %d pepitas por $%d!" % [amount, amount * NUGGET_PRICE])
	elif event.is_action_pressed("save_game"):
		save_game()
		hud.flash("Jogo salvo!")
	elif event.is_action_pressed("reset_game"):
		reset_game()
	elif event.is_action_pressed("ui_cancel"):
		if shop_open:
			_toggle_shop()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func near_stall() -> bool:
	return player != null and player.global_position.distance_to(stall_pos) < 4.5


func try_dig(hit: Vector3) -> void:
	if dig_cooldown > 0.0 or shop_open:
		return
	if hit.distance_to(player.global_position) > 9.0:
		return
	dig_cooldown = _dig_cooldown()
	if owned.has("pump"):
		terrain.add_water_at(hit, 1.2)
	var nuggets: int = terrain.dig(hit, _dig_radius(), _dig_power())
	deepest = minf(deepest, hit.y)
	for i in nuggets:
		_spawn_nugget(hit)
	_check_objectives()


func can_buy(item: Dictionary) -> bool:
	if owned.has(item["id"]):
		return false
	if item.has("req") and not owned.has(item["req"]):
		return false
	return money >= item["price"]


func buy(id: String) -> void:
	var item := _item(id)
	if item.is_empty() or not can_buy(item):
		return
	money -= item["price"]
	owned[id] = true
	match id:
		"bucket2":
			bucket_cap = 40
		"bucket3":
			bucket_cap = 120
	hud.flash("Comprou: %s!" % item["name"])
	hud.refresh_shop()
	_check_objectives()


func save_game() -> void:
	var nug := []
	for n in _nuggets:
		if is_instance_valid(n):
			nug.append([n.position.x, n.position.y, n.position.z])
	var data := {
		"money": money,
		"bucket": bucket,
		"bucket_cap": bucket_cap,
		"total_collected": total_collected,
		"total_sold": total_sold,
		"deepest": deepest,
		"objective_index": objective_index,
		"owned": owned,
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"heights": Array(terrain.heights),
		"water": Array(terrain.water),
		"nuggets": nug,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


func _dig_radius() -> float:
	if owned.has("shovel3"):
		return 2.6
	if owned.has("shovel2"):
		return 1.9
	return 1.3


func _dig_power() -> float:
	if owned.has("shovel3"):
		return 0.6
	if owned.has("shovel2"):
		return 0.45
	return 0.35


func _dig_cooldown() -> float:
	if owned.has("shovel3"):
		return 0.28
	if owned.has("shovel2"):
		return 0.34
	return 0.42


func _sell(amount: int) -> void:
	var value := amount * NUGGET_PRICE
	money += value
	total_sold += value
	_check_objectives()


func _collect_nuggets(radius: float) -> int:
	var collected := 0
	var i := _nuggets.size() - 1
	while i >= 0:
		var n := _nuggets[i]
		if not is_instance_valid(n):
			_nuggets.remove_at(i)
		elif bucket < bucket_cap and n.global_position.distance_to(player.global_position) < radius:
			_nuggets.remove_at(i)
			n.queue_free()
			bucket += 1
			total_collected += 1
			collected += 1
		i -= 1
	return collected


func _spawn_nugget(pos: Vector3, drop := true) -> void:
	if _nuggets.size() >= 400:
		return
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	m.mesh = mesh
	m.material_override = _nugget_material
	var p := pos + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
	if drop:
		p.y = terrain.height_at(p.x, p.z) + 0.15
	m.position = p
	add_child(m)
	_nuggets.append(m)


func _check_objectives() -> void:
	while objective_index < OBJECTIVES.size() and _objective_done(objective_index):
		var reward: int = OBJECTIVES[objective_index]["reward"]
		money += reward
		objective_index += 1
		hud.flash("Objetivo concluído! +$%d" % reward)


func _objective_done(i: int) -> bool:
	match i:
		0:
			return total_collected >= 10
		1:
			return total_sold >= 500
		2:
			return owned.has("shovel2")
		3:
			return deepest <= -5.0
		4:
			return owned.has("pump")
		5:
			return total_sold >= 3000
		6:
			return deepest <= -9.0
		7:
			return total_sold >= 10000
	return true


func _item(id: String) -> Dictionary:
	for item in SHOP_ITEMS:
		if item["id"] == id:
			return item
	return {}


func _toggle_shop() -> void:
	shop_open = not shop_open
	hud.set_shop_visible(shop_open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if shop_open else Input.MOUSE_MODE_CAPTURED


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("sell", KEY_E)
	_add_key("shop", KEY_B)
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


func _build_props() -> void:
	var sx := 36.0
	var sz := 24.0
	var sy: float = terrain.height_at(sx, sz)
	stall_pos = Vector3(sx, sy, sz)
	var counter := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 1.2, 1.5)
	counter.mesh = box
	counter.position = Vector3(sx, sy + 0.6, sz)
	add_child(counter)
	var roof := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(4.5, 0.2, 2.2)
	roof.mesh = rbox
	roof.position = Vector3(sx, sy + 2.6, sz)
	add_child(roof)
	for pole_x in [-2.0, 2.0]:
		var pole := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.15, 2.6, 0.15)
		pole.mesh = pbox
		pole.position = Vector3(sx + pole_x, sy + 1.3, sz + 0.9)
		add_child(pole)
	var stall_sign := Label3D.new()
	stall_sign.text = "LOJA — aperte E para vender"
	stall_sign.font_size = 128
	stall_sign.pixel_size = 0.01
	stall_sign.outline_size = 20
	stall_sign.position = Vector3(sx, sy + 3.3, sz)
	add_child(stall_sign)
	var fx := -43.5
	var fz := -43.5
	var fy: float = terrain.height_at(fx, fz)
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 2.0
	pipe.mesh = cyl
	pipe.position = Vector3(fx, fy + 1.0, fz)
	add_child(pipe)
	var wsign := Label3D.new()
	wsign.text = "FONTE D'ÁGUA"
	wsign.font_size = 96
	wsign.pixel_size = 0.01
	wsign.outline_size = 16
	wsign.position = Vector3(fx, fy + 2.6, fz)
	add_child(wsign)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	money = int(parsed.get("money", money))
	bucket = int(parsed.get("bucket", 0))
	bucket_cap = int(parsed.get("bucket_cap", bucket_cap))
	total_collected = int(parsed.get("total_collected", 0))
	total_sold = int(parsed.get("total_sold", 0))
	deepest = float(parsed.get("deepest", 0.0))
	objective_index = int(parsed.get("objective_index", 0))
	var saved_owned = parsed.get("owned", {})
	if typeof(saved_owned) == TYPE_DICTIONARY:
		owned = saved_owned
	var h = parsed.get("heights", [])
	if typeof(h) == TYPE_ARRAY and h.size() == terrain.heights.size():
		terrain.heights = PackedFloat32Array(h)
		terrain.rebuild_mesh()
	var w = parsed.get("water", [])
	if typeof(w) == TYPE_ARRAY and w.size() == terrain.water.size():
		terrain.water = PackedFloat32Array(w)
		terrain.rebuild_water_mesh()
	var p = parsed.get("player", [])
	if typeof(p) == TYPE_ARRAY and p.size() == 3:
		player.global_position = Vector3(p[0], p[1], p[2])
	for n in parsed.get("nuggets", []):
		if typeof(n) == TYPE_ARRAY and n.size() == 3:
			_spawn_nugget(Vector3(n[0], n[1], n[2]), false)

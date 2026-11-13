extends Node3D
## Jogador em primeira pessoa (câmera idêntica a Hydroneer).
## Movimento, mira e clique; toda a lógica fica no main (game).

const SPEED := 6.0
const RUN_SPEED := 10.0
const JUMP_SPEED := 6.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0028

var terrain: Node3D
var game: Node3D

var _camera: Camera3D
var _yaw := 0.0
var _pitch := -0.1
var _vy := 0.0
var _shovel: Node3D
var _bucket: Node3D
var _bucket_fill: MeshInstance3D
var _swing := 0.0


func _ready() -> void:
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.position = Vector3(0, 1.6, 0)
	_camera.rotation.x = _pitch
	_camera.current = true
	_camera.far = 400.0
	_build_viewmodel()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if game != null and (game.menu_open or game.map_open or game.hud.intro_visible() or game.hud.title_visible()):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS * 0.6, -1.35, 1.35)
		rotation.y = _yaw
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if terrain == null or game == null:
		return
	if game.menu_open or game.map_open or game.hud.intro_visible() or game.hud.title_visible():
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_vec.x, 0, input_vec.y).rotated(Vector3.UP, _yaw)
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else SPEED
	global_position += dir * speed * delta
	global_position.x = clampf(global_position.x, -terrain.HALF + 2.0, terrain.HALF - 2.0)
	global_position.z = clampf(global_position.z, -terrain.HALF + 2.0, terrain.HALF - 2.0)

	var ground: float = terrain.height_at(global_position.x, global_position.z)
	_vy -= GRAVITY * delta
	if global_position.y <= ground + 0.01 and _vy <= 0.0:
		global_position.y = ground
		_vy = 0.0
		if Input.is_action_just_pressed("jump"):
			_vy = JUMP_SPEED
	global_position.y += _vy * delta
	if global_position.y < ground:
		global_position.y = ground
		_vy = 0.0

	_update_viewmodel(delta)

	var hit := _ground_point()
	if hit != Vector3.ZERO:
		game.update_aim(hit, true)
	else:
		game.update_aim(Vector3.ZERO, false)
	if Input.is_action_just_pressed("dig"):
		game.on_click()
	if Input.is_action_pressed("dig"):
		game.tool_hold(delta)


func _build_viewmodel() -> void:
	_shovel = Node3D.new()
	_camera.add_child(_shovel)
	_shovel.position = Vector3(0.38, -0.42, -0.55)
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.025
	hm.bottom_radius = 0.03
	hm.height = 0.9
	handle.mesh = hm
	handle.rotation = Vector3(deg_to_rad(65.0), 0.0, deg_to_rad(8.0))
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.45, 0.3, 0.18)
	handle.material_override = hmat
	_shovel.add_child(handle)
	var tip := Node3D.new()
	_shovel.add_child(tip)
	tip.position = Vector3(0.03, -0.2, -0.42)
	tip.rotation = Vector3(deg_to_rad(-25.0), 0.0, deg_to_rad(8.0))
	var socket := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.038
	sm.height = 0.14
	socket.mesh = sm
	socket.position = Vector3(0, 0.02, 0)
	var skmat := StandardMaterial3D.new()
	skmat.albedo_color = Color(0.5, 0.52, 0.56)
	skmat.metallic = 0.7
	skmat.roughness = 0.4
	socket.material_override = skmat
	tip.add_child(socket)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.34, 0.05)
	blade.mesh = bm
	blade.position = Vector3(0, -0.2, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.62, 0.64, 0.68)
	bmat.metallic = 0.75
	bmat.roughness = 0.3
	blade.material_override = bmat
	tip.add_child(blade)
	var point := MeshInstance3D.new()
	var pm2 := BoxMesh.new()
	pm2.size = Vector3(0.15, 0.16, 0.05)
	point.mesh = pm2
	point.position = Vector3(0, -0.42, 0)
	point.rotation.z = deg_to_rad(45.0)
	point.material_override = bmat
	tip.add_child(point)

	_bucket = Node3D.new()
	_camera.add_child(_bucket)
	_bucket.position = Vector3(-0.42, -0.5, -0.65)
	_bucket.visible = false
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.11
	cm.height = 0.26
	body.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.18)
	body.material_override = mat
	_bucket.add_child(body)
	_bucket_fill = MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.12
	fm.bottom_radius = 0.09
	fm.height = 0.2
	_bucket_fill.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.4, 0.28, 0.18)
	_bucket_fill.material_override = fmat
	_bucket.add_child(_bucket_fill)


func _update_viewmodel(delta: float) -> void:
	if _shovel == null or game == null:
		return
	var terra: float = game.bucket_terra
	var agua: float = game.bucket_water
	var carrying := terra > 0.0 or agua > 0.0
	_bucket.visible = carrying
	if carrying:
		var mat: StandardMaterial3D = _bucket_fill.material_override
		if agua > 0.0:
			mat.albedo_color = Color(0.2, 0.45, 0.8, 0.75)
			_bucket_fill.scale = Vector3(1.0, 0.8, 1.0)
			_bucket_fill.position.y = 0.064
		else:
			var cap: float = GameData.PA_TIERS[game.pa_tier]["bucket"]
			var frac := clampf(terra / maxf(cap, 0.01), 0.05, 1.0)
			mat.albedo_color = Color(0.4, 0.28, 0.18)
			_bucket_fill.scale = Vector3(1.0, frac, 1.0)
			_bucket_fill.position.y = -0.08 + 0.08 * frac
	if game.dig_cooldown > 0.0:
		_swing = 0.25
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta)
		var k := _swing / 0.25
		_shovel.rotation.x = -0.9 * sin(k * PI)
		_shovel.position.z = -0.55 - 0.15 * sin(k * PI)
	else:
		_shovel.rotation.x = 0.0
		_shovel.position.z = -0.55


func _ground_point() -> Vector3:
	var origin: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z
	var prev := origin
	var t := 1.0
	while t < 60.0:
		var p := origin + dir * t
		if terrain.height_at(p.x, p.z) >= p.y:
			return (prev + p) * 0.5
		prev = p
		t += 0.4
	return Vector3.ZERO

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
var _brush: Node3D
var _swing := 0.0
var _bob := 0.0


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
	if game != null and (game.menu_open or game.map_open or game.driving or game.hud.intro_visible() or game.hud.title_visible()):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS * 0.6, -1.35, 1.35)
		rotation.y = _yaw
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if terrain == null or game == null:
		return
	if game.menu_open or game.map_open or game.driving or game.hud.intro_visible() or game.hud.title_visible():
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_vec.x, 0, input_vec.y).rotated(Vector3.UP, _yaw)
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else SPEED
	global_position += dir * speed * delta
	global_position.x = clampf(global_position.x, -terrain.HALF + 2.0, terrain.HALF - 2.0)
	global_position.z = clampf(global_position.z, -terrain.HALF + 2.0, terrain.HALF - 2.0)

	var ground: float = terrain.height_at(global_position.x, global_position.z)
	if game.showroom_open and global_position.x > -22.0 and global_position.x < 22.0 and global_position.z > -78.0 and global_position.z < -58.0:
		ground = maxf(ground, 28.2)
	if global_position.y <= ground + 0.05 and input_vec.length() > 0.1:
		_bob += delta * (11.0 if Input.is_action_pressed("sprint") else 7.5)
		_camera.position.y = 1.6 + sin(_bob) * 0.035
		_camera.position.x = cos(_bob * 0.5) * 0.02
	else:
		_camera.position.y = lerpf(_camera.position.y, 1.6, delta * 8.0)
		_camera.position.x = lerpf(_camera.position.x, 0.0, delta * 8.0)
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
	else:
		game.end_tool()


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
	var bm := SphereMesh.new()
	bm.radius = 0.16
	bm.height = 0.2
	bm.radial_segments = 12
	bm.rings = 6
	blade.mesh = bm
	blade.scale = Vector3(1.05, 0.7, 0.75)
	blade.position = Vector3(0, -0.24, 0)
	blade.rotation.x = deg_to_rad(18.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.62, 0.64, 0.68)
	bmat.metallic = 0.75
	bmat.roughness = 0.3
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material_override = bmat
	tip.add_child(blade)
	var edge := MeshInstance3D.new()
	var em := TorusMesh.new()
	em.inner_radius = 0.13
	em.outer_radius = 0.17
	edge.mesh = em
	edge.rotation.x = deg_to_rad(18.0)
	edge.position = Vector3(0, -0.24, 0)
	edge.material_override = bmat
	tip.add_child(edge)
	var skin := Color(0.85, 0.66, 0.52)
	var hand1 := MeshInstance3D.new()
	var h1m := BoxMesh.new()
	h1m.size = Vector3(0.09, 0.1, 0.13)
	hand1.mesh = h1m
	hand1.position = Vector3(0.02, -0.03, -0.1)
	var skmat2 := StandardMaterial3D.new()
	skmat2.albedo_color = skin
	skmat2.roughness = 0.9
	hand1.material_override = skmat2
	_shovel.add_child(hand1)
	var hand2 := MeshInstance3D.new()
	var h2m := BoxMesh.new()
	h2m.size = Vector3(0.09, 0.1, 0.13)
	hand2.mesh = h2m
	hand2.position = Vector3(-0.01, 0.12, 0.14)
	hand2.material_override = skmat2
	_shovel.add_child(hand2)

	_bucket = Node3D.new()
	_camera.add_child(_bucket)
	_bucket.position = Vector3(-0.42, -0.5, -0.65)
	_bucket.visible = false
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.11
	cm.height = 0.26
	cm.cap_top = false
	body.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material_override = mat
	_bucket.add_child(body)
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rim.inner_radius = 0.125
	rim.outer_radius = 0.155
	rim.mesh = rm
	rim.position = Vector3(0, 0.13, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.35, 0.24, 0.15)
	rim.material_override = rmat
	_bucket.add_child(rim)
	var bail := MeshInstance3D.new()
	var bm3 := CylinderMesh.new()
	bm3.top_radius = 0.008
	bm3.bottom_radius = 0.008
	bm3.height = 0.28
	bail.mesh = bm3
	bail.rotation.z = deg_to_rad(90.0)
	bail.position = Vector3(0, 0.13, 0)
	bail.material_override = rmat
	_bucket.add_child(bail)
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
	var hand3 := MeshInstance3D.new()
	var h3m := BoxMesh.new()
	h3m.size = Vector3(0.09, 0.12, 0.11)
	hand3.mesh = h3m
	hand3.position = Vector3(0.13, 0.08, 0.06)
	var skmat3 := StandardMaterial3D.new()
	skmat3.albedo_color = Color(0.85, 0.66, 0.52)
	skmat3.roughness = 0.9
	hand3.material_override = skmat3
	_bucket.add_child(hand3)

	_brush = Node3D.new()
	_camera.add_child(_brush)
	_brush.position = Vector3(0.36, -0.44, -0.5)
	_brush.visible = false
	var bhandle := MeshInstance3D.new()
	var bhm := CylinderMesh.new()
	bhm.top_radius = 0.018
	bhm.bottom_radius = 0.022
	bhm.height = 0.5
	bhandle.mesh = bhm
	bhandle.rotation = Vector3(deg_to_rad(75.0), 0.0, deg_to_rad(10.0))
	bhandle.material_override = hmat
	_brush.add_child(bhandle)
	var ferrule := MeshInstance3D.new()
	var frm := CylinderMesh.new()
	frm.top_radius = 0.03
	frm.bottom_radius = 0.026
	frm.height = 0.1
	ferrule.mesh = frm
	ferrule.position = Vector3(0.02, -0.16, -0.22)
	ferrule.rotation = Vector3(deg_to_rad(-15.0), 0.0, deg_to_rad(10.0))
	ferrule.material_override = skmat
	_brush.add_child(ferrule)
	var block := MeshInstance3D.new()
	var blm := BoxMesh.new()
	blm.size = Vector3(0.16, 0.06, 0.1)
	block.mesh = blm
	block.position = Vector3(0.03, -0.22, -0.3)
	block.rotation.x = deg_to_rad(-15.0)
	var blmat := StandardMaterial3D.new()
	blmat.albedo_color = Color(0.42, 0.3, 0.18)
	block.material_override = blmat
	_brush.add_child(block)
	for bi in 4:
		var bristle := MeshInstance3D.new()
		var brm := BoxMesh.new()
		brm.size = Vector3(0.15, 0.09, 0.016)
		bristle.mesh = brm
		bristle.position = Vector3(0.03, -0.285, -0.345 + 0.033 * float(bi))
		bristle.rotation.x = deg_to_rad(-15.0)
		var brmat := StandardMaterial3D.new()
		brmat.albedo_color = Color(0.75, 0.68, 0.45)
		bristle.material_override = brmat
		_brush.add_child(bristle)
	var hand4 := MeshInstance3D.new()
	var h4m := BoxMesh.new()
	h4m.size = Vector3(0.09, 0.1, 0.13)
	hand4.mesh = h4m
	hand4.position = Vector3(0.02, -0.03, -0.1)
	hand4.material_override = skmat2
	_brush.add_child(hand4)


func set_brushing(on: bool) -> void:
	if _brush == null:
		return
	_brush.visible = on
	if _shovel != null:
		_shovel.visible = not on


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

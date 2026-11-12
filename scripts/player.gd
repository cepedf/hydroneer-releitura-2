extends Node3D
## Jogador em terceira pessoa com câmera orbital e escavação por raio.

const SPEED := 6.0
const RUN_SPEED := 10.0
const JUMP_SPEED := 6.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0028

var terrain: Node3D
var game: Node3D

var _pivot: Node3D
var _camera: Camera3D
var _yaw := 0.0
var _pitch := -0.55
var _vy := 0.0


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_pivot.add_child(_camera)
	_camera.position = Vector3(0, 7, 9)
	_camera.rotation.x = _pitch
	_camera.current = true
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	add_child(body)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if game != null and game.shop_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS * 0.6, -1.25, -0.1)
		_pivot.rotation.y = _yaw
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if terrain == null or (game != null and game.shop_open):
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

	if Input.is_action_pressed("dig"):
		var hit := _ground_point()
		if hit != Vector3.ZERO:
			game.try_dig(hit)


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

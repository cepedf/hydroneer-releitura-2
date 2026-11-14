extends Node3D
## Máquinas e canos como dados puros + spatial hash. Zero entidades simuladas.
## Processa apenas uma fração das máquinas por frame (janela rotativa).

const CELL := 8.0
const MACHINE_CAP := 20000
const CULL_DIST := 60.0
const LABEL_DIST := 25.0
const AUDIO_POOL_SIZE := 6
const AUDIO_DIST := 22.0
const ORE_CAP := 8

var game: Node3D
var terrain: Node3D

var list: Array = []
var pipes: Array = []
var pipe_nodes: Array = []
var _by_cell := {}
var _pipe_cells := {}
var _connected := {}
var _segments: Array = []
var wires: Array = []
var wire_nodes: Array = []
var _wire_cells := {}
var _wired := {}
var _wire_segments: Array = []
var _wire_mat_on: StandardMaterial3D
var _wire_mat_off: StandardMaterial3D
var _mat_cache := {}
var _spinners: Array = []
var _wire_ghost: Node3D
var _wire_timer := 0.0
var _power_supply := 0
var _power_demand := 0
var _off_switches: Array = []
var _cursor := 0
var _cull_timer := 0.0
var _audio_pool: Array = []
var _pipe_mat_on: StandardMaterial3D
var _pipe_mat_off: StandardMaterial3D
var _ghost: MeshInstance3D
var _pipe_ghost: Node3D
var _belt_ghost: Node3D
var _drill_ghost: Node3D
var _ghost_link: MeshInstance3D


func _ready() -> void:
	_pipe_mat_on = StandardMaterial3D.new()
	_pipe_mat_on.albedo_color = Color(0.3, 0.55, 0.9)
	_pipe_mat_on.metallic = 0.6
	_pipe_mat_on.roughness = 0.4
	_pipe_mat_off = StandardMaterial3D.new()
	_pipe_mat_off.albedo_color = Color(0.45, 0.45, 0.5)
	_pipe_mat_off.albedo_texture = Textures.rust()
	_pipe_mat_off.uv1_triplanar = true
	_pipe_mat_off.uv1_scale = Vector3(0.6, 0.6, 0.6)
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.3, 0.8, 1.0, 0.35)
	_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 1.2, 1.2)
	_ghost.mesh = bm
	_ghost.material_override = gm
	_ghost.visible = false
	add_child(_ghost)
	var pgm := StandardMaterial3D.new()
	pgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pgm.albedo_color = Color(0.35, 0.75, 1.0, 0.55)
	pgm.emission_enabled = true
	pgm.emission = Color(0.1, 0.4, 0.7)
	_pipe_ghost = Node3D.new()
	var pball := MeshInstance3D.new()
	var psm := SphereMesh.new()
	psm.radius = 0.17
	psm.height = 0.34
	pball.mesh = psm
	pball.material_override = pgm
	_pipe_ghost.add_child(pball)
	var pstub := MeshInstance3D.new()
	var pcm := CylinderMesh.new()
	pcm.top_radius = 0.13
	pcm.bottom_radius = 0.13
	pcm.height = 0.6
	pstub.mesh = pcm
	pstub.position = Vector3(0.0, -0.3, 0.0)
	pstub.material_override = pgm
	_pipe_ghost.add_child(pstub)
	_pipe_ghost.visible = false
	add_child(_pipe_ghost)
	_wire_mat_on = StandardMaterial3D.new()
	_wire_mat_on.albedo_color = Color(0.95, 0.8, 0.2)
	_wire_mat_on.metallic = 0.3
	_wire_mat_on.roughness = 0.5
	_wire_mat_on.emission_enabled = true
	_wire_mat_on.emission = Color(0.35, 0.28, 0.05)
	_wire_mat_off = StandardMaterial3D.new()
	_wire_mat_off.albedo_color = Color(0.3, 0.28, 0.25)
	var wgm := StandardMaterial3D.new()
	wgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wgm.albedo_color = Color(1.0, 0.85, 0.25, 0.55)
	wgm.emission_enabled = true
	wgm.emission = Color(0.45, 0.35, 0.05)
	_wire_ghost = Node3D.new()
	var wball := MeshInstance3D.new()
	var wsm := SphereMesh.new()
	wsm.radius = 0.14
	wsm.height = 0.28
	wball.mesh = wsm
	wball.material_override = wgm
	_wire_ghost.add_child(wball)
	var wstub := MeshInstance3D.new()
	var wcm := CylinderMesh.new()
	wcm.top_radius = 0.05
	wcm.bottom_radius = 0.05
	wcm.height = 0.6
	wstub.mesh = wcm
	wstub.position = Vector3(0.0, -0.3, 0.0)
	wstub.material_override = wgm
	_wire_ghost.add_child(wstub)
	_wire_ghost.visible = false
	add_child(_wire_ghost)
	var bgm := StandardMaterial3D.new()
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bgm.albedo_color = Color(1.0, 0.8, 0.2, 0.55)
	bgm.emission_enabled = true
	bgm.emission = Color(0.4, 0.3, 0.05)
	_belt_ghost = MeshInstance3D.new()
	var bbm := BoxMesh.new()
	bbm.size = Vector3(2.0, 0.18, 0.9)
	_belt_ghost.mesh = bbm
	_belt_ghost.material_override = bgm
	_belt_ghost.visible = false
	var gam := StandardMaterial3D.new()
	gam.albedo_color = Color(0.2, 0.95, 0.35, 0.9)
	gam.emission_enabled = true
	gam.emission = Color(0.1, 0.5, 0.15)
	var ga1 := MeshInstance3D.new()
	var gm1 := BoxMesh.new()
	gm1.size = Vector3(0.5, 0.06, 0.12)
	ga1.mesh = gm1
	ga1.position = Vector3(0.3, 0.12, 0)
	ga1.material_override = gam
	_belt_ghost.add_child(ga1)
	var ga2 := MeshInstance3D.new()
	var gm2 := BoxMesh.new()
	gm2.size = Vector3(0.2, 0.06, 0.3)
	ga2.mesh = gm2
	ga2.position = Vector3(0.62, 0.12, 0)
	ga2.material_override = gam
	_belt_ghost.add_child(ga2)
	add_child(_belt_ghost)
	var lgm := StandardMaterial3D.new()
	lgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lgm.albedo_color = Color(0.6, 1.0, 0.9, 0.5)
	lgm.emission_enabled = true
	lgm.emission = Color(0.2, 0.6, 0.5)
	_ghost_link = MeshInstance3D.new()
	var lcm := CylinderMesh.new()
	lcm.top_radius = 0.08
	lcm.bottom_radius = 0.08
	lcm.height = 1.0
	_ghost_link.mesh = lcm
	_ghost_link.material_override = lgm
	_ghost_link.visible = false
	add_child(_ghost_link)
	var dgm := StandardMaterial3D.new()
	dgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dgm.albedo_color = Color(0.4, 0.9, 1.0, 0.4)
	dgm.emission_enabled = true
	dgm.emission = Color(0.2, 0.5, 0.6)
	_drill_ghost = Node3D.new()
	var dbox := MeshInstance3D.new()
	var dbm := BoxMesh.new()
	dbm.size = Vector3(1.2, 1.2, 1.2)
	dbox.mesh = dbm
	dbox.position = Vector3(0, 0.8, 0)
	dbox.material_override = dgm
	_drill_ghost.add_child(dbox)
	var shaft := MeshInstance3D.new()
	var scm := CylinderMesh.new()
	scm.top_radius = 0.06
	scm.bottom_radius = 0.06
	scm.height = 0.9
	shaft.mesh = scm
	shaft.rotation.z = -PI * 0.5
	shaft.position = Vector3(0.75, 0.6, 0)
	shaft.material_override = dgm
	_drill_ghost.add_child(shaft)
	var cone := MeshInstance3D.new()
	var ccm := CylinderMesh.new()
	ccm.top_radius = 0.0
	ccm.bottom_radius = 0.16
	ccm.height = 0.35
	cone.mesh = ccm
	cone.rotation.z = -PI * 0.5
	cone.position = Vector3(1.35, 0.6, 0)
	cone.material_override = dgm
	_drill_ghost.add_child(cone)
	_drill_ghost.visible = false
	add_child(_drill_ghost)


@warning_ignore("integer_division")
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var total := list.size()
	if total > 0:
		var window := maxi(1, total / 4)
		for k in window:
			var idx := (_cursor + k) % total
			var m: Dictionary = list[idx]
			if not bool(m.get("dead", false)):
				_update_machine(m, now)
		_cursor = (_cursor + window) % total
	_wire_timer -= delta
	if _wire_timer <= 0.0:
		_wire_timer = 2.0
		_recompute_wires()
	var pp := Vector3.ZERO
	if game != null and game.player != null:
		pp = game.player.global_position
	for s in _spinners:
		var n: Node3D = s[0]
		if not is_instance_valid(n):
			continue
		var md: Dictionary = s[1]
		if bool(md.get("dead", false)) or not bool(md.get("active", false)):
			continue
		if n.global_position.distance_to(pp) > 40.0:
			continue
		var spd := float(s[2])
		if md.has("spin_factor"):
			spd *= float(md["spin_factor"])
		if String(s[3]) == "z":
			n.rotation.z += delta * spd
		else:
			n.rotation.y += delta * spd
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 0.5
		_cull_and_labels()
		_update_audio()


func _cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL)), int(floor(pos.z / CELL)))


func is_belt(t: String) -> bool:
	return t == "esteira" or t == "filtro" or t == "esteira_v" or t == "splitter"


func nearest_pipe_pos(pos: Vector3) -> Vector3:
	var c := _cell_of(pos)
	var best := Vector3(1.0e30, 1.0e30, 1.0e30)
	var best_d := 1.2
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _pipe_cells.has(key):
				continue
			var ids: Array = _pipe_cells[key]
			for j in ids:
				var p: Vector3 = pipes[int(j)]
				var d := Vector2(p.x - pos.x, p.z - pos.z).length()
				if d < best_d:
					best_d = d
					best = p
	return best


func pipe_factor_at(pos: Vector3) -> float:
	var c := _cell_of(pos)
	var found := false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _pipe_cells.has(key):
				continue
			var ids: Array = _pipe_cells[key]
			for j in ids:
				var idx := int(j)
				var p: Vector3 = pipes[idx]
				if Vector2(p.x, p.z).distance_to(Vector2(pos.x, pos.z)) <= 1.2:
					found = true
					if _connected.has(idx):
						return 1.0
	if found:
		return 0.0
	return 0.6


func add_machine(type: String, tier: int, pos: Vector3, yaw: float = 0.0) -> int:
	if list.size() >= MACHINE_CAP:
		return -1
	var m := {
		"id": list.size(), "type": type, "tier": tier, "pos": pos, "yaw": yaw, "prev": -1,
		"dirt": 0.0, "water": 0.0, "water_time": 0.0, "acc": 0.0,
		"caixa": {}, "caixa_gems": {}, "cargo": {}, "filter": "", "orebox": {}, "diverted": 0, "active": false,
		"store": {}, "open": true, "stress": false, "ore": "", "cooldown": 0.0,
		"dir": 1, "spin_factor": 1.0, "tray": {},
		"last": Time.get_ticks_msec() / 1000.0, "dead": false,
	}
	var visual: Dictionary = _build_visual(type, tier, pos, yaw)
	m["node"] = visual["node"]
	m["label"] = visual["label"]
	m["pile"] = visual["pile"]
	m["bit"] = visual["bit"]
	m["water_mesh"] = visual["water_mesh"]
	m["pile_mat"] = visual["pile_mat"]
	m["lamp"] = visual["lamp"]
	if not is_belt(type) and type != "vein" and type != "registro" and not _is_structure(type):
		var skirt := _box(Vector3(1.4, 0.7, 1.4), Color(0.23, 0.2, 0.17), Vector3(0, -0.22, 0))
		visual["node"].add_child(skirt)
	if visual["node"].has_meta("spinner"):
		_spinners.append([visual["node"].get_meta("spinner"), m, float(visual["node"].get_meta("spin_speed")), "y"])
	if visual["node"].has_meta("spinners"):
		for sp in visual["node"].get_meta("spinners"):
			_spinners.append([sp[0], m, float(sp[1]), String(sp[2])])
	list.append(m)
	var key := _cell_of(pos)
	if not _by_cell.has(key):
		_by_cell[key] = []
	_by_cell[key].append(int(m["id"]))
	return int(m["id"])


func set_prev(id: int, prev_id: int) -> void:
	if id < 0 or id >= list.size():
		return
	var mm: Dictionary = list[id]
	mm["prev"] = prev_id
	update_belt_pitch(id)


func update_belt_pitch(id: int) -> void:
	if id < 0 or id >= list.size():
		return
	var m: Dictionary = list[id]
	if String(m["type"]) != "esteira_v":
		return
	var pid := int(m["prev"])
	var node: Node3D = m["node"]
	if node == null or not is_instance_valid(node):
		return
	node.rotation = Vector3(0.0, float(m["yaw"]), 0.0)
	if pid < 0 or pid >= list.size():
		return
	var pv: Dictionary = list[pid]
	if bool(pv.get("dead", false)):
		return
	var d2 := Vector2(pv["pos"].x - m["pos"].x, pv["pos"].z - m["pos"].z).length()
	if d2 < 0.05:
		return
	var dy: float = float(pv["pos"].y) - float(m["pos"].y)
	if absf(dy) < 0.3:
		return
	node.rotate_object_local(Vector3(0.0, 0.0, 1.0), -atan2(dy, d2))


func invert_belt(id: int) -> String:
	if id < 0 or id >= list.size():
		return ""
	var m: Dictionary = list[id]
	if not is_belt(String(m["type"])):
		return ""
	var child := -1
	for other in list:
		if bool(other.get("dead", false)) or int(other.get("prev", -1)) != id:
			continue
		child = int(other["id"])
		break
	if child < 0:
		return "Sem peça à frente para inverter — o sentido muda trocando de lugar com a próxima esteira"
	var old_prev := int(m["prev"])
	m["prev"] = child
	list[child]["prev"] = old_prev
	m["dir"] = -int(m.get("dir", 1))
	list[child]["dir"] = -int(list[child].get("dir", 1))
	m["yaw"] = float(m["yaw"]) + PI
	var node: Node3D = m["node"]
	if node != null and is_instance_valid(node):
		node.rotation = Vector3(0.0, float(m["yaw"]), 0.0)
	update_belt_pitch(id)
	update_belt_pitch(child)
	return ""


func _transfer_tray(m: Dictionary) -> void:
	var tray: Dictionary = m["tray"]
	if tray.is_empty():
		return
	var side := float(m.get("dir", 1))
	var drop: Vector3 = m["pos"] + Vector3(0.0, 0.0, 1.1 * side).rotated(Vector3.UP, float(m["yaw"]))
	var dest := nearest_of_type(drop, "cadinho", 2.2)
	if dest.is_empty():
		dest = nearest_of_type(drop, "bau", 2.2)
	if dest.is_empty():
		return
	for k in tray.keys():
		var n_t: int = int(tray[k])
		if n_t <= 0:
			continue
		if String(dest["type"]) == "bau":
			var st: Dictionary = dest["store"]
			n_t = mini(n_t, maxi(0, 150 - _cargo_total(st)))
			if n_t <= 0:
				continue
			st[k] = int(st.get(k, 0)) + n_t
		else:
			var box: Dictionary = dest["orebox"]
			box[k] = int(box.get(k, 0)) + n_t
		tray[k] = int(tray[k]) - n_t
		if int(tray[k]) <= 0:
			tray.erase(k)
		m["diverted"] = int(m.get("diverted", 0)) + n_t


func remove_machine(idx: int) -> void:
	if idx < 0 or idx >= list.size():
		return
	var m: Dictionary = list[idx]
	if bool(m.get("dead", false)):
		return
	m["dead"] = true
	var node: Node3D = m["node"]
	if is_instance_valid(node):
		node.queue_free()
	var key := _cell_of(m["pos"])
	if _by_cell.has(key):
		_by_cell[key].erase(idx)


func add_pipe(pos: Vector3) -> void:
	var stub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.13
	cm.bottom_radius = 0.13
	cm.height = 0.6
	stub.mesh = cm
	stub.position = pos + Vector3(0.0, -0.3, 0.0)
	stub.material_override = _pipe_mat_off
	add_child(stub)
	var flange := MeshInstance3D.new()
	var flm := CylinderMesh.new()
	flm.top_radius = 0.2
	flm.bottom_radius = 0.2
	flm.height = 0.08
	flange.mesh = flm
	flange.position = pos + Vector3(0.0, -0.08, 0.0)
	flange.material_override = _cached_mat(Color(0.4, 0.4, 0.44), 0.4, 0.7)
	add_child(flange)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	ball.mesh = sm
	ball.position = pos
	ball.material_override = _pipe_mat_off
	add_child(ball)
	pipes.append(pos)
	pipe_nodes.append(ball)
	var key := _cell_of(pos)
	if not _pipe_cells.has(key):
		_pipe_cells[key] = []
	_pipe_cells[key].append(pipes.size() - 1)
	_recompute_connections()


func add_wire(pos: Vector3) -> void:
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	knob.mesh = sm
	knob.position = pos
	knob.material_override = _wire_mat_off
	add_child(knob)
	var jbox := MeshInstance3D.new()
	var jbm := BoxMesh.new()
	jbm.size = Vector3(0.24, 0.18, 0.16)
	jbox.mesh = jbm
	jbox.position = pos + Vector3(0.0, -0.14, 0.0)
	jbox.material_override = _cached_mat(Color(0.36, 0.3, 0.22), 0.9, 0.0)
	add_child(jbox)
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 0.6
	post.mesh = cm
	post.position = pos + Vector3(0.0, -0.3, 0.0)
	post.material_override = _wire_mat_off
	add_child(post)
	wires.append(pos)
	wire_nodes.append(knob)
	var key := _cell_of(pos)
	if not _wire_cells.has(key):
		_wire_cells[key] = []
	_wire_cells[key].append(wires.size() - 1)
	_recompute_wires()


func snap_cabo(hit: Vector3) -> Dictionary:
	var best := Vector3.ZERO
	var found := false
	var best_d := 3.5
	for p in wires:
		var d := Vector2(hit.x - p.x, hit.z - p.z).length()
		if d < best_d:
			best_d = d
			best = p
			found = true
	if not found:
		for m in list:
			if bool(m.get("dead", false)) or String(m["type"]) != "gerador":
				continue
			var dm: float = Vector2(hit.x - m["pos"].x, hit.z - m["pos"].z).length()
			if dm < best_d:
				best_d = dm
				best = m["pos"] + Vector3(0.0, 1.2, 0.0)
				found = true
	if found:
		var dir := Vector2(hit.x - best.x, hit.z - best.z)
		if dir.length() < 0.15:
			dir = Vector2(1.0, 0.0)
		dir = dir.normalized()
		var np := Vector3(best.x + dir.x * 1.2, 0.0, best.z + dir.y * 1.2)
		np.y = maxf(best.y, terrain.height_at(np.x, np.z) + 0.6)
		return {"pos": np, "from": best, "linked": true}
	return {"pos": Vector3(hit.x, terrain.height_at(hit.x, hit.z) + 0.6, hit.z), "from": Vector3.ZERO, "linked": false}


func snap_pipe(hit: Vector3) -> Dictionary:
	var best := Vector3.ZERO
	var found := false
	var best_d := 3.5
	for p in pipes:
		var d := Vector2(hit.x - p.x, hit.z - p.z).length()
		if d < best_d:
			best_d = d
			best = p
			found = true
	if found:
		var dir := Vector2(hit.x - best.x, hit.z - best.z)
		if dir.length() < 0.15:
			dir = Vector2(1.0, 0.0)
		dir = dir.normalized()
		var np := Vector3(best.x + dir.x * 1.2, 0.0, best.z + dir.y * 1.2)
		np.y = maxf(best.y, terrain.height_at(np.x, np.z) + 0.4)
		return {"pos": np, "from": best, "linked": true}
	var dr := nearest_of_type(hit, "drill", 3.5)
	if not dr.is_empty():
		var dp: Vector3 = dr["pos"]
		var dir2 := Vector2(hit.x - dp.x, hit.z - dp.z)
		if dir2.length() < 0.15:
			dir2 = Vector2(1.0, 0.0)
		dir2 = dir2.normalized()
		var np2 := Vector3(dp.x + dir2.x * 1.3, 0.0, dp.z + dir2.y * 1.3)
		np2.y = terrain.height_at(np2.x, np2.z) + 0.4
		var dyaw_p: float = float(dr.get("yaw", 0.0))
		var inlet: Vector3 = Vector3(0.95, 0.6, 0.0).rotated(Vector3.UP, dyaw_p)
		return {"pos": np2, "from": dp + inlet, "linked": true}
	return {"pos": Vector3(hit.x, terrain.height_at(hit.x, hit.z) + 0.4, hit.z), "from": Vector3.ZERO, "linked": false}


func snap_esteira(hit: Vector3) -> Dictionary:
	var best_id := -1
	var best_d := 3.0
	var c := _cell_of(hit)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _by_cell.has(key):
				continue
			var ids: Array = _by_cell[key]
			for id in ids:
				var idx := int(id)
				var m: Dictionary = list[idx]
				if bool(m.get("dead", false)):
					continue
				var t: String = m["type"]
				if not is_belt(t):
					continue
				var d: float = Vector2(hit.x - m["pos"].x, hit.z - m["pos"].z).length()
				if d < best_d:
					best_d = d
					best_id = idx
	if best_id >= 0:
		var bp: Vector3 = list[best_id]["pos"]
		var dir := Vector2(hit.x - bp.x, hit.z - bp.z)
		if dir.length() < 0.15:
			dir = Vector2(1.0, 0.0)
		dir = dir.normalized()
		var np := Vector3(bp.x + dir.x * 1.6, 0.0, bp.z + dir.y * 1.6)
		var on_pipe := false
		var pipe_p := nearest_pipe_pos(np)
		if pipe_p.x < 1.0e29:
			on_pipe = true
			if Vector2(pipe_p.x - bp.x, pipe_p.z - bp.z).length() >= 1.4:
				np.x = pipe_p.x
				np.z = pipe_p.z
			np.y = pipe_p.y + 0.32
		else:
			np.y = terrain.height_at(np.x, np.z) + 0.05
		var yaw := atan2(-dir.y, dir.x)
		return {"pos": np, "yaw": yaw, "prev_id": best_id, "from": bp, "linked": true, "on_pipe": on_pipe}
	var pipe_hit := nearest_pipe_pos(hit)
	if pipe_hit.x < 1.0e29:
		var dir_p := Vector2(hit.x - pipe_hit.x, hit.z - pipe_hit.z)
		if dir_p.length() < 0.15:
			dir_p = Vector2(1.0, 0.0)
		dir_p = dir_p.normalized()
		var np_p := Vector3(pipe_hit.x, pipe_hit.y + 0.32, pipe_hit.z)
		var yaw_p := atan2(-dir_p.y, dir_p.x)
		return {"pos": np_p, "yaw": yaw_p, "prev_id": -1, "from": pipe_hit, "linked": true, "on_pipe": true}
	var dr := nearest_of_type(hit, "drill", 3.5)
	if not dr.is_empty():
		var dp: Vector3 = dr["pos"]
		var dyaw: float = float(dr.get("yaw", 0.0))
		var fwd := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, dyaw)
		var np2: Vector3 = dp + fwd * 1.8
		var on_pipe2 := false
		var pipe_p2 := nearest_pipe_pos(np2)
		if pipe_p2.x < 1.0e29:
			on_pipe2 = true
			if Vector2(pipe_p2.x - dp.x, pipe_p2.z - dp.z).length() >= 1.4:
				np2.x = pipe_p2.x
				np2.z = pipe_p2.z
			np2.y = pipe_p2.y + 0.32
		else:
			np2.y = terrain.height_at(np2.x, np2.z) + 0.05
		var mouth: Vector3 = Vector3(1.2, 0.5, 0.0).rotated(Vector3.UP, dyaw)
		return {"pos": np2, "yaw": dyaw, "prev_id": -1, "from": dp + mouth, "linked": true, "on_pipe": on_pipe2}
	return {"pos": Vector3(hit.x, terrain.height_at(hit.x, hit.z) + 0.05, hit.z), "yaw": 0.0, "prev_id": -1, "from": Vector3.ZERO, "linked": false, "on_pipe": false}


func set_ghost(pos: Vector3) -> void:
	_ghost.visible = true
	_pipe_ghost.visible = false
	_belt_ghost.visible = false
	_drill_ghost.visible = false
	_wire_ghost.visible = false
	_ghost_link.visible = false
	_ghost.position = pos + Vector3(0.0, 0.8, 0.0)


func set_drill_ghost(pos: Vector3, yaw: float) -> void:
	_ghost.visible = false
	_pipe_ghost.visible = false
	_belt_ghost.visible = false
	_drill_ghost.visible = true
	_drill_ghost.position = pos
	_drill_ghost.rotation = Vector3(0.0, yaw, 0.0)
	_wire_ghost.visible = false
	_ghost_link.visible = false


func set_pipe_ghost(pos: Vector3, from: Vector3, linked: bool) -> void:
	_ghost.visible = false
	_belt_ghost.visible = false
	_drill_ghost.visible = false
	_wire_ghost.visible = false
	_pipe_ghost.visible = true
	_pipe_ghost.position = pos
	_show_link(from, pos, linked)


func set_wire_ghost(pos: Vector3, from: Vector3, linked: bool) -> void:
	_ghost.visible = false
	_belt_ghost.visible = false
	_drill_ghost.visible = false
	_pipe_ghost.visible = false
	_wire_ghost.visible = true
	_wire_ghost.position = pos
	_show_link(from, pos, linked)


func set_belt_ghost(pos: Vector3, yaw: float, from: Vector3, linked: bool) -> void:
	_ghost.visible = false
	_pipe_ghost.visible = false
	_drill_ghost.visible = false
	_wire_ghost.visible = false
	_belt_ghost.visible = true
	_belt_ghost.position = pos + Vector3(0.0, 0.25, 0.0)
	_belt_ghost.rotation = Vector3(0.0, yaw, 0.0)
	_show_link(from, pos, linked)


func _show_link(from: Vector3, to: Vector3, linked: bool) -> void:
	if not linked:
		_ghost_link.visible = false
		return
	var d := from.distance_to(to)
	if d < 0.05:
		_ghost_link.visible = false
		return
	var cm: CylinderMesh = _ghost_link.mesh
	cm.height = d
	_ghost_link.position = (from + to) * 0.5
	_ghost_link.look_at(to, Vector3.UP)
	_ghost_link.rotate_object_local(Vector3(1.0, 0.0, 0.0), PI * 0.5)
	_ghost_link.visible = true


func hide_ghost() -> void:
	_ghost.visible = false
	_pipe_ghost.visible = false
	_belt_ghost.visible = false
	_drill_ghost.visible = false
	_wire_ghost.visible = false
	_ghost_link.visible = false


func _cargo_total(cargo: Dictionary) -> int:
	var t := 0
	for k in cargo:
		t += int(cargo[k])
	return t


func _find_belt_output(pos: Vector3, max_dist: float) -> Dictionary:
	var c := _cell_of(pos)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _by_cell.has(key):
				continue
			var ids: Array = _by_cell[key]
			for id in ids:
				var idx := int(id)
				var mm: Dictionary = list[idx]
				if bool(mm.get("dead", false)):
					continue
				var t: String = mm["type"]
				if not is_belt(t):
					continue
				if int(mm["prev"]) != -1:
					continue
				if pos.distance_to(mm["pos"]) <= max_dist and _cargo_total(mm["cargo"]) < ORE_CAP:
					return mm
	return {}


func _is_structure(t: String) -> bool:
	return t == "fundacao" or t == "piso" or t == "parede" or t == "escada" or t == "cerca"


func recompute_water() -> void:
	_recompute_connections()


func recompute_wires() -> void:
	_recompute_wires()


func is_power_connected_at(pos: Vector3) -> bool:
	var c := _cell_of(pos)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _wire_cells.has(key):
				continue
			var ids: Array = _wire_cells[key]
			for j in ids:
				var idx := int(j)
				if not _wired.has(idx):
					continue
				var p: Vector3 = wires[idx]
				if Vector2(p.x, p.z).distance_to(Vector2(pos.x, pos.z)) <= 2.5:
					return true
	return false


func power_ok() -> bool:
	return _power_supply >= _power_demand


func is_shut_down(pos: Vector3) -> bool:
	for sw in _off_switches:
		var sp: Vector3 = sw
		if Vector2(sp.x, sp.z).distance_to(Vector2(pos.x, pos.z)) <= 10.0:
			return true
	return false


func power_stats() -> Dictionary:
	return {"supply": _power_supply, "demand": _power_demand}


func _recompute_wires() -> void:
	_wired.clear()
	var queue: Array = []
	for m in list:
		if bool(m.get("dead", false)) or String(m["type"]) != "gerador":
			continue
		var gp: Vector3 = m["pos"] + Vector3(0.0, 1.2, 0.0)
		var c := _cell_of(gp)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var key := Vector2i(c.x + dx, c.y + dz)
				if not _wire_cells.has(key):
					continue
				var ids: Array = _wire_cells[key]
				for j in ids:
					var idx := int(j)
					if wires[idx].distance_to(gp) <= 2.5 and not _wired.has(idx):
						_wired[idx] = true
						queue.append(idx)
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		for j in _wire_neighbors(wires[i], i):
			if not _wired.has(int(j)):
				_wired[int(j)] = true
				queue.append(int(j))
	for i in wires.size():
		var node: MeshInstance3D = wire_nodes[i]
		if _wired.has(i):
			node.material_override = _wire_mat_on
		else:
			node.material_override = _wire_mat_off
	for s in _wire_segments:
		s.queue_free()
	_wire_segments.clear()
	for i in wires.size():
		if not _wired.has(i):
			continue
		for j in _wire_neighbors(wires[i], i):
			if int(j) <= i:
				continue
			_add_wire_segment(wires[i], wires[int(j)])
	_power_supply = 0
	_power_demand = 0
	for m in list:
		if bool(m.get("dead", false)):
			continue
		var t: String = m["type"]
		if t == "gerador":
			_power_supply += int(GameData.GERADOR_TIERS[int(m["tier"])]["power"])
		elif t == "polidora" or t == "prensa":
			_power_demand += 1
	_off_switches.clear()
	for m in list:
		if bool(m.get("dead", false)) or String(m["type"]) != "interruptor":
			continue
		if not bool(m.get("open", true)):
			_off_switches.append(m["pos"])


func _wire_neighbors(pi: Vector3, self_idx: int) -> Array:
	var out: Array = []
	var c := _cell_of(pi)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _wire_cells.has(key):
				continue
			var ids: Array = _wire_cells[key]
			for j in ids:
				var idx := int(j)
				if idx == self_idx:
					continue
				var pj: Vector3 = wires[idx]
				if pj.distance_to(pi) <= 1.6:
					out.append(idx)
	return out


func _add_wire_segment(a: Vector3, b: Vector3) -> void:
	var d := a.distance_to(b)
	if d < 0.05:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.04
	cm.height = d
	mi.mesh = cm
	mi.position = (a + b) * 0.5
	add_child(mi)
	mi.look_at(b, Vector3.UP)
	mi.rotate_object_local(Vector3(1.0, 0.0, 0.0), PI * 0.5)
	mi.material_override = _wire_mat_on
	_wire_segments.append(mi)


func cargo_total(cargo: Dictionary) -> int:
	return _cargo_total(cargo)


func find_belt_output(pos: Vector3, max_dist: float) -> Dictionary:
	return _find_belt_output(pos, max_dist)


func find_dirt_source(pos: Vector3, want_type: String, max_dist: float) -> Dictionary:
	return _find_dirt_source(pos, want_type, max_dist)


func _find_cargo_source(pos: Vector3, max_dist: float) -> Dictionary:
	var c := _cell_of(pos)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _by_cell.has(key):
				continue
			var ids: Array = _by_cell[key]
			for id in ids:
				var idx := int(id)
				var mm: Dictionary = list[idx]
				if bool(mm.get("dead", false)):
					continue
				var t: String = mm["type"]
				if not is_belt(t):
					continue
				if _cargo_total(mm["cargo"]) <= 0:
					continue
				if pos.distance_to(mm["pos"]) <= max_dist:
					return mm
	return {}


func nearest(pos: Vector3, max_dist: float, include_structures: bool = true) -> Dictionary:
	var best := {}
	var best_d := max_dist
	var c := _cell_of(pos)
	var r := int(ceil(max_dist / CELL)) + 1
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _by_cell.has(key):
				continue
			var ids: Array = _by_cell[key]
			for id in ids:
				var idx := int(id)
				var m: Dictionary = list[idx]
				if bool(m.get("dead", false)):
					continue
				if not include_structures and _is_structure(String(m["type"])):
					continue
				var d: float = pos.distance_to(m["pos"])
				if d < best_d:
					best_d = d
					best = m
	return best


func nearest_of_type(pos: Vector3, type: String, max_dist: float) -> Dictionary:
	var m := nearest(pos, max_dist)
	if m.is_empty():
		return m
	if String(m["type"]) != type:
		return {}
	return m


func find_machine_2d(pos: Vector3, want_type: String, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for m in list:
		if bool(m.get("dead", false)) or String(m["type"]) != want_type:
			continue
		var d: float = Vector2(pos.x - m["pos"].x, pos.z - m["pos"].z).length()
		if d < best_d:
			best_d = d
			best = m
	return best


func is_pipe_connected_at(pos: Vector3) -> bool:
	var c := _cell_of(pos)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _pipe_cells.has(key):
				continue
			var ids: Array = _pipe_cells[key]
			for j in ids:
				var idx := int(j)
				if not _connected.has(idx):
					continue
				var p: Vector3 = pipes[idx]
				if Vector2(p.x, p.z).distance_to(Vector2(pos.x, pos.z)) <= 2.5:
					return true
	return false


func _recompute_connections() -> void:
	_connected.clear()
	var blocked := {}
	for m in list:
		if bool(m.get("dead", false)) or String(m["type"]) != "registro":
			continue
		if bool(m.get("open", true)):
			continue
		for i in pipes.size():
			if pipes[i].distance_to(m["pos"]) <= 1.5:
				blocked[i] = true
	var queue: Array = []
	for i in pipes.size():
		var p: Vector3 = pipes[i]
		if Vector2(p.x, p.z).distance_to(terrain.LAKE_POS) <= 12.0:
			if not _connected.has(i):
				_connected[i] = true
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		for j in _pipe_neighbors(pipes[i], i):
			if blocked.has(j):
				continue
			if not _connected.has(j):
				_connected[j] = true
				queue.append(j)
	for i in pipes.size():
		var node: MeshInstance3D = pipe_nodes[i]
		if _connected.has(i):
			node.material_override = _pipe_mat_on
		else:
			node.material_override = _pipe_mat_off
	for s in _segments:
		s.queue_free()
	_segments.clear()
	for i in pipes.size():
		if not _connected.has(i):
			continue
		for j in _pipe_neighbors(pipes[i], i):
			if int(j) <= i:
				continue
			if not _connected.has(int(j)):
				continue
			_add_segment(pipes[i], pipes[int(j)])


func _add_segment(a: Vector3, b: Vector3) -> void:
	var d := a.distance_to(b)
	if d < 0.05:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11
	cm.bottom_radius = 0.11
	cm.height = d
	mi.mesh = cm
	mi.position = (a + b) * 0.5
	add_child(mi)
	mi.look_at(b, Vector3.UP)
	mi.rotate_object_local(Vector3(1.0, 0.0, 0.0), PI * 0.5)
	mi.material_override = _pipe_mat_on
	_segments.append(mi)


func _pipe_neighbors(pi: Vector3, self_idx: int) -> Array:
	var out: Array = []
	var c := _cell_of(pi)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _pipe_cells.has(key):
				continue
			var ids: Array = _pipe_cells[key]
			for j in ids:
				var idx := int(j)
				if idx == self_idx:
					continue
				var pj: Vector3 = pipes[idx]
				if pj.distance_to(pi) <= 1.6:
					out.append(idx)
	return out


func _find_dirt_source(pos: Vector3, want_type: String, max_dist: float) -> Dictionary:
	var c := _cell_of(pos)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _by_cell.has(key):
				continue
			var ids: Array = _by_cell[key]
			for id in ids:
				var idx := int(id)
				var m: Dictionary = list[idx]
				if bool(m.get("dead", false)):
					continue
				var mt: String = String(m["type"])
				if want_type == "esteira":
					if not is_belt(mt):
						continue
				elif mt != want_type:
					continue
				if float(m["dirt"]) > 0.05 and pos.distance_to(m["pos"]) <= max_dist:
					return m
	return {}


func _update_machine(m: Dictionary, now: float) -> void:
	var last: float = m["last"]
	var dt := clampf(now - last, 0.0, 5.0)
	m["last"] = now
	var type: String = m["type"]
	if (type == "drill" or is_belt(type) or type == "harvester") and is_shut_down(m["pos"]):
		m["active"] = false
		return
	if type == "drill":
		var tier: int = m["tier"]
		var rate: float = GameData.DRILL_TIERS[tier]["rate"]
		var watered := false
		if float(m["water_time"]) > 0.0:
			m["water_time"] = float(m["water_time"]) - dt
			watered = true
		if is_pipe_connected_at(m["pos"]):
			watered = true
		m["active"] = watered
		if watered:
			if not bool(m.get("wet_flag", false)):
				m["wet_flag"] = true
				if game != null:
					game.on_drill_watered()
			var cap := 40.0 + 20.0 * float(tier)
			if float(m["dirt"]) < cap:
				m["dirt"] = minf(float(m["dirt"]) + rate * dt, cap)
			var bit: MeshInstance3D = m["bit"]
			if bit != null:
				bit.rotate_y(dt * 12.0)
			var pile: MeshInstance3D = m["pile"]
			var s := 0.3 + float(m["dirt"]) * 0.03
			pile.scale = Vector3(s, s, s)
			pile.position = Vector3(1.2, 0.5 * s, 0.0)
			pile.visible = float(m["dirt"]) > 0.2
	elif type == "bacia":
		m["water"] = maxf(0.0, float(m["water"]) - dt * 0.003)
		var wm: MeshInstance3D = m["water_mesh"]
		if wm != null:
			var wf := clampf(float(m["water"]) / 1.5, 0.05, 1.0)
			wm.scale = Vector3(1.0, wf, 1.0)
			wm.position.y = 0.27 + 0.15 * wf
			wm.visible = float(m["water"]) > 0.05
		var pile2: MeshInstance3D = m["pile"]
		var s2 := 0.2 + minf(float(m["dirt"]), 20.0) * 0.04
		pile2.scale = Vector3(s2, s2, s2)
		pile2.position = Vector3(0.0, 0.3 + 0.3 * s2, 0.0)
		pile2.visible = float(m["dirt"]) > 0.2
	elif is_belt(type):
		var cap_e := 6.0
		var factor := 1.0
		if type != "filtro":
			factor = pipe_factor_at(m["pos"])
		m["spin_factor"] = factor
		var budget_e := 2.5 * factor * dt
		var prev_id := int(m["prev"])
		if factor <= 0.05:
			m["active"] = false
			return
		if prev_id >= 0:
			var pv: Dictionary = list[prev_id]
			if not bool(pv.get("dead", false)):
				var pt: String = pv["type"]
				if is_belt(pt):
					if float(pv["dirt"]) > 0.0:
						var take_e := minf(budget_e, minf(float(pv["dirt"]), cap_e - float(m["dirt"])))
						if take_e > 0.0:
							pv["dirt"] = float(pv["dirt"]) - take_e
							m["dirt"] = float(m["dirt"]) + take_e
					var cargo: Dictionary = m["cargo"]
					var space: int = ORE_CAP - _cargo_total(cargo)
					var moved: int = 0
					if space > 0:
						var pcargo: Dictionary = pv["cargo"]
						for k in pcargo.keys():
							if moved >= 2 or space - moved <= 0:
								break
							var n: int = int(pcargo[k])
							var mv: int = mini(n, mini(2 - moved, space - moved))
							if mv > 0:
								pcargo[k] = n - mv
								if int(pcargo[k]) <= 0:
									pcargo.erase(k)
								cargo[k] = int(cargo.get(k, 0)) + mv
								moved += mv
		else:
			var src_e := _find_dirt_source(m["pos"], "drill", 2.6)
			if not src_e.is_empty():
				var take2 := minf(budget_e, minf(float(src_e["dirt"]), cap_e - float(m["dirt"])))
				if take2 > 0.0:
					src_e["dirt"] = float(src_e["dirt"]) - take2
					m["dirt"] = float(m["dirt"]) + take2
		if type == "splitter":
			_transfer_tray(m)
		elif type == "filtro":
			var sel: String = String(m["filter"])
			if sel != "":
				var cad: Dictionary = nearest_of_type(m["pos"], "cadinho", 3.0)
				if not cad.is_empty():
					var cargo_f: Dictionary = m["cargo"]
					var n_f: int = int(cargo_f.get(sel, 0))
					if n_f > 0:
						var box: Dictionary = cad["orebox"]
						box[sel] = int(box.get(sel, 0)) + n_f
						cargo_f.erase(sel)
						m["diverted"] = int(m.get("diverted", 0)) + n_f
		var cargo_v: Dictionary = m["cargo"]
		m["active"] = true
		var node_b: Node3D = m["node"]
		if node_b != null and is_instance_valid(node_b):
			if node_b.has_meta("arrow"):
				var ar: Node3D = node_b.get_meta("arrow")
				ar.scale.x = float(m.get("dir", 1))
			if node_b.has_meta("tray"):
				var tr: Node3D = node_b.get_meta("tray")
				tr.position.z = 0.78 * float(m.get("dir", 1))
		var load_m: MeshInstance3D = m["pile"]
		var pmat: StandardMaterial3D = m["pile_mat"]
		var total_c := _cargo_total(cargo_v)
		var best_ore := ""
		var best_n := 0
		for k2 in cargo_v:
			if int(cargo_v[k2]) > best_n:
				best_n = int(cargo_v[k2])
				best_ore = String(k2)
		if total_c > 0 and best_ore != "":
			pmat.albedo_color = GameData.ORES[best_ore]["color"]
			load_m.visible = true
			load_m.scale = Vector3(0.9, 0.45, 0.9)
		elif float(m["dirt"]) > 0.05:
			pmat.albedo_color = Color(0.4, 0.28, 0.18)
			var ls := clampf(float(m["dirt"]) / 6.0, 0.0, 1.0)
			load_m.visible = ls > 0.02
			load_m.scale = Vector3(0.9, 0.3 + ls * 0.7, 0.9)
		else:
			load_m.visible = false
	elif type == "bau":
		var store: Dictionary = m["store"]
		var space_b: int = 150 - _cargo_total(store)
		if space_b > 0:
			var src_b: Dictionary = _find_cargo_source(m["pos"], 3.0)
			if not src_b.is_empty():
				var pcargo: Dictionary = src_b["cargo"]
				var moved_b := 0
				for k in pcargo.keys():
					if moved_b >= 2 or space_b - moved_b <= 0:
						break
					var n: int = int(pcargo[k])
					var mv: int = mini(n, mini(2 - moved_b, space_b - moved_b))
					if mv > 0:
						pcargo[k] = n - mv
						if int(pcargo[k]) <= 0:
							pcargo.erase(k)
						store[k] = int(store.get(k, 0)) + mv
						moved_b += mv
		m["active"] = _cargo_total(store) > 0
	elif type == "silo":
		var cap_s := 800.0
		var budget_s := 3.0 * dt
		if float(m["dirt"]) < cap_s:
			var src_s: Dictionary = _find_dirt_source(m["pos"], "esteira", 3.0)
			if src_s.is_empty():
				src_s = _find_dirt_source(m["pos"], "drill", 3.0)
			if not src_s.is_empty():
				var take_s: float = minf(budget_s, minf(float(src_s["dirt"]), cap_s - float(m["dirt"])))
				if take_s > 0.0:
					src_s["dirt"] = float(src_s["dirt"]) - take_s
					m["dirt"] = float(m["dirt"]) + take_s
		m["active"] = float(m["dirt"]) > 0.05
	elif type == "harvester":
		var tier2: int = m["tier"]
		var rate2: float = GameData.HARVESTER_TIERS[tier2]["rate"]
		var factor_h := pipe_factor_at(m["pos"])
		m["spin_factor"] = factor_h
		if factor_h <= 0.05:
			m["active"] = false
			return
		var budget := rate2 * factor_h * dt
		var in_id := -1
		var in_probe: Dictionary = _find_dirt_source(m["pos"], "esteira", 3.5)
		if not in_probe.is_empty():
			in_id = int(in_probe["id"])
		var got := 0.0
		var guard := 0
		while budget > 0.001 and guard < 40:
			guard += 1
			var src := _find_dirt_source(m["pos"], "drill", 2.6)
			if src.is_empty():
				src = _find_dirt_source(m["pos"], "esteira", 3.5)
			if src.is_empty():
				src = _find_dirt_source(m["pos"], "silo", 3.5)
			if src.is_empty():
				break
			var take := minf(budget, float(src["dirt"]))
			if take <= 0.0001:
				break
			src["dirt"] = float(src["dirt"]) - take
			budget -= take
			got += take
		m["active"] = got > 0.001
		if got > 0.0 and game != null:
			m["acc"] = float(m["acc"]) + got
			var zone := GameData.zone_at(m["pos"].x)
			while float(m["acc"]) >= 1.0:
				m["acc"] = float(m["acc"]) - 1.0
				var ore: String = game.roll_ore(zone)
				if ore != "":
					var out_belt: Dictionary = _find_belt_output(m["pos"], 2.6)
					if not out_belt.is_empty() and int(out_belt["id"]) == in_id:
						out_belt = {}
					if not out_belt.is_empty():
						var bc: Dictionary = out_belt["cargo"]
						bc[ore] = int(bc.get(ore, 0)) + 1
					else:
						var caixa: Dictionary = m["caixa"]
						caixa[ore] = int(caixa.get(ore, 0)) + 1
					game.on_harvester_ore()
				if randf() < 0.05:
					var gem: String = game.roll_gem(zone)
					if gem != "":
						var cg: Dictionary = m["caixa_gems"]
						cg[gem] = int(cg.get(gem, 0)) + 1
	elif type == "vein":
		if float(m.get("cooldown", 0.0)) > 0.0:
			m["cooldown"] = maxf(0.0, float(m["cooldown"]) - dt)
		m["active"] = float(m.get("cooldown", 0.0)) <= 0.0
	elif type == "sensor":
		var src_s: Dictionary = _find_cargo_source(m["pos"], 3.0)
		if not src_s.is_empty():
			var tot_s := _cargo_total(src_s["cargo"])
			var last_tot := int(m.get("last_total", 0))
			if tot_s > last_tot:
				m["count"] = int(m.get("count", 0)) + (tot_s - last_tot)
			m["last_total"] = tot_s
		m["active"] = int(m.get("count", 0)) > 0
	elif type == "alarme":
		var sen: Dictionary = nearest_of_type(m["pos"], "sensor", 6.0)
		if not sen.is_empty():
			var cnt := int(sen.get("count", 0))
			var meta := int(m.get("meta", 50))
			if cnt >= meta and not bool(m.get("fired", false)):
				m["fired"] = true
				if game != null:
					game.on_alarm_fired(meta)
			if cnt < meta:
				m["fired"] = false


func _cull_and_labels() -> void:
	var pp := Vector3.ZERO
	if game != null and game.player != null:
		pp = game.player.global_position
	for m in list:
		if bool(m.get("dead", false)):
			continue
		var node: Node3D = m["node"]
		var pos: Vector3 = m["pos"]
		var dist := pp.distance_to(pos)
		if terrain != null:
			var ground: float = terrain.height_at(pos.x, pos.z)
			if node.position.y > ground + 0.05:
				node.position.y = ground
		node.visible = dist < CULL_DIST
		if String(m["type"]) == "filtro":
			var lamp: MeshInstance3D = m["lamp"]
			if lamp != null and is_instance_valid(lamp):
				var lmat: StandardMaterial3D = lamp.material_override
				var sel2: String = String(m["filter"])
				if sel2 != "":
					lmat.albedo_color = GameData.ORES[sel2]["color"]
					lmat.emission = GameData.ORES[sel2]["color"] * 0.5
				else:
					lmat.albedo_color = Color(0.6, 0.6, 0.6)
					lmat.emission = Color(0.15, 0.15, 0.15)
		if String(m["type"]) == "registro":
			var lamp2: MeshInstance3D = m["lamp"]
			if lamp2 != null and is_instance_valid(lamp2):
				var vmat2: StandardMaterial3D = lamp2.material_override
				if bool(m.get("open", true)):
					vmat2.albedo_color = Color(0.3, 0.8, 0.35)
					vmat2.emission = Color(0.1, 0.4, 0.12)
				else:
					vmat2.albedo_color = Color(0.9, 0.25, 0.2)
					vmat2.emission = Color(0.45, 0.08, 0.05)
		if String(m["type"]) == "interruptor":
			var lamp4: MeshInstance3D = m["lamp"]
			if lamp4 != null and is_instance_valid(lamp4):
				var imat: StandardMaterial3D = lamp4.material_override
				if bool(m.get("open", true)):
					imat.albedo_color = Color(0.3, 0.8, 0.35)
					imat.emission = Color(0.1, 0.4, 0.12)
				else:
					imat.albedo_color = Color(0.9, 0.25, 0.2)
					imat.emission = Color(0.45, 0.08, 0.05)
		if String(m["type"]) == "alarme":
			var lamp5: MeshInstance3D = m["lamp"]
			if lamp5 != null and is_instance_valid(lamp5):
				var amat: StandardMaterial3D = lamp5.material_override
				if bool(m.get("fired", false)):
					amat.albedo_color = Color(1.0, 0.6, 0.1)
					amat.emission = Color(0.5, 0.25, 0.02)
				else:
					amat.albedo_color = Color(0.6, 0.6, 0.6)
					amat.emission = Color(0.15, 0.15, 0.15)
		if String(m["type"]) == "gerador":
			var lamp3: MeshInstance3D = m["lamp"]
			if lamp3 != null and is_instance_valid(lamp3):
				var gmat2: StandardMaterial3D = lamp3.material_override
				if is_power_connected_at(pos):
					gmat2.albedo_color = Color(0.3, 0.8, 0.35)
					gmat2.emission = Color(0.1, 0.4, 0.12)
				else:
					gmat2.albedo_color = Color(0.9, 0.25, 0.2)
					gmat2.emission = Color(0.45, 0.08, 0.05)
		if dist < LABEL_DIST:
			var label: Label3D = m["label"]
			label.text = _status_text(m)


func _update_audio() -> void:
	if game == null or game.sound == null or game.sound.hum_stream == null:
		return
	if _audio_pool.is_empty():
		for i in AUDIO_POOL_SIZE:
			var p := AudioStreamPlayer3D.new()
			p.stream = game.sound.hum_stream
			p.max_distance = float(AUDIO_DIST)
			p.volume_db = -4.0
			add_child(p)
			_audio_pool.append(p)
	var pp := Vector3.ZERO
	if game.player != null:
		pp = game.player.global_position
	var cands: Array = []
	for m in list:
		if bool(m.get("dead", false)) or not bool(m.get("active", false)):
			continue
		var d: float = pp.distance_to(m["pos"])
		if d < float(AUDIO_DIST):
			cands.append([d, m])
	cands.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	for i in _audio_pool.size():
		var pl: AudioStreamPlayer3D = _audio_pool[i]
		if i < cands.size():
			var mm: Dictionary = cands[i][1]
			pl.position = mm["pos"]
			if not pl.playing:
				pl.play()
		elif pl.playing:
			pl.stop()


func _status_text(m: Dictionary) -> String:
	var type: String = m["type"]
	var tier: int = m["tier"]
	var base := ""
	if type == "drill":
		base = String(GameData.DRILL_TIERS[tier]["name"])
	elif type == "harvester":
		base = String(GameData.HARVESTER_TIERS[tier]["name"])
	elif type == "gerador":
		base = String(GameData.GERADOR_TIERS[tier]["name"])
	else:
		if type == "bau":
			base = "Baú"
		elif type == "silo":
			base = "Silo"
		elif type == "fundacao":
			base = "Fundação"
		elif type == "escada":
			base = "Escada"
		elif type == "esteira_v":
			base = "Esteira Vertical"
		elif type == "splitter":
			base = "Divisor de Esteira"
		else:
			base = type.capitalize()
	match type:
		"drill":
			if bool(m["active"]):
				return base + " — terra: %d" % int(float(m["dirt"]))
			return base + " — SEM ÁGUA"
		"harvester":
			var factor_s := pipe_factor_at(m["pos"])
			if factor_s <= 0.05:
				return base + " — SEM ÁGUA (ligue canos ao lago)"
			var agua := "água: %d%%" % int(round(factor_s * 100.0))
			if factor_s < 0.9:
				agua += " (sem cano — encoste num cano ligado ao lago)"
			var caixa: Dictionary = m["caixa"]
			var cg: Dictionary = m["caixa_gems"]
			var total := 0
			for k in caixa:
				total += int(caixa[k])
			for k in cg:
				total += int(cg[k])
			var has_out := not _find_belt_output(m["pos"], 2.6).is_empty()
			var saida := "sim"
			if not has_out:
				saida = "não — encoste uma esteira nova"
			return base + " — %s | caixa: %d (E coleta) | saída p/ esteira: %s" % [agua, total, saida]
		"bacia":
			var water_txt := "sim"
			if float(m["water"]) <= 0.2:
				water_txt = "não"
			return base + " — terra: %d | água: %s" % [int(float(m["dirt"])), water_txt]
		"esteira", "esteira_v", "splitter":
			var carg: Dictionary = m["cargo"]
			var tray2: Dictionary = m.get("tray", {})
			var f := pipe_factor_at(m["pos"])
			var ftxt := "%d%%" % int(round(f * 100.0))
			if f <= 0.05:
				ftxt = "PARADA (cano sem água)"
			elif f < 0.9:
				ftxt = "%d%% (sem cano embaixo)" % int(round(f * 100.0))
			var txt := base + " — terra: %d | minério: %d | velocidade: %s" % [int(float(m["dirt"])), _cargo_total(carg), ftxt]
			if not tray2.is_empty():
				txt += " | bandeja: %d (aguardando cadinho/baú do lado)" % _cargo_total(tray2)
			return txt
		"filtro":
			var sel: String = String(m["filter"])
			var sel_txt := "nenhum (E escolhe)"
			if sel != "":
				sel_txt = String(GameData.ORES[sel]["name"])
			return base + " — desviar: %s | linha: %d | enviados: %d" % [sel_txt, _cargo_total(m["cargo"]), int(m["diverted"])]
		"bau":
			var st: Dictionary = m["store"]
			return base + " — minério: %d/150 (E para pegar)" % _cargo_total(st)
		"silo":
			return base + " — terra: %d/800" % int(float(m["dirt"]))
		"registro":
			if bool(m.get("open", true)):
				return base + " — ABERTO (E fecha a água)"
			return base + " — FECHADO (E abre a água)"
		"gerador":
			var st_g := power_stats()
			var has_wire := is_power_connected_at(m["pos"])
			var rede := "sem cabos ligados"
			if has_wire:
				rede = "rede OK"
			return base + " — energia: %d | consumo: %d | %s" % [int(st_g["supply"]), int(st_g["demand"]), rede]
		"polidora":
			if not is_power_connected_at(m["pos"]):
				return base + " — SEM ENERGIA (ligue cabos a um gerador)"
			if not power_ok():
				return base + " — REDE SOBRECARREGADA (adicione geradores)"
			return base + " — pronta (E pólir gemas)"
		"prensa":
			if not is_power_connected_at(m["pos"]):
				return base + " — SEM ENERGIA (ligue cabos a um gerador)"
			if not power_ok():
				return base + " — REDE SOBRECARREGADA (adicione geradores)"
			return base + " — pronta (E prensar gemas)"
		"sensor":
			return base + " — contagem: %d (E zera)" % int(m.get("count", 0))
		"alarme":
			var sen_st := nearest_of_type(m["pos"], "sensor", 6.0)
			var sen_txt := "nenhum sensor a 6m!"
			if not sen_st.is_empty():
				sen_txt = "sensor em %d/%d" % [int(sen_st.get("count", 0)), int(m.get("meta", 50))]
			if bool(m.get("fired", false)):
				return base + " — META ATINGIDA! (E muda a meta)"
			return base + " — meta: %d | %s" % [int(m.get("meta", 50)), sen_txt]
		"interruptor":
			if bool(m.get("open", true)):
				return base + " — LIGADO (E desliga as máquinas a 10m)"
			return base + " — DESLIGADO (E liga as máquinas)"
		"vein":
			var cd := float(m.get("cooldown", 0.0))
			if cd > 0.0:
				return "Veio — recarregando (%ds)" % int(ceil(cd))
			var ore_v: String = String(m.get("ore", ""))
			if game != null and bool(game.has_detector) and ore_v != "":
				return "Veio de %s pronto (E minerar)" % String(GameData.ORES[ore_v]["name"])
			return "Veio pronto (E minerar)"
		_:
			return base


func _build_visual(type: String, tier: int, pos: Vector3, yaw: float = 0.0) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(0.0, yaw, 0.0)
	add_child(root)
	var band: Color = GameData.TIER_COLORS[tier]
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 12
	var pile := MeshInstance3D.new()
	var pile_mesh := CylinderMesh.new()
	pile_mesh.top_radius = 0.05
	pile_mesh.bottom_radius = 0.7
	pile_mesh.height = 1.0
	pile.mesh = pile_mesh
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.4, 0.28, 0.18)
	pile.material_override = pm
	pile.visible = false
	var bit: MeshInstance3D = null
	var water_mesh: MeshInstance3D = null
	var lamp: MeshInstance3D = null
	var h := 2.4
	if type == "drill":
		var wood := Color(0.42, 0.3, 0.19)
		var steel := Color(0.35, 0.36, 0.4)
		for lx in [-0.55, 0.55]:
			for lz in [-0.55, 0.55]:
				root.add_child(_box(Vector3(0.1, 2.6, 0.1), wood, Vector3(lx, 1.3, lz)))
		for lvl in [0.7, 1.5, 2.3]:
			root.add_child(_box(Vector3(1.2, 0.08, 0.1), steel, Vector3(0, lvl, -0.55)))
			root.add_child(_box(Vector3(1.2, 0.08, 0.1), steel, Vector3(0, lvl, 0.55)))
			root.add_child(_box(Vector3(0.1, 0.08, 1.2), steel, Vector3(-0.55, lvl, 0)))
			root.add_child(_box(Vector3(0.1, 0.08, 1.2), steel, Vector3(0.55, lvl, 0)))
		root.add_child(_box(Vector3(1.3, 0.16, 1.3), steel, Vector3(0, 2.68, 0)))
		root.add_child(_box(Vector3(0.7, 0.5, 0.7), Color(0.45, 0.3, 0.2), Vector3(0, 2.95, 0)))
		root.add_child(_box(Vector3(0.5, 0.45, 0.5), Color(0.5, 0.35, 0.25), Vector3(0.85, 0.35, 0)))
		var hose := _cyl(0.07, 0.95, Color(0.2, 0.2, 0.22), Vector3(0.85, 1.0, 0))
		hose.rotation.z = deg_to_rad(16.0)
		root.add_child(hose)
		root.add_child(_box(Vector3(1.3, 0.25, 1.3), band, Vector3(0, 1.7, 0)))
		bit = _cyl(0.18, 1.1, Color(0.3, 0.3, 0.35), Vector3(0, 0.15, 0))
		var tip2 := MeshInstance3D.new()
		var tm2 := CylinderMesh.new()
		tm2.top_radius = 0.18
		tm2.bottom_radius = 0.02
		tm2.height = 0.3
		tip2.mesh = tm2
		tip2.position = Vector3(0, -0.65, 0)
		tip2.material_override = _cached_mat(Color(0.5, 0.5, 0.55), 0.3, 0.9)
		bit.add_child(tip2)
		root.add_child(bit)
		var inlet := _cyl(0.1, 0.4, Color(0.35, 0.65, 1.0), Vector3(0.75, 0.6, 0.0))
		inlet.rotation.z = PI * 0.5
		root.add_child(inlet)
		var cap := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.09
		gm.height = 0.18
		cap.mesh = gm
		cap.position = Vector3(0.95, 0.6, 0.0)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.3, 0.8, 1.0)
		gmat.emission_enabled = true
		gmat.emission = Color(0.2, 0.6, 0.9)
		gmat.emission_energy_multiplier = 1.5
		cap.material_override = gmat
		root.add_child(cap)
		root.add_child(pile)
		pile.position = Vector3(1.2, 0.4, 0.0)
		label.text = "Drill"
	elif type == "harvester":
		var steel := Color(0.42, 0.43, 0.48)
		for lx in [-0.75, 0.75]:
			for lz in [-0.5, 0.5]:
				root.add_child(_box(Vector3(0.12, 0.5, 0.12), steel, Vector3(lx, 0.25, lz)))
		root.add_child(_box(Vector3(1.8, 0.14, 1.3), steel, Vector3(0, 0.55, 0)))
		root.add_child(_cyl(0.4, 0.7, Color(0.5, 0.5, 0.55), Vector3(0, 0.95, 0)))
		root.add_child(_open_cyl(0.85, 0.22, 0.9, band, Vector3(0, 1.4, 0), 0.5))
		root.add_child(_box(Vector3(0.5, 0.35, 0.9), Color(0.4, 0.4, 0.45), Vector3(1.05, 0.75, 0)))
		root.add_child(_box(Vector3(0.42, 0.1, 0.8), Color(0.15, 0.14, 0.14), Vector3(1.05, 0.95, 0)))
		root.add_child(_box(Vector3(0.6, 0.35, 0.35), Color(0.45, 0.32, 0.2), Vector3(-1.1, 0.75, 0)))
		for a in 6:
			var ang := float(a) / 6.0 * TAU
			var rv := _rivet(Vector3(cos(ang) * 0.42, 1.18, sin(ang) * 0.42), "y")
			rv.rotation = Vector3(PI * 0.5, PI * 0.5 - ang, 0.0)
			root.add_child(rv)
		for fx in [-0.16, 0.16]:
			for fz in [-0.36, 0.36]:
				root.add_child(_rivet(Vector3(1.31, 0.75 + fx, fz), "x"))
		label.text = "Harvester"
	elif type == "bacia":
		var stone := Color(0.52, 0.42, 0.32)
		root.add_child(_open_cyl(1.05, 0.8, 0.7, stone, Vector3(0, 0.35, 0), 0.1))
		root.add_child(_cyl(0.88, 0.14, Color(0.4, 0.32, 0.26), Vector3(0, 0.07, 0)))
		root.add_child(_torus(0.94, 1.12, Color(0.6, 0.48, 0.36), Vector3(0, 0.7, 0), 0.1))
		for lx in [-0.8, 0.8]:
			root.add_child(_box(Vector3(0.18, 0.18, 0.5), Color(0.45, 0.36, 0.28), Vector3(lx, 0.09, 0.95)))
		water_mesh = _cyl(0.9, 0.3, Color(0.25, 0.45, 0.75, 0.8), Vector3(0, 0.42, 0))
		water_mesh.material_override = _cached_mat(Color(0.25, 0.45, 0.75, 0.8), 0.15, 0.4)
		root.add_child(water_mesh)
		root.add_child(pile)
		pile.position = Vector3(0, 0.5, 0)
		h = 1.6
		label.text = "Bacia"
	elif type == "cadinho":
		root.add_child(_open_cyl(0.52, 0.34, 0.72, Color(0.4, 0.33, 0.3), Vector3(0, 0.36, 0), 0.2))
		root.add_child(_cyl(0.36, 0.1, Color(0.3, 0.26, 0.24), Vector3(0, 0.05, 0)))
		root.add_child(_torus(0.46, 0.56, Color(0.48, 0.4, 0.36), Vector3(0, 0.72, 0), 0.2))
		root.add_child(_box(Vector3(0.18, 0.06, 0.3), Color(0.48, 0.4, 0.36), Vector3(0, 0.72, 0.62)))
		for lx in [-0.55, 0.55]:
			root.add_child(_box(Vector3(0.12, 0.5, 0.12), Color(0.3, 0.26, 0.24), Vector3(lx, 0.25, 0.3)))
		h = 1.6
		label.text = "Cadinho"
	elif type == "forja":
		var stone := Color(0.38, 0.35, 0.33)
		root.add_child(_box(Vector3(1.5, 0.5, 1.5), stone, Vector3(0, 0.25, 0)))
		root.add_child(_box(Vector3(1.3, 0.9, 1.3), Color(0.32, 0.29, 0.28), Vector3(0, 0.95, 0)))
		for fx in [-0.55, 0.55]:
			root.add_child(_box(Vector3(0.2, 0.5, 0.2), stone, Vector3(fx, 1.65, -0.55)))
		root.add_child(_box(Vector3(1.3, 0.2, 1.3), stone, Vector3(0, 1.75, 0)))
		for fx2 in [-0.68, 0.68]:
			for fz2 in [-0.68, 0.68]:
				root.add_child(_rivet(Vector3(fx2, 0.52, fz2)))
		var dome := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.62
		dm.height = 0.75
		dome.mesh = dm
		dome.position = Vector3(0, 1.85, 0)
		dome.material_override = _cached_mat(stone, 0.9, 0.0)
		root.add_child(dome)
		var mouth := MeshInstance3D.new()
		var mm2 := BoxMesh.new()
		mm2.size = Vector3(0.7, 0.5, 0.1)
		mouth.mesh = mm2
		mouth.position = Vector3(0, 0.7, 0.68)
		var mmat := StandardMaterial3D.new()
		mmat.albedo_color = Color(1.0, 0.45, 0.1)
		mmat.emission_enabled = true
		mmat.emission = Color(1.0, 0.35, 0.05)
		mmat.emission_energy_multiplier = 1.6
		mouth.material_override = mmat
		root.add_child(mouth)
		root.add_child(_cyl(0.16, 1.2, Color(0.34, 0.31, 0.3), Vector3(0, 2.55, -0.35)))
		root.add_child(_torus(0.13, 0.22, Color(0.3, 0.27, 0.26), Vector3(0, 3.16, -0.35)))
		var smoke := CPUParticles3D.new()
		smoke.amount = 8
		smoke.lifetime = 2.2
		smoke.direction = Vector3(0, 1, 0)
		smoke.spread = 12.0
		smoke.initial_velocity_min = 0.5
		smoke.initial_velocity_max = 1.0
		smoke.gravity = Vector3(0, 0.6, 0)
		smoke.scale_amount_min = 0.3
		smoke.scale_amount_max = 0.8
		var smesh := QuadMesh.new()
		smesh.size = Vector2(0.4, 0.4)
		smoke.mesh = smesh
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.4, 0.4, 0.4, 0.4)
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smesh.material = smat
		smoke.position = Vector3(0, 3.3, -0.35)
		root.add_child(smoke)
		h = 3.4
		label.text = "Forja"
	elif type == "bigorna":
		var steel := Color(0.24, 0.24, 0.28)
		root.add_child(_cyl(0.42, 0.5, Color(0.38, 0.27, 0.17), Vector3(0, 0.25, 0)))
		root.add_child(_box(Vector3(0.55, 0.14, 0.55), Color(0.3, 0.21, 0.13), Vector3(0, 0.55, 0)))
		root.add_child(_box(Vector3(0.7, 0.22, 0.4), steel, Vector3(0, 0.72, 0)))
		root.add_child(_box(Vector3(0.4, 0.3, 0.32), steel, Vector3(0, 0.95, 0)))
		var horn := MeshInstance3D.new()
		var hm2 := CylinderMesh.new()
		hm2.top_radius = 0.14
		hm2.bottom_radius = 0.03
		hm2.height = 0.5
		horn.mesh = hm2
		horn.rotation.z = deg_to_rad(-90.0)
		horn.position = Vector3(0.42, 0.95, 0)
		horn.material_override = _cached_mat(steel, 0.35, 0.8)
		root.add_child(horn)
		root.add_child(_box(Vector3(0.16, 0.1, 0.16), steel, Vector3(0, 1.13, 0)))
		h = 1.6
		label.text = "Bigorna"
	elif type == "polidora":
		root.add_child(_box(Vector3(1.3, 0.12, 0.9), Color(0.45, 0.32, 0.2), Vector3(0, 0.75, 0)))
		for lx in [-0.55, 0.55]:
			for lz in [-0.35, 0.35]:
				root.add_child(_box(Vector3(0.1, 0.7, 0.1), Color(0.38, 0.27, 0.17), Vector3(lx, 0.35, lz)))
		root.add_child(_box(Vector3(0.12, 0.5, 0.12), Color(0.3, 0.3, 0.34), Vector3(0.5, 1.0, 0)))
		var wheel := Node3D.new()
		wheel.position = Vector3(0.62, 1.15, 0)
		root.add_child(wheel)
		var disc := _cyl(0.34, 0.08, band, Vector3(0, 0, 0))
		disc.rotation.x = PI * 0.5
		wheel.add_child(disc)
		wheel.add_child(_cyl(0.07, 0.16, Color(0.3, 0.3, 0.34), Vector3(0, 0, 0)))
		root.set_meta("spinners", [[wheel, 7.0, "z"]])
		var guard := _torus(0.28, 0.42, Color(0.75, 0.55, 0.15), Vector3(0.62, 1.15, 0), 0.6)
		guard.rotation.x = PI * 0.5
		root.add_child(guard)
		h = 2.2
		label.text = "Polidora"
	elif type == "prensa":
		var steel := Color(0.4, 0.41, 0.47)
		for px in [-0.55, 0.55]:
			root.add_child(_box(Vector3(0.18, 2.3, 0.5), steel, Vector3(px, 1.15, 0)))
		root.add_child(_box(Vector3(1.4, 0.25, 0.6), steel, Vector3(0, 2.35, 0)))
		root.add_child(_box(Vector3(1.4, 0.3, 0.7), steel, Vector3(0, 0.15, 0)))
		root.add_child(_box(Vector3(0.9, 0.14, 0.9), Color(0.5, 0.5, 0.55), Vector3(0, 0.37, 0)))
		root.add_child(_box(Vector3(0.6, 1.6, 0.6), Color(0.55, 0.56, 0.6), Vector3(0, 1.5, 0)))
		root.add_child(_box(Vector3(0.7, 0.22, 0.7), band, Vector3(0, 2.12, 0)))
		root.add_child(_box(Vector3(0.3, 0.4, 0.08), Color(0.2, 0.45, 0.3), Vector3(0.72, 1.4, 0)))
		h = 3.0
		label.text = "Prensa"
	elif type == "gerador":
		root.add_child(_box(Vector3(1.6, 0.9, 1.0), Color(0.45, 0.47, 0.52), Vector3(0, 0.55, 0)))
		root.add_child(_box(Vector3(1.7, 0.12, 1.2), Color(0.3, 0.3, 0.34), Vector3(0, 0.06, 0)))
		for fz3 in [-0.3, 0.3]:
			for fy3 in [0.35, 0.75]:
				root.add_child(_rivet(Vector3(0.81, fy3, fz3), "x"))
				root.add_child(_rivet(Vector3(-0.81, fy3, fz3), "x"))
		root.add_child(_cyl(0.28, 0.8, Color(0.5, 0.35, 0.25), Vector3(-0.4, 1.35, 0)))
		root.add_child(_box(Vector3(0.5, 0.35, 0.4), Color(0.35, 0.36, 0.4), Vector3(0.35, 1.2, 0.1)))
		var pipe := _cyl(0.07, 0.7, Color(0.25, 0.25, 0.28), Vector3(0.6, 1.75, -0.25))
		pipe.rotation.z = deg_to_rad(-8.0)
		root.add_child(pipe)
		root.add_child(_box(Vector3(0.45, 0.55, 0.08), Color(0.2, 0.45, 0.3), Vector3(0, 1.0, 0.52)))
		var fan := Node3D.new()
		fan.position = Vector3(-0.4, 1.85, 0)
		root.add_child(fan)
		fan.add_child(_box(Vector3(0.18, 0.7, 0.18), Color(0.3, 0.3, 0.34), Vector3(0, 0, 0)))
		fan.add_child(_box(Vector3(0.5, 0.1, 0.06), Color(0.5, 0.52, 0.56), Vector3(0.1, 0.2, 0)))
		fan.add_child(_box(Vector3(0.5, 0.1, 0.06), Color(0.5, 0.52, 0.56), Vector3(-0.1, -0.2, 0)))
		root.set_meta("spinner", fan)
		root.set_meta("spin_speed", 9.0)
		lamp = MeshInstance3D.new()
		var glm := SphereMesh.new()
		glm.radius = 0.1
		glm.height = 0.2
		lamp.mesh = glm
		lamp.position = Vector3(0.55, 1.95, 0)
		var glmat := StandardMaterial3D.new()
		glmat.albedo_color = Color(0.9, 0.25, 0.2)
		glmat.emission_enabled = true
		glmat.emission = Color(0.45, 0.08, 0.05)
		lamp.material_override = glmat
		root.add_child(lamp)
		h = 2.6
		label.text = "Gerador"
	elif type == "sensor":
		root.add_child(_cyl(0.06, 0.9, Color(0.4, 0.4, 0.45), Vector3(0, 0.45, 0)))
		root.add_child(_box(Vector3(0.34, 0.3, 0.34), Color(0.3, 0.45, 0.6), Vector3(0, 1.0, 0)))
		lamp = MeshInstance3D.new()
		var slm := SphereMesh.new()
		slm.radius = 0.07
		slm.height = 0.14
		lamp.mesh = slm
		lamp.position = Vector3(0, 1.25, 0)
		var slmat := StandardMaterial3D.new()
		slmat.albedo_color = Color(0.3, 0.8, 0.35)
		slmat.emission_enabled = true
		slmat.emission = Color(0.1, 0.4, 0.12)
		lamp.material_override = slmat
		root.add_child(lamp)
		h = 1.8
		label.text = "Sensor"
	elif type == "alarme":
		root.add_child(_box(Vector3(0.5, 0.6, 0.4), Color(0.75, 0.25, 0.2), Vector3(0, 0.3, 0)))
		root.add_child(_cyl(0.18, 0.2, Color(0.9, 0.75, 0.2), Vector3(0, 0.7, 0)))
		lamp = MeshInstance3D.new()
		var alm := SphereMesh.new()
		alm.radius = 0.09
		alm.height = 0.18
		lamp.mesh = alm
		lamp.position = Vector3(0, 0.95, 0)
		var almat := StandardMaterial3D.new()
		almat.albedo_color = Color(0.6, 0.6, 0.6)
		almat.emission_enabled = true
		almat.emission = Color(0.15, 0.15, 0.15)
		lamp.material_override = almat
		root.add_child(lamp)
		h = 1.6
		label.text = "Alarme"
	elif type == "interruptor":
		root.add_child(_box(Vector3(0.4, 0.6, 0.3), Color(0.35, 0.35, 0.4), Vector3(0, 0.3, 0)))
		root.add_child(_box(Vector3(0.08, 0.35, 0.08), Color(0.85, 0.7, 0.2), Vector3(0, 0.65, 0)))
		lamp = MeshInstance3D.new()
		var ilm := SphereMesh.new()
		ilm.radius = 0.07
		ilm.height = 0.14
		lamp.mesh = ilm
		lamp.position = Vector3(0, 0.85, 0)
		var ilmat := StandardMaterial3D.new()
		ilmat.albedo_color = Color(0.3, 0.8, 0.35)
		ilmat.emission_enabled = true
		ilmat.emission = Color(0.1, 0.4, 0.12)
		lamp.material_override = ilmat
		root.add_child(lamp)
		h = 1.4
		label.text = "Interruptor"
	elif type == "vein":
		var vmat := StandardMaterial3D.new()
		vmat.albedo_color = Color(0.35, 0.3, 0.28)
		vmat.roughness = 0.95
		var r1 := _box(Vector3(1.1, 0.7, 0.9), Color.WHITE, Vector3(0, 0.3, 0))
		r1.material_override = vmat
		r1.rotation.y = 0.4
		root.add_child(r1)
		var r2 := _box(Vector3(0.7, 0.5, 0.6), Color.WHITE, Vector3(0.6, 0.25, 0.4))
		r2.material_override = vmat
		r2.rotation.y = -0.7
		root.add_child(r2)
		var r3 := _box(Vector3(0.5, 0.4, 0.5), Color.WHITE, Vector3(-0.55, 0.2, -0.3))
		r3.material_override = vmat
		r3.rotation.y = 1.1
		root.add_child(r3)
		var glint := MeshInstance3D.new()
		var gmesh := SphereMesh.new()
		gmesh.radius = 0.09
		gmesh.height = 0.18
		glint.mesh = gmesh
		glint.position = Vector3(0.15, 0.55, 0.1)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.6, 0.6, 0.6)
		gmat.emission_enabled = true
		gmat.emission = Color(0.1, 0.1, 0.1)
		gmat.emission_energy_multiplier = 1.6
		glint.material_override = gmat
		root.add_child(glint)
		root.set_meta("vein_mat", vmat)
		root.set_meta("glint_mat", gmat)
		h = 1.6
		label.text = "Veio"
	elif type == "filtro":
		root.add_child(_box(Vector3(2.0, 0.14, 0.9), Color(0.32, 0.3, 0.34), Vector3(0, 0.25, 0)))
		root.add_child(_box(Vector3(2.1, 0.1, 0.08), Color(0.75, 0.62, 0.2), Vector3(0, 0.33, 0.44)))
		root.add_child(_box(Vector3(2.1, 0.1, 0.08), Color(0.75, 0.62, 0.2), Vector3(0, 0.33, -0.44)))
		root.add_child(_cyl(0.18, 0.95, Color(0.35, 0.35, 0.4), Vector3(-0.95, 0.25, 0)))
		root.add_child(_cyl(0.18, 0.95, Color(0.35, 0.35, 0.4), Vector3(0.95, 0.25, 0)))
		root.add_child(_box(Vector3(0.7, 0.5, 0.6), Color(0.5, 0.45, 0.4), Vector3(0, 0.55, 0.75)))
		lamp = MeshInstance3D.new()
		var lbm := BoxMesh.new()
		lbm.size = Vector3(0.28, 0.28, 0.28)
		lamp.mesh = lbm
		lamp.position = Vector3(0, 1.0, 0)
		var lmat0 := StandardMaterial3D.new()
		lmat0.albedo_color = Color(0.6, 0.6, 0.6)
		lmat0.emission_enabled = true
		lmat0.emission = Color(0.15, 0.15, 0.15)
		lamp.material_override = lmat0
		root.add_child(lamp)
		root.add_child(pile)
		pile.position = Vector3(0.0, 0.42, 0.0)
		pile.visible = false
		h = 1.8
		label.text = "Filtro"
	elif type == "registro":
		root.add_child(_cyl(0.17, 0.7, Color(0.5, 0.5, 0.55), Vector3(0, 0.2, 0)))
		lamp = MeshInstance3D.new()
		var vm := TorusMesh.new()
		vm.inner_radius = 0.16
		vm.outer_radius = 0.3
		lamp.mesh = vm
		lamp.position = Vector3(0, 0.55, 0)
		lamp.rotation.x = PI * 0.5
		var vmat := StandardMaterial3D.new()
		vmat.albedo_color = Color(0.3, 0.8, 0.35)
		vmat.metallic = 0.4
		vmat.roughness = 0.4
		vmat.emission_enabled = true
		vmat.emission = Color(0.1, 0.4, 0.12)
		lamp.material_override = vmat
		root.add_child(lamp)
		h = 1.6
		label.text = "Registro"
	elif type == "bau":
		var wcol := Color(0.5, 0.34, 0.19)
		root.add_child(_box(Vector3(1.4, 0.7, 0.9), wcol, Vector3(0, 0.35, 0)))
		root.add_child(_box(Vector3(1.44, 0.06, 0.94), Color(0.36, 0.24, 0.13), Vector3(0, 0.03, 0)))
		var lid := Node3D.new()
		lid.position = Vector3(0, 0.7, -0.45)
		lid.rotation.x = deg_to_rad(-65.0)
		lid.add_child(_box(Vector3(1.4, 0.08, 0.9), wcol, Vector3(0, 0.04, 0.45)))
		lid.add_child(_box(Vector3(1.42, 0.1, 0.08), Color(0.32, 0.22, 0.13), Vector3(0, 0.04, 0.88)))
		root.add_child(lid)
		for cx in [-0.62, 0.62]:
			root.add_child(_box(Vector3(0.08, 0.74, 0.94), Color(0.65, 0.66, 0.7), Vector3(cx, 0.35, 0)))
		root.add_child(_box(Vector3(0.16, 0.2, 0.06), Color(0.85, 0.7, 0.2), Vector3(0, 0.62, 0.46)))
		root.add_child(_box(Vector3(0.06, 0.06, 0.12), Color(0.85, 0.7, 0.2), Vector3(0, 0.55, 0.5)))
		h = 1.6
		label.text = "Baú"
	elif type == "silo":
		root.add_child(_cyl(0.85, 1.9, Color(0.68, 0.69, 0.74), Vector3(0, 1.25, 0)))
		root.add_child(_cyl(0.95, 0.14, band, Vector3(0, 2.12, 0)))
		var cone := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.05
		cm2.bottom_radius = 0.92
		cm2.height = 0.6
		cone.mesh = cm2
		cone.position = Vector3(0, 2.5, 0)
		cone.material_override = _cached_mat(Color(0.55, 0.56, 0.62), 0.4, 0.6)
		root.add_child(cone)
		for lx in [-0.6, 0.6]:
			for lz in [-0.6, 0.6]:
				root.add_child(_box(Vector3(0.1, 0.35, 0.1), Color(0.3, 0.3, 0.35), Vector3(lx, 0.17, lz)))
		root.add_child(_box(Vector3(0.3, 0.4, 0.06), Color(0.45, 0.3, 0.2), Vector3(0, 0.4, 0.87)))
		h = 3.4
		label.text = "Silo"
	elif type == "fundacao":
		root.add_child(_box(Vector3(2.0, 0.25, 2.0), Color(0.6, 0.58, 0.56), Vector3(0, 0.12, 0)))
		for bx in [-0.94, 0.94]:
			root.add_child(_box(Vector3(0.12, 0.34, 2.0), Color(0.5, 0.48, 0.46), Vector3(bx, 0.17, 0)))
		for bz in [-0.94, 0.94]:
			root.add_child(_box(Vector3(2.0, 0.34, 0.12), Color(0.5, 0.48, 0.46), Vector3(0, 0.17, bz)))
		h = 1.2
		label.text = "Fundação"
	elif type == "piso":
		root.add_child(_box(Vector3(2.0, 0.14, 2.0), Color(0.55, 0.4, 0.26), Vector3(0, 0.35, 0)))
		root.add_child(_box(Vector3(2.0, 0.05, 0.12), Color(0.45, 0.32, 0.2), Vector3(0, 0.44, 0.6)))
		root.add_child(_box(Vector3(2.0, 0.05, 0.12), Color(0.45, 0.32, 0.2), Vector3(0, 0.44, 0.0)))
		root.add_child(_box(Vector3(2.0, 0.05, 0.12), Color(0.45, 0.32, 0.2), Vector3(0, 0.44, -0.6)))
		h = 1.2
		label.text = "Piso"
	elif type == "parede":
		root.add_child(_box(Vector3(2.0, 2.0, 0.16), Color(0.85, 0.8, 0.7), Vector3(0, 1.0, 0)))
		root.add_child(_box(Vector3(2.1, 0.12, 0.24), Color(0.5, 0.36, 0.24), Vector3(0, 2.05, 0)))
		root.add_child(_box(Vector3(2.1, 0.14, 0.26), Color(0.5, 0.36, 0.24), Vector3(0, 0.08, 0)))
		for wx in [-0.95, 0.95]:
			root.add_child(_box(Vector3(0.14, 2.0, 0.2), Color(0.5, 0.36, 0.24), Vector3(wx, 1.0, 0)))
		h = 2.6
		label.text = "Parede"
	elif type == "escada":
		for side in [-0.42, 0.42]:
			var st := _box(Vector3(0.06, 0.18, 3.2), Color(0.45, 0.33, 0.2), Vector3(side, 1.2, -0.3))
			st.rotation.x = deg_to_rad(-38.0)
			root.add_child(st)
		for si in 5:
			root.add_child(_box(Vector3(0.9, 0.06, 0.3), Color(0.55, 0.42, 0.28), Vector3(0, 0.3 + 0.45 * float(si), 0.9 - 0.6 * float(si))))
		h = 2.4
		label.text = "Escada"
	elif type == "cerca":
		root.add_child(_box(Vector3(0.12, 1.0, 0.12), Color(0.45, 0.32, 0.2), Vector3(-0.85, 0.5, 0)))
		root.add_child(_box(Vector3(0.12, 1.0, 0.12), Color(0.45, 0.32, 0.2), Vector3(0.85, 0.5, 0)))
		root.add_child(_box(Vector3(1.8, 0.1, 0.08), Color(0.5, 0.37, 0.24), Vector3(0, 0.85, 0)))
		root.add_child(_box(Vector3(1.8, 0.1, 0.08), Color(0.5, 0.37, 0.24), Vector3(0, 0.45, 0)))
		h = 1.4
		label.text = "Cerca"
	elif type == "esteira" or type == "esteira_v" or type == "splitter":
		var steel := Color(0.24, 0.25, 0.28)
		for fx in [-0.85, 0.85]:
			for fz in [-0.3, 0.3]:
				root.add_child(_box(Vector3(0.09, 0.42, 0.09), steel, Vector3(fx, 0.21, fz)))
		root.add_child(_box(Vector3(2.05, 0.08, 0.1), steel, Vector3(0, 0.5, 0.42)))
		root.add_child(_box(Vector3(2.05, 0.08, 0.1), steel, Vector3(0, 0.5, -0.42)))
		root.add_child(_box(Vector3(2.05, 0.06, 0.08), steel, Vector3(0, 0.28, 0.42)))
		root.add_child(_box(Vector3(2.05, 0.06, 0.08), steel, Vector3(0, 0.28, -0.42)))
		root.add_child(_box(Vector3(1.9, 0.06, 0.68), Color(0.15, 0.14, 0.14), Vector3(0, 0.4, 0)))
		var rollers: Array = []
		for rx in [-0.98, 0.98]:
			var piv := Node3D.new()
			piv.position = Vector3(rx, 0.4, 0)
			var roll := _cyl(0.12, 0.7, Color(0.35, 0.36, 0.4), Vector3.ZERO)
			roll.rotation.x = PI * 0.5
			piv.add_child(roll)
			root.add_child(piv)
			rollers.append([piv, 7.0, "z"])
		root.set_meta("spinners", rollers)
		var arrow := Node3D.new()
		arrow.add_child(_box(Vector3(0.28, 0.03, 0.07), Color(0.15, 0.85, 0.3), Vector3(0.3, 0.46, 0)))
		arrow.add_child(_box(Vector3(0.12, 0.03, 0.17), Color(0.15, 0.85, 0.3), Vector3(0.48, 0.46, 0)))
		root.add_child(arrow)
		root.set_meta("arrow", arrow)
		if type == "splitter":
			var tray := Node3D.new()
			tray.add_child(_box(Vector3(0.6, 0.05, 0.55), steel, Vector3(0, 0.36, 0.78)))
			tray.add_child(_box(Vector3(0.6, 0.16, 0.05), steel, Vector3(0, 0.44, 1.03)))
			tray.add_child(_box(Vector3(0.6, 0.16, 0.05), steel, Vector3(0, 0.44, 0.53)))
			root.add_child(tray)
			root.set_meta("tray", tray)
			label.text = "Divisor de Esteira"
		elif type == "esteira_v":
			root.add_child(_cyl(0.16, 0.5, steel, Vector3(-0.98, 0.62, 0)))
			root.add_child(_cyl(0.16, 0.5, steel, Vector3(0.98, 0.62, 0)))
			label.text = "Esteira Vertical"
		else:
			label.text = "Esteira"
		root.add_child(pile)
		pile.position = Vector3(0.0, 0.5, 0.0)
		pile.visible = false
		h = 1.4
	label.text += " T%d" % (tier + 1)
	label.position = Vector3(0, h + 0.7, 0)
	root.add_child(label)
	return {"node": root, "label": label, "pile": pile, "bit": bit, "water_mesh": water_mesh, "pile_mat": pm, "lamp": lamp}


func vein_set_ore(id: int, ore: String) -> void:
	if id < 0 or id >= list.size():
		return
	var m: Dictionary = list[id]
	m["ore"] = ore
	if not GameData.ORES.has(ore):
		return
	var col: Color = GameData.ORES[ore]["color"]
	var node: Node3D = m["node"]
	if node != null and is_instance_valid(node) and node.has_meta("vein_mat"):
		var vmat: StandardMaterial3D = node.get_meta("vein_mat")
		vmat.albedo_color = Color(0.35, 0.3, 0.28).lerp(col, 0.45)
	if node != null and is_instance_valid(node) and node.has_meta("glint_mat"):
		var gmat: StandardMaterial3D = node.get_meta("glint_mat")
		gmat.albedo_color = col
		gmat.emission = col * 0.6
		if ore == "sacradium":
			gmat.emission_energy_multiplier = 2.2
	if ore == "sacradium" and node != null and is_instance_valid(node):
		var aura: OmniLight3D = null
		if node.has_meta("aura"):
			aura = node.get_meta("aura")
		if aura == null or not is_instance_valid(aura):
			aura = OmniLight3D.new()
			aura.omni_range = 5.0
			aura.light_energy = 1.1
			aura.position = Vector3(0, 0.9, 0)
			node.add_child(aura)
			node.set_meta("aura", aura)
		aura.light_color = col


func _cached_mat(color: Color, rough: float, metal: float, cull := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), rough, metal, cull]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if metal < 0.9:
		mat.albedo_texture = Textures.pick(color, metal)
		mat.normal_enabled = true
		mat.normal_texture = Textures.normal_for(color, metal)
		mat.normal_scale = 0.7
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	if cull:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = mat
	return mat


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _cached_mat(color, 0.8, 0.0)
	mi.position = pos
	return mi


func _cyl(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.8
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _cached_mat(color, 0.5, 0.5)
	mi.position = pos
	return mi


func _open_cyl(r_top: float, r_bot: float, height: float, color: Color, pos: Vector3, metal := 0.3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.material_override = _cached_mat(color, 0.55, metal, true)
	mi.position = pos
	return mi


func _torus(inner: float, outer: float, color: Color, pos: Vector3, metal := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	mi.mesh = tm
	mi.material_override = _cached_mat(color, 0.45, metal)
	mi.position = pos
	return mi


func _rivet(pos: Vector3, axis := "y") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.045
	cm.height = 0.045
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = _cached_mat(Color(0.22, 0.22, 0.25), 0.5, 0.75)
	mi.position = pos
	if axis == "z":
		mi.rotation.x = PI * 0.5
	elif axis == "x":
		mi.rotation.z = PI * 0.5
	return mi

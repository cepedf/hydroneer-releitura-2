extends Node3D
## Máquinas e canos como dados puros + spatial hash. Zero entidades simuladas.
## Processa apenas uma fração das máquinas por frame (janela rotativa).

const CELL := 8.0
const MACHINE_CAP := 20000
const PULL_RADIUS := 10.0
const CULL_DIST := 60.0
const LABEL_DIST := 25.0

var game: Node3D
var terrain: Node3D

var list: Array = []
var pipes: Array = []
var pipe_nodes: Array = []
var _by_cell := {}
var _pipe_cells := {}
var _connected := {}
var _segments: Array = []
var _cursor := 0
var _cull_timer := 0.0
var _pipe_mat_on: StandardMaterial3D
var _pipe_mat_off: StandardMaterial3D
var _ghost: MeshInstance3D


func _ready() -> void:
	_pipe_mat_on = StandardMaterial3D.new()
	_pipe_mat_on.albedo_color = Color(0.3, 0.55, 0.9)
	_pipe_mat_on.metallic = 0.6
	_pipe_mat_on.roughness = 0.4
	_pipe_mat_off = StandardMaterial3D.new()
	_pipe_mat_off.albedo_color = Color(0.45, 0.45, 0.5)
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.3, 0.8, 1.0, 0.35)
	_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.4, 1.4)
	_ghost.mesh = bm
	_ghost.material_override = gm
	_ghost.visible = false
	add_child(_ghost)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var total := list.size()
	if total > 0:
		var window := maxi(1, int(total / 4))
		for k in window:
			var idx := (_cursor + k) % total
			var m: Dictionary = list[idx]
			if not bool(m.get("dead", false)):
				_update_machine(m, now)
		_cursor = (_cursor + window) % total
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 0.5
		_cull_and_labels()


func _cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL)), int(floor(pos.z / CELL)))


func add_machine(type: String, tier: int, pos: Vector3) -> int:
	if list.size() >= MACHINE_CAP:
		return -1
	var m := {
		"id": list.size(), "type": type, "tier": tier, "pos": pos,
		"dirt": 0.0, "water": 0.0, "water_time": 0.0, "acc": 0.0,
		"caixa": {}, "caixa_gems": {}, "active": false,
		"last": Time.get_ticks_msec() / 1000.0, "dead": false,
	}
	var visual: Dictionary = _build_visual(type, tier, pos)
	m["node"] = visual["node"]
	m["label"] = visual["label"]
	m["pile"] = visual["pile"]
	m["bit"] = visual["bit"]
	m["water_mesh"] = visual["water_mesh"]
	list.append(m)
	var key := _cell_of(pos)
	if not _by_cell.has(key):
		_by_cell[key] = []
	_by_cell[key].append(int(m["id"]))
	return int(m["id"])


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


func snap_pipe_pos(hit: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var found := false
	var best_d := 2.4
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
		return np
	var dr := nearest_of_type(hit, "drill", 3.2)
	if not dr.is_empty():
		var dp: Vector3 = dr["pos"]
		var dir2 := Vector2(hit.x - dp.x, hit.z - dp.z)
		if dir2.length() < 0.15:
			dir2 = Vector2(1.0, 0.0)
		dir2 = dir2.normalized()
		var np2 := Vector3(dp.x + dir2.x * 1.3, 0.0, dp.z + dir2.y * 1.3)
		np2.y = terrain.height_at(np2.x, np2.z) + 0.4
		return np2
	return Vector3(hit.x, terrain.height_at(hit.x, hit.z) + 0.4, hit.z)


func set_ghost(pos: Vector3) -> void:
	_ghost.visible = true
	_ghost.position = pos + Vector3(0.0, 0.8, 0.0)


func hide_ghost() -> void:
	_ghost.visible = false


func nearest(pos: Vector3, max_dist: float) -> Dictionary:
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


func _find_dirt_source(pos: Vector3) -> Dictionary:
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
				if String(m["type"]) != "drill":
					continue
				if float(m["dirt"]) > 0.05 and pos.distance_to(m["pos"]) <= PULL_RADIUS:
					return m
	return {}


func _update_machine(m: Dictionary, now: float) -> void:
	var last: float = m["last"]
	var dt := clampf(now - last, 0.0, 5.0)
	m["last"] = now
	var type: String = m["type"]
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
	elif type == "harvester":
		var tier2: int = m["tier"]
		var rate2: float = GameData.HARVESTER_TIERS[tier2]["rate"]
		var budget := rate2 * dt
		var got := 0.0
		var guard := 0
		while budget > 0.001 and guard < 40:
			guard += 1
			var src := _find_dirt_source(m["pos"])
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
					var caixa: Dictionary = m["caixa"]
					caixa[ore] = int(caixa.get(ore, 0)) + 1
					game.on_harvester_ore()
				if randf() < 0.05:
					var gem: String = game.roll_gem(zone)
					if gem != "":
						var cg: Dictionary = m["caixa_gems"]
						cg[gem] = int(cg.get(gem, 0)) + 1


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
		if dist < LABEL_DIST:
			var label: Label3D = m["label"]
			label.text = _status_text(m)


func _status_text(m: Dictionary) -> String:
	var type: String = m["type"]
	var tier: int = m["tier"]
	var base := ""
	if type == "drill":
		base = String(GameData.DRILL_TIERS[tier]["name"])
	elif type == "harvester":
		base = String(GameData.HARVESTER_TIERS[tier]["name"])
	else:
		base = type.capitalize()
	match type:
		"drill":
			if bool(m["active"]):
				return base + " — terra: %d" % int(float(m["dirt"]))
			return base + " — SEM ÁGUA"
		"harvester":
			var caixa: Dictionary = m["caixa"]
			var cg: Dictionary = m["caixa_gems"]
			var total := 0
			for k in caixa:
				total += int(caixa[k])
			for k in cg:
				total += int(cg[k])
			return base + " — caixa: %d (E coleta)" % total
		"bacia":
			var water_txt := "sim"
			if float(m["water"]) <= 0.2:
				water_txt = "não"
			return base + " — terra: %d | água: %s" % [int(float(m["dirt"])), water_txt]
		_:
			return base


func _build_visual(type: String, tier: int, pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
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
	var h := 2.4
	if type == "drill":
		root.add_child(_box(Vector3(0.12, 0.6, 0.12), Color(0.35, 0.24, 0.16), Vector3(-0.5, 0.3, -0.5)))
		root.add_child(_box(Vector3(0.12, 0.6, 0.12), Color(0.35, 0.24, 0.16), Vector3(0.5, 0.3, -0.5)))
		root.add_child(_box(Vector3(0.12, 0.6, 0.12), Color(0.35, 0.24, 0.16), Vector3(-0.5, 0.3, 0.5)))
		root.add_child(_box(Vector3(0.12, 0.6, 0.12), Color(0.35, 0.24, 0.16), Vector3(0.5, 0.3, 0.5)))
		root.add_child(_box(Vector3(1.2, 1.0, 1.2), Color(0.45, 0.3, 0.2), Vector3(0, 1.1, 0)))
		root.add_child(_box(Vector3(0.4, 1.4, 0.4), Color(0.6, 0.6, 0.65), Vector3(0, 2.3, 0)))
		root.add_child(_box(Vector3(0.16, 0.5, 0.16), Color(0.3, 0.3, 0.32), Vector3(0.3, 2.2, 0.3)))
		root.add_child(_box(Vector3(1.3, 0.25, 1.3), band, Vector3(0, 1.7, 0)))
		bit = _cyl(0.2, 0.9, Color(0.3, 0.3, 0.35), Vector3(0, 0.1, 0))
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
		root.add_child(_box(Vector3(0.12, 0.5, 0.12), Color(0.35, 0.24, 0.16), Vector3(-0.7, 0.25, -0.45)))
		root.add_child(_box(Vector3(0.12, 0.5, 0.12), Color(0.35, 0.24, 0.16), Vector3(0.7, 0.25, -0.45)))
		root.add_child(_box(Vector3(0.12, 0.5, 0.12), Color(0.35, 0.24, 0.16), Vector3(-0.7, 0.25, 0.45)))
		root.add_child(_box(Vector3(0.12, 0.5, 0.12), Color(0.35, 0.24, 0.16), Vector3(0.7, 0.25, 0.45)))
		root.add_child(_box(Vector3(1.8, 0.9, 1.3), Color(0.5, 0.5, 0.55), Vector3(0, 0.95, 0)))
		root.add_child(_cyl(0.45, 1.6, band, Vector3(0, 1.9, 0)))
		root.add_child(_box(Vector3(0.5, 0.4, 0.9), Color(0.4, 0.4, 0.45), Vector3(0.9, 0.7, 0)))
		label.text = "Harvester"
	elif type == "bacia":
		root.add_child(_box(Vector3(2.2, 0.2, 1.6), Color(0.55, 0.4, 0.28), Vector3(0, 0.1, 0)))
		root.add_child(_box(Vector3(2.2, 0.5, 0.15), Color(0.55, 0.4, 0.28), Vector3(0, 0.45, 0.725)))
		root.add_child(_box(Vector3(2.2, 0.5, 0.15), Color(0.55, 0.4, 0.28), Vector3(0, 0.45, -0.725)))
		root.add_child(_box(Vector3(0.15, 0.5, 1.6), Color(0.55, 0.4, 0.28), Vector3(1.025, 0.45, 0)))
		root.add_child(_box(Vector3(0.15, 0.5, 1.6), Color(0.55, 0.4, 0.28), Vector3(-1.025, 0.45, 0)))
		water_mesh = _box(Vector3(1.9, 0.3, 1.3), Color(0.25, 0.45, 0.75, 0.8), Vector3(0, 0.42, 0))
		root.add_child(water_mesh)
		root.add_child(pile)
		pile.position = Vector3(0, 0.5, 0)
		h = 1.6
		label.text = "Bacia"
	elif type == "cadinho":
		root.add_child(_cyl(0.55, 0.9, Color(0.35, 0.3, 0.3), Vector3(0, 0.45, 0)))
		h = 1.6
		label.text = "Cadinho"
	elif type == "forja":
		root.add_child(_box(Vector3(1.4, 1.6, 1.4), Color(0.3, 0.28, 0.28), Vector3(0, 0.8, 0)))
		root.add_child(_box(Vector3(0.9, 0.5, 0.1), Color(1.0, 0.45, 0.1), Vector3(0, 0.7, 0.72)))
		h = 2.4
		label.text = "Forja"
	elif type == "bigorna":
		root.add_child(_box(Vector3(1.0, 0.5, 0.5), Color(0.2, 0.2, 0.25), Vector3(0, 0.25, 0)))
		root.add_child(_box(Vector3(0.5, 0.4, 0.4), Color(0.25, 0.25, 0.3), Vector3(0, 0.65, 0)))
		h = 1.6
		label.text = "Bigorna"
	elif type == "polidora":
		root.add_child(_box(Vector3(1.2, 0.8, 1.2), Color(0.45, 0.45, 0.5), Vector3(0, 0.4, 0)))
		root.add_child(_cyl(0.3, 1.0, band, Vector3(0, 1.2, 0)))
		h = 2.2
		label.text = "Polidora"
	elif type == "prensa":
		root.add_child(_box(Vector3(1.2, 2.2, 1.2), Color(0.4, 0.4, 0.48), Vector3(0, 1.1, 0)))
		root.add_child(_box(Vector3(1.4, 0.3, 1.4), band, Vector3(0, 2.3, 0)))
		h = 3.0
		label.text = "Prensa"
	label.text += " T%d" % (tier + 1)
	label.position = Vector3(0, h + 0.7, 0)
	root.add_child(label)
	return {"node": root, "label": label, "pile": pile, "bit": bit, "water_mesh": water_mesh}


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	return mi


func _cyl(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.8
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.5
	mi.material_override = mat
	mi.position = pos
	return mi

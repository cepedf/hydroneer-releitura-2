extends Node3D
## Terreno escavável em grade + água que escorre e enche os buracos.
## Grade de alturas em vez de milhares de objetos: é isso que mantém o FPS alto.

const N := 96
const CELL := 1.0
const BEDROCK := -12.0
const HALF := N * CELL * 0.5
const SPRING_CELL := Vector2i(4, 4)

var heights := PackedFloat32Array()
var water := PackedFloat32Array()
var richness := PackedFloat32Array()

var _mesh_instance: MeshInstance3D
var _water_instance: MeshInstance3D
var _water_timer := 0.0
var _water_mesh_timer := 0.0
var _sim_cursor := 0


func _ready() -> void:
	_gen_data()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.material_override = _terrain_material()
	add_child(_mesh_instance)
	_water_instance = MeshInstance3D.new()
	_water_instance.material_override = _water_material()
	add_child(_water_instance)
	rebuild_mesh()
	rebuild_water_mesh()


func _physics_process(delta: float) -> void:
	_water_timer -= delta
	_water_mesh_timer -= delta
	if _water_timer <= 0.0:
		_water_timer = 0.1
		_simulate_water()
	if _water_mesh_timer <= 0.0:
		_water_mesh_timer = 0.25
		rebuild_water_mesh()


func idx_v(x: int, z: int) -> int:
	return z * (N + 1) + x


func idx_c(x: int, z: int) -> int:
	return z * N + x


func height_at(wx: float, wz: float) -> float:
	var fx := clampf(wx / CELL + N * 0.5, 0.0, N - 0.001)
	var fz := clampf(wz / CELL + N * 0.5, 0.0, N - 0.001)
	var x := int(fx)
	var z := int(fz)
	var tx := fx - x
	var tz := fz - z
	var h00 := heights[idx_v(x, z)]
	var h10 := heights[idx_v(x + 1, z)]
	var h01 := heights[idx_v(x, z + 1)]
	var h11 := heights[idx_v(x + 1, z + 1)]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func dig(pos: Vector3, radius: float, power: float) -> int:
	var cx := int(clampf(pos.x / CELL + N * 0.5, 0.0, N - 1.0))
	var cz := int(clampf(pos.z / CELL + N * 0.5, 0.0, N - 1.0))
	var vr := int(ceil(radius / CELL)) + 1
	var removed := 0.0
	for z in range(maxi(0, cz - vr), mini(N + 1, cz + vr + 2)):
		for x in range(maxi(0, cx - vr), mini(N + 1, cx + vr + 2)):
			var wx := (x - N * 0.5) * CELL
			var wz := (z - N * 0.5) * CELL
			var d := Vector2(wx - pos.x, wz - pos.z).length()
			if d > radius:
				continue
			var f := 1.0 - d / radius
			var amount := power * f * f
			var i := idx_v(x, z)
			var new_h := maxf(BEDROCK, heights[i] - amount)
			removed += heights[i] - new_h
			heights[i] = new_h
	if removed <= 0.001:
		return 0
	var avg_rich := 0.0
	var cells := 0
	for z in range(maxi(0, cz - vr), mini(N, cz + vr + 1)):
		for x in range(maxi(0, cx - vr), mini(N, cx + vr + 1)):
			avg_rich += richness[idx_c(x, z)]
			cells += 1
	if cells > 0:
		avg_rich /= cells
	var wet := water[idx_c(cx, cz)] > 0.05
	var depth_bonus := 1.0 + maxf(0.0, -pos.y) * 0.1
	var nuggets := int(removed * (0.8 + 2.2 * avg_rich) * depth_bonus) * (2 if wet else 1)
	rebuild_mesh()
	_water_mesh_timer = 0.0
	return nuggets


func add_water_at(pos: Vector3, amount: float) -> void:
	var cx := int(clampf(pos.x / CELL + N * 0.5, 0.0, N - 1.0))
	var cz := int(clampf(pos.z / CELL + N * 0.5, 0.0, N - 1.0))
	water[idx_c(cx, cz)] = minf(water[idx_c(cx, cz)] + amount, 1.5)


func rebuild_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in N:
		for x in N:
			var x0 := (x - N * 0.5) * CELL
			var z0 := (z - N * 0.5) * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			var h00 := heights[idx_v(x, z)]
			var h10 := heights[idx_v(x + 1, z)]
			var h11 := heights[idx_v(x + 1, z + 1)]
			var h01 := heights[idx_v(x, z + 1)]
			st.set_color(_color_for(h00))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(_color_for(h10))
			st.add_vertex(Vector3(x1, h10, z0))
			st.set_color(_color_for(h11))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(_color_for(h00))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(_color_for(h11))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(_color_for(h01))
			st.add_vertex(Vector3(x0, h01, z1))
	st.generate_normals()
	_mesh_instance.mesh = st.commit()


func rebuild_water_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for z in N:
		for x in N:
			var w := water[idx_c(x, z)]
			if w <= 0.02:
				continue
			quads += 1
			var x0 := (x - N * 0.5) * CELL
			var z0 := (z - N * 0.5) * CELL
			var y := _terrain_avg(x, z) + w
			var col := Color(0.15, 0.45, 0.85, 0.6)
			st.set_color(col)
			st.add_vertex(Vector3(x0, y, z0))
			st.set_color(col)
			st.add_vertex(Vector3(x0 + CELL, y, z0))
			st.set_color(col)
			st.add_vertex(Vector3(x0 + CELL, y, z0 + CELL))
			st.set_color(col)
			st.add_vertex(Vector3(x0, y, z0))
			st.set_color(col)
			st.add_vertex(Vector3(x0 + CELL, y, z0 + CELL))
			st.set_color(col)
			st.add_vertex(Vector3(x0, y, z0 + CELL))
	if quads == 0:
		_water_instance.mesh = null
		return
	st.generate_normals()
	_water_instance.mesh = st.commit()


func _terrain_avg(x: int, z: int) -> float:
	return (heights[idx_v(x, z)] + heights[idx_v(x + 1, z)] + heights[idx_v(x, z + 1)] + heights[idx_v(x + 1, z + 1)]) * 0.25


func _gen_data() -> void:
	heights.resize((N + 1) * (N + 1))
	water.resize(N * N)
	richness.resize(N * N)
	var shape := FastNoiseLite.new()
	shape.seed = 7
	shape.frequency = 0.045
	var detail := FastNoiseLite.new()
	detail.seed = 21
	detail.frequency = 0.12
	var veins := FastNoiseLite.new()
	veins.seed = 99
	veins.frequency = 0.09
	for z in N + 1:
		for x in N + 1:
			var wx := (x - N * 0.5) * CELL
			var wz := (z - N * 0.5) * CELL
			var h := 1.5 + shape.get_noise_2d(wx, wz) * 2.0 + detail.get_noise_2d(wx, wz) * 0.5
			var d := Vector2(wx, wz).length()
			h -= clampf(4.0 - d * 0.08, 0.0, 4.0) * 0.8
			heights[idx_v(x, z)] = h
	for z in N:
		for x in N:
			var v := veins.get_noise_2d(x * 3.7, z * 3.7)
			richness[idx_c(x, z)] = clampf(v * 0.5 + 0.5, 0.0, 1.0)


func _simulate_water() -> void:
	var s := SPRING_CELL
	var si := idx_c(s.x, s.y)
	water[si] = minf(water[si] + 0.25, 1.5)
	var total := N * N
	var window := maxi(1, total / 6)
	for i in window:
		var c := (_sim_cursor + i) % total
		var w := water[c]
		if w <= 0.01:
			continue
		var x := c % N
		var z := c / N
		var my_level := _surface_level(x, z)
		var best := -1
		var best_level := my_level
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = x + offset.x
			var nz: int = z + offset.y
			if nx < 0 or nx >= N or nz < 0 or nz >= N:
				continue
			var level := _surface_level(nx, nz)
			if level < best_level - 0.02:
				best_level = level
				best = idx_c(nx, nz)
		if best >= 0:
			var move := minf(w * 0.5, (my_level - best_level) * 0.5)
			water[c] -= move
			water[best] += move
	_sim_cursor = (_sim_cursor + window) % total


func _surface_level(x: int, z: int) -> float:
	return _terrain_avg(x, z) + water[idx_c(x, z)]


func _color_for(h: float) -> Color:
	if h > 2.6:
		return Color(0.36, 0.55, 0.25)
	if h > 0.5:
		return Color(0.48, 0.35, 0.22)
	if h > -4.0:
		return Color(0.42, 0.3, 0.19)
	return Color(0.35, 0.33, 0.35)


func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _water_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.5, 0.9, 0.55)
	mat.roughness = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

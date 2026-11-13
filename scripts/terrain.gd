extends Node3D
## Terreno escavável em chunks + zonas de terrenos (T1-T5) + água com lago contido.
## Zero entidades simuladas: tudo é grade de alturas e valores.

const N := 160
const CELL := 1.0
const CHUNK := 16
const HALF := N * CELL * 0.5
const SPRING_CELL := Vector2i(35, 60)
const LAKE_POS := Vector2(-45.0, -20.0)
const LAKE_RADIUS := 9.0
const VILLAGE_MIN := Vector2(-24.0, 58.0)
const VILLAGE_MAX := Vector2(14.0, 78.0)

var heights := PackedFloat32Array()
var water := PackedFloat32Array()

var game: Node3D

var _chunks := {}
var _water_instance: MeshInstance3D
var _water_timer := 0.0
var _water_mesh_timer := 0.0
var _sim_cursor := 0


func _ready() -> void:
	_gen_data()
	for cz in intdiv(N, CHUNK):
		for cx in intdiv(N, CHUNK):
			var mi := MeshInstance3D.new()
			mi.material_override = _terrain_material()
			add_child(mi)
			_chunks[Vector2i(cx, cz)] = mi
	for key in _chunks:
		rebuild_chunk(key.x, key.y)
	_water_instance = MeshInstance3D.new()
	_water_instance.material_override = _water_material()
	add_child(_water_instance)
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


func bedrock_at(wx: float) -> float:
	return GameData.ZONE_BEDROCK[GameData.zone_at(wx)]


func dig(pos: Vector3, radius: float, power: float) -> float:
	if game != null and not game.zone_unlocked(GameData.zone_at(pos.x)):
		return -1.0
	var cx := int(clampf(pos.x / CELL + N * 0.5, 0.0, N - 1.0))
	var cz := int(clampf(pos.z / CELL + N * 0.5, 0.0, N - 1.0))
	var vr := int(ceil(radius / CELL)) + 1
	var removed := 0.0
	var dirty := {}
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
			var bedrock: float = GameData.ZONE_BEDROCK[GameData.zone_at(wx)]
			var new_h := maxf(bedrock, heights[i] - amount)
			removed += heights[i] - new_h
			heights[i] = new_h
			dirty[Vector2i(intdiv(x, CHUNK), intdiv(z, CHUNK))] = true
	for key in dirty:
		rebuild_chunk(key.x, key.y)
	if removed > 0.0:
		_water_mesh_timer = 0.0
	return removed


func rebuild_chunk(cx: int, cz: int) -> void:
	var mi: MeshInstance3D = _chunks[Vector2i(cx, cz)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(cz * CHUNK, (cz + 1) * CHUNK):
		for x in range(cx * CHUNK, (cx + 1) * CHUNK):
			var x0 := (x - N * 0.5) * CELL
			var z0 := (z - N * 0.5) * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			var h00 := heights[idx_v(x, z)]
			var h10 := heights[idx_v(x + 1, z)]
			var h11 := heights[idx_v(x + 1, z + 1)]
			var h01 := heights[idx_v(x, z + 1)]
			st.set_color(_color_for(h00) * _tint(x0, z0))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(_color_for(h10) * _tint(x1, z0))
			st.add_vertex(Vector3(x1, h10, z0))
			st.set_color(_color_for(h11) * _tint(x1, z1))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(_color_for(h00) * _tint(x0, z0))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(_color_for(h11) * _tint(x1, z1))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(_color_for(h01) * _tint(x0, z1))
			st.add_vertex(Vector3(x0, h01, z1))
	st.generate_normals()
	mi.mesh = st.commit()


func rebuild_all() -> void:
	for key in _chunks:
		rebuild_chunk(key.x, key.y)


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
			var col := Color(0.12, 0.52, 0.78, 0.55)
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
	var shape := FastNoiseLite.new()
	shape.seed = 7
	shape.frequency = 0.045
	var detail := FastNoiseLite.new()
	detail.seed = 21
	detail.frequency = 0.12
	for z in N + 1:
		for x in N + 1:
			var wx := (x - N * 0.5) * CELL
			var wz := (z - N * 0.5) * CELL
			var h := 1.5 + shape.get_noise_2d(wx, wz) * 2.0 + detail.get_noise_2d(wx, wz) * 0.5
			var d := Vector2(wx, wz).length()
			h -= clampf(4.0 - d * 0.08, 0.0, 4.0) * 0.8
			if wx > VILLAGE_MIN.x and wx < VILLAGE_MAX.x and wz > VILLAGE_MIN.y and wz < VILLAGE_MAX.y:
				var ex := minf(wx - VILLAGE_MIN.x, VILLAGE_MAX.x - wx)
				var ez := minf(wz - VILLAGE_MIN.y, VILLAGE_MAX.y - wz)
				var edge := minf(ex, ez)
				h = lerpf(2.0, h, clampf(edge / 4.0, 0.0, 1.0))
			heights[idx_v(x, z)] = h
	for z in N + 1:
		for x in N + 1:
			var wx := (x - N * 0.5) * CELL
			var wz := (z - N * 0.5) * CELL
			var d := Vector2(wx, wz).distance_to(LAKE_POS)
			if d < LAKE_RADIUS:
				var f := 1.0 - d / LAKE_RADIUS
				heights[idx_v(x, z)] -= 3.5 * f * f
			elif d < LAKE_RADIUS + 3.0:
				var r := (d - LAKE_RADIUS) / 3.0
				heights[idx_v(x, z)] += 1.8 * (1.0 - r * r)


func _simulate_water() -> void:
	var si := idx_c(SPRING_CELL.x, SPRING_CELL.y)
	water[si] = minf(water[si] + 0.15, 1.2)
	var total := N * N
	var window := maxi(1, intdiv(total, 6))
	for i in window:
		var c := (_sim_cursor + i) % total
		var w := water[c] * 0.995
		water[c] = w
		if w <= 0.03:
			water[c] = 0.0
			continue
		var x := c % N
		var z := intdiv(c, N)
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
	var grass_a := Color(0.29, 0.56, 0.17)
	var grass_b := Color(0.42, 0.68, 0.24)
	var dirt := Color(0.5, 0.35, 0.2)
	var soil := Color(0.4, 0.29, 0.18)
	var rock := Color(0.42, 0.41, 0.44)
	var deep := Color(0.28, 0.27, 0.32)
	if h > 3.2:
		return grass_b.lerp(Color(0.5, 0.66, 0.34), clampf((h - 3.2) / 3.0, 0.0, 1.0))
	if h > 1.2:
		return grass_a.lerp(grass_b, clampf((h - 1.2) / 2.0, 0.0, 1.0))
	if h > 0.0:
		return dirt.lerp(grass_a, clampf(h / 1.2, 0.0, 1.0))
	if h > -6.0:
		return soil.lerp(dirt, clampf((h + 6.0) / 6.0, 0.0, 1.0))
	if h > -14.0:
		return rock.lerp(soil, clampf((h + 14.0) / 8.0, 0.0, 1.0))
	return deep


func _tint(wx: float, wz: float) -> float:
	var n := sin(wx * 12.9898 + wz * 78.233) * 43758.5453
	return 0.94 + 0.12 * absf(fmod(n, 1.0))


func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _water_material() -> Material:
	var code := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;
uniform vec4 albedo : source_color = vec4(0.1, 0.5, 0.75, 0.6);
uniform float wave_height = 0.07;
uniform float wave_speed = 1.3;
void vertex() {
	VERTEX.y += sin(VERTEX.x * 1.4 + TIME * wave_speed) * cos(VERTEX.z * 1.2 + TIME * wave_speed * 0.8) * wave_height;
}
void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	METALLIC = 0.3;
	ROUGHNESS = 0.05;
	EMISSION = albedo.rgb * 0.22;
}
"""
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat

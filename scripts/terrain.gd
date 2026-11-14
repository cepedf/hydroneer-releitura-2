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
var _dig_noise: FastNoiseLite
var _tint_noise: FastNoiseLite


@warning_ignore("integer_division")
func _ready() -> void:
	_gen_data()
	for cz in N / CHUNK:
		for cx in N / CHUNK:
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


func _init_noise() -> void:
	_dig_noise = FastNoiseLite.new()
	_dig_noise.seed = 909
	_dig_noise.frequency = 0.9
	_tint_noise = FastNoiseLite.new()
	_tint_noise.seed = 414
	_tint_noise.frequency = 0.35


@warning_ignore("integer_division")
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
			var edge := 0.82 + 0.36 * (0.5 + 0.5 * _dig_noise.get_noise_2d(wx * 2.2, wz * 2.2))
			var amount := power * f * f * edge
			var i := idx_v(x, z)
			var bedrock: float = GameData.ZONE_BEDROCK[GameData.zone_at(wx)]
			var new_h := maxf(bedrock, heights[i] - amount)
			removed += heights[i] - new_h
			heights[i] = new_h
			dirty[Vector2i(x / CHUNK, z / CHUNK)] = true
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
			st.set_color(_ground_color(h00, x, z) * _tint(x0, z0))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(_ground_color(h10, x + 1, z) * _tint(x1, z0))
			st.add_vertex(Vector3(x1, h10, z0))
			st.set_color(_ground_color(h11, x + 1, z + 1) * _tint(x1, z1))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(_ground_color(h00, x, z) * _tint(x0, z0))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(_ground_color(h11, x + 1, z + 1) * _tint(x1, z1))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(_ground_color(h01, x, z + 1) * _tint(x0, z1))
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
			if water[idx_c(x, z)] <= 0.02:
				continue
			quads += 1
			var x0 := (x - N * 0.5) * CELL
			var z0 := (z - N * 0.5) * CELL
			var a := _water_corner(x, z)
			var b := _water_corner(x + 1, z)
			var c := _water_corner(x + 1, z + 1)
			var d := _water_corner(x, z + 1)
			st.set_color(Color(a[1], a[2], 0.0, 1.0))
			st.add_vertex(Vector3(x0, a[0], z0))
			st.set_color(Color(b[1], b[2], 0.0, 1.0))
			st.add_vertex(Vector3(x0 + CELL, b[0], z0))
			st.set_color(Color(c[1], c[2], 0.0, 1.0))
			st.add_vertex(Vector3(x0 + CELL, c[0], z0 + CELL))
			st.set_color(Color(a[1], a[2], 0.0, 1.0))
			st.add_vertex(Vector3(x0, a[0], z0))
			st.set_color(Color(c[1], c[2], 0.0, 1.0))
			st.add_vertex(Vector3(x0 + CELL, c[0], z0 + CELL))
			st.set_color(Color(d[1], d[2], 0.0, 1.0))
			st.add_vertex(Vector3(x0, d[0], z0 + CELL))
	if quads == 0:
		_water_instance.mesh = null
		return
	st.generate_normals()
	_water_instance.mesh = st.commit()


func _water_corner(x: int, z: int) -> PackedFloat32Array:
	var best := -1.0e9
	var count := 0
	for dz in [0, -1]:
		for dx in [0, -1]:
			var cx: int = x + dx
			var cz: int = z + dz
			if cx < 0 or cx >= N or cz < 0 or cz >= N:
				continue
			var w := water[idx_c(cx, cz)]
			if w <= 0.02:
				continue
			count += 1
			best = maxf(best, _surface_level(cx, cz))
	if count == 0:
		best = heights[idx_v(x, z)]
	var depth := clampf(best - heights[idx_v(x, z)], 0.0, 4.0)
	var foam := 1.0 - clampf(depth / 0.35, 0.0, 1.0)
	return PackedFloat32Array([best, foam, depth * 0.25])


func _terrain_avg(x: int, z: int) -> float:
	return (heights[idx_v(x, z)] + heights[idx_v(x + 1, z)] + heights[idx_v(x, z + 1)] + heights[idx_v(x + 1, z + 1)]) * 0.25


func _gen_data() -> void:
	_init_noise()
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


@warning_ignore("integer_division")
func _simulate_water() -> void:
	var si := idx_c(SPRING_CELL.x, SPRING_CELL.y)
	water[si] = minf(water[si] + 0.15, 1.2)
	var total := N * N
	var window := maxi(1, total / 6)
	for i in window:
		var c := (_sim_cursor + i) % total
		var w := water[c] * 0.995
		water[c] = w
		if w <= 0.03:
			water[c] = 0.0
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


func _slope_at(x: int, z: int) -> float:
	var h := heights[idx_v(x, z)]
	var s := 0.0
	if x > 0:
		s = maxf(s, absf(heights[idx_v(x - 1, z)] - h))
	if x < N:
		s = maxf(s, absf(heights[idx_v(x + 1, z)] - h))
	if z > 0:
		s = maxf(s, absf(heights[idx_v(x, z - 1)] - h))
	if z < N:
		s = maxf(s, absf(heights[idx_v(x, z + 1)] - h))
	return s


func _ground_color(h: float, x: int, z: int) -> Color:
	var col := _color_for(h)
	var moist := clampf(_slope_at(x, z) * 0.16, 0.0, 0.34)
	return col.darkened(moist)


func _tint(wx: float, wz: float) -> float:
	return 0.9 + 0.2 * (0.5 + 0.5 * _tint_noise.get_noise_2d(wx * 0.35, wz * 0.35))


func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = Textures.dirt()
	mat.normal_enabled = true
	mat.normal_texture = Textures.dirt_normal()
	mat.normal_scale = 0.8
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
	return mat


func _water_material() -> Material:
	var code := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;
uniform vec4 shallow_col : source_color = vec4(0.22, 0.58, 0.68, 0.55);
uniform vec4 deep_col : source_color = vec4(0.02, 0.16, 0.3, 0.92);
uniform float wave_height = 0.06;
uniform float wave_speed = 1.3;
varying vec3 wpos;
void vertex() {
	wpos = VERTEX;
	VERTEX.y += sin(VERTEX.x * 1.4 + TIME * wave_speed) * cos(VERTEX.z * 1.2 + TIME * wave_speed * 0.8) * wave_height;
}
void fragment() {
	float depth_n = clamp(COLOR.g, 0.0, 1.0);
	float foam = clamp(COLOR.r, 0.0, 1.0);
	float shimmer = 0.5 + 0.5 * sin(TIME * 2.2 + wpos.x * 2.6 + wpos.z * 1.9);
	float foam_amt = foam * (0.6 + 0.4 * shimmer);
	vec3 col = mix(shallow_col.rgb, deep_col.rgb, depth_n);
	col = mix(col, vec3(0.93, 0.97, 1.0), foam_amt * 0.75);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.72, 0.86, 0.96), fres * 0.4);
	ALBEDO = col;
	ALPHA = clamp(mix(shallow_col.a, deep_col.a, depth_n) + foam_amt * 0.35 + fres * 0.3, 0.0, 1.0);
	METALLIC = 0.35;
	ROUGHNESS = 0.02 + 0.1 * foam;
	SPECULAR = 0.6;
	EMISSION = col * 0.1 + vec3(0.9, 0.95, 1.0) * foam_amt * 0.08 + vec3(0.8, 0.9, 1.0) * fres * 0.06;
}
"""
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat

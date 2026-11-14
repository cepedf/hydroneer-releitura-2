class_name Textures

static var _cache: Dictionary = {}


static func _noise_img(w: int, h: int, seed_v: int, freq: float, fx: float, fy: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = freq
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var n := noise.get_noise_2d(float(x) * fx, float(y) * fy)
			var v := clampf(0.5 + n * 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img


static func _put(key: String, img: Image) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func _load_png(key: String, path: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			_cache[key] = t
			return t
	return null


static func grunge() -> Texture2D:
	var t := _load_png("grunge", "res://assets/textures/grunge.png")
	if t != null:
		return t
	var img := _noise_img(64, 64, 8123, 0.12, 1.0, 1.0)
	for y in 64:
		for x in 64:
			var c := img.get_pixel(x, y)
			var v := 0.965 + (c.r - 0.5) * 0.11
			img.set_pixel(x, y, Color(v, v, v))
	return _put("grunge", img)


static func wood() -> Texture2D:
	var t := _load_png("wood", "res://assets/textures/wood.png")
	if t != null:
		return t
	var noise := FastNoiseLite.new()
	noise.seed = 4444
	noise.frequency = 0.09
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var n := noise.get_noise_2d(float(x) * 0.35, float(y) * 3.2)
			var grain := sin((float(x) * 0.55 + n * 5.0) * 2.1) * 0.5 + 0.5
			var v := clampf(0.82 + grain * 0.18 + n * 0.06, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return _put("wood", img)


static func metal() -> Texture2D:
	var t := _load_png("metal", "res://assets/textures/metal.png")
	if t != null:
		return t
	var noise := FastNoiseLite.new()
	noise.seed = 7654
	noise.frequency = 0.2
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var n := noise.get_noise_2d(float(x) * 4.0, float(y) * 0.35)
			var v := clampf(0.94 + n * 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return _put("metal", img)


static func rust() -> Texture2D:
	var t := _load_png("rust", "res://assets/textures/rust.png")
	if t != null:
		return t
	var noise := FastNoiseLite.new()
	noise.seed = 9012
	noise.frequency = 0.14
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var n := noise.get_noise_2d(float(x), float(y))
			var m := clampf(0.5 + n * 0.5, 0.0, 1.0)
			var r := 0.42 + m * 0.28
			var g := 0.24 + m * 0.16
			var b := 0.14 + m * 0.08
			img.set_pixel(x, y, Color(r, g, b))
	return _put("rust", img)


static func dirt() -> Texture2D:
	var t := _load_png("dirt", "res://assets/textures/dirt.png")
	if t != null:
		return t
	var noise := FastNoiseLite.new()
	noise.seed = 6262
	noise.frequency = 0.06
	var noise2 := FastNoiseLite.new()
	noise2.seed = 1717
	noise2.frequency = 0.35
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var n := noise.get_noise_2d(float(x), float(y))
			var n2 := noise2.get_noise_2d(float(x), float(y))
			var v := clampf(0.9 + n * 0.16 + n2 * 0.06, 0.0, 1.0)
			var r := v
			var g := v * (0.96 + n2 * 0.05)
			var b := v * 0.92
			img.set_pixel(x, y, Color(r, g, b))
	return _put("dirt", img)


static func stone() -> Texture2D:
	var t := _load_png("stone", "res://assets/textures/stone.png")
	if t != null:
		return t
	var img := _noise_img(128, 128, 2024, 0.08, 1.0, 1.0)
	for y in 128:
		for x in 128:
			var c := img.get_pixel(x, y)
			var v := clampf(0.52 + (c.r - 0.5) * 0.4, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return _put("stone", img)


static func pick(color: Color, metal_amt: float) -> Texture2D:
	if metal_amt >= 0.5:
		return metal()
	if color.s < 0.12:
		return stone()
	if color.h > 0.02 and color.h < 0.12 and color.s > 0.2:
		return wood()
	return grunge()


static func _normal_from(key: String, src: Texture2D, strength: float, path := "") -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if path != "":
		var loaded := _load_png(key, path)
		if loaded != null:
			return loaded
	var img: Image = src.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var xl: float = img.get_pixel((x - 1 + w) % w, y).r
			var xr: float = img.get_pixel((x + 1) % w, y).r
			var yu: float = img.get_pixel(x, (y - 1 + h) % h).r
			var yd: float = img.get_pixel(x, (y + 1) % h).r
			var nx := (xl - xr) * strength
			var ny := (yu - yd) * strength
			var l := sqrt(nx * nx + ny * ny + 1.0)
			out.set_pixel(x, y, Color(nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, 1.0 / l * 0.5 + 0.5))
	return _put(key, out)


static func normal_for(color: Color, metal_amt: float) -> Texture2D:
	if metal_amt >= 0.5:
		return _normal_from("n_metal", metal(), 2.4, "res://assets/textures/metal_n.png")
	if color.s < 0.12:
		return _normal_from("n_stone", stone(), 1.9, "res://assets/textures/stone_n.png")
	if color.h > 0.02 and color.h < 0.12 and color.s > 0.2:
		return _normal_from("n_wood", wood(), 1.6, "res://assets/textures/wood_n.png")
	return _normal_from("n_grunge", grunge(), 1.0, "res://assets/textures/grunge_n.png")


static func stone_normal() -> Texture2D:
	return _normal_from("n_stone", stone(), 1.9, "res://assets/textures/stone_n.png")


static func wood_normal() -> Texture2D:
	return _normal_from("n_wood", wood(), 1.6, "res://assets/textures/wood_n.png")


static func water_normal() -> Texture2D:
	var t := _load_png("n_water", "res://assets/textures/water_n.png")
	if t != null:
		return t
	return _normal_from("n_water", ImageTexture.create_from_image(_noise_img(256, 256, 5150, 0.05, 1.0, 1.0)), 1.6)


static func dirt_normal() -> Texture2D:
	return _normal_from("n_dirt", dirt(), 2.0, "res://assets/textures/dirt_n.png")


static func roof_tiles() -> Texture2D:
	var t := _load_png("roof", "res://assets/textures/roof.png")
	if t != null:
		return t
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var yi := floorf(float(y) / 8.0)
			var xo := fmod(yi, 2.0) * 8.0
			var u := fmod(float(x) + xo, 16.0)
			var v := fmod(float(y), 8.0)
			var d1 := minf(u, 16.0 - u)
			var d2 := minf(v, 8.0 - v)
			var line := 1.0
			if d1 < 1.3 or d2 < 1.0:
				line = 0.7
			var shade := 0.93 + 0.07 * sin((float(x) + xo) * 0.39)
			var vv := clampf(line * shade, 0.0, 1.0)
			img.set_pixel(x, y, Color(vv, vv, vv))
	return _put("roof", img)


static func roof_normal() -> Texture2D:
	return _normal_from("n_roof", roof_tiles(), 2.6, "res://assets/textures/roof_n.png")


static func hazard() -> Texture2D:
	var t := _load_png("hazard", "res://assets/textures/hazard.png")
	if t != null:
		return t
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var s := int(floorf(fmod((float(x) + float(y)) / 8.0, 2.0)))
			if s == 0:
				img.set_pixel(x, y, Color(0.88, 0.72, 0.12))
			else:
				img.set_pixel(x, y, Color(0.14, 0.14, 0.15))
	return _put("hazard", img)


static func hazard_normal() -> Texture2D:
	return _normal_from("n_hazard", hazard(), 0.8, "res://assets/textures/hazard_n.png")

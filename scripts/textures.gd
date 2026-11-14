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


static func grunge() -> ImageTexture:
	if _cache.has("grunge"):
		return _cache["grunge"]
	var img := _noise_img(64, 64, 8123, 0.12, 1.0, 1.0)
	for y in 64:
		for x in 64:
			var c := img.get_pixel(x, y)
			var v := 0.965 + (c.r - 0.5) * 0.11
			img.set_pixel(x, y, Color(v, v, v))
	return _put("grunge", img)


static func wood() -> ImageTexture:
	if _cache.has("wood"):
		return _cache["wood"]
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


static func metal() -> ImageTexture:
	if _cache.has("metal"):
		return _cache["metal"]
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


static func rust() -> ImageTexture:
	if _cache.has("rust"):
		return _cache["rust"]
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


static func dirt() -> ImageTexture:
	if _cache.has("dirt"):
		return _cache["dirt"]
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


static func pick(color: Color, metal: float) -> ImageTexture:
	if metal >= 0.5:
		return metal()
	if color.h > 0.02 and color.h < 0.12 and color.s > 0.2:
		return wood()
	return grunge()

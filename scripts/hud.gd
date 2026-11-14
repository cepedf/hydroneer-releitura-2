extends CanvasLayer
## HUD: status, bolso, missões, mira, barra de escova, menus genéricos e intro.

var game: Node3D

var _money_label: Label
var _debt_label: Label
var _bucket_label: Label
var _pocket_label: Label
var _quest_label: Label
var _prompt_label: Label
var _help_label: Label
var _flash_label: Label
var _crosshair: Control
var _brush_bg: Panel
var _brush_fill: ColorRect
var _bucket_bg: Panel
var _bucket_fill: ColorRect
var _menu_center: CenterContainer
var _menu_title: Label
var _menu_list: VBoxContainer
var _intro: Control
var _intro_visible := false
var _title: Control
var _title_visible := false
var _title_continue: Button
var _flash_time := 0.0
var _diag_label: Label
var _diag_time := 0.0
var _map: Control
var _map_visible := false
var _map_markers: Control
var _map_timer := 0.0
var _map_buttons: Array = []
var _clock_label: Label
var _perf_label: Label
var _scaled: Array = []
var _credits: Control
var _credits_visible := false


func _ready() -> void:
	_money_label = _make_label(Vector2(16, 12), 24)
	_debt_label = _make_label(Vector2(16, 46), 16)
	_debt_label.modulate = Color(1.0, 0.45, 0.4)
	_debt_label.visible = false
	_bucket_label = _make_label(Vector2(16, 72), 17)
	_pocket_label = _make_label(Vector2(16, 98), 17)
	_quest_label = _make_label(Vector2(16, 126), 17)
	_help_label = _make_label(Vector2(16, -28), 14)
	_help_label.anchor_top = 1.0
	_help_label.anchor_bottom = 1.0
	_flash_label = _make_label(Vector2(0, 150), 24)
	_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash_label.modulate.a = 0.0
	_diag_label = _make_label(Vector2(0, 230), 16)
	_diag_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_diag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diag_label.modulate.a = 0.0
	_clock_label = _make_label(Vector2(-210, 12), 18)
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_perf_label = _make_label(Vector2(-210, 36), 14)
	_perf_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_crosshair = CrossControl.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_crosshair)
	_prompt_label = _make_label(Vector2(0, 190), 20)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_build_brush_bar()
	_build_menu()
	_build_intro()
	_build_title()
	_build_map()
	_build_credits()


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_label.modulate.a = clampf(_flash_time, 0.0, 1.0)
	if _diag_time > 0.0:
		_diag_time -= delta
		_diag_label.modulate.a = clampf(_diag_time, 0.0, 1.0)
	if _map_visible:
		_map_timer -= delta
		if _map_timer <= 0.0:
			_map_timer = 0.4
			update_map()


func flash(text: String) -> void:
	_flash_label.text = text
	_flash_time = 3.5
	_flash_label.modulate.a = 1.0


func show_diag(text: String) -> void:
	_diag_label.text = text
	_diag_time = 8.0
	_diag_label.modulate.a = 1.0


func show_stats(text: String) -> void:
	_diag_label.text = text
	_diag_time = 20.0
	_diag_label.modulate.a = 1.0


func intro_visible() -> bool:
	return _intro_visible


func title_visible() -> bool:
	return _title_visible


func show_title(has_save: bool) -> void:
	_title_visible = true
	_title.visible = true
	_title_continue.disabled = not has_save
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_title() -> void:
	_title_visible = false
	_title.visible = false


func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_title.add_child(box)
	var logo := Label.new()
	logo.text = "HYDRONEER 2"
	logo.add_theme_font_size_override("font_size", 72)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.modulate = Color(1.0, 0.8, 0.3)
	box.add_child(logo)
	var sub := Label.new()
	sub.text = "Mineração, construção e automação industrial"
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.8, 0.75, 0.65)
	box.add_child(sub)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 18)
	box.add_child(esp)
	_title_continue = Button.new()
	_title_continue.text = "Continuar"
	_title_continue.custom_minimum_size = Vector2(280, 44)
	_title_continue.pressed.connect(func() -> void: game.title_continue())
	box.add_child(_title_continue)
	var bnew := Button.new()
	bnew.text = "Novo Jogo"
	bnew.custom_minimum_size = Vector2(280, 44)
	bnew.pressed.connect(func() -> void: game.title_new_game())
	box.add_child(bnew)
	var bquit := Button.new()
	bquit.text = "Sair"
	bquit.custom_minimum_size = Vector2(280, 44)
	bquit.pressed.connect(func() -> void: game._quit_game())
	box.add_child(bquit)
	var bcred := Button.new()
	bcred.text = "Créditos"
	bcred.custom_minimum_size = Vector2(280, 44)
	bcred.pressed.connect(func() -> void: game._show_credits())
	box.add_child(bcred)
	add_child(_title)


func show_intro() -> void:
	_intro.visible = true
	_intro_visible = true


func hide_intro() -> void:
	_intro.visible = false
	_intro_visible = false


func map_visible() -> bool:
	return _map_visible


func show_map() -> void:
	_map_visible = true
	_map.visible = true
	update_map()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_map() -> void:
	_map_visible = false
	_map.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _map_px(x: float, z: float) -> Vector2:
	return Vector2((x + 80.0) / 160.0 * 480.0, (z + 80.0) / 160.0 * 480.0)


func _map_dot(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos - sz * 0.5
	r.size = sz
	_map_markers.add_child(r)


func update_map() -> void:
	if game == null:
		return
	for child in _map_markers.get_children():
		_map_markers.remove_child(child)
		child.queue_free()
	for gx in [-30.0, 0.0, 30.0, 55.0]:
		var p := _map_px(float(gx), 0.0)
		_map_dot(Vector2(p.x, 240.0), Vector2(3, 480), Color(0.45, 0.38, 0.28, 0.9))
	var v0 := _map_px(-24.0, 58.0)
	var v1 := _map_px(14.0, 78.0)
	var vil := ColorRect.new()
	vil.color = Color(0.55, 0.42, 0.25, 0.55)
	vil.position = v0
	vil.size = v1 - v0
	_map_markers.add_child(vil)
	var lake: Vector2 = game.terrain.LAKE_POS
	_map_dot(_map_px(lake.x, lake.y), Vector2(20, 20), Color(0.25, 0.5, 0.85))
	_map_dot(_map_px(-6.0, 66.0), Vector2(10, 10), Color(1.0, 0.8, 0.2))
	_map_dot(_map_px(-12.0, 64.0), Vector2(8, 8), Color(0.9, 0.6, 0.3))
	_map_dot(_map_px(0.0, 68.0), Vector2(8, 8), Color(0.85, 0.75, 0.4))
	for m in game.machines.list:
		if bool(m.get("dead", false)) or String(m["type"]) != "vein":
			continue
		var col := Color(0.5, 0.5, 0.5)
		if bool(game.has_detector):
			col = GameData.ORES[String(m["ore"])]["color"]
		_map_dot(_map_px(m["pos"].x, m["pos"].z), Vector2(7, 7), col)
	var pp: Vector3 = game.player.global_position
	_map_dot(_map_px(pp.x, pp.z), Vector2(11, 11), Color(1.0, 1.0, 1.0))
	for b in _map_buttons:
		var dest: String = b.get_meta("dest")
		var need := 0
		if dest == "t3":
			need = 2
		elif dest == "t4":
			need = 3
		elif dest == "t5":
			need = 4
		b.disabled = need > 0 and not game.zone_unlocked(need)


func _build_map() -> void:
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "MAPA DO VALE"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var area := Control.new()
	area.custom_minimum_size = Vector2(480, 480)
	var map_bg := ColorRect.new()
	map_bg.color = Color(0.33, 0.43, 0.23)
	map_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(map_bg)
	_map_markers = Control.new()
	_map_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(_map_markers)
	box.add_child(area)
	var hint := Label.new()
	hint.text = "Pontos cinzas: veios (compre o Detector para ver o minério) | Clique num destino para viajar"
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var dests := [["Vilarejo", "vila"], ["Lago", "lago"], ["Portão T2", "t2"], ["Portão T3", "t3"], ["Portão T4", "t4"], ["Portão T5", "t5"]]
	for d in dests:
		var b := Button.new()
		b.text = String(d[0])
		b.custom_minimum_size = Vector2(110, 36)
		b.set_meta("dest", String(d[1]))
		b.pressed.connect(func() -> void: game.fast_travel(String(b.get_meta("dest"))))
		row.add_child(b)
		_map_buttons.append(b)
	add_child(_map)


func open_menu(title: String, options: Array) -> void:
	_menu_title.text = title
	for child in _menu_list.get_children():
		_menu_list.remove_child(child)
		child.queue_free()
	for opt in options:
		var btn := Button.new()
		btn.text = String(opt.get("label", "?"))
		btn.icon = _icon_texture(String(opt.get("label", "?")))
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 20)
		btn.disabled = bool(opt.get("disabled", false))
		_style_button(btn)
		var cb: Callable = opt.get("action", Callable())
		if cb.is_valid():
			btn.pressed.connect(cb)
		_menu_list.add_child(btn)
	_menu_center.visible = true


func close_menu() -> void:
	_menu_center.visible = false


func refresh_all() -> void:
	if game == null:
		return
	_money_label.text = "Dinheiro: $%d" % game.money
	if game.debt > 0:
		_debt_label.visible = true
		_debt_label.text = "Dívida no banco: $%d" % game.debt
	else:
		_debt_label.visible = false
	var pa: Dictionary = GameData.PA_TIERS[game.pa_tier]
	var water_txt := "não"
	if game.bucket_water > 0.0:
		water_txt = "sim"
	var bucket_text := "Balde: %d/%d terra | água: %s" % [game.bucket_terra, int(pa["bucket"]), water_txt]
	if game.bars_heated > 0.0:
		bucket_text += "  |  Barras aquecidas: %ds" % int(game.bars_heated)
	_bucket_label.text = bucket_text
	var n_ores := 0
	for k in game.pocket_ores:
		n_ores += int(game.pocket_ores[k])
	var n_bars := 0.0
	for k in game.pocket_bars:
		n_bars += float(game.pocket_bars[k])
	var n_raw := 0
	for k in game.pocket_gems_raw:
		n_raw += int(game.pocket_gems_raw[k])
	var n_pol := 0
	for k in game.pocket_gems:
		n_pol += int(game.pocket_gems[k])
	_pocket_label.text = "Minérios: %d | Barras: %d | Gemas brutas: %d | Polidas: %d | Jóias: %d | Artefatos: %d" % [n_ores, int(n_bars), n_raw, n_pol, game.joias.size(), game.artefatos.size()]
	if game.quest_index < GameData.MAIN_QUESTS.size():
		var q: Dictionary = GameData.MAIN_QUESTS[game.quest_index]
		var qt := "Missão: %s" % String(q["text"])
		if not game.active_order.is_empty():
			var need := int(float(game.active_order["bars"]))
			var reward := int(float(game.active_order["reward"]))
			var ore_name: String = String(GameData.ORES[String(game.active_order["ore"])]["name"])
			qt += "\nEncomenda: %d barra(s) de %s — $%d" % [need, ore_name, reward]
		_quest_label.text = qt
	else:
		_quest_label.text = "Todas as missões principais concluídas! Continue construindo!"
	_prompt_label.text = game.get_prompt()
	_prompt_label.visible = _prompt_label.text != ""
	if game.brush_progress > 0.01:
		_brush_bg.visible = true
		var frac := clampf(game.brush_progress / maxf(game.brush_needed, 0.1), 0.0, 1.0)
		_brush_fill.size = Vector2(234.0 * frac, 8)
	else:
		_brush_bg.visible = false
	var bcap := float(GameData.PA_TIERS[game.pa_tier]["bucket"])
	var bfrac := clampf(game.bucket_terra / maxf(bcap, 0.01), 0.0, 1.0)
	if game.bucket_water > 0.0:
		bfrac = 1.0
		_bucket_fill.color = Color(0.3, 0.6, 0.9)
	else:
		_bucket_fill.color = Color(0.55, 0.38, 0.2)
	_bucket_bg.visible = bfrac > 0.01
	_bucket_fill.size = Vector2(234.0 * bfrac, 8)
	var hh := int(game.world_hour)
	var mm := int(fmod(game.world_hour, 1.0) * 60.0)
	var periodo := "madrugada"
	if hh >= 6 and hh < 12:
		periodo = "manhã"
	elif hh >= 12 and hh < 18:
		periodo = "tarde"
	elif hh >= 18:
		periodo = "noite"
	_clock_label.text = "%02d:%02d — %s" % [hh, mm, periodo]
	_perf_label.text = "FPS: %d | máquinas: %d" % [Engine.get_frames_per_second(), game.machines.list.size()]
	_help_label.text = "WASD mover | Shift correr | Espaço pular | Clique esq.: cavar / escovar | E: interagir | R: esvaziar balde | T: construir | Q/E ou roda: girar drill | X: desmontar | G: mover peça | V: dinamite | B: blueprint | M: mapa | H: diagnóstico | J: estatísticas | Esc: pausa | F5 salvar | F9 reiniciar | F10 teste | F11 showroom"


func set_text_scale(f: float) -> void:
	for e in _scaled:
		e[0].add_theme_font_size_override("font_size", int(float(e[1]) * f))


func credits_visible() -> bool:
	return _credits_visible


func show_credits() -> void:
	_credits_visible = true
	_credits.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_credits() -> void:
	_credits_visible = false
	_credits.visible = false


func _build_credits() -> void:
	_credits = Control.new()
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_credits.add_child(box)
	var lines: Array = [
		"HYDRONEER 2 — A HERANÇA",
		"Mineração, construção e automação industrial",
		"",
		"Design, programação e sons procedurais:",
		"Projeto Evolução do Hydroneer",
		"",
		"Feito com Godot Engine 4",
		"Inspirado na jogabilidade de Hydroneer, com identidade visual própria",
		"",
		"Obrigado por jogar! Aperte qualquer tecla para voltar.",
	]
	for i in lines.size():
		var l := Label.new()
		l.text = String(lines[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 40 if i == 0 else 18)
		if i == 0:
			l.modulate = Color(1.0, 0.8, 0.3)
		box.add_child(l)
	add_child(_credits)


var _icon_cache: Dictionary = {}
var _panel_cache: Texture2D = null


class CrossControl:
	extends Control

	func _draw() -> void:
		var c := Color(1.0, 1.0, 1.0, 0.85)
		draw_rect(Rect2(-11, -1, 8, 2), c)
		draw_rect(Rect2(3, -1, 8, 2), c)
		draw_rect(Rect2(-1, -11, 2, 8), c)
		draw_rect(Rect2(-1, 3, 2, 8), c)
		draw_rect(Rect2(-1.5, -1.5, 3, 3), Color(1.0, 0.35, 0.2))


func _panel_tex() -> Texture2D:
	if _panel_cache != null:
		return _panel_cache
	var loaded := load("res://assets/textures/wood.png") as Texture2D
	if loaded != null:
		_panel_cache = loaded
		return _panel_cache
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		var plank := y / 16
		var seed_v := 900 + plank * 17
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var base := 0.3 + rng.randf() * 0.1
		var grain_off := rng.randf() * 10.0
		for x in 128:
			var g := sin((float(x) + grain_off) * 0.35) * 0.03 + sin(float(x) * 0.08 + grain_off) * 0.04
			var v := clampf(base + g, 0.0, 1.0)
			if y % 16 == 0 or y % 16 == 15:
				v *= 0.55
			img.set_pixel(x, y, Color(v * 1.15, v * 0.85, v * 0.55))
	_panel_cache = ImageTexture.create_from_image(img)
	return _panel_cache


func _wood_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _panel_tex()
	sb.modulate_color = Color(0.85, 0.78, 0.72)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 9.0
	return sb


func _rustic_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 9.0
	return sb


func _bevel(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := _rustic_box(bg, border)
	sb.border_color = border.lightened(0.18)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _ic_rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, 19) + 1):
		for x in range(maxi(x0, 0), mini(x1, 19) + 1):
			img.set_pixel(x, y, col)


func _ic_line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0)) + 1
	for i in steps:
		var t := float(i) / float(maxi(steps - 1, 1))
		var x := roundi(float(x0) + (float(x1 - x0)) * t)
		var y := roundi(float(y0) + (float(y1 - y0)) * t)
		_ic_rect(img, x, y, x, y, col)


func _ic_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in 20:
		for x in 20:
			var d := Vector2(float(x) - cx, float(y) - cy).length()
			if d <= r and d >= r - 1.7:
				img.set_pixel(x, y, col)


func _icon_texture(label: String) -> ImageTexture:
	var key := label.to_lower()
	var kind := "hammer"
	var kinds := [["vertical", "esteira_v"], ["divisor", "splitter"], ["esteira", "esteira"], ["filtro", "filtro"], ["bacia", "bacia"], ["drill", "drill"], ["forja", "forja"], ["ba\u00fa", "bau"], ["silo", "silo"], ["gerador", "gerador"], ["polidora", "polidora"], ["prensa", "prensa"], ["cadinho", "cadinho"], ["bigorna", "bigorna"], ["harvester", "harvester"], ["cano", "cano"], ["cabo", "cabo"], ["parede", "parede"], ["piso", "piso"], ["funda\u00e7", "fundacao"], ["escada", "escada"], ["cerca", "cerca"], ["sensor", "sensor"], ["alarme", "alarme"], ["registro", "registro"], ["interruptor", "interruptor"], ["melhorar", "upgrade"], ["comprar", "dinheiro"], ["vender", "dinheiro"], ["salvar", "disquete"], ["mapa", "mapa"], ["cr\u00e9dito", "mapa"]]
	for k in kinds:
		if key.contains(String(k[0])):
			kind = String(k[1])
			break
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var gold := Color(0.9, 0.72, 0.3, 0.95)
	var dark := Color(0.25, 0.18, 0.1, 0.0)
	match kind:
		"drill":
			_ic_line(img, 4, 17, 10, 3, gold)
			_ic_line(img, 16, 17, 10, 3, gold)
			_ic_line(img, 6, 13, 14, 13, gold)
			_ic_line(img, 10, 3, 10, 18, Color(0.7, 0.72, 0.76, 0.95))
		"bacia":
			_ic_circle(img, 10.0, 10.0, 7.0, gold)
			_ic_rect(img, 6, 10, 14, 11, Color(0.35, 0.6, 0.85, 0.9))
		"forja":
			_ic_rect(img, 4, 9, 16, 17, gold)
			_ic_rect(img, 12, 3, 14, 9, gold)
			_ic_rect(img, 7, 12, 13, 15, Color(1.0, 0.5, 0.1, 0.95))
		"bau":
			_ic_rect(img, 4, 9, 16, 16, gold)
			_ic_rect(img, 4, 6, 16, 8, Color(0.75, 0.58, 0.25, 0.95))
			_ic_rect(img, 9, 10, 11, 12, Color(0.95, 0.8, 0.3, 0.95))
		"silo":
			_ic_rect(img, 7, 8, 13, 17, gold)
			_ic_line(img, 7, 8, 10, 4, gold)
			_ic_line(img, 13, 8, 10, 4, gold)
		"gerador":
			_ic_rect(img, 4, 9, 14, 16, gold)
			_ic_circle(img, 15.0, 8.0, 3.0, Color(0.7, 0.72, 0.76, 0.95))
		"polidora":
			_ic_circle(img, 10.0, 8.0, 4.5, gold)
			_ic_rect(img, 4, 15, 16, 17, Color(0.7, 0.5, 0.25, 0.95))
		"prensa":
			_ic_rect(img, 4, 3, 16, 4, gold)
			_ic_rect(img, 4, 4, 6, 17, gold)
			_ic_rect(img, 14, 4, 16, 17, gold)
			_ic_rect(img, 8, 6, 12, 11, Color(0.7, 0.72, 0.76, 0.95))
		"cadinho":
			_ic_line(img, 5, 6, 7, 16, gold)
			_ic_line(img, 15, 6, 13, 16, gold)
			_ic_line(img, 7, 16, 13, 16, gold)
			_ic_line(img, 5, 6, 15, 6, gold)
		"bigorna":
			_ic_rect(img, 5, 8, 15, 11, gold)
			_ic_rect(img, 8, 12, 12, 14, gold)
			_ic_rect(img, 6, 15, 14, 17, Color(0.5, 0.35, 0.2, 0.95))
		"harvester":
			_ic_line(img, 4, 4, 9, 10, gold)
			_ic_line(img, 16, 4, 11, 10, gold)
			_ic_rect(img, 8, 10, 12, 16, gold)
		"esteira", "esteira_v", "splitter", "filtro":
			_ic_line(img, 3, 8, 17, 8, gold)
			_ic_line(img, 3, 12, 17, 12, gold)
			_ic_circle(img, 6.0, 10.0, 1.6, gold)
			_ic_circle(img, 10.0, 10.0, 1.6, gold)
			_ic_circle(img, 14.0, 10.0, 1.6, gold)
		"cano":
			_ic_rect(img, 3, 9, 17, 11, Color(0.7, 0.72, 0.76, 0.95))
			_ic_rect(img, 8, 7, 10, 13, Color(0.55, 0.57, 0.62, 0.95))
		"cabo":
			_ic_rect(img, 4, 6, 5, 17, Color(0.5, 0.35, 0.2, 0.95))
			_ic_rect(img, 15, 6, 16, 17, Color(0.5, 0.35, 0.2, 0.95))
			_ic_line(img, 5, 7, 15, 7, gold)
		"parede":
			_ic_rect(img, 4, 4, 16, 17, gold)
			_ic_rect(img, 6, 6, 14, 15, dark)
			_ic_line(img, 6, 6, 14, 15, gold)
		"piso":
			_ic_rect(img, 3, 8, 17, 14, gold)
			_ic_line(img, 3, 11, 17, 11, dark)
		"fundacao":
			_ic_rect(img, 3, 8, 17, 15, gold)
			_ic_rect(img, 5, 10, 15, 13, dark)
		"escada":
			_ic_line(img, 4, 17, 10, 4, gold)
			for i in 4:
				_ic_rect(img, 5 + i * 3, 14 - i * 3, 9 + i * 3, 15 - i * 3, gold)
		"cerca":
			_ic_rect(img, 5, 6, 6, 17, gold)
			_ic_rect(img, 14, 6, 15, 17, gold)
			_ic_rect(img, 3, 8, 17, 9, gold)
			_ic_rect(img, 3, 13, 17, 14, gold)
		"sensor", "alarme":
			_ic_rect(img, 9, 10, 11, 17, Color(0.7, 0.72, 0.76, 0.95))
			_ic_circle(img, 10.0, 7.0, 3.5, gold)
		"registro":
			_ic_circle(img, 10.0, 10.0, 6.0, gold)
			_ic_line(img, 10, 5, 10, 15, gold)
			_ic_line(img, 5, 10, 15, 10, gold)
		"interruptor":
			_ic_rect(img, 6, 8, 14, 17, gold)
			_ic_line(img, 10, 8, 14, 4, Color(0.95, 0.8, 0.3, 0.95))
		"upgrade":
			_ic_line(img, 10, 16, 10, 5, gold)
			_ic_line(img, 6, 9, 10, 5, gold)
			_ic_line(img, 14, 9, 10, 5, gold)
		"dinheiro":
			_ic_circle(img, 10.0, 10.0, 6.5, gold)
			_ic_rect(img, 9, 6, 11, 14, gold)
		"disquete":
			_ic_rect(img, 4, 4, 16, 16, gold)
			_ic_rect(img, 7, 4, 13, 9, dark)
			_ic_rect(img, 6, 12, 14, 16, dark)
		"mapa":
			_ic_rect(img, 4, 4, 16, 16, gold)
			_ic_line(img, 8, 4, 8, 16, dark)
			_ic_line(img, 13, 4, 13, 16, dark)
		"hammer":
			_ic_rect(img, 5, 4, 15, 8, gold)
			_ic_line(img, 10, 8, 10, 17, Color(0.6, 0.42, 0.22, 0.95))
	var t := ImageTexture.create_from_image(img)
	_icon_cache[kind] = t
	return t
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(9)
	return sb


func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _bevel(Color(0.24, 0.17, 0.1), Color(0.5, 0.36, 0.18)))
	btn.add_theme_stylebox_override("hover", _bevel(Color(0.34, 0.25, 0.14), Color(0.85, 0.62, 0.3)))
	btn.add_theme_stylebox_override("pressed", _bevel(Color(0.42, 0.3, 0.17), Color(0.9, 0.7, 0.35)))
	btn.add_theme_stylebox_override("disabled", _bevel(Color(0.13, 0.11, 0.09), Color(0.28, 0.24, 0.2)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.93, 0.87, 0.74))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.6))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.46, 0.42))


func _make_label(pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	_scaled.append([label, size])
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


func _gauge_panel(off_top: int) -> Panel:
	var p := Panel.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -122
	p.offset_right = 122
	p.offset_top = off_top
	p.offset_bottom = off_top + 14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	sb.border_color = Color(0.55, 0.56, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	add_child(p)
	return p


func _build_brush_bar() -> void:
	_brush_bg = _gauge_panel(-60)
	_brush_fill = ColorRect.new()
	_brush_fill.color = Color(0.95, 0.65, 0.15)
	_brush_fill.position = Vector2(3, 3)
	_brush_fill.size = Vector2(0, 8)
	_brush_bg.add_child(_brush_fill)
	_bucket_bg = _gauge_panel(-78)
	_bucket_fill = ColorRect.new()
	_bucket_fill.color = Color(0.55, 0.38, 0.2)
	_bucket_fill.position = Vector2(3, 3)
	_bucket_fill.size = Vector2(0, 8)
	_bucket_bg.add_child(_bucket_fill)


func _build_menu() -> void:
	_menu_center = CenterContainer.new()
	_menu_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_center.visible = false
	add_child(_menu_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _wood_box())
	_menu_center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	_menu_title = Label.new()
	_menu_title.add_theme_font_size_override("font_size", 24)
	_menu_title.modulate = Color(1.0, 0.8, 0.3)
	vb.add_child(_menu_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 440)
	vb.add_child(scroll)
	_menu_list = VBoxContainer.new()
	_menu_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_menu_list)
	var hint := Label.new()
	hint.text = "E / T / Esc para fechar"
	hint.add_theme_font_size_override("font_size", 14)
	vb.add_child(hint)


func _build_intro() -> void:
	_intro = ColorRect.new()
	(_intro as ColorRect).color = Color(0, 0, 0, 0.88)
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.visible = false
	add_child(_intro)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _wood_box())
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "HYDRONEER 2 — A HERANÇA"
	title.add_theme_font_size_override("font_size", 30)
	vb.add_child(title)
	var body := Label.new()
	body.text = "Seu avô partiu, e estas terras (T1) agora são suas.\nSua família passa dificuldades — mas o vilarejo vizinho é amistoso\ne vai crescer junto com você.\n\nCOMO COMEÇAR:\n1. Vá até o lago (a oeste) e aperte E para encher o balde de água.\n2. Segure o clique esquerdo para cavar terra com a pá.\n3. Aperte E perto da bacia para despejar a terra.\n4. Aperte E de novo (com o balde d'água) para molhar a bacia.\n5. Mire na bacia e segure o clique esquerdo para ESCOVAR e revelar minérios.\n6. Ande perto dos minérios para pegá-los. E perto do Mercador para vender.\nDica: R esvazia o balde se ele estiver cheio com a coisa errada.\n\nAperte T para construir (canos, drill, harvester, forja, bigorna...).\nBoa sorte — e faça o vilarejo prosperar!"
	body.add_theme_font_size_override("font_size", 17)
	vb.add_child(body)
	var go := Label.new()
	go.text = "Pressione qualquer tecla para começar"
	go.add_theme_font_size_override("font_size", 19)
	vb.add_child(go)

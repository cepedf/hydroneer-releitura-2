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
var _crosshair: Label
var _brush_bg: ColorRect
var _brush_fill: ColorRect
var _menu_center: CenterContainer
var _menu_title: Label
var _menu_list: VBoxContainer
var _intro: Control
var _intro_visible := false
var _flash_time := 0.0
var _diag_label: Label
var _diag_time := 0.0


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
	_crosshair = _make_label(Vector2(-7, -12), 22)
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label = _make_label(Vector2(0, 190), 20)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_build_brush_bar()
	_build_menu()
	_build_intro()


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_label.modulate.a = clampf(_flash_time, 0.0, 1.0)
	if _diag_time > 0.0:
		_diag_time -= delta
		_diag_label.modulate.a = clampf(_diag_time, 0.0, 1.0)


func flash(text: String) -> void:
	_flash_label.text = text
	_flash_time = 3.5
	_flash_label.modulate.a = 1.0


func show_diag(text: String) -> void:
	_diag_label.text = text
	_diag_time = 8.0
	_diag_label.modulate.a = 1.0


func intro_visible() -> bool:
	return _intro_visible


func show_intro() -> void:
	_intro.visible = true
	_intro_visible = true


func hide_intro() -> void:
	_intro.visible = false
	_intro_visible = false


func open_menu(title: String, options: Array) -> void:
	_menu_title.text = title
	for child in _menu_list.get_children():
		_menu_list.remove_child(child)
		child.queue_free()
	for opt in options:
		var btn := Button.new()
		btn.text = String(opt.get("label", "?"))
		btn.disabled = bool(opt.get("disabled", false))
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
		_brush_fill.size = Vector2(236.0 * frac, 8)
	else:
		_brush_bg.visible = false
	_help_label.text = "WASD mover | Shift correr | Espaço pular | Clique esq.: cavar / escovar | E: interagir | R: esvaziar balde | T: construir | Q/E ou roda: girar drill | X: desmontar | H: diagnóstico | F5 salvar | F9 reiniciar | F10 teste"


func _make_label(pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


func _build_brush_bar() -> void:
	_brush_bg = ColorRect.new()
	_brush_bg.color = Color(0, 0, 0, 0.5)
	_brush_bg.anchor_left = 0.5
	_brush_bg.anchor_right = 0.5
	_brush_bg.anchor_top = 1.0
	_brush_bg.anchor_bottom = 1.0
	_brush_bg.offset_left = -120
	_brush_bg.offset_right = 120
	_brush_bg.offset_top = -60
	_brush_bg.offset_bottom = -48
	_brush_bg.visible = false
	add_child(_brush_bg)
	_brush_fill = ColorRect.new()
	_brush_fill.color = Color(0.4, 0.8, 1.0)
	_brush_fill.position = Vector2(2, 2)
	_brush_fill.size = Vector2(0, 8)
	_brush_bg.add_child(_brush_fill)


func _build_menu() -> void:
	_menu_center = CenterContainer.new()
	_menu_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_center.visible = false
	add_child(_menu_center)
	var panel := PanelContainer.new()
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

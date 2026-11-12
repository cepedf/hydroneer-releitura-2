extends CanvasLayer
## HUD: dinheiro, pepitas, objetivo atual, avisos e loja.

var game: Node3D

var _money_label: Label
var _bucket_label: Label
var _objective_label: Label
var _help_label: Label
var _flash_label: Label
var _shop_center: CenterContainer
var _shop_list: VBoxContainer
var _flash_time := 0.0


func _ready() -> void:
	_money_label = _make_label(Vector2(16, 12), 24)
	_bucket_label = _make_label(Vector2(16, 46), 18)
	_objective_label = _make_label(Vector2(16, 74), 18)
	_help_label = _make_label(Vector2(16, -30), 14)
	_help_label.anchor_top = 1.0
	_help_label.anchor_bottom = 1.0
	_flash_label = _make_label(Vector2(0, 130), 24)
	_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash_label.modulate.a = 0.0
	var crosshair := _make_label(Vector2(-6, -12), 22)
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_build_shop()


func _process(delta: float) -> void:
	_money_label.text = "Dinheiro: $%d" % game.money
	_bucket_label.text = "Pepitas: %d / %d" % [game.bucket, game.bucket_cap]
	if game.objective_index < game.OBJECTIVES.size():
		var obj: Dictionary = game.OBJECTIVES[game.objective_index]
		_objective_label.text = "Objetivo: %s  (recompensa $%d)" % [obj["text"], obj["reward"]]
	else:
		_objective_label.text = "Todos os objetivos concluídos! Continue minerando!"
	var hint := "WASD mover | Shift correr | Espaço pular | Segurar clique esquerdo: cavar | B: loja | F5: salvar | F9: reiniciar"
	if game.near_stall():
		hint = ">> Aperte E para vender as pepitas <<   " + hint
	_help_label.text = hint
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_label.modulate.a = clampf(_flash_time, 0.0, 1.0)


func flash(text: String) -> void:
	_flash_label.text = text
	_flash_time = 3.0
	_flash_label.modulate.a = 1.0


func set_shop_visible(value: bool) -> void:
	_shop_center.visible = value
	if value:
		refresh_shop()


func refresh_shop() -> void:
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()
	for item in game.SHOP_ITEMS:
		var btn := Button.new()
		var owned_text := "  (COMPRADO)" if game.owned.has(item["id"]) else ""
		btn.text = "%s — $%d%s\n%s" % [item["name"], item["price"], owned_text, item["desc"]]
		btn.disabled = not game.can_buy(item)
		btn.pressed.connect(game.buy.bind(item["id"]))
		_shop_list.add_child(btn)


func _make_label(pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


func _build_shop() -> void:
	_shop_center = CenterContainer.new()
	_shop_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_center.visible = false
	add_child(_shop_center)
	var panel := PanelContainer.new()
	_shop_center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "LOJA DE EQUIPAMENTOS"
	title.add_theme_font_size_override("font_size", 26)
	vb.add_child(title)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 6)
	vb.add_child(_shop_list)
	var hint := Label.new()
	hint.text = "Aperte B para fechar"
	hint.add_theme_font_size_override("font_size", 14)
	vb.add_child(hint)

class_name LabPanel
extends CanvasLayer
## Painel do Laboratorio: mundo, alvo e a tabela de pontos (x, y) do ultimo tiro.
##
## A tabela compara, metro a metro, a altura medida na bala de verdade com a
## altura que a equacao preve. E a ideia de funcao na pratica: entra x, sai y.

signal world_chosen(key: String)
signal clear_pressed
signal exit_pressed

const MAX_ROWS := 40

var _rows: GridContainer
var _target: Label
var _hint: Label


func _ready() -> void:
	layer = 4
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))
	panel.custom_minimum_size = Vector2(250, 0)
	add_child(panel)
	# Abaixo do botão de ajuda do canto, que continua clicável.
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -14.0
	panel.offset_top = 74.0

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var title := Label.new()
	title.text = "LABORATÓRIO"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	col.add_child(title)

	var worlds := GridContainer.new()
	worlds.columns = 3
	worlds.add_theme_constant_override("h_separation", 4)
	worlds.add_theme_constant_override("v_separation", 4)
	col.add_child(worlds)
	for key in Campaign.LAB_WORLDS:
		var b := UiButton.create(Campaign.LAB_WORLDS[key].name, UiButton.Kind.SECONDARY)
		b.custom_minimum_size = Vector2(72, 32)
		b.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
		if key == Global.lab_world:
			b.add_theme_color_override("font_color", UiTokens.EDITABLE)
		b.pressed.connect(func(): world_chosen.emit(key))
		worlds.add_child(b)

	_hint = Label.new()
	_hint.text = "Clique no céu para pôr um alvo."
	_hint.theme_type_variation = &"CaptionLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	_target = Label.new()
	_target.theme_type_variation = &"CaptionLabel"
	_target.add_theme_color_override("font_color", UiTokens.EDITABLE)
	_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_target)

	var head := HBoxContainer.new()
	for t in ["x (m)", "y bala", "y conta"]:
		var h := Label.new()
		h.text = t
		h.theme_type_variation = &"CaptionLabel"
		h.custom_minimum_size = Vector2(70, 0)
		head.add_child(h)
	col.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_rows = GridContainer.new()
	_rows.columns = 3
	_rows.add_theme_constant_override("h_separation", 0)
	scroll.add_child(_rows)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	var clear := UiButton.create("Limpar", UiButton.Kind.SECONDARY)
	clear.custom_minimum_size = Vector2(110, 36)
	clear.pressed.connect(func(): clear_pressed.emit())
	buttons.add_child(clear)
	var leave := UiButton.create("Sair", UiButton.Kind.SECONDARY)
	leave.custom_minimum_size = Vector2(110, 36)
	leave.pressed.connect(func(): exit_pressed.emit())
	buttons.add_child(leave)


func clear_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()


## Uma linha da tabela. Quando bala e conta concordam (ate 0,1 m), o valor da
## conta fica na cor do calculado; senao, em perigo (bala desviada pela mira).
func add_row(x: int, y_bullet: float, y_eq: float, accent: Color) -> void:
	if _rows.get_child_count() >= MAX_ROWS * 3:
		return
	var agree := absf(y_bullet - y_eq) <= 0.15
	for i in range(3):
		var l := Label.new()
		l.custom_minimum_size = Vector2(70, 0)
		l.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
		match i:
			0:
				l.text = str(x)
			1:
				l.text = Ballistics.fmt(y_bullet)
			2:
				l.text = Ballistics.fmt(y_eq)
				l.add_theme_color_override("font_color", accent if agree else UiTokens.DANGER)
		_rows.add_child(l)


func set_target_text(text: String) -> void:
	_target.text = text
	_hint.visible = text == ""


func panel_rect() -> Rect2:
	return get_child(0).get_global_rect()

class_name HelpOverlay
extends UiModal
## Tela de ajuda da arena (H ou botao "?"), com o jogo pausado.
##
## Tres abas, em linguagem de crianca:
##   Teclas          -- todos os controles, com o desenho da tecla
##   A parabola      -- mini-diagrama: vertice, raiz, altura do canhao (c)
##   As engrenagens  -- o efeito de cada engrenagem, em tres mini-graficos
##
## A pausa fica com a arena (pauses_game = false aqui).

const ICON_ARROWS_V = preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_vertical.png")
const ICON_ARROWS_H = preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_horizontal.png")
const ICON_SHIFT = preload("res://assets/sprites/keyboard_mouse/keyboard_shift.png")
const ICON_SPACE = preload("res://assets/sprites/keyboard_mouse/keyboard_space.png")
const ICON_TAB = preload("res://assets/sprites/keyboard_mouse/keyboard_tab.png")
const ICON_ESCAPE = preload("res://assets/sprites/keyboard_mouse/keyboard_escape.png")
const ICON_MOUSE = preload("res://assets/sprites/keyboard_mouse/mouse_left.png")

const PANEL_SIZE := Vector2(940, 560)
const PAGE_SIZE := Vector2(880, 400)

var _pages: Array = []
var _tabs: Array = []
var _close_btn: Button


## Compatibilidade com a arena; o UiModal ja usa a moldura MODAL.
func setup(_panel_style: StyleBox = null) -> void:
	pass


func _build_content() -> void:
	pauses_game = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "Como jogar e o que é a parábola"

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", UiTokens.GAP_SM)
	body.add_child(tab_row)
	var group := ButtonGroup.new()
	for title in ["As teclas", "A parábola", "As engrenagens"]:
		var tab := UiButton.create(title, UiButton.Kind.SECONDARY, null, true)
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2(200, 44)
		tab.add_theme_color_override("font_pressed_color", UiTokens.EDITABLE)
		var index := _tabs.size()
		tab.toggled.connect(_on_tab_toggled.bind(index))
		tab_row.add_child(tab)
		_tabs.append(tab)

	_pages = [_build_keys_page(), _build_parabola_page(), _build_gears_page()]
	for page in _pages:
		page.custom_minimum_size = PAGE_SIZE
		body.add_child(page)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(buttons)
	var again := UiButton.create("Rever o tutorial da Ada", UiButton.Kind.SECONDARY, null, true)
	again.custom_minimum_size = Vector2(300, 52)
	again.pressed.connect(_replay_tutorial.bind(again))
	buttons.add_child(again)
	_close_btn = UiButton.create("ENTENDI!", UiButton.Kind.PRIMARY, null, true)
	_close_btn.pressed.connect(close)
	buttons.add_child(_close_btn)
	_tabs[0].button_pressed = true


func open() -> void:
	super()
	_close_btn.grab_focus.call_deferred()


## O tutorial volta a aparecer na proxima vez que a Base Alpha, fase 1, abrir.
func _replay_tutorial(button: Button) -> void:
	Global.tutorial_done = false
	Global.save_game()
	button.text = "Ok! Ele aparece na Alpha, fase 1"
	button.disabled = true


func _on_tab_toggled(on: bool, index: int) -> void:
	if on:
		_show_page(index)


func _show_page(index: int) -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == index


# ═════════════════════════════════════════════════════════════════════
#  ABA 1 — TECLAS
# ═════════════════════════════════════════════════════════════════════


func _build_keys_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 10)
	var rows := [
		[ICON_ARROWS_H, "Esquerda e Direita", "escolhem a engrenagem que você vai girar"],
		[ICON_ARROWS_V, "Cima e Baixo", "giram a engrenagem escolhida"],
		[ICON_MOUSE, "Mouse", "segure na engrenagem e gire em volta dela"],
		[ICON_SHIFT, "Shift + seta", "gira devagarinho, para acertar o número"],
		[ICON_SPACE, "Espaço", "dispara o canhão"],
		[ICON_TAB, "Tab", "troca a munição"],
		[null, "A e D", "andam com o tanque (quando há combustível)"],
		[null, "F", "mostra a conta por trás da curva"],
		[null, "C", "modo chute: esconde a curva para você calcular"],
		[null, "H", "abre esta ajuda"],
		[ICON_ESCAPE, "Esc", "pausa o jogo ou fecha esta tela"],
	]
	for r in rows:
		grid.add_child(_key_row(r[0], r[1], r[2]))
	return grid


func _key_row(tex: Texture2D, key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(420, 0)
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	else:
		# Tecla sem desenho no pack: a letra numa moldura de tecla.
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override(
			"panel", UiButton.make_style(UiTokens.TEXT, UiTokens.TEXT_DIM, false, 4)
		)
		cap.custom_minimum_size = Vector2(44, 40)
		var letter := Label.new()
		letter.text = key.substr(0, 1)
		letter.add_theme_color_override("font_color", UiTokens.INK)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(letter)
		row.add_child(cap)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	var k := Label.new()
	k.text = key
	k.theme_type_variation = &"EditableLabel"
	k.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	col.add_child(k)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	t.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	col.add_child(t)
	row.add_child(col)
	return row


# ═════════════════════════════════════════════════════════════════════
#  ABA 2 — A PARÁBOLA
# ═════════════════════════════════════════════════════════════════════


func _build_parabola_page() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_LG)

	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	row.add_child(paper)
	var diagram := ParabolaDiagram.new()
	diagram.custom_minimum_size = Vector2(470, 250)
	diagram.annotate = true
	diagram.span_m = 29.0
	diagram.curves = [
		{"angle": 45.0, "speed": 800.0, "gravity": 500.0, "color": UiTokens.CALCULATED_ON_PAPER}
	]
	paper.add_child(diagram)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 10)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_heading("A bala faz uma curva"))
	text.add_child(
		_para(
			(
				"Ela sobe, vai ficando mais devagar, para um instantinho lá no alto e cai. "
				+ "Essa curva se chama PARÁBOLA."
			)
		)
	)
	text.add_child(_heading("A conta da curva"))
	text.add_child(
		_para(
			(
				"No painel de cima: y = ax² + bx + c. O x é a distância (a régua) e o y é a "
				+ "altura. O 'a' é negativo e dobra a curva para baixo; o 'c' é a altura do canhão."
			)
		)
	)
	text.add_child(_heading("Confira na tela"))
	text.add_child(
		_para(
			(
				"O losango marca o vértice e a bandeira marca a raiz. Os números do painel "
				+ "batem com a régua: confira com os olhos!"
			)
		)
	)
	return row


# ═════════════════════════════════════════════════════════════════════
#  ABA 3 — AS ENGRENAGENS
# ═════════════════════════════════════════════════════════════════════


func _build_gears_page() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)
	var calc := UiTokens.CALCULATED_ON_PAPER
	var edit := UiTokens.EDITABLE_ON_PAPER
	var danger := UiTokens.DANGER_ON_PAPER
	(
		row
		. add_child(
			_gear_card(
				"ÂNGULO  ·  mexe no a e no b",
				"45° vai mais longe. 30° e 60° caem no mesmo lugar!",
				[
					{
						"angle": 30.0,
						"speed": 800.0,
						"gravity": 500.0,
						"color": edit,
						"label": "30°"
					},
					{
						"angle": 45.0,
						"speed": 800.0,
						"gravity": 500.0,
						"color": calc,
						"label": "45°"
					},
					{
						"angle": 60.0,
						"speed": 800.0,
						"gravity": 500.0,
						"color": danger,
						"label": "60°"
					},
				],
				30.0
			)
		)
	)
	(
		row
		. add_child(
			_gear_card(
				"FORÇA  ·  mexe no a",
				"Metade da força: a bala vai só a um quarto da distância.",
				[
					{
						"angle": 45.0,
						"speed": 400.0,
						"gravity": 500.0,
						"color": edit,
						"label": "50%"
					},
					{
						"angle": 45.0,
						"speed": 800.0,
						"gravity": 500.0,
						"color": calc,
						"label": "100%"
					},
				],
				30.0
			)
		)
	)
	(
		row
		. add_child(
			_gear_card(
				"GRAVIDADE  ·  mexe no a",
				"Mais gravidade, curva mais fechada e tiro mais curto.",
				[
					{
						"angle": 45.0,
						"speed": 400.0,
						"gravity": 185.0,
						"color": edit,
						"label": "Marte",
						"label_at": "root"
					},
					{
						"angle": 45.0,
						"speed": 400.0,
						"gravity": 490.0,
						"color": calc,
						"label": "Terra",
						"label_at": "root"
					},
					{
						"angle": 45.0,
						"speed": 400.0,
						"gravity": 1240.0,
						"color": danger,
						"label": "Júpiter",
						"label_at": "root"
					},
				],
				20.0
			)
		)
	)
	return row


func _gear_card(title: String, text: String, curves: Array, span: float) -> Control:
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	paper.add_child(col)
	var head := Label.new()
	head.text = title
	head.theme_type_variation = &"InkLabel"
	head.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	col.add_child(head)
	var diagram := ParabolaDiagram.new()
	diagram.custom_minimum_size = Vector2(250, 220)
	diagram.curves = curves
	diagram.span_m = span
	col.add_child(diagram)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InkLabel"
	label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	col.add_child(label)
	return paper


func _heading(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = &"HeadingLabel"
	return label


func _para(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(370, 0)
	label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	return label

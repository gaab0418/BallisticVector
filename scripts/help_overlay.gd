class_name HelpOverlay
extends CanvasLayer
## Tela de ajuda da arena: explica as teclas e o que é a parábola, com o jogo pausado.
##
## É um CanvasLayer próprio, e não um Control dentro do HUD, por dois motivos: layer = 10
## garante o desenho por cima sem depender da ordem dos irmãos, e PROCESS_MODE_ALWAYS no
## nó raiz propaga por herança para a árvore inteira do overlay, que precisa continuar
## respondendo enquanto get_tree().paused congela o resto do jogo.

signal closed

const BTN_TEXTURE = preload(
	"res://assets/sprites/ui_pack/Grey/Default/button_rectangle_depth_flat.png"
)
const ICON_ARROWS_V = preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_vertical.png")
const ICON_ARROWS_H = preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_horizontal.png")
const ICON_SHIFT = preload("res://assets/sprites/keyboard_mouse/keyboard_shift.png")
const ICON_SPACE = preload("res://assets/sprites/keyboard_mouse/keyboard_space.png")
const ICON_TAB = preload("res://assets/sprites/keyboard_mouse/keyboard_tab.png")
const ICON_ESCAPE = preload("res://assets/sprites/keyboard_mouse/keyboard_escape.png")
const ICON_MOUSE = preload("res://assets/sprites/keyboard_mouse/mouse_left.png")

const PANEL_SIZE := Vector2(1080, 620)
const SCROLL_SIZE := Vector2(1020, 460)
const KEYS_WIDTH: float = 340.0

const COLOR_TITLE := Color(1.0, 0.85, 0.3)
const COLOR_TEXT := Color(0.9, 0.8, 0.6)
const COLOR_DIM := Color(0.7, 0.6, 0.42)
const COLOR_SUBTITLE := Color(0.85, 0.68, 0.35)

var _font: Font
var _close_btn: Button


func setup(font: Font, panel_style: StyleBoxFlat) -> void:
	_font = font
	layer = 10
	# Sem isto o overlay congelaria junto com o jogo e não daria nem para fechá-lo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.03, 0.0, 0.82)
	# Segura o clique para não vazar nos botões da HUD que ficam atrás.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Container que garante o alinhamento centralizado independente da resolução
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var window := PanelContainer.new()
	panel_style.set_content_margin_all(24)
	window.add_theme_stylebox_override("panel", panel_style)
	window.custom_minimum_size = PANEL_SIZE
	center.add_child(window)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	window.add_child(box)
	box.add_child(_make_label("Como jogar e o que é a parábola", 32, COLOR_TITLE, true))
	box.add_child(_build_columns())
	box.add_child(_build_close_button())


func open() -> void:
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Só o Esc precisa ser tratado como evento; o resto do jogo lê input por polling
## (Input.is_action_*), que set_input_as_handled() não bloqueia. Quem protege o jogo
## enquanto esta tela está aberta é o get_tree().paused, não o consumo do evento.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# O ScrollContainer não é enfeite: no build Linux a SystemFont cai para DejaVu, com
# métricas maiores, e sem ele o texto transbordaria o painel em vez de rolar.
func _build_columns() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = SCROLL_SIZE
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var columns := HBoxContainer.new()
	# Força o container de colunas a esticar até a borda direita do ScrollContainer
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	scroll.add_child(columns)

	columns.add_child(_build_keys_column())
	columns.add_child(VSeparator.new())
	columns.add_child(_build_physics_column())
	return scroll


func _build_keys_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(KEYS_WIDTH, 0.0)
	col.add_child(_make_label("As teclas", 20, COLOR_SUBTITLE, false))

	col.add_child(
		_make_key_row(ICON_ARROWS_H, "Esquerda e Direita\nescolhem qual engrenagem você vai girar")
	)
	col.add_child(_make_key_row(ICON_ARROWS_V, "Cima e Baixo\ngiram a engrenagem escolhida"))
	col.add_child(_make_key_row(ICON_MOUSE, "Mouse\nsegure na engrenagem e gire em volta dela"))
	col.add_child(
		_make_key_row(ICON_SHIFT, "Shift + seta\ngira devagarinho, para acertar o número exato")
	)
	col.add_child(_make_key_row(ICON_SPACE, "Espaço\ndispara o canhão"))
	col.add_child(_make_key_row(ICON_TAB, "Tab\ntroca a munição"))
	col.add_child(_make_key_row(ICON_ESCAPE, "Esc\nfecha esta tela"))

	col.add_child(HSeparator.new())
	var formula := (
		"Para quem quiser ver a conta:\n"
		+ "Alcance = força × força × sen(2 × ângulo) ÷ gravidade\n"
		+ "Altura = força × força × sen(ângulo) × sen(ângulo) ÷ (2 × gravidade)"
	)
	col.add_child(_make_paragraph(formula, 15, COLOR_DIM))
	return col


func _build_physics_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_make_label("A parábola", 20, COLOR_SUBTITLE, false))

	col.add_child(
		_make_paragraph(
			(
				"A bala não anda em linha reta. Ela sobe, vai ficando mais devagar, para "
				+ "um instantinho lá no alto e depois cai. Esse caminho curvo se chama "
				+ "parábola — é a linha vermelha que aparece na frente do canhão."
			),
			19,
			COLOR_TEXT
		)
	)

	col.add_child(_make_label("Por que a curva acontece?", 20, COLOR_SUBTITLE, false))
	col.add_child(
		_make_paragraph(
			(
				"Duas coisas acontecem ao mesmo tempo: para a frente, a bala anda sempre "
				+ "na mesma velocidade; para baixo, a gravidade puxa a bala o tempo todo, "
				+ "sem parar. Junte as duas e nasce a curva."
			),
			19,
			COLOR_TEXT
		)
	)

	col.add_child(_make_label("Gire as engrenagens e veja", 20, COLOR_SUBTITLE, false))
	col.add_child(
		_make_paragraph(
			(
				"• Ângulo — perto de 45° a bala vai mais longe. Mais alto, ela sobe muito "
				+ "e cai perto. Mais baixo, ela cai cedo demais.\n"
				+ "• Força — se você dobrar a força, o alcance fica quatro vezes maior. "
				+ "A força conta duas vezes na conta!\n"
				+ "• Gravidade — 2 é como na Lua, 10 é como aqui na Terra e 25 é como em "
				+ "Júpiter. Quanto maior, mais rápido a bala cai e mais curto fica o tiro."
			),
			19,
			COLOR_TEXT
		)
	)

	col.add_child(
		_make_paragraph(
			(
				"Alcance e Altura máx. mostram, em metros, onde a bala cairia e até que "
				+ "altura ela subiria num campo plano, sem montanhas. Se o canhão apontar "
				+ "para baixo aparece um traço, porque a conta só vale com o tiro subindo."
			),
			19,
			COLOR_TEXT
		)
	)

	col.add_child(
		_make_paragraph(
			(
				"A munição Enferrujada é velha e treme um pouquinho, então a bala foge um "
				+ "pouco da linha desenhada. A Perfurante é certeira: use ela quando quiser "
				+ "conferir se as contas batem."
			),
			19,
			COLOR_DIM
		)
	)

	col.add_child(
		_make_paragraph(
			(
				"Dica: abra esta tela no meio de um tiro. O jogo congela e você vê a bala "
				+ "parada bem em cima da parábola!"
			),
			19,
			COLOR_SUBTITLE
		)
	)
	return col


func _build_close_button() -> Button:
	_close_btn = Button.new()
	_close_btn.text = "ENTENDI!"
	_close_btn.custom_minimum_size = Vector2(0, 48)
	_close_btn.add_theme_font_override("font", _font)
	_close_btn.add_theme_font_size_override("font_size", 22)
	_close_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))

	var normal_style := StyleBoxTexture.new()
	normal_style.texture = BTN_TEXTURE
	normal_style.set_content_margin_all(10.0)
	var hover_style: StyleBoxTexture = normal_style.duplicate()
	hover_style.modulate_color = Color(1.1, 1.05, 0.95)
	var pressed_style: StyleBoxTexture = normal_style.duplicate()
	pressed_style.modulate_color = Color(0.85, 0.8, 0.75)
	_close_btn.add_theme_stylebox_override("normal", normal_style)
	_close_btn.add_theme_stylebox_override("hover", hover_style)
	_close_btn.add_theme_stylebox_override("pressed", pressed_style)

	# Com foco, o Espaço (que é o tiro) acionaria este botão e as setas virariam
	# navegação de foco, matando as engrenagens.
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.pressed.connect(close)
	return _close_btn


func _make_key_row(tex: Texture2D, text_value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := _make_paragraph(text_value, 17, COLOR_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _make_label(text_value: String, size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_paragraph(text_value: String, size: int, color: Color) -> Label:
	var label := _make_label(text_value, size, color, false)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

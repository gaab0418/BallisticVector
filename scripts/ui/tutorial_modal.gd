class_name TutorialModal
extends UiModal
## Tutorial modal: 7 paginas da mecanica e a confirmacao "Deseja sair do tutorial?"
## na mesma janela (modais empilhados disputam o Esc, ver pause_menu.gd). A
## navegacao com as setas e o rodape seguem o notebook_panel.gd.
##
## Modos de abertura:
##   open()              -- pagina 0; cancelar a saida volta ao mesmo passo;
##   open_exit_prompt()  -- direto na confirmacao (arena de pratica); cancelar
##                          fecha a janela.
## `completed` sai no botao da ultima pagina; `aborted`, ao confirmar a saida. O
## modal nao grava nada no save: quem escuta decide (menu e arena de pratica).

signal completed
signal aborted

const EXIT_QUESTION := "Deseja sair do tutorial?"
const PANEL_SIZE := Vector2(880, 0)
const CONFIRM_SIZE := Vector2(440, 260)
const FIGURE_SIZE := Vector2(640, 230)
## Teto do angulo na demonstracao da pagina "Angulo".
const SWEEP_MAX_ANGLE := 60.0
const TEXT_WIDTH := 700.0

const NEXT_LABEL := "PRÓXIMO →"
const LAST_LABEL := "IR PARA A CALIBRAGEM"
const PREV_LABEL := "← ANTERIOR"
const LEAVE_LABEL := "SAIR DO TUTORIAL"
const FIGURE_COMMANDS := "commands"

## `figure` escolhe o desenho em _build_figure(); a pagina de comandos nao tem
## figura, e sim a lista de COMMANDS no fundo do modal.
const PAGES := [
	{
		"title": "O seu tanque",
		"figure": "gears",
		"text":
		(
			"Três engrenagens controlam o tiro: ÂNGULO, FORÇA e GRAVIDADE. "
			+ "← → escolhem a engrenagem; ↑ ↓ giram (ou arraste com o mouse)."
		),
	},
	{
		"title": "Ângulo",
		"figure": "sweep",
		"text":
		"O ângulo muda a forma da curva antes mesmo do tiro. Perto de 45° a bala vai mais longe.",
	},
	{
		"title": "Força",
		"figure": "power",
		"text":
		(
			"A força é a velocidade de saída da bala. "
			+ "Metade da força leva a bala a um quarto da distância."
		),
	},
	{
		"title": "A parábola",
		"figure": "parabola",
		"text":
		(
			"O caminho da bala é uma parábola: y = ax² + bx + c. "
			+ "O losango marca o vértice, a altura máxima; a bandeira marca a raiz, onde a bala cai."
		),
	},
	{
		"title": "Gravidade",
		"figure": "gravity",
		"text":
		(
			'A gravidade mexe no "a" da equação: '
			+ "mais gravidade, curva mais fechada e tiro mais curto."
		),
	},
	{"title": "Comandos", "figure": FIGURE_COMMANDS, "text": ""},
	{
		"title": "Calibragem",
		"figure": "calibration",
		"text":
		"Antes de partir, a Ada testa o canhão numa fortaleza que já caiu. Um acerto derruba.",
	},
]

## Pagina 6: [visual da tecla, nome, rotulo]. O visual e montado em _key_visual().
const COMMANDS := [
	["space", "Espaço", "dispara"],
	["ad", "A e D", "anda, quando há combustível"],
	["tab", "Tab", "troca a munição"],
	["star", "Estrela", "missões da fase (três estrelas)"],
	["h", "H", "ajuda"],
]

const GEARS := [
	["angle", "ÂNGULO"],
	["force", "FORÇA"],
	["planet", "GRAVIDADE"],
]

const TANK_TEXTURE := preload("res://assets/sprites/tank_player.png")
const BOSS_TEXTURE := preload("res://assets/sprites/boss.png")
const SPRITE_SIZE := Vector2(180, 100)

var _index := 0
var _page_box: VBoxContainer
var _sheet: PanelContainer
var _figure_slot: CenterContainer
var _commands: VBoxContainer
var _text: Label
var _footer: HBoxContainer
var _prev_btn: Button
var _counter: Label
var _next_btn: Button
var _confirm_box: VBoxContainer
var _continue_btn: Button
var _confirming := false
## Aberto so para confirmar a saida (arena de pratica): cancelar fecha a janela.
var _exit_only := false


func _build_content() -> void:
	close_on_escape = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "TUTORIAL"
	_build_pages()
	_build_footer()
	_build_confirm()


func _build_pages() -> void:
	_page_box = VBoxContainer.new()
	_page_box.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(_page_box)

	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.SHEET))
	_page_box.add_child(_sheet)
	_figure_slot = CenterContainer.new()
	_figure_slot.custom_minimum_size = FIGURE_SIZE
	_sheet.add_child(_figure_slot)

	_commands = VBoxContainer.new()
	_commands.name = "CommandList"
	_commands.add_theme_constant_override("separation", 10)
	_commands.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry in COMMANDS:
		_commands.add_child(_command_row(entry[0], entry[1], entry[2]))
	_page_box.add_child(_commands)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 90)
	_page_box.add_child(_text)


func _build_footer() -> void:
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(_footer)

	var leave := UiButton.create(LEAVE_LABEL, UiButton.Kind.SECONDARY, null, true)
	leave.pressed.connect(ask_exit)
	_footer.add_child(leave)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(gap)

	_prev_btn = UiButton.create(PREV_LABEL, UiButton.Kind.SECONDARY, null, true)
	_prev_btn.pressed.connect(prev_page)
	_footer.add_child(_prev_btn)

	_counter = Label.new()
	_counter.custom_minimum_size = Vector2(130, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_child(_counter)

	_next_btn = UiButton.create(NEXT_LABEL, UiButton.Kind.PRIMARY, null, true)
	_next_btn.custom_minimum_size.x = 280
	_next_btn.pressed.connect(_on_next_pressed)
	_footer.add_child(_next_btn)


func _build_confirm() -> void:
	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(_confirm_box)

	var question := Label.new()
	question.text = EXIT_QUESTION
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm_box.add_child(question)

	_continue_btn = UiButton.create("CONTINUAR O TUTORIAL", UiButton.Kind.SECONDARY, null, true)
	_continue_btn.pressed.connect(cancel_exit)
	_confirm_box.add_child(_continue_btn)

	var leave := UiButton.create("SAIR", UiButton.Kind.DANGER, null, true)
	leave.pressed.connect(confirm_exit)
	_confirm_box.add_child(leave)
	_confirm_box.visible = false


# ═════════════════════════════════════════════════════════════════════
#  API
# ═════════════════════════════════════════════════════════════════════


## Abre na pagina 0.
func open() -> void:
	_begin(false)


## Abre direto na confirmacao; cancelar fecha o modal (usado na arena de pratica).
func open_exit_prompt() -> void:
	_begin(true)
	ask_exit()


func close() -> void:
	Narrator.stop()
	super()


func page_index() -> int:
	return _index


func next_page() -> void:
	_go_to(_index + 1)


func prev_page() -> void:
	_go_to(_index - 1)


func ask_exit() -> void:
	_confirming = true
	_page_box.visible = false
	_footer.visible = false
	_confirm_box.visible = true
	Narrator.speak(EXIT_QUESTION)
	_focus_continue.call_deferred()


func cancel_exit() -> void:
	_confirming = false
	_confirm_box.visible = false
	if _exit_only:
		_exit_only = false
		close()
		return
	_page_box.visible = true
	_footer.visible = true
	_speak_page()
	_focus_next.call_deferred()


func confirm_exit() -> void:
	_confirming = false
	_exit_only = false
	_confirm_box.visible = false
	close()
	aborted.emit()


func is_confirming() -> bool:
	return visible and _confirming


# ═════════════════════════════════════════════════════════════════════
#  Estado e navegacao
# ═════════════════════════════════════════════════════════════════════


func _begin(exit_only: bool) -> void:
	_exit_only = exit_only
	_confirming = false
	_confirm_box.visible = false
	_index = 0
	window.custom_minimum_size = CONFIRM_SIZE if exit_only else PANEL_SIZE
	_page_box.visible = not exit_only
	_footer.visible = not exit_only
	if not exit_only:
		_show_page()
	super.open()
	if not exit_only:
		_focus_next.call_deferred()


func _go_to(target: int) -> void:
	var clamped := clampi(target, 0, PAGES.size() - 1)
	if clamped == _index:
		return
	_index = clamped
	_show_page()


func _on_next_pressed() -> void:
	if _index < PAGES.size() - 1:
		next_page()
		return
	close()
	completed.emit()


## Esc pede para sair (ou cancela a confirmacao); as setas viram a pagina.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirming:
			cancel_exit()
		else:
			ask_exit()
	elif _confirming:
		return
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		prev_page()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		next_page()


## Foco no "continuar": Enter por engano nao tira o jogador do tutorial. Deferido,
## e a confirmacao pode ja ter trocado de cena quando ele roda.
func _focus_continue() -> void:
	if is_inside_tree() and is_confirming():
		_continue_btn.grab_focus()


func _focus_next() -> void:
	if is_inside_tree() and visible and not _confirming:
		_next_btn.grab_focus()


# ═════════════════════════════════════════════════════════════════════
#  Paginas
# ═════════════════════════════════════════════════════════════════════


func _show_page() -> void:
	var page: Dictionary = PAGES[_index]
	var is_list: bool = page.figure == FIGURE_COMMANDS
	title_label.text = page.title
	_sheet.visible = not is_list
	_commands.visible = is_list
	_text.visible = not is_list
	_text.text = page.text
	_text.add_theme_font_size_override(
		"font_size", UiTokens.FONT_LG if Global.big_text else UiTokens.FONT_MD
	)
	_clear_figure()
	if not is_list:
		_figure_slot.add_child(_build_figure(page.figure))
	_counter.text = "Passo %d de %d" % [_index + 1, PAGES.size()]
	_prev_btn.disabled = _index == 0
	_next_btn.text = LAST_LABEL if _index == PAGES.size() - 1 else NEXT_LABEL
	_speak_page()


func _clear_figure() -> void:
	for child in _figure_slot.get_children():
		_figure_slot.remove_child(child)
		child.queue_free()


func _speak_page() -> void:
	var page: Dictionary = PAGES[_index]
	if page.figure != FIGURE_COMMANDS:
		Narrator.speak("%s. %s" % [page.title, page.text])
		return
	var lines: PackedStringArray = [page.title]
	for entry in COMMANDS:
		lines.append("%s %s" % [entry[1], entry[2]])
	Narrator.speak(". ".join(lines))


func _build_figure(kind: String) -> Control:
	match kind:
		"gears":
			return _figure_gears()
		"sweep":
			return _figure_diagram("sweep", {"max_angle": SWEEP_MAX_ANGLE})
		"power":
			return _figure_diagram("power", {})
		"gravity":
			return _figure_diagram("gravity", {"from": 185.0, "to": 1240.0})
		"parabola":
			return _figure_parabola()
		_:
			return _figure_calibration()


func _figure_diagram(mode: String, params: Dictionary) -> AnimatedDiagram:
	var diagram := AnimatedDiagram.new()
	diagram.custom_minimum_size = FIGURE_SIZE
	diagram.play(mode, params)
	return diagram


## Mesma curva da aba 2 da ajuda (HelpOverlay._build_parabola_page).
func _figure_parabola() -> ParabolaDiagram:
	var diagram := ParabolaDiagram.new()
	diagram.custom_minimum_size = FIGURE_SIZE
	diagram.annotate = true
	diagram.span_m = 29.0
	diagram.curves = [
		{"angle": 45.0, "speed": 800.0, "gravity": 500.0, "color": UiTokens.CALCULATED_ON_PAPER}
	]
	return diagram


func _figure_gears() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_LG)
	row.add_child(_sprite(TANK_TEXTURE))
	for gear in GEARS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.add_child(UiIcon.make(gear[0], UiTokens.EDITABLE_ON_PAPER, 56.0))
		var name_label := _ink_label(gear[1], UiTokens.FONT_SM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		row.add_child(col)
	return row


func _figure_calibration() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_LG)
	row.add_child(_sprite(TANK_TEXTURE))
	var boss := _sprite(BOSS_TEXTURE)
	boss.self_modulate = UiTokens.TEXT_DISABLED
	row.add_child(boss)
	return row


func _sprite(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = SPRITE_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _ink_label(text_value: String, size_px: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = &"InkLabel"
	label.add_theme_font_size_override("font_size", size_px)
	return label


# ═════════════════════════════════════════════════════════════════════
#  Pagina 6: lista de comandos (mesmo formato da aba "As teclas" da ajuda)
# ═════════════════════════════════════════════════════════════════════


func _command_row(visual: String, key: String, text_value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_key_visual(visual))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	var name_label := Label.new()
	name_label.text = key
	name_label.theme_type_variation = &"EditableLabel"
	name_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	col.add_child(name_label)
	var hint := Label.new()
	hint.text = text_value
	hint.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	hint.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	col.add_child(hint)
	row.add_child(col)
	return row


func _key_visual(visual: String) -> Control:
	match visual:
		"space":
			return _key_icon(HelpOverlay.ICON_SPACE)
		"tab":
			return _key_icon(HelpOverlay.ICON_TAB)
		"ad":
			var pair := HBoxContainer.new()
			pair.add_theme_constant_override("separation", 4)
			pair.add_child(HelpOverlay.keycap("A"))
			pair.add_child(HelpOverlay.keycap("D"))
			return pair
		"star":
			return UiIcon.make("star", UiTokens.EDITABLE, 40.0)
		_:
			return HelpOverlay.keycap(visual.to_upper())


func _key_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

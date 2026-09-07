class_name UiModal
extends CanvasLayer
## Base de toda janela sobreposta do jogo: ajuda, audio, ataque, loja e pausa.
##
## Concentra tres acertos que antes cada modal precisava lembrar sozinho, e
## que o molde antigo (menu_play._open_audio_settings) errava:
##
## 1. Centralizacao por CenterContainer, nao por PRESET_CENTER. O preset congela
##    offsets calculados uma unica vez, a partir do size daquele instante; nao e
##    vinculo vivo, entao o painel desalinha em qualquer resolucao diferente da
##    de projeto.
## 2. process_mode ALWAYS na raiz, que propaga por heranca. Sem isto um menu
##    aberto com a arvore pausada congela junto e nem fecha.
## 3. Despausar deferido. Despausar no mesmo frame em que o menu fecha deixa o
##    _process do jogo rodar ainda naquele frame, lendo o mesmo estado de
##    teclado -- e como a arena le input por polling, set_input_as_handled() nao
##    protege. Sem isto, fechar com Esc dispara o canhao.

signal closed

const DEFAULT_SIZE := Vector2(420, 280)

## Se o modal congela a arvore ao abrir. A loja e o popup de ataque nao pausam;
## a ajuda e o menu de pausa sim.
var pauses_game: bool = false
var close_on_escape: bool = true

var backdrop: ColorRect
var window: PanelContainer
var title_label: Label
## Onde a subclasse pendura o conteudo dela.
var body: VBoxContainer


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_shell()
	_build_content()


func _build_shell() -> void:
	backdrop = ColorRect.new()
	backdrop.color = UiTokens.BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	# Depois do add_child: o preset se calcula contra o retangulo do pai, e sem
	# pai a conta sai contra um retangulo vazio.
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	# Sem isto o container engoliria o clique destinado ao backdrop.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	window = PanelContainer.new()
	window.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.MODAL))
	window.custom_minimum_size = DEFAULT_SIZE
	center.add_child(window)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.GAP)
	window.add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	title_label.add_theme_color_override("font_color", UiTokens.AMBER)
	column.add_child(title_label)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", UiTokens.GAP)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)


## Ponto de extensao. A subclasse preenche `body` e ajusta titulo e tamanho.
func _build_content() -> void:
	pass


func open() -> void:
	visible = true
	if pauses_game:
		get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	if pauses_game:
		get_tree().set_deferred("paused", false)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not close_on_escape:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

class_name PauseMenu
extends UiModal
## Menu de pausa da arena: continuar, audio, reiniciar e voltar ao mapa.
##
## Tres paginas na mesma janela (raiz, audio, confirmacao) em vez de modais
## empilhados, que disputariam o Esc.

signal restart_requested
signal return_to_map_requested

const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")

const PANEL_SIZE := Vector2(400, 340)

enum Page { ROOT, AUDIO, CONFIRM }

var _root_box: VBoxContainer
var _audio_box: VBoxContainer
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _page: int = Page.ROOT
## Primeiro botao de cada pagina, que recebe o foco ao abrir a pagina: com o
## jogo pausado as setas podem navegar o menu sem roubar nada da arena.
var _first: Dictionary = {}
## Qual sinal a confirmacao dispara quando o jogador confirma.
var _pending: Callable = Callable()


func _build_content() -> void:
	# O UiModal pausa a arvore e despausa deferido ao fechar.
	pauses_game = true
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "JOGO PAUSADO"

	_root_box = _make_page()
	_audio_box = _make_page()
	_confirm_box = _make_page()

	_build_root()
	_build_audio()
	_build_confirm()
	_show_page(Page.ROOT)


func _make_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(page)
	return page


func _build_root() -> void:
	var resume := UiButton.create("CONTINUAR", UiButton.Kind.PRIMARY, null, true)
	resume.pressed.connect(close)
	_first[Page.ROOT] = resume
	_root_box.add_child(resume)

	var audio := UiButton.create("CONFIGURAÇÕES DE ÁUDIO", UiButton.Kind.SECONDARY, null, true)
	audio.pressed.connect(_show_page.bind(Page.AUDIO))
	_root_box.add_child(audio)

	var restart := UiButton.create("REINICIAR BATALHA", UiButton.Kind.SECONDARY, null, true)
	restart.pressed.connect(
		_ask.bind("Reiniciar a batalha do zero?\nO progresso desta fase se perde.", _do_restart)
	)
	_root_box.add_child(restart)

	var leave := UiButton.create("VOLTAR AO MAPA DE GUERRA", UiButton.Kind.SECONDARY, null, true)
	leave.pressed.connect(
		_ask.bind("Abandonar o combate?\nA fase atual não será concluída.", _do_return_to_map)
	)
	_root_box.add_child(leave)


func _build_audio() -> void:
	_audio_box.add_child(AudioSettingsScript.new())

	var back := UiButton.create("VOLTAR", UiButton.Kind.SECONDARY, null, true)
	back.pressed.connect(_show_page.bind(Page.ROOT))
	_first[Page.AUDIO] = back
	_audio_box.add_child(back)


func _build_confirm() -> void:
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm_box.add_child(_confirm_label)

	var yes := UiButton.create("CONFIRMAR", UiButton.Kind.DANGER, null, true)
	yes.pressed.connect(_confirm)
	_confirm_box.add_child(yes)

	var no := UiButton.create("CANCELAR", UiButton.Kind.SECONDARY, null, true)
	no.pressed.connect(_show_page.bind(Page.ROOT))
	# Foco no "nao": Enter por engano nao apaga a batalha.
	_first[Page.CONFIRM] = no
	_confirm_box.add_child(no)


func open() -> void:
	# Reabrir sempre na raiz: voltar direto para a confirmacao de uma acao que o
	# jogador ja desistiu de fazer seria uma armadilha.
	super()
	_show_page(Page.ROOT)


func _show_page(page: int) -> void:
	_page = page
	_root_box.visible = page == Page.ROOT
	_audio_box.visible = page == Page.AUDIO
	_confirm_box.visible = page == Page.CONFIRM

	if _first.has(page) and visible:
		_first[page].grab_focus.call_deferred()

	match page:
		Page.AUDIO:
			title_label.text = "AJUSTES DE ÁUDIO"
		Page.CONFIRM:
			title_label.text = "TEM CERTEZA?"
		_:
			title_label.text = "JOGO PAUSADO"


func _ask(question: String, action: Callable) -> void:
	_confirm_label.text = question
	_pending = action
	_show_page(Page.CONFIRM)


func _confirm() -> void:
	if _pending.is_valid():
		_pending.call()


func _do_restart() -> void:
	close()
	restart_requested.emit()


func _do_return_to_map() -> void:
	close()
	return_to_map_requested.emit()


## Esc dentro de uma subpagina volta para a raiz em vez de fechar o menu inteiro;
## so na raiz ele despausa o jogo.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _page == Page.ROOT:
		close()
	else:
		_show_page(Page.ROOT)

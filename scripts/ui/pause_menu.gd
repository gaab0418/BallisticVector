class_name PauseMenu
extends UiModal
## Menu de pausa da arena. Nao existia: o que havia era um painel de engrenagem
## com "Voltar ao Mapa" e "Desistir" que NAO pausava -- o combate seguia rodando
## atras dele, e os avioes continuavam bombardeando enquanto o jogador lia.
##
## Tres paginas dentro da mesma janela, em vez de modais empilhados: a raiz, os
## ajustes de audio e a confirmacao. Empilhar CanvasLayer daria duas camadas
## disputando o Esc.

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
## Qual sinal a confirmacao dispara quando o jogador confirma.
var _pending: Callable = Callable()


func _build_content() -> void:
	# A pausa e o motivo de este modal existir; o UiModal cuida do
	# get_tree().paused e de despausar deferido ao fechar.
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
	var resume := UiButton.create("CONTINUAR", UiButton.Kind.PRIMARY)
	resume.pressed.connect(close)
	_root_box.add_child(resume)

	var audio := UiButton.create("CONFIGURAÇÕES DE ÁUDIO")
	audio.pressed.connect(_show_page.bind(Page.AUDIO))
	_root_box.add_child(audio)

	var restart := UiButton.create("REINICIAR BATALHA")
	restart.pressed.connect(
		_ask.bind("Reiniciar a batalha do zero?\nO progresso desta fase se perde.", _do_restart)
	)
	_root_box.add_child(restart)

	var leave := UiButton.create("VOLTAR AO MAPA DE GUERRA")
	leave.pressed.connect(
		_ask.bind("Abandonar o combate?\nA fase atual nao sera concluida.", _do_return_to_map)
	)
	_root_box.add_child(leave)


func _build_audio() -> void:
	_audio_box.add_child(AudioSettingsScript.new())

	var back := UiButton.create("VOLTAR")
	back.pressed.connect(_show_page.bind(Page.ROOT))
	_audio_box.add_child(back)


func _build_confirm() -> void:
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm_box.add_child(_confirm_label)

	var yes := UiButton.create("CONFIRMAR", UiButton.Kind.DANGER)
	yes.pressed.connect(_confirm)
	_confirm_box.add_child(yes)

	var no := UiButton.create("CANCELAR")
	no.pressed.connect(_show_page.bind(Page.ROOT))
	_confirm_box.add_child(no)


func open() -> void:
	# Reabrir sempre na raiz: voltar direto para a confirmacao de uma acao que o
	# jogador ja desistiu de fazer seria uma armadilha.
	_show_page(Page.ROOT)
	super()


func _show_page(page: int) -> void:
	_page = page
	_root_box.visible = page == Page.ROOT
	_audio_box.visible = page == Page.AUDIO
	_confirm_box.visible = page == Page.CONFIRM

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

class_name TutorialModal
extends UiModal
## Tutorial modal: paginas da mecanica e a confirmacao "Deseja sair do tutorial?"
## na mesma janela (modais empilhados disputam o Esc, ver pause_menu.gd).
##
## Por enquanto so existe a confirmacao de saida, que a arena de pratica usa por
## open_exit_prompt(). As paginas, open(), next_page() e prev_page() entram com o
## tutorial completo, sem mudar a API abaixo.

signal completed
signal aborted

const EXIT_QUESTION := "Deseja sair do tutorial?"
const PANEL_SIZE := Vector2(440, 260)

var _confirm_box: VBoxContainer
var _continue_btn: Button
var _confirming := false
## Aberto so para confirmar a saida (arena de pratica): cancelar fecha a janela.
var _exit_only := false


func _build_content() -> void:
	close_on_escape = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "TUTORIAL"

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


## Abre direto na confirmacao; cancelar fecha o modal (usado na arena de pratica).
func open_exit_prompt() -> void:
	_exit_only = true
	open()
	ask_exit()


func ask_exit() -> void:
	_confirming = true
	_confirm_box.visible = true
	_focus_continue.call_deferred()


## Foco no "continuar": Enter por engano nao tira o jogador do tutorial. Deferido,
## e a confirmacao pode ja ter trocado de cena quando ele roda.
func _focus_continue() -> void:
	if is_inside_tree() and is_confirming():
		_continue_btn.grab_focus()


func cancel_exit() -> void:
	_confirming = false
	_confirm_box.visible = false
	if _exit_only:
		_exit_only = false
		close()


func confirm_exit() -> void:
	_confirming = false
	_exit_only = false
	_confirm_box.visible = false
	close()
	aborted.emit()


func is_confirming() -> bool:
	return visible and _confirming


## Esc numa pagina pede para sair; Esc na confirmacao cancela.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _confirming:
		cancel_exit()
	else:
		ask_exit()

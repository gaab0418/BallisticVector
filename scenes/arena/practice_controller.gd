extends Node
## Arena de pratica do fim do tutorial: a Ada calibra o canhao numa fortaleza
## que ja caiu (chefe com 1 HP). Derrubar o chefe conclui o tutorial; sair pede
## confirmacao. Nada aqui mexe em ouro, municao, estrelas ou selos: a arena
## consulta _counts_for_progress() e so as funcoes mark_* do Global gravam.

## O castelo desenha max_hp - hp estragos (castle_damage.gd): com 3 e 1 HP ele
## aparece rachado e em fogo, sem mexer no stage_builder.
const RUIN_MAX_HP := 3
const TITLE := "Calibragem"
const SUBTITLE := "Fortaleza em ruínas · tiros grátis"
const OPENING_LINES := [
	{
		"text": "Canhão consertado. Antes de partir, vamos calibrar.",
		"expr": "proud",
		"caption": "CALIBRAGEM",
	},
	{
		"text": "Aquela fortaleza já caiu: um acerto derruba. Faça a conta e atire.",
		"expr": "thinking"
	},
]
const CLEARED_LINE := {"text": "Calibrado. O canhão acerta onde a conta manda.", "expr": "proud"}
const MENU_SCENE := "res://scenes/menu_play/menu_play.tscn"
const MAP_SCENE := "res://scenes/war_map/war_map.tscn"

var arena: Node2D
## Confirmacao "Deseja sair do tutorial?" (Esc e o botao de pausa da HUD).
var exit_modal: TutorialModal


func setup(host: Node2D) -> void:
	arena = host
	for e in arena.active_enemies:
		if is_instance_valid(e) and e.has_meta("is_boss"):
			e.set_meta("max_hp", RUIN_MAX_HP)
	exit_modal = TutorialModal.new()
	exit_modal.pauses_game = true
	host.add_child(exit_modal)
	exit_modal.aborted.connect(_on_exit_confirmed)
	arena.coach.ada.say(OPENING_LINES)


## Chefe derrubado: o tutorial so conta como concluido aqui.
func on_cleared() -> void:
	Global.mark_tutorial_done()
	var ada: AdaDialog = arena.coach.ada
	ada.say([CLEARED_LINE])
	ada.finished.connect(_leave, CONNECT_ONE_SHOT)


func ask_exit() -> void:
	if exit_modal.visible:
		return
	exit_modal.open_exit_prompt()


## Vindo do botao TUTORIAL do menu, sair nao grava nada: o JOGAR ainda oferece
## o tutorial. Na primeira vez, ele nao reabre sozinho.
func _on_exit_confirmed() -> void:
	if not _from_menu():
		Global.mark_tutorial_skipped()
	_leave()


## practice_mode e transitorio: zerar aqui impede a proxima fase de virar pratica.
func _leave() -> void:
	Global.practice_mode = false
	arena.get_tree().paused = false
	arena.get_tree().change_scene_to_file(MENU_SCENE if _from_menu() else MAP_SCENE)


func _from_menu() -> bool:
	return Global.tutorial_origin == "menu"

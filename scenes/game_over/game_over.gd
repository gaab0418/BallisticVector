extends EndScreen
## Derrota: a blindagem chegou a zero. Oferece tentar a mesma fase de novo.

const TIPS := [
	"Repare na faixa azul sobre a régua: é onde a bala pode cair. Munição melhor deixa a faixa menor.",
	"Antes de atirar, confira a bandeira da raiz: ela mostra onde a bala vai tocar o chão.",
	"Se o losango do vértice estiver abaixo do topo da montanha, a bala bate nela. Levante o ângulo!",
	"Tanque amassado mira pior: compre o Kit de Reparo na loja antes da batalha.",
]


func _ready() -> void:
	configure(
		EndScreen.Mood.DEFEAT,
		"POSTO PERDIDO",
		"Sua blindagem foi destruída.",
		[],
		"Dica: " + TIPS.pick_random(),
		[
			["TENTAR DE NOVO", UiButton.Kind.PRIMARY, _on_retry],
			["VOLTAR AO MAPA", UiButton.Kind.SECONDARY, _on_back_button_pressed],
		]
	)


func _on_retry() -> void:
	Global.reset_armor()
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")

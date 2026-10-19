extends EndScreen
## Vitoria final: todas as bases conquistadas.


func _ready() -> void:
	Global.victory_seen = true
	Global.save_game()
	var stars := Global.total_stars()
	var total := Global.max_stars()
	var lines := [
		"%d de %d estrelas" % [stars, total],
	]
	var tip := "Você usou vértice, raiz, ângulo, força, gravidade, translação, retas e quiques. "
	if stars < total:
		tip += "Volte às fases para pegar as estrelas que faltam!"
	else:
		tip += "Todas as estrelas: você domina a parábola!"
	configure(
		EndScreen.Mood.VICTORY,
		"VITÓRIA!",
		"Todas as bases inimigas foram conquistadas.",
		lines,
		tip,
		[
			["VOLTAR AO MAPA", UiButton.Kind.PRIMARY, _on_map_pressed],
			["MENU", UiButton.Kind.SECONDARY, _on_back_button_pressed],
		]
	)


func _on_map_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu_play/menu_play.tscn")

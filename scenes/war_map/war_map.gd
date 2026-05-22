extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# 1. Verifica se o evento é um clique de botão do mouse
	if event is InputEventMouseButton:
		# 2. Verifica se é o botão esquerdo E se ele acabou de ser pressionado (clique)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			$AttackPopup.visible = not $AttackPopup.visible

func _on_attack_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

extends Control

func _ready() -> void:
	$VBoxContainer/BackButton.pressed.connect(_on_back_button_pressed)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu_play/menu_play.tscn")

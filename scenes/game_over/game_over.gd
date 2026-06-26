extends Control

func _ready() -> void:
	$VBoxContainer/BackButton.pressed.connect(_on_back_button_pressed)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")

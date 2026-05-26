extends Node

var money: int = 150
var ammo_inventory: Dictionary = {
	"Enferrujada": 15,
	"Perfurante": 5
}

# Novos sistemas de progressão
var bases: Array[Dictionary] = [
	{"id": "A", "stages_cleared": 0},
	{"id": "B", "stages_cleared": 0},
	{"id": "C", "stages_cleared": 0}
]

var player_armor: float = 100.0
var max_player_armor: float = 100.0
var current_base_id: String = ""
var current_stage: int = 0

func get_base_data(id: String) -> Dictionary:
	for base in bases:
		if base.id == id:
			return base
	return {}

func update_base_cleared(id: String, cleared: int) -> void:
	for i in range(bases.size()):
		if bases[i].id == id:
			bases[i].stages_cleared = cleared
			break

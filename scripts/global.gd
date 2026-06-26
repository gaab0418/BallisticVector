extends Node

# ── Recursos do jogador ──────────────────────────────────────────────
var money: int = 150
var ammo_inventory: Dictionary = {
	"Enferrujada": 15,
	"Perfurante": 5
}

# ── Estado de jogo ───────────────────────────────────────────────────
var player_armor: float = 100.0
var current_base_id: String = "Base_A"
var current_stage: int = 0

# ── Progressão das bases ─────────────────────────────────────────────
var bases: Dictionary = {
	"Base_A": {"name": "Base Alpha", "stages_cleared": 0, "total_stages": 3},
	"Base_B": {"name": "Base Bravo", "stages_cleared": 0, "total_stages": 3},
	"Base_C": {"name": "Base Charlie", "stages_cleared": 0, "total_stages": 3},
}

# ── Métodos auxiliares ───────────────────────────────────────────────

func get_base_data(base_id: String) -> Dictionary:
	return bases.get(base_id, {})

func update_base_cleared(base_id: String, stages_cleared: int) -> void:
	if bases.has(base_id):
		bases[base_id]["stages_cleared"] = stages_cleared

func is_base_complete(base_id: String) -> bool:
	var data = get_base_data(base_id)
	return data.get("stages_cleared", 0) >= data.get("total_stages", 3)

func are_all_bases_complete() -> bool:
	for base_id in bases:
		if not is_base_complete(base_id):
			return false
	return true

func reset_armor() -> void:
	player_armor = 100.0

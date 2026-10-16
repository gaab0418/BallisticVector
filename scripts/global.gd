extends Node

# ── Recursos do jogador ──────────────────────────────────────────────
var money: int = 150
var ammo_inventory: Dictionary = {"Enferrujada": 15, "Perfurante": 5}

# ── Estado de jogo ───────────────────────────────────────────────────
## Modo Professor: libera todas as bases e abre a "conta" da parabola por padrao,
## para o professor ir direto a licao que quer mostrar em aula.
var teacher_mode: bool = false
var player_armor: float = 100.0
var max_player_armor: float = 100.0
var current_base_id: String = "Base_A"
var current_stage: int = 0

# ── Progressão das bases ─────────────────────────────────────────────
# "stars" guarda o melhor resultado (0 a 3) de cada fase; o conteudo de cada
# fase (licao, cenario, desafios) mora em scripts/campaign.gd.
var bases: Dictionary = {
	"Base_A": {"name": "Base Alpha", "stages_cleared": 0, "total_stages": 3, "stars": [0, 0, 0]},
	"Base_B": {"name": "Base Bravo", "stages_cleared": 0, "total_stages": 3, "stars": [0, 0, 0]},
	"Base_C": {"name": "Base Charlie", "stages_cleared": 0, "total_stages": 3, "stars": [0, 0, 0]},
	"Base_D": {"name": "Base Delta", "stages_cleared": 0, "total_stages": 3, "stars": [0, 0, 0]},
}

# ── Métodos auxiliares ───────────────────────────────────────────────


func get_base_data(base_id: String) -> Dictionary:
	return bases.get(base_id, {})


func update_base_cleared(base_id: String, stages_cleared: int) -> void:
	if bases.has(base_id):
		bases[base_id]["stages_cleared"] = stages_cleared


## Guarda so o melhor resultado: refazer uma fase nunca tira estrela.
func record_stars(base_id: String, stage: int, stars: int) -> void:
	if not bases.has(base_id):
		return
	var list: Array = bases[base_id].get("stars", [0, 0, 0])
	if stage >= 0 and stage < list.size():
		list[stage] = maxi(list[stage], stars)
	bases[base_id]["stars"] = list


func total_stars() -> int:
	var total := 0
	for base_id in bases:
		for n in bases[base_id].get("stars", []):
			total += n
	return total


func is_base_complete(base_id: String) -> bool:
	var data = get_base_data(base_id)
	return data.get("stages_cleared", 0) >= data.get("total_stages", 3)


## Os capitulos seguem em ordem (angulo, forca, gravidade, translacao): uma base
## abre quando a anterior e conquistada, ou sempre, no Modo Professor.
func is_base_unlocked(base_id: String) -> bool:
	if teacher_mode:
		return true
	var ids := bases.keys()
	var i := ids.find(base_id)
	return i <= 0 or is_base_complete(ids[i - 1])


func are_all_bases_complete() -> bool:
	for base_id in bases:
		if not is_base_complete(base_id):
			return false
	return true


func reset_armor() -> void:
	player_armor = max_player_armor

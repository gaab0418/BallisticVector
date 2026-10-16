extends Node

## Arquivo de progresso. user:// e a pasta de dados do jogo no sistema do
## jogador (no Linux, ~/.local/share/godot/app_userdata/BallisticVector).
const SAVE_PATH := "user://progresso.cfg"
## Por caminho: este autoload compila antes do cache de classes globais.
const CosmeticsData := preload("res://scripts/cosmetics.gd")
const SAVE_VERSION := 1
## Kit de emergencia: municao gratis quando a crianca fica sem bala e sem ouro
## para comprar (senao ela fica presa, sem poder jogar nem comprar).
const EMERGENCY_AMMO := 8
const CHEAPEST_AMMO_PRICE := 10

# ── Recursos do jogador ──────────────────────────────────────────────
var money: int = 150
## Latao: moeda da Oficina da Ada (camuflagens, rastros, bandeiras).
const BRASS_PER_WIN := 100
var brass: int = 0
var owned: Dictionary = {}
var equipped: Dictionary = {"camo": "camo_original", "trail": "trail_smoke", "flag": "flag_none"}
## Paginas do Caderno da Ada que a crianca ja abriu (id -> true).
var notebook_seen: Dictionary = {}
var ammo_inventory: Dictionary = {"Enferrujada": 15, "Perfurante": 5}

# ── Estado de jogo ───────────────────────────────────────────────────
## Modo Professor: libera todas as bases e abre a "conta" da parabola por padrao,
## para o professor ir direto a licao que quer mostrar em aula.
var teacher_mode: bool = false
## Laboratorio: arena sem inimigos, municao infinita e tabela de pontos.
var lab_mode: bool = false
## Mundo escolhido no Laboratorio (chave de Campaign.LAB_WORLDS).
var lab_world: String = "earth"
## A Ada ja deu o tutorial da primeira fase.
var tutorial_done: bool = false
## A Ada ja apresentou o mapa de guerra.
var map_intro_done: bool = false
var player_armor: float = 100.0
var max_player_armor: float = 100.0
var current_base_id: String = "Base_A"
var current_stage: int = 0
## Base conquistada agora ha pouco: o mapa anima o barquinho na rota dela.
var just_conquered: String = ""

# ── Progressão das bases ─────────────────────────────────────────────
# "stars" guarda o melhor resultado (0 a 3) de cada fase; o conteudo de cada
# fase (licao, cenario, desafios) mora em scripts/campaign.gd. "bonus" = base
# opcional: nao conta para a vitoria final.
var bases: Dictionary = _fresh_bases()
## Onde o progresso e salvo. BV_SAVE_PATH troca o arquivo: os testes usam isso
## para nunca tocar no save real de quem joga na mesma maquina.
var save_path := SAVE_PATH


func _ready() -> void:
	# Por caminho, e nao pelo nome da classe: autoloads compilam antes de o cache
	# de classes existir numa importacao do zero.
	var ui_theme: Script = load("res://scripts/ui/ui_theme.gd")
	ui_theme.apply_fonts(ThemeDB.get_project_theme())
	if OS.has_environment("BV_SAVE_PATH"):
		save_path = OS.get_environment("BV_SAVE_PATH")
	load_game()


static func _fresh_bases() -> Dictionary:
	return {
		"Base_A": _base("Base Alpha", 3),
		"Base_B": _base("Base Bravo", 3),
		"Base_C": _base("Base Charlie", 3),
		"Base_D": _base("Base Delta", 3),
		"Base_E": _base("Base Echo", 3),
		"Base_Z": _base("Ilha Invertida", 2, true),
	}


static func _base(display_name: String, stages: int, bonus: bool = false) -> Dictionary:
	var stars := []
	stars.resize(stages)
	stars.fill(0)
	return {
		"name": display_name,
		"stages_cleared": 0,
		"total_stages": stages,
		"stars": stars,
		"bonus": bonus,
	}


# ── Métodos auxiliares ───────────────────────────────────────────────


func get_base_data(base_id: String) -> Dictionary:
	return bases.get(base_id, {})


func update_base_cleared(base_id: String, stages_cleared: int) -> void:
	if bases.has(base_id):
		var before: int = bases[base_id]["stages_cleared"]
		bases[base_id]["stages_cleared"] = stages_cleared
		if stages_cleared >= bases[base_id]["total_stages"] and before < stages_cleared:
			just_conquered = base_id
		save_game()


## Guarda so o melhor resultado: refazer uma fase nunca tira estrela.
func record_stars(base_id: String, stage: int, stars: int) -> void:
	if not bases.has(base_id):
		return
	var list: Array = bases[base_id].get("stars", [])
	if stage >= 0 and stage < list.size():
		list[stage] = maxi(list[stage], stars)
	bases[base_id]["stars"] = list
	save_game()


func total_stars() -> int:
	var total := 0
	for base_id in bases:
		for n in bases[base_id].get("stars", []):
			total += n
	return total


func max_stars() -> int:
	var total := 0
	for base_id in bases:
		total += 3 * int(bases[base_id]["total_stages"])
	return total


func is_base_complete(base_id: String) -> bool:
	var data = get_base_data(base_id)
	return data.get("stages_cleared", 0) >= data.get("total_stages", 3)


## Uma base abre quando a anterior e conquistada (os capitulos seguem em
## ordem), ou sempre, no Modo Professor.
func is_base_unlocked(base_id: String) -> bool:
	if teacher_mode:
		return true
	var ids := bases.keys()
	var i := ids.find(base_id)
	return i <= 0 or is_base_complete(ids[i - 1])


## A vitoria final pede as bases da campanha; a ilha bonus e opcional.
func are_all_bases_complete() -> bool:
	for base_id in bases:
		if not bases[base_id].get("bonus", false) and not is_base_complete(base_id):
			return false
	return true


func reset_armor() -> void:
	player_armor = max_player_armor


## Sem municao nenhuma e sem ouro para a mais barata: entrega o kit e devolve
## true (para a tela avisar). Chamado ao entrar no mapa.
func grant_emergency_ammo() -> bool:
	var total := 0
	for n in ammo_inventory.values():
		total += int(n)
	if total > 0 or money >= CHEAPEST_AMMO_PRICE:
		return false
	ammo_inventory["Enferrujada"] = EMERGENCY_AMMO
	save_game()
	return true


func total_ammo() -> int:
	var total := 0
	for n in ammo_inventory.values():
		total += int(n)
	return total


# ── Salvar e carregar ────────────────────────────────────────────────


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("player", "money", money)
	cfg.set_value("player", "ammo", ammo_inventory)
	cfg.set_value("player", "teacher_mode", teacher_mode)
	cfg.set_value("player", "brass", brass)
	cfg.set_value("player", "owned", owned)
	cfg.set_value("player", "equipped", equipped)
	cfg.set_value("player", "notebook_seen", notebook_seen)
	cfg.set_value("player", "tutorial_done", tutorial_done)
	cfg.set_value("player", "map_intro_done", map_intro_done)
	for base_id in bases:
		cfg.set_value(base_id, "stages_cleared", bases[base_id]["stages_cleared"])
		cfg.set_value(base_id, "stars", bases[base_id]["stars"])
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("Nao foi possivel salvar o progresso (erro %d)" % err)


## Carrega campo a campo, com o valor atual como padrao: um save antigo (sem
## bases novas, por exemplo) abre sem quebrar.
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	money = int(cfg.get_value("player", "money", money))
	var ammo = cfg.get_value("player", "ammo", ammo_inventory)
	if ammo is Dictionary:
		for k in ammo:
			ammo_inventory[k] = int(ammo[k])
	teacher_mode = bool(cfg.get_value("player", "teacher_mode", teacher_mode))
	brass = int(cfg.get_value("player", "brass", brass))
	var own = cfg.get_value("player", "owned", owned)
	if own is Dictionary:
		owned = own
	var seen = cfg.get_value("player", "notebook_seen", notebook_seen)
	if seen is Dictionary:
		notebook_seen = seen
	var eq = cfg.get_value("player", "equipped", equipped)
	if eq is Dictionary:
		for k in eq:
			equipped[k] = str(eq[k])
	tutorial_done = bool(cfg.get_value("player", "tutorial_done", tutorial_done))
	map_intro_done = bool(cfg.get_value("player", "map_intro_done", map_intro_done))
	for base_id in bases:
		var total: int = bases[base_id]["total_stages"]
		var cleared := int(cfg.get_value(base_id, "stages_cleared", 0))
		bases[base_id]["stages_cleared"] = clampi(cleared, 0, total)
		var stars = cfg.get_value(base_id, "stars", [])
		if stars is Array:
			var list: Array = bases[base_id]["stars"]
			for i in range(mini(list.size(), stars.size())):
				list[i] = clampi(int(stars[i]), 0, 3)


## Comeca a campanha do zero (botao do menu, com confirmacao).
func reset_progress() -> void:
	money = 150
	brass = 0
	owned = {}
	equipped = {"camo": "camo_original", "trail": "trail_smoke", "flag": "flag_none"}
	notebook_seen = {}
	ammo_inventory = {"Enferrujada": 15, "Perfurante": 5}
	bases = _fresh_bases()
	just_conquered = ""
	save_game()


func owns(item_id: String) -> bool:
	return owned.has(item_id) or CosmeticsData.item(item_id).get("price", 1) == 0


## Compra um item da oficina; devolve false se nao tem latao.
func buy_cosmetic(item_id: String) -> bool:
	var price: int = CosmeticsData.item(item_id).get("price", 0)
	if owns(item_id):
		return true
	if brass < price:
		return false
	brass -= price
	owned[item_id] = true
	save_game()
	return true


func equip(slot: String, item_id: String) -> void:
	if owns(item_id):
		equipped[slot] = item_id
		save_game()


func has_progress() -> bool:
	return total_stars() > 0

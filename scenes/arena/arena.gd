extends Node2D

# === Icones reutilizados (const preload evita recarregar o recurso) ===

# =============================================================================
#  Arena de Combate — arena.gd
#  Gerencia o combate por turnos: canhão do jogador, inimigos dinâmicos,
#  obstáculos, sistema de fases e HUD.
# =============================================================================

# === Referências dos nós (cena) ===
@onready var player: Node2D = $Player
@onready var cannon: Node2D = $Player/Cannon
@onready var aim_line: Line2D = $Player/Cannon/AimLine
@onready var bg: ColorRect = $BackgroundColorRect
@onready var obstacles_node: Node2D = $Obstacles

# === Variáveis de UI ===
var hud: CanvasLayer
var aim_preview: Node2D
var help_overlay: CanvasLayer
var pause_menu: CanvasLayer

# === Configurações ===
const ROTATION_SPEED: float = 1.5  # Velocidade de rotação do canhão (rad/s)
# Em Godot 2D o eixo Y cresce para baixo, entao rotation POSITIVA aponta o cano para BAIXO.
const MAX_CANNON_ANGLE: float = 1.225  # Limite apontando para baixo (~70°)
const MIN_CANNON_ANGLE: float = -1.2  # Limite apontando para cima (~69°)

# === Engrenagens da HUD (as variáveis da parábola) ===
const GEAR_COUNT: int = 3
const GEAR_ANGULO: int = 0
const GEAR_FORCA: int = 1
const GEAR_GRAVIDADE: int = 2
const FINE_STEP_MULT: float = 0.2  # passo fino do Shift, o mesmo que o jogo já usava
const POWER_RATE: float = 0.5  # fração de força por segundo de tecla
const MIN_POWER: float = 0.05
const GRAVITY_RATE: float = 250.0  # px/s² por segundo de tecla
const MIN_GRAVITY: float = 100.0  # 2 m/s² — a Lua
const MAX_GRAVITY: float = 1250.0  # 25 m/s² — Júpiter
const GEAR_SPIN_SPEED: float = 3.0  # rad/s de giro visual da engrenagem
# Duas voltas de mouse varrem a faixa inteira: devagar o bastante para dar precisão,
# rápido o bastante para não cansar a mão.
const DRAG_TURNS_FULL_RANGE: float = 2.0

# === Precisão do disparo ===
# Boca do cano, em coordenadas locais do Cannon. Era literal em dois lugares.
const BARREL_TIP := Vector2(50, 0)
# Era 0.12, com o resto do erro vindo de um tremor por frame no projétil. O tremor saiu
# (ver projectile.gd) e o fator subiu para concentrar toda a imprecisão no ângulo, que é
# a única fonte previsível o bastante para virar o "± N m" da HUD. Calibrado para
# reproduzir a dispersão total que o jogo tinha antes.
const IMPRECISION_FACTOR: float = 0.14
const ARMOR_PENALTY_MAX: float = 0.15

# === Sistema de Munição (Resources) ===
var ammo_types: Array[AmmoData] = []
var current_ammo_index: int = 0
var ammo_counts: Array[int] = []  # Quantidade restante de cada tipo

# === Variáveis de estado ===
var _tab_was_pressed: bool = false
var current_power: float = 1.0
# Gravidade em px/s² desta arena. Comeca na da municao e a engrenagem ajusta a partir dai.
# NUNCA escrever em ammo.gravity: Resource e cacheado pelo Godot e o valor vazaria para as
# fases seguintes, que sao carregadas com reload_current_scene().
var gravity_override: float = 500.0
var selected_gear: int = GEAR_ANGULO
var _at_limit: bool = false  # borda do limite, para o som de erro tocar uma vez só
var _help_was_pressed: bool = false

# === Sistema de inimigos ===
var active_enemies: Array = []  # Lista de inimigos vivos na cena
var stage_cleared: bool = false  # Se todos os inimigos morreram nesta fase

# === Polígonos de obstáculos em coordenadas globais (calculados uma vez) ===
var _obstacle_polygons_cache: Array = []

# === Preload dos scripts ===
const ProjectileScript = preload("res://scenes/arena/projectile.gd")
const ArenaHudScript = preload("res://scripts/ui/arena_hud.gd")
const HelpOverlayScript = preload("res://scripts/help_overlay.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const AimPreviewScript = preload("res://scripts/aim_preview.gd")
const AirplaneScript = preload("res://scenes/arena/airplane_enemy.gd")

# === Configuração de inimigos por fase ===
# Cada fase tem: boss_hp, num_airplanes, airplane_hp
const STAGE_CONFIG: Array = [
	{"boss_hp": 3, "num_airplanes": 2, "airplane_hp": 1},
	{"boss_hp": 3, "num_airplanes": 3, "airplane_hp": 1},
	{"boss_hp": 3, "num_airplanes": 3, "airplane_hp": 2},
]


func _ready() -> void:
	randomize()
	# Fundo aleatório
	if bg:
		bg.color = Color(
			randf_range(0.15, 0.6), randf_range(0.15, 0.6), randf_range(0.15, 0.6), 1.0
		)

	# Calcular polígonos de obstáculos em coordenadas globais (uma vez)
	_cache_obstacle_polygons()

	# Carregar munições dos Resources
	_load_ammo_types()
	gravity_override = _get_current_ammo().gravity

	aim_preview = AimPreviewScript.new()
	cannon.add_child(aim_preview)
	aim_preview.setup(cannon, aim_line)
	aim_preview.set_obstacles(_obstacle_polygons_cache)

	_build_hud()
	AudioManager.play_bgm("res://assets/audio/Battle.mp3")

	# Inicializar HUD
	_update_hud()
	_refresh_parabola_hud()
	_update_aim_line()
	_update_armor_hud()
	_update_stage_label()

	# Spawnar inimigos para a fase atual
	_spawn_enemies()


# === Calcular polígonos dos obstáculos em coordenadas globais ===
func _cache_obstacle_polygons() -> void:
	_obstacle_polygons_cache.clear()
	if not obstacles_node:
		return
	for child in obstacles_node.get_children():
		if child is StaticBody2D:
			var col_poly = child.get_node_or_null("CollisionPolygon2D")
			if col_poly and col_poly is CollisionPolygon2D:
				var local_poly: PackedVector2Array = col_poly.polygon
				var global_poly: PackedVector2Array = PackedVector2Array()
				for point in local_poly:
					# Converter ponto local do StaticBody2D para global
					global_poly.append(child.to_global(point))
				_obstacle_polygons_cache.append(global_poly)


# === Retorna os polígonos de obstáculos (usado pelos projéteis inimigos) ===
func get_obstacle_polygons() -> Array:
	return _obstacle_polygons_cache


# === Carregar tipos de munição dos Resources ===
func _load_ammo_types() -> void:
	var enferrujada = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	var perfurante = load("res://assets/resources/ammo_perfurante.tres") as AmmoData

	ammo_types.append(enferrujada)
	ammo_types.append(perfurante)

	# Inicializar contadores com o inventário global
	for ammo in ammo_types:
		if Global.ammo_inventory.has(ammo.ammo_name):
			ammo_counts.append(Global.ammo_inventory[ammo.ammo_name])
		else:
			ammo_counts.append(0)


func _get_current_ammo() -> AmmoData:
	return ammo_types[current_ammo_index]


# =============================================================================
#  SPAWNING DE INIMIGOS
# =============================================================================
func _spawn_enemies() -> void:
	active_enemies.clear()
	var stage = Global.current_stage
	var config = STAGE_CONFIG[clampi(stage, 0, STAGE_CONFIG.size() - 1)]

	# --- Spawnar o Boss ---
	var boss = _create_boss(config.boss_hp)
	boss.position = Vector2(1100, 640)
	add_child(boss)
	active_enemies.append(boss)

	# --- Spawnar aviões ---
	for i in range(config.num_airplanes):
		var airplane = AirplaneScript.new()
		airplane.name = "Airplane"
		airplane.position = Vector2(randf_range(750.0, 1200.0), randf_range(200.0, 480.0))
		airplane.hp = config.airplane_hp
		airplane.player_ref = player
		add_child(airplane)
		active_enemies.append(airplane)


# --- Cria o nó do Boss (Node2D com Sprite2D) ---
func _create_boss(boss_hp: int) -> Node2D:
	var boss = Node2D.new()
	boss.name = "Boss"

	# Visual do boss (usando Sprite2D no lugar do ColorRect)
	var body = Sprite2D.new()
	body.name = "Body"

	# ALERTA: Mude o caminho abaixo para a pasta onde está o PNG do seu boss!
	body.texture = preload("res://assets/sprites/boss.png")

	# Ajuste a escala do PNG aqui se ele ficar muito grande ou muito pequeno
	body.scale = Vector2(0.5, 0.5)

	boss.add_child(body)

	# Variáveis de HP no boss
	boss.set_meta("hp", boss_hp)
	boss.set_meta("max_hp", boss_hp)
	boss.set_meta("is_boss", true)

	return boss


# =============================================================================
#  LOOP PRINCIPAL (_process)
# =============================================================================
func _process(delta: float) -> void:
	# Fora do early-return de propósito: a ajuda abre mesmo com a fase já limpa.
	_poll_help_hotkey()

	# Não processar input se a fase foi limpa
	if stage_cleared:
		return

	# === Engrenagens: cima/baixo escolhem, esquerda/direita giram ===
	_poll_gear_selection()
	_poll_gear_rotation(delta)

	# === Disparo com espaço ===
	if Input.is_action_just_pressed("ui_accept"):
		_fire_projectile()

	# === Trocar munição com Tab ===
	if Input.is_key_pressed(KEY_TAB) == false and _tab_was_pressed:
		_on_switch_ammo()
	_tab_was_pressed = Input.is_key_pressed(KEY_TAB)


# =============================================================================
#  ENGRENAGENS (seleção e ajuste das variáveis da parábola)
# =============================================================================


## Esquerda/direita trocam a engrenagem selecionada, acompanhando a ordem em que elas
## aparecem na HUD. Edge-triggered de propósito: com is_action_pressed, segurar a seta
## varreria as três em poucos frames.
func _poll_gear_selection() -> void:
	var step: int = 0
	if Input.is_action_just_pressed("ui_left"):
		step = -1
	elif Input.is_action_just_pressed("ui_right"):
		step = 1
	if step == 0:
		return

	_select_gear(wrapi(selected_gear + step, 0, GEAR_COUNT))


func _select_gear(index: int) -> void:
	if index == selected_gear:
		return
	selected_gear = index
	_at_limit = false
	AudioManager.play_sfx("res://assets/audio/menu_hover_.ogg")
	hud.parabola.set_selected(selected_gear)


## Cima/baixo giram a engrenagem selecionada, de forma contínua e escalada por delta.
## dir positivo sempre significa "o número da HUD aumenta" — para o ângulo isso é o cano
## subindo, o que casa com a tecla.
func _poll_gear_rotation(delta: float) -> void:
	var dir: float = 0.0
	if Input.is_action_pressed("ui_up"):
		dir += 1.0
	if Input.is_action_pressed("ui_down"):
		dir -= 1.0

	if is_zero_approx(dir):
		_at_limit = false
		return

	var mult: float = FINE_STEP_MULT if Input.is_key_pressed(KEY_SHIFT) else 1.0

	if _adjust_selected_gear(dir, delta, mult):
		_at_limit = false
		hud.parabola.spin_selected(selected_gear, dir * mult * delta * GEAR_SPIN_SPEED)
		_refresh_parabola_hud()
		_update_aim_line()
		return

	# No limite a engrenagem trava (não recebe spin) e o valor pisca. O som toca uma vez
	# só: o AudioManager tem um único sfx_player e repetir a 60 Hz cortaria todo o resto.
	hud.parabola.flash_selected(selected_gear)
	if not _at_limit:
		_at_limit = true
		AudioManager.play_sfx("res://assets/audio/erro.ogg")


## Passo por segundo de tecla. Devolve true se o valor mudou; false = bateu no limite.
## A conta do ângulo é a mesma de sempre (ROTATION_SPEED e compensação por impulso),
## só que com o sinal invertido: elevar o cano é diminuir cannon.rotation.
func _adjust_selected_gear(dir: float, delta: float, mult: float) -> bool:
	match selected_gear:
		GEAR_FORCA:
			return _set_power(current_power + dir * POWER_RATE * mult * delta)
		GEAR_GRAVIDADE:
			return _set_gravity(gravity_override + dir * GRAVITY_RATE * mult * delta)
		_:
			var ammo = _get_current_ammo()
			var comp: float = 500.0 / max(ammo.impulse, 10.0)
			return _set_angle(cannon.rotation - dir * ROTATION_SPEED * mult * comp * delta)


## Passo em fração da faixa total, usado pelo arrasto de mouse.
func _adjust_selected_gear_by(frac: float) -> bool:
	match selected_gear:
		GEAR_FORCA:
			return _set_power(current_power + frac * (1.0 - MIN_POWER))
		GEAR_GRAVIDADE:
			return _set_gravity(gravity_override + frac * (MAX_GRAVITY - MIN_GRAVITY))
		_:
			return _set_angle(cannon.rotation - frac * (MAX_CANNON_ANGLE - MIN_CANNON_ANGLE))


func _set_angle(value: float) -> bool:
	var before: float = cannon.rotation
	cannon.rotation = clamp(value, MIN_CANNON_ANGLE, MAX_CANNON_ANGLE)
	return not is_equal_approx(cannon.rotation, before)


func _set_power(value: float) -> bool:
	var before: float = current_power
	current_power = clamp(value, MIN_POWER, 1.0)
	return not is_equal_approx(current_power, before)


func _set_gravity(value: float) -> bool:
	var before: float = gravity_override
	gravity_override = clamp(value, MIN_GRAVITY, MAX_GRAVITY)
	return not is_equal_approx(gravity_override, before)


## Agarrar a engrenagem com o mouse também a seleciona, senão o jogador arrastaria uma
## e veria outra mudar.
func _on_gear_grabbed(index: int) -> void:
	_select_gear(index)


## Girar o mouse em volta da engrenagem move a variável, como uma manivela. Sentido
## horário aumenta o número, igual à seta para cima.
func _on_gear_dragged(index: int, delta_rad: float) -> void:
	if stage_cleared or index != selected_gear:
		return

	if _adjust_selected_gear_by(delta_rad / (TAU * DRAG_TURNS_FULL_RANGE)):
		_at_limit = false
		# A engrenagem acompanha o cursor exatamente, sem fator de escala.
		hud.parabola.spin_selected(selected_gear, delta_rad)
		_refresh_parabola_hud()
		_update_aim_line()
		return

	hud.parabola.flash_selected(selected_gear)
	if not _at_limit:
		_at_limit = true
		AudioManager.play_sfx("res://assets/audio/erro.ogg")


# =============================================================================
#  TELA DE AJUDA
# =============================================================================


## Mesmo idioma de detecção de borda do Tab, para não ter que criar uma seção [input]
## no project.godot só por causa de uma tecla.
func _poll_help_hotkey() -> void:
	if Input.is_key_pressed(KEY_H) == false and _help_was_pressed:
		_on_help_pressed()
	_help_was_pressed = Input.is_key_pressed(KEY_H)


func _on_help_pressed() -> void:
	if help_overlay == null or help_overlay.visible:
		return
	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")
	help_overlay.open()
	get_tree().paused = true


func _on_help_closed() -> void:
	AudioManager.play_sfx("res://assets/audio/menu_back.ogg")
	# Deferido de propósito: despausar agora faria o _process rodar ainda neste frame,
	# lendo o mesmo estado de teclado — e polling não é bloqueado por
	# set_input_as_handled(). Sem isto, fechar com Esc podia disparar o canhão.
	get_tree().set_deferred("paused", false)


# =============================================================================
#  LINHA DE MIRA
# =============================================================================
## Desvio máximo para cada lado, em radianos. Fonte única: o disparo real e o "± N m"
## exibido na HUD saem daqui, então o número mostrado é o erro que de fato acontece.
func _current_spread() -> float:
	var ammo = _get_current_ammo()
	var armor_ratio: float = Global.player_armor / Global.max_player_armor
	var armor_penalty: float = (1.0 - armor_ratio) * ARMOR_PENALTY_MAX
	return (1.0 - ammo.precision) * IMPRECISION_FACTOR + armor_penalty


func _update_aim_line() -> void:
	if aim_preview == null:
		return
	var ammo = _get_current_ammo()
	aim_preview.update_preview(
		cannon.to_global(BARREL_TIP),
		cannon.global_rotation,
		ammo.impulse * current_power,
		gravity_override
	)


# =============================================================================
#  DISPARO DO PROJÉTIL
# =============================================================================
func _fire_projectile() -> void:
	var ammo = _get_current_ammo()

	if ammo_counts[current_ammo_index] <= 0:
		return

	AudioManager.play_sfx("res://assets/audio/cannon_fire.ogg")
	ammo_counts[current_ammo_index] -= 1
	Global.ammo_inventory[ammo.ammo_name] = ammo_counts[current_ammo_index]
	_update_hud()

	# Criar o projétil usando o Script carregado
	var projectile = ProjectileScript.new()

	projectile.position = cannon.to_global(BARREL_TIP)

	# Mesmo _current_spread() que alimenta o "± N m" da HUD: o erro possível do tiro é o
	# erro que o jogador leu na tela antes de atirar.
	var angle_deviation = randf_range(-1.0, 1.0) * _current_spread()
	var fire_direction = Vector2.RIGHT.rotated(cannon.global_rotation + angle_deviation)

	# Configurar o projétil com dados do Resource
	projectile.velocity = fire_direction * (ammo.impulse * current_power)
	projectile.gravity = gravity_override
	projectile.bullet_color = ammo.color
	projectile.damage = ammo.damage
	projectile.enemy_nodes = active_enemies.duplicate()
	projectile.obstacle_polygons = _obstacle_polygons_cache
	projectile.is_enemy_projectile = false

	# Adicionar à cena
	add_child(projectile)


# =============================================================================
#  CALLBACKS DE COLISÃO (chamados pelo projectile.gd)
# =============================================================================


# --- Projétil do jogador acertou um inimigo ---
func on_enemy_hit(enemy: Node2D, dmg: int) -> void:
	if not enemy or not is_instance_valid(enemy):
		return

	# Verificar se o inimigo tem o método take_damage (aviões com script)
	if enemy.has_method("take_damage"):
		enemy.take_damage(dmg)
	else:
		# Boss sem script — sempre perde 1 HP por tiro (3 tiros pra morrer)
		var current_hp = enemy.get_meta("hp", 0)
		current_hp -= 1
		enemy.set_meta("hp", current_hp)
		_flash_enemy(enemy)
		if current_hp <= 0:
			on_enemy_destroyed(enemy)
			enemy.queue_free()


# --- Projétil inimigo acertou o jogador ---
func on_player_hit(dmg: int) -> void:
	Global.player_armor -= dmg
	Global.player_armor = max(Global.player_armor, 0.0)
	_update_armor_hud()
	# A armadura entra em _current_spread(): levar dano aumenta o "± N m" na hora, em vez
	# de piorar a mira em silêncio como acontecia antes.
	_refresh_parabola_hud()
	_update_aim_line()
	_flash_player()

	# Verificar game over
	if Global.player_armor <= 0:
		get_tree().change_scene_to_file("res://scenes/game_over/game_over.tscn")


# --- Inimigo foi destruído (chamado pelo airplane_enemy.gd ou internamente) ---
func on_enemy_destroyed(enemy: Node2D) -> void:
	if enemy.name == "Boss":
		Global.money += 150
	else:
		Global.money += 25

	active_enemies.erase(enemy)
	# Limpar referências inválidas
	var still_alive: Array = []
	for e in active_enemies:
		if e and is_instance_valid(e):
			still_alive.append(e)
	active_enemies = still_alive

	if active_enemies.size() == 0:
		_on_stage_cleared()


# =============================================================================
#  SISTEMA DE FASES
# =============================================================================


# --- Fase limpa — todos os inimigos mortos ---
func _on_stage_cleared() -> void:
	stage_cleared = true
	# Recompensar o jogador
	Global.money += 250

	# Mostrar botão de próxima fase
	if Global.current_stage >= 2:
		hud.show_next_stage("Vitória!")
	else:
		hud.show_next_stage("Próxima Fase")


# --- Botão "Próxima Fase" pressionado ---
func _on_next_stage() -> void:
	if Global.current_stage < 2:
		# Avançar para a próxima fase
		Global.current_stage += 1
		Global.update_base_cleared(Global.current_base_id, Global.current_stage)
		# Recarregar a cena da arena
		get_tree().reload_current_scene()
	else:
		# Fase final concluída — base totalmente limpa
		Global.update_base_cleared(Global.current_base_id, 3)
		get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


# --- Botão "Voltar ao Mapa" pressionado ---
func _on_return_to_map() -> void:
	# Salvar progresso atual e voltar ao mapa
	Global.update_base_cleared(Global.current_base_id, Global.current_stage)
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


# =============================================================================
#  EFEITOS VISUAIS
# =============================================================================


# --- Flash branco no inimigo (para bosses sem script) ---
func _flash_enemy(enemy: Node2D) -> void:
	var body = enemy.get_node_or_null("Body")
	if body and body is Sprite2D:
		body.modulate = Color(3.0, 3.0, 3.0, 1.0)

		# Espera 0.15 segundos
		await get_tree().create_timer(0.15).timeout

		# Só devolve a cor se o boss ainda existir
		if is_instance_valid(body):
			body.modulate = Color(1.0, 1.0, 1.0, 1.0)


# --- Flash branco no jogador ao ser atingido ---
func _flash_player() -> void:
	var body = player.get_node_or_null("Body")
	# Mudamos a checagem de ColorRect para Sprite2D
	if body and body is Sprite2D:
		# Modulate faz a imagem ficar branca
		body.modulate = Color(3.0, 3.0, 3.0, 1.0)
		var timer = get_tree().create_timer(0.15)
		var body_ref = body
		timer.timeout.connect(
			func():
				if is_instance_valid(body_ref):
					body_ref.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Restaura a cor
		)


# =============================================================================
#  ATUALIZAÇÃO DA HUD
# =============================================================================


## A HUD, a ajuda e a pausa sao tres CanvasLayer irmaos. A ajuda fica acima da
## pausa porque e ela que pode ser aberta com a pausa ja no ar (pelo botao "?").
func _build_hud() -> void:
	hud = ArenaHudScript.new()
	add_child(hud)
	hud.parabola.gear_grabbed.connect(_on_gear_grabbed)
	hud.parabola.gear_dragged.connect(_on_gear_dragged)
	hud.help_pressed.connect(_on_help_pressed)
	hud.next_stage_pressed.connect(_on_next_stage)
	hud.pause_pressed.connect(_on_pause_pressed)

	help_overlay = HelpOverlayScript.new()
	add_child(help_overlay)
	help_overlay.setup(UiPanel.create(UiPanel.Kind.MODAL))
	help_overlay.closed.connect(_on_help_closed)

	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)
	pause_menu.layer = 9
	pause_menu.restart_requested.connect(_on_restart_stage)
	pause_menu.return_to_map_requested.connect(_on_return_to_map)


func _on_pause_pressed() -> void:
	if help_overlay and help_overlay.visible:
		return
	pause_menu.open()


## Esc chega aqui so quando nenhum modal esta aberto: a ajuda e a pausa tratam a
## acao em _input e chamam set_input_as_handled(), que roda antes do unhandled.
## Sem isso os dois disputariam a mesma tecla.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_pause_pressed()


func _on_restart_stage() -> void:
	get_tree().reload_current_scene()


func _update_hud() -> void:
	var ammo = _get_current_ammo()
	hud.set_ammo(ammo_counts[current_ammo_index], ammo.color, ammo.ammo_name)


## A elevação é -rad_to_deg porque em Godot 2D o Y cresce para baixo: rotation negativa
## é o cano apontado para cima, que para o jogador é ângulo positivo.
func _refresh_parabola_hud() -> void:
	if hud == null:
		return
	var ammo = _get_current_ammo()
	hud.parabola.set_state(
		-rad_to_deg(cannon.rotation),
		ammo.impulse * current_power,
		gravity_override,
		current_power,
		_current_spread()
	)


func _update_armor_hud() -> void:
	hud.set_armor(Global.player_armor, Global.max_player_armor)


## Usa o nome de exibicao da base ("Base Alpha"), nao o id ("Base_A"): concatenar
## "Base " ao id rendia "Base Base_A" na tela.
func _update_stage_label() -> void:
	var data: Dictionary = Global.get_base_data(Global.current_base_id)
	var base_name: String = data.get("name", "Base desconhecida")
	hud.set_stage("%s — Fase %d/3" % [base_name, Global.current_stage + 1])


# =============================================================================
#  CALLBACKS DOS BOTÕES DA HUD (mantidos do original)
# =============================================================================


func _on_switch_ammo() -> void:
	current_ammo_index = (current_ammo_index + 1) % ammo_types.size()
	# gravity e um stat de AmmoData: cada bala cai do seu jeito, entao o ajuste nao carrega.
	gravity_override = _get_current_ammo().gravity
	_update_hud()
	_refresh_parabola_hud()
	hud.parabola.flash_gravity()
	_update_aim_line()

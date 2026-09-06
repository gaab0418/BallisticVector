extends Node2D

# === Icones reutilizados (const preload evita recarregar o recurso) ===
const ICON_EXIT := preload("res://assets/sprites/icons/exit.png")
const ICON_GEAR := preload("res://assets/sprites/icons/gear_white.png")


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
var hud_canvas: CanvasLayer
var ammo_label: Label
var ammo_icon: Control
var ammo_name_label: Label
var armor_bar: ProgressBar
var stage_label: Label
var parabola_hud: Control
var help_overlay: CanvasLayer
var help_btn: Button
var menu_btn: Button
var menu_panel: PanelContainer
var next_stage_btn: Button
var return_btn: Button
var quit_btn: Button

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
const ParabolaHudScript = preload("res://scripts/parabola_hud.gd")
const HelpOverlayScript = preload("res://scripts/help_overlay.gd")
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

	_setup_ui()
	AudioManager.play_bgm("res://assets/audio/Battle.mp3")

	# Inicializar HUD
	_update_hud()
	_refresh_parabola_hud()
	_update_aim_line()
	_update_armor_hud()
	_update_stage_label()

	# Esconder botão de próxima fase inicialmente
	if next_stage_btn:
		next_stage_btn.visible = false

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
	if parabola_hud:
		parabola_hud.set_selected(selected_gear)


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
		if parabola_hud:
			parabola_hud.spin_selected(selected_gear, dir * mult * delta * GEAR_SPIN_SPEED)
		_refresh_parabola_hud()
		_update_aim_line()
		return

	# No limite a engrenagem trava (não recebe spin) e o valor pisca. O som toca uma vez
	# só: o AudioManager tem um único sfx_player e repetir a 60 Hz cortaria todo o resto.
	if parabola_hud:
		parabola_hud.flash_selected(selected_gear)
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
		if parabola_hud:
			# A engrenagem acompanha o cursor exatamente, sem fator de escala.
			parabola_hud.spin_selected(selected_gear, delta_rad)
		_refresh_parabola_hud()
		_update_aim_line()
		return

	if parabola_hud:
		parabola_hud.flash_selected(selected_gear)
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
func _update_aim_line() -> void:
	var ammo = _get_current_ammo()
	var points: PackedVector2Array = PackedVector2Array()

	# Ponto de partida: ponta do cano em global
	var barrel_tip_global: Vector2 = cannon.to_global(Vector2(50, 0))

	# Velocidade inicial em global (mesma do projétil real)
	var fire_direction: Vector2 = Vector2.RIGHT.rotated(cannon.global_rotation)
	var sim_vel: Vector2 = fire_direction * (ammo.impulse * current_power)
	var sim_pos: Vector2 = barrel_tip_global

	var dt: float = 0.02  # Passo de simulação
	var steps: int = 200  # Passos suficientes para cobrir toda a tela
	var g: float = gravity_override

	# Primeiro ponto (ponta do cano em local)
	points.append(cannon.to_local(sim_pos))

	for i in range(steps):
		# Gravidade age no Y global (igual ao projétil)
		sim_vel.y += g * dt
		sim_pos += sim_vel * dt

		# Parar se saiu lateralmente ou por baixo da tela
		if sim_pos.x > 1300 or sim_pos.x < -50 or sim_pos.y > 740:
			break

		# Parar se entrou em um obstáculo
		var hit_obstacle = false
		for poly in _obstacle_polygons_cache:
			if Geometry2D.is_point_in_polygon(sim_pos, poly):
				hit_obstacle = true
				break
		if hit_obstacle:
			points.append(cannon.to_local(sim_pos))
			break

		# Converter ponto global para local do canhão (para a Line2D)
		points.append(cannon.to_local(sim_pos))

	aim_line.points = points


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

	# Posição global da ponta do cano
	var barrel_tip_local = Vector2(50, 0)
	var barrel_tip_global = cannon.to_global(barrel_tip_local)
	projectile.position = barrel_tip_global

	# Penalidade de precisão baseada na armadura
	var armor_penalty = (1.0 - Global.player_armor / Global.max_player_armor) * 0.15

	# Direção do disparo (ângulo global do canhão + desvio de precisão)
	var total_imprecision = (1.0 - ammo.precision) * 0.12 + armor_penalty
	var angle_deviation = randf_range(-1.0, 1.0) * total_imprecision
	var fire_direction = Vector2.RIGHT.rotated(cannon.global_rotation + angle_deviation)

	# Configurar o projétil com dados do Resource
	projectile.velocity = fire_direction * (ammo.impulse * current_power)
	projectile.gravity = gravity_override
	projectile.precision = ammo.precision
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
	if next_stage_btn:
		if Global.current_stage >= 2:
			next_stage_btn.text = "✓ Vitória!"
		next_stage_btn.visible = true


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


func _update_hud() -> void:
	var ammo = _get_current_ammo()
	if ammo_label:
		ammo_label.text = "x" + str(ammo_counts[current_ammo_index])
	if ammo_icon:
		ammo_icon.ammo_color = ammo.color
		ammo_icon.queue_redraw()
	if ammo_name_label:
		ammo_name_label.text = ammo.ammo_name


## A elevação é -rad_to_deg porque em Godot 2D o Y cresce para baixo: rotation negativa
## é o cano apontado para cima, que para o jogador é ângulo positivo.
func _refresh_parabola_hud() -> void:
	if parabola_hud == null:
		return
	var ammo = _get_current_ammo()
	parabola_hud.set_state(
		-rad_to_deg(cannon.rotation), ammo.impulse * current_power, gravity_override, current_power
	)


func _update_armor_hud() -> void:
	if armor_bar:
		armor_bar.value = Global.player_armor


func _update_stage_label() -> void:
	if stage_label:
		var base_id = Global.current_base_id if Global.current_base_id != "" else "?"
		var stage_num = Global.current_stage + 1  # Mostrar 1-indexed
		stage_label.text = "Base " + base_id + " - Fase " + str(stage_num) + "/3"


# =============================================================================
#  CALLBACKS DOS BOTÕES DA HUD (mantidos do original)
# =============================================================================


func _on_switch_ammo() -> void:
	current_ammo_index = (current_ammo_index + 1) % ammo_types.size()
	# gravity e um stat de AmmoData: cada bala cai do seu jeito, entao o ajuste nao carrega.
	gravity_override = _get_current_ammo().gravity
	_update_hud()
	_refresh_parabola_hud()
	if parabola_hud:
		parabola_hud.flash_gravity()
	_update_aim_line()


func _on_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


## Botão quadrado só com ícone, usado pelo menu e pela ajuda.
func _create_icon_button(font: Font, styles: Array, icon: Texture2D, handler: Callable) -> Button:
	var btn := Button.new()
	btn.add_theme_font_override("font", font)
	btn.add_theme_stylebox_override("normal", styles[0])
	btn.add_theme_stylebox_override("hover", styles[1])
	btn.add_theme_stylebox_override("pressed", styles[2])
	btn.icon = icon
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 32)
	btn.custom_minimum_size = Vector2(56, 56)
	btn.size = Vector2(56, 56)
	# Sem isto o clique dá foco ao botão, e aí as setas viram navegação de foco e o
	# Espaço aciona o botão focado além de disparar o canhão.
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(handler)
	return btn


func _create_menu_button(font: Font, styles: Array, text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", styles[0])
	btn.add_theme_stylebox_override("hover", styles[1])
	btn.add_theme_stylebox_override("pressed", styles[2])
	btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	btn.icon = ICON_EXIT
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(handler)
	return btn


func _on_toggle_menu() -> void:
	if menu_panel == null:
		return
	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")
	menu_panel.visible = not menu_panel.visible



func _create_steampunk_panel() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.1, 0.9)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.7, 0.5, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	return style



func _setup_ui() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.name = "HUD"
	add_child(hud_canvas)

	var font = SystemFont.new()
	font.font_names = ["Georgia", "Times New Roman", "Serif"]

	var btn_tex = load("res://assets/sprites/ui_pack/Grey/Default/button_rectangle_depth_flat.png")
	var normal_style = StyleBoxTexture.new()
	normal_style.texture = btn_tex
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_right = 12.0
	normal_style.content_margin_bottom = 8.0
	var hover_style = normal_style.duplicate()
	hover_style.modulate_color = Color(1.1, 1.05, 0.95)
	var pressed_style = normal_style.duplicate()
	pressed_style.modulate_color = Color(0.85, 0.8, 0.75)
	var btn_styles: Array = [normal_style, hover_style, pressed_style]

	# Menu (canto superior esquerdo). A lista de controles saiu daqui: ela agora vive
	# inteira na tela de ajuda, num lugar so, em vez de ocupar meia lateral da tela.
	menu_btn = _create_icon_button(font, btn_styles, ICON_GEAR, _on_toggle_menu)
	menu_btn.position = Vector2(20, 20)
	hud_canvas.add_child(menu_btn)

	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _create_steampunk_panel())
	menu_panel.position = Vector2(20, 130)
	menu_panel.visible = false
	hud_canvas.add_child(menu_panel)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 10)
	menu_panel.add_child(menu_vbox)

	return_btn = _create_menu_button(font, btn_styles, "Voltar ao Mapa", _on_return_to_map)
	menu_vbox.add_child(return_btn)

	quit_btn = _create_menu_button(font, btn_styles, "Desistir", _on_quit)
	menu_vbox.add_child(quit_btn)

	# Painel Inferior (Munição e Vida)
	var bottom_panel = PanelContainer.new()
	bottom_panel.add_theme_stylebox_override("panel", _create_steampunk_panel())
	bottom_panel.position = Vector2(440, 620)
	bottom_panel.size = Vector2(400, 80)
	hud_canvas.add_child(bottom_panel)

	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 20)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.size = Vector2(400, 80)
	bottom_panel.add_child(bottom_hbox)

	var ammo_info_vbox = VBoxContainer.new()
	ammo_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_child(ammo_info_vbox)

	var ammo_hbox = HBoxContainer.new()
	ammo_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_info_vbox.add_child(ammo_hbox)

	ammo_icon = load("res://scripts/ammo_icon.gd").new()
	ammo_icon.custom_minimum_size = Vector2(40, 40)
	ammo_hbox.add_child(ammo_icon)

	ammo_label = Label.new()
	ammo_label.add_theme_font_override("font", font)
	ammo_label.add_theme_font_size_override("font_size", 28)
	ammo_hbox.add_child(ammo_label)

	ammo_name_label = Label.new()
	ammo_name_label.add_theme_font_override("font", font)
	ammo_name_label.add_theme_font_size_override("font_size", 16)
	ammo_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_info_vbox.add_child(ammo_name_label)

	var vs = VSeparator.new()
	bottom_hbox.add_child(vs)

	var hp_vbox = VBoxContainer.new()
	hp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_vbox.custom_minimum_size = Vector2(150, 0)
	bottom_hbox.add_child(hp_vbox)

	var hp_lbl = Label.new()
	hp_lbl.text = "Armadura"
	hp_lbl.add_theme_font_override("font", font)
	hp_lbl.add_theme_font_size_override("font_size", 18)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_vbox.add_child(hp_lbl)

	armor_bar = ProgressBar.new()
	armor_bar.max_value = 100
	armor_bar.value = 100
	armor_bar.custom_minimum_size = Vector2(150, 20)

	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	sb_bg.corner_radius_top_left = 5
	sb_bg.corner_radius_bottom_right = 5
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.2, 0.6, 0.8, 1.0)
	sb_fg.corner_radius_top_left = 5
	sb_fg.corner_radius_bottom_right = 5
	armor_bar.add_theme_stylebox_override("background", sb_bg)
	armor_bar.add_theme_stylebox_override("fill", sb_fg)
	hp_vbox.add_child(armor_bar)

	# Stage Label
	stage_label = Label.new()
	stage_label.add_theme_font_override("font", font)
	stage_label.add_theme_font_size_override("font_size", 24)
	stage_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	stage_label.position = Vector2(20, 84)
	stage_label.size = Vector2(270, 36)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_canvas.add_child(stage_label)

	# HUD das variáveis da parábola, centrada de verdade: x 296..984 em 1280 de largura.
	# Só coube no meio porque o painel de controles saiu da lateral esquerda.
	parabola_hud = ParabolaHudScript.new()
	parabola_hud.position = Vector2(296, 8)
	parabola_hud.size = Vector2(688, 128)
	hud_canvas.add_child(parabola_hud)
	parabola_hud.setup(font, _create_steampunk_panel())
	parabola_hud.gear_grabbed.connect(_on_gear_grabbed)
	parabola_hud.gear_dragged.connect(_on_gear_dragged)

	# Botão de ajuda — canto superior direito, abaixo do rótulo da fase
	help_btn = Button.new()
	help_btn.text = "?"
	help_btn.add_theme_font_override("font", font)
	help_btn.add_theme_font_size_override("font_size", 32)
	help_btn.add_theme_stylebox_override("normal", normal_style)
	help_btn.add_theme_stylebox_override("hover", hover_style)
	help_btn.add_theme_stylebox_override("pressed", pressed_style)
	help_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	help_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help_btn.offset_left = -84.0
	help_btn.offset_top = 20.0
	help_btn.offset_right = -20.0
	help_btn.offset_bottom = 84.0
	# Sem isto, clicar aqui daria foco ao botão: as setas virariam navegação de foco e o
	# Espaço passaria a acionar o botão além de disparar o canhão.
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	help_btn.pressed.connect(_on_help_pressed)
	hud_canvas.add_child(help_btn)

	# CanvasLayer próprio, fora do hud_canvas, para desenhar por cima de toda a HUD
	help_overlay = HelpOverlayScript.new()
	add_child(help_overlay)
	help_overlay.setup(font, _create_steampunk_panel())
	help_overlay.closed.connect(_on_help_closed)

	# Next Stage Btn
	next_stage_btn = Button.new()
	next_stage_btn.text = "-> Proxima Fase"
	next_stage_btn.add_theme_font_override("font", font)
	next_stage_btn.add_theme_font_size_override("font_size", 22)
	next_stage_btn.add_theme_stylebox_override("normal", normal_style)
	next_stage_btn.add_theme_stylebox_override("hover", hover_style)
	next_stage_btn.add_theme_stylebox_override("pressed", pressed_style)
	next_stage_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	next_stage_btn.position = Vector2(1000, 330)
	next_stage_btn.size = Vector2(250, 50)
	next_stage_btn.visible = false
	next_stage_btn.focus_mode = Control.FOCUS_NONE
	next_stage_btn.pressed.connect(_on_next_stage)
	hud_canvas.add_child(next_stage_btn)

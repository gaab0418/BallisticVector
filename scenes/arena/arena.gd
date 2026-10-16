extends Node2D

# =============================================================================
#  Arena de Combate — arena.gd
#  Gerencia o combate por turnos: canhão do jogador, inimigos, obstáculos,
#  a parábola visível (equação, vértice, raiz, régua) e os desafios da fase.
#
#  O conteúdo de cada fase (cenário, inimigos, lição, desafios) vem de
#  Campaign; a matemática do tiro vem de Ballistics — a mesma conta alimenta a
#  física do disparo, a curva desenhada e os números do painel.
# =============================================================================

# === Referências dos nós (cena) ===
@onready var player: Node2D = $Player
@onready var cannon: Node2D = $Player/Cannon
@onready var obstacles_node: Node2D = $Obstacles
@onready var backdrop: Node2D = $Backdrop
@onready var terrain: Node2D = $Terrain
@onready var ruler: Node2D = $Ruler
@onready var trajectory: Node2D = $Trajectory
@onready var camera: Camera2D = $Camera

# === Variáveis de UI ===
var hud: CanvasLayer
var help_overlay: CanvasLayer
var pause_menu: CanvasLayer
var briefing: StageBriefing
var result: StageResult

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
const MIN_GRAVITY: float = 80.0  # 1,6 m/s² — a Lua
const MAX_GRAVITY: float = 1250.0  # 25 m/s² — Júpiter
const GEAR_SPIN_SPEED: float = 3.0  # rad/s de giro visual da engrenagem
# Duas voltas de mouse varrem a faixa inteira: devagar o bastante para dar precisão,
# rápido o bastante para não cansar a mão.
const DRAG_TURNS_FULL_RANGE: float = 2.0

# === Movimento do tanque (fases da Base Delta) ===
const MOVE_SPEED: float = 90.0  # px/s

# === Precisão do disparo ===
# Comprimento do cano, do munhão até a boca, em coordenadas locais do Cannon.
const BARREL_TIP := Vector2(59, 0)
# Toda a imprecisão do tiro está no ângulo, a única fonte previsível o bastante
# para virar a faixa "a bala pode cair aqui" desenhada sobre a régua.
const IMPRECISION_FACTOR: float = 0.14
const ARMOR_PENALTY_MAX: float = 0.15

# === Sistema de Munição (Resources) ===
var ammo_types: Array[AmmoData] = []
var current_ammo_index: int = 0
var ammo_counts: Array[int] = []  # Quantidade restante de cada tipo

# === Variáveis de estado ===
var _tab_was_pressed: bool = false
var _help_was_pressed: bool = false
var _formula_was_pressed: bool = false
var current_power: float = 1.0
# Gravidade em px/s² desta arena. Comeca na da municao (ou do planeta da fase) e a
# engrenagem ajusta a partir dai. NUNCA escrever em ammo.gravity: Resource e
# cacheado pelo Godot e o valor vazaria para as fases seguintes.
var gravity_override: float = 500.0
var selected_gear: int = GEAR_ANGULO
var _at_limit: bool = false  # borda do limite, para o som de erro tocar uma vez só

# === Fase ===
var stage_data: Dictionary = {}
var world_theme: Dictionary = UiTokens.WORLD_EARTH
var goals := StageGoals.new()
var move_zone := Vector2(1, 0)
## Metros que o tanque ainda pode andar; INF = faixa livre (Base Delta).
var fuel_m := INF
var _tank_start_x: float = 0.0
var _money_at_start: int = 0
var _last_planet := ""
## Gravidade para cima (Ilha Invertida): a > 0 e a engrenagem anda nos negativos.
var inverted := false
var lab: Node
var _fx: Node
## A Engenheira Ada: tutorial, abertura da fase, dicas e parabéns.
var coach: Node

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
const LabControllerScript = preload("res://scenes/arena/lab_controller.gd")
const ImpactWatcherScript = preload("res://scenes/arena/impact_watcher.gd")
const AdaCoachScript = preload("res://scenes/arena/ada_coach.gd")
const ShotTrailScript = preload("res://scenes/arena/shot_trail.gd")
const TankFlagScript = preload("res://scenes/arena/tank_flag.gd")
## Ponta da antena do sprite do tanque, em coordenadas do Player.
const ANTENNA_TIP := Vector2(-62, -6)

const SFX_HOVER := "res://assets/audio/menu_hover_.ogg"
const SFX_CLICK := "res://assets/audio/menu_click.ogg"
const SFX_BACK := "res://assets/audio/menu_back.ogg"
const SFX_ERROR := "res://assets/audio/erro.ogg"
const SFX_FIRE := "res://assets/audio/cannon_fire.ogg"

const WORLDS := {
	"moon": UiTokens.WORLD_MOON,
	"mars": UiTokens.WORLD_MARS,
	"jupiter": UiTokens.WORLD_JUPITER,
	"inverted": UiTokens.WORLD_INVERTED,
}


func _ready() -> void:
	randomize()
	if Global.lab_mode:
		stage_data = Campaign.lab_stage(Global.lab_world)
	else:
		stage_data = Campaign.stage(Global.current_base_id, Global.current_stage)
	world_theme = WORLDS.get(stage_data.get("planet", ""), UiTokens.WORLD_EARTH)
	move_zone = stage_data.get("move_zone", Vector2(1, 0))
	fuel_m = stage_data.get("fuel_m", INF)
	inverted = stage_data.get("inverted", false)
	# Platô: o tanque sobe junto, e a altura do canhão (o "c") cresce com ele.
	player.position.y -= Ballistics.to_px(stage_data.get("tank_height", 0.0))
	trajectory.height_line = stage_data.get("height_line", NAN)
	# Continua redesenhando com o jogo pausado (falas da Ada): senao a curva fica
	# com os rotulos calculados antes de a HUD terminar o layout.
	trajectory.process_mode = Node.PROCESS_MODE_ALWAYS
	_tank_start_x = player.position.x
	_money_at_start = Global.money

	_build_world()
	_dress_player()
	_fx = ImpactWatcherScript.new()
	add_child(_fx)
	_fx.setup(self, camera, ProjectileScript)

	# Carregar munições dos Resources
	_load_ammo_types()
	gravity_override = _stage_gravity()

	goals.setup(stage_data.get("goals", []))

	_build_hud()
	AudioManager.play_bgm("res://assets/audio/Battle.mp3")

	# Inicializar HUD
	_update_hud()
	_update_armor_hud()
	_update_stage_label()
	_refresh_goals()
	_refresh_math()

	coach = AdaCoachScript.new()
	add_child(coach)
	coach.setup(self)
	_fx.player_shot_ended.connect(coach.on_shot_ended)

	if Global.lab_mode:
		lab = LabControllerScript.new()
		add_child(lab)
		lab.setup(self)
		return

	# Spawnar inimigos para a fase atual
	_spawn_enemies()

	# A Ada abre a fase (ou dá o tutorial, na primeira vez).
	coach.start_stage()


# =============================================================================
#  MUNDO (fundo, obstáculos, chão, régua)
# =============================================================================


func _build_world() -> void:
	var seed_value := hash(Global.current_base_id) + Global.current_stage * 97
	backdrop.setup(world_theme, Campaign.GROUND_Y, seed_value)
	terrain.setup(world_theme, Campaign.GROUND_Y, seed_value + 5)
	ruler.setup(Campaign.ORIGIN_X, Campaign.GROUND_Y, move_zone)

	StageBuilder.build_obstacles(
		obstacles_node, stage_data, world_theme.rock, terrain.collision_polygon()
	)

	_cache_obstacle_polygons()
	trajectory.obstacles = _mountain_polygons()


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


## Só as montanhas: a trajetória desenha a queda no chão como raiz, não como batida.
func _mountain_polygons() -> Array:
	var out: Array = []
	for i in range(_obstacle_polygons_cache.size() - 1):
		out.append(_obstacle_polygons_cache[i])
	return out


# === Retorna os polígonos de obstáculos (usado pelos aviões e projéteis inimigos) ===
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


## Na Terra cada munição traz a sua gravidade; num planeta, a gravidade é do
## planeta e vale para qualquer bala.
func _stage_gravity() -> float:
	return stage_data.get("gravity", _get_current_ammo().gravity)


# =============================================================================
#  SPAWNING DE INIMIGOS
# =============================================================================
func _spawn_enemies() -> void:
	active_enemies = StageBuilder.spawn_enemies(self, stage_data, player)


# =============================================================================
#  LOOP PRINCIPAL (_process)
# =============================================================================
func _process(delta: float) -> void:
	# Fora do early-return de propósito: a ajuda abre mesmo com a fase já limpa.
	_poll_help_hotkey()
	_poll_formula_hotkey()

	# Não processar input se a fase foi limpa
	if stage_cleared:
		return

	# === Engrenagens: esquerda/direita escolhem, cima/baixo giram ===
	_poll_gear_selection()
	_poll_gear_rotation(delta)
	_poll_movement(delta)

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
	AudioManager.play_sfx(SFX_HOVER)
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
		_after_gear_change()
		return

	# No limite a engrenagem trava (não recebe spin) e o valor pisca. O som toca uma vez
	# só: o AudioManager tem um único sfx_player e repetir a 60 Hz cortaria todo o resto.
	_hit_limit()


func _hit_limit() -> void:
	hud.parabola.flash_selected(selected_gear)
	if not _at_limit:
		_at_limit = true
		AudioManager.play_sfx(SFX_ERROR)


func _after_gear_change() -> void:
	if selected_gear == GEAR_GRAVIDADE:
		goals.on_gravity_touched()
		_announce_planet()
	_refresh_math()


## Ao girar a gravidade até o valor de um lugar de verdade, avisa qual é: liga o
## número a uma ideia ("10 é a Terra, 1,6 é a Lua").
func _announce_planet() -> void:
	if inverted:
		return
	var planet := Campaign.planet_like(Ballistics.to_m(gravity_override))
	if planet != "" and planet != _last_planet:
		var where := ("da " if planet in ["Terra", "Lua"] else "de ") + planet
		hud.show_toast("Gravidade parecida com a " + where + "!", UiTokens.EDITABLE)
	_last_planet = planet


## Passo por segundo de tecla. Devolve true se o valor mudou; false = bateu no limite.
## Elevar o cano é diminuir cannon.rotation.
func _adjust_selected_gear(dir: float, delta: float, mult: float) -> bool:
	match selected_gear:
		GEAR_FORCA:
			return _set_power(current_power + dir * POWER_RATE * mult * delta)
		GEAR_GRAVIDADE:
			# No mundo invertido "mais gravidade" é mais negativo.
			var sgn := -1.0 if inverted else 1.0
			return _set_gravity(gravity_override + sgn * dir * GRAVITY_RATE * mult * delta)
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
			var sgn := -1.0 if inverted else 1.0
			return _set_gravity(gravity_override + sgn * frac * (MAX_GRAVITY - MIN_GRAVITY))
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
	if inverted:
		gravity_override = clamp(value, -MAX_GRAVITY, -MIN_GRAVITY)
	else:
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
		_after_gear_change()
		return
	_hit_limit()


# =============================================================================
#  MOVIMENTO DO TANQUE (A/D, só nas fases com faixa de manobra)
# =============================================================================


## Andar com o tanque é a translação da parábola: a curva inteira escorrega e, na
## equação, só b e c mudam. Por isso a faixa existe só nas fases que ensinam isso.
func _poll_movement(delta: float) -> void:
	if move_zone.y <= move_zone.x or fuel_m <= 0.0:
		return
	var dir := 0.0
	if Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir += 1.0
	if is_zero_approx(dir):
		return
	var offset := cannon.position.x
	var x := clampf(
		player.position.x + dir * MOVE_SPEED * delta, move_zone.x - offset, move_zone.y - offset
	)
	if is_equal_approx(x, player.position.x):
		return
	if not is_inf(fuel_m):
		fuel_m = maxf(fuel_m - Ballistics.to_m(absf(x - player.position.x)), 0.0)
		hud.set_fuel(fuel_m)
		if fuel_m <= 0.0:
			hud.show_toast("Acabou o combustível! Agora é só no ângulo e na força.", UiTokens.DANGER)
	player.position.x = x
	# Balanço de esteira: um pixel para cima e para baixo enquanto anda.
	player.get_node("Body").position.y = 6.0 + (1.0 if int(x / 6.0) % 2 == 0 else 0.0)
	_refresh_math()


func _moved_meters() -> float:
	return Ballistics.to_m(absf(player.position.x - _tank_start_x))


# =============================================================================
#  TELA DE AJUDA E "VER CONTA"
# =============================================================================


## Mesmo idioma de detecção de borda do Tab, para não ter que criar uma seção [input]
## no project.godot só por causa de uma tecla.
func _poll_help_hotkey() -> void:
	if Input.is_key_pressed(KEY_H) == false and _help_was_pressed:
		_on_help_pressed()
	_help_was_pressed = Input.is_key_pressed(KEY_H)


func _poll_formula_hotkey() -> void:
	if Input.is_key_pressed(KEY_F) == false and _formula_was_pressed and not get_tree().paused:
		hud.formula.toggle()
		AudioManager.play_sfx(SFX_CLICK)
		_refresh_math()
	_formula_was_pressed = Input.is_key_pressed(KEY_F)


func _on_help_pressed() -> void:
	if help_overlay == null or help_overlay.visible:
		return
	if coach and coach.ada.is_talking():
		return
	AudioManager.play_sfx(SFX_CLICK)
	help_overlay.open()
	get_tree().paused = true


func _on_help_closed() -> void:
	AudioManager.play_sfx(SFX_BACK)
	# Deferido de propósito: despausar agora faria o _process rodar ainda neste frame,
	# lendo o mesmo estado de teclado — e polling não é bloqueado por
	# set_input_as_handled(). Sem isto, fechar com Esc podia disparar o canhão.
	get_tree().set_deferred("paused", false)


# =============================================================================
#  A PARÁBOLA VISÍVEL (mira, painel, régua)
# =============================================================================


## Desvio máximo para cada lado, em radianos. Fonte única: o disparo real e a faixa
## desenhada na régua saem daqui, então o que a tela mostra é o erro que de fato acontece.
func _current_spread() -> float:
	# No Laboratório a mira é perfeita: a tabela compara bala e conta, e o desvio
	# da munição esconderia que a equação acerta.
	if Global.lab_mode:
		return 0.0
	var ammo = _get_current_ammo()
	var armor_ratio: float = Global.player_armor / Global.max_player_armor
	var armor_penalty: float = (1.0 - armor_ratio) * ARMOR_PENALTY_MAX
	return (1.0 - ammo.precision) * IMPRECISION_FACTOR + armor_penalty


func _angle_deg() -> float:
	# Em Godot 2D o Y cresce para baixo: rotation negativa é o cano para cima.
	return -rad_to_deg(cannon.rotation)


func _speed_px() -> float:
	return _get_current_ammo().impulse * current_power


func _shot_for(angle_deg: float, speed_px: float, gravity_px: float) -> Dictionary:
	return Ballistics.shot(
		angle_deg,
		speed_px,
		gravity_px,
		cannon.global_position,
		Campaign.ORIGIN_X,
		Campaign.GROUND_Y
	)


## A equação do tiro na mira agora (usada pelo Laboratório).
func current_shot() -> Dictionary:
	return _shot_for(_angle_deg(), _speed_px(), gravity_override)


## Recalcula a equação e empurra para painel, gaveta e curva.
func _refresh_math() -> void:
	if hud == null:
		return
	var angle := _angle_deg()
	var speed := _speed_px()
	var s := _shot_for(angle, speed, gravity_override)
	var band := Ballistics.landing_band(
		angle,
		rad_to_deg(_current_spread()),
		speed,
		gravity_override,
		cannon.global_position,
		Campaign.ORIGIN_X,
		Campaign.GROUND_Y
	)
	(
		hud
		. parabola
		. set_state(
			{
				"angle_deg": angle,
				"power": current_power,
				"shot": s,
				"effects":
				Ballistics.gear_effects(
					angle,
					speed,
					gravity_override,
					cannon.global_position,
					Campaign.ORIGIN_X,
					Campaign.GROUND_Y
				),
				"planet": Campaign.planet_like(s.g),
				"vertex_form": move_zone.y > move_zone.x and is_inf(fuel_m),
			}
		)
	)
	hud.formula.set_height_line(trajectory.height_line)
	hud.formula.set_shot(s)
	if lab:
		lab.refresh_target(s)
	trajectory.show_cannon_height = hud.formula.visible
	trajectory.occluder_source = hud.occluder_rects
	trajectory.update_shot(s, cannon.global_position, band)


# =============================================================================
#  DISPARO DO PROJÉTIL
# =============================================================================
func _fire_projectile() -> void:
	var ammo = _get_current_ammo()

	if not Global.lab_mode and ammo_counts[current_ammo_index] <= 0:
		AudioManager.play_sfx(SFX_ERROR)
		var other := ammo_counts[(current_ammo_index + 1) % ammo_counts.size()]
		if other > 0:
			hud.show_toast("Sem munição! Tab troca o tipo.", UiTokens.DANGER)
		else:
			# Sem nenhuma bala: o mapa entrega um kit de emergência se faltar ouro.
			hud.show_toast("Acabou a munição! Volte ao mapa (Esc).", UiTokens.DANGER)
		return

	AudioManager.play_sfx(SFX_FIRE)
	if not Global.lab_mode:
		ammo_counts[current_ammo_index] -= 1
		Global.ammo_inventory[ammo.ammo_name] = ammo_counts[current_ammo_index]
	_update_hud()
	goals.on_fire(_angle_deg())
	_refresh_goals()

	var projectile = ProjectileScript.new()
	# A bala nasce no munhão: é a origem da equação y = ax² + bx + c que o painel mostra.
	# O cano é desenhado por cima, então ela aparece saindo da boca.
	projectile.position = cannon.global_position

	# Mesmo _current_spread() que desenha a faixa na régua: o erro possível do tiro é
	# o erro que o jogador viu na tela antes de atirar.
	var angle_deviation = randf_range(-1.0, 1.0) * _current_spread()
	var fire_direction = Vector2.RIGHT.rotated(cannon.global_rotation + angle_deviation)

	# Configurar o projétil com dados do Resource
	projectile.velocity = fire_direction * _speed_px()
	projectile.gravity = gravity_override
	projectile.bullet_color = ammo.color
	projectile.damage = ammo.damage
	projectile.enemy_nodes = active_enemies.duplicate()
	projectile.obstacle_polygons = _obstacle_polygons_cache
	projectile.is_enemy_projectile = false
	# O que os desafios precisam saber quando esta bala acertar algo.
	projectile.set_meta("angle", _angle_deg())
	projectile.set_meta("power", current_power)
	projectile.set_meta("moved", _moved_meters())
	projectile.set_meta("shot", _shot_for(_angle_deg(), _speed_px(), gravity_override))

	add_child(projectile)
	_attach_trail(projectile)
	coach.on_fire()
	if lab:
		lab.on_fired(projectile)
	ArenaFx.spawn(self, cannon.to_global(BARREL_TIP), ArenaFx.Kind.MUZZLE, fire_direction)
	_fx.kick(2.0)


# =============================================================================
#  CALLBACKS DE COLISÃO (chamados pelo projectile.gd)
# =============================================================================


# --- Projétil do jogador acertou um inimigo ---
func on_enemy_hit(enemy: Node2D, dmg: int) -> void:
	if not enemy or not is_instance_valid(enemy):
		return

	var bullet := _bullet_near(enemy)
	coach.on_hit()
	# Bunker só quebra com tiro caindo de cima; rasante ricocheteia no concreto.
	if enemy.has_meta("bunker") and bullet != null:
		var v: Vector2 = bullet.velocity
		var descent := rad_to_deg(atan2(v.y, absf(v.x)))
		if descent < enemy.MIN_DESCENT_DEG:
			ArenaFx.spawn(self, enemy.global_position + Vector2(0, -20), ArenaFx.Kind.SPARK)
			var msg := (
				"ricochete! a bala desceu a %d°, precisa de %d°"
				% [maxi(0, roundi(descent)), roundi(enemy.MIN_DESCENT_DEG)]
			)
			ArenaFx.float_text(self, enemy.global_position + Vector2(-110, -60), msg, UiTokens.TEXT)
			return
	if enemy.has_meta("balloon") and bullet != null:
		goals.on_balloon_hit(bullet.velocity.y < 0.0)
	_report_hit_to_goals(enemy, bullet)
	ArenaFx.spawn(self, enemy.global_position, ArenaFx.Kind.SPARK)

	# Verificar se o inimigo tem o método take_damage (aviões com script)
	if enemy.has_method("take_damage"):
		enemy.take_damage(dmg)
	else:
		# Boss sem script — sempre perde 1 HP por tiro (3 tiros pra morrer)
		var current_hp = enemy.get_meta("hp", 0)
		current_hp -= 1
		enemy.set_meta("hp", current_hp)
		ArenaFx.flash_sprite(enemy.get_node_or_null("Body"))
		_fx.kick(5.0)
		ArenaFx.float_text(self, enemy.global_position + Vector2(0, -70), "−1", UiTokens.DANGER)
		if current_hp <= 0:
			on_enemy_destroyed(enemy)
			enemy.queue_free()


## A bala que acertou ainda existe neste instante (o projétil só se libera depois de
## chamar a arena): a mais perto do alvo é ela.
func _bullet_near(enemy: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for child in get_children():
		if child.get_script() == ProjectileScript and child.has_meta("shot"):
			var d: float = child.position.distance_to(enemy.global_position)
			if d < best_d:
				best_d = d
				best = child
	return best


func _report_hit_to_goals(enemy: Node2D, best: Node2D) -> void:
	if best == null:
		return
	if enemy.has_meta("is_boss"):
		var shot: Dictionary = best.get_meta("shot")
		var vy := Ballistics.vertex(shot).y if Ballistics.has_arc(shot) else NAN
		goals.on_boss_hit(
			best.get_meta("angle"), best.get_meta("power"), best.get_meta("moved"), vy
		)
		return
	var s: Dictionary = best.get_meta("shot")
	if Ballistics.has_arc(s):
		var v := Ballistics.vertex(s)
		var vp := Ballistics.point_px(s, v.x)
		goals.on_plane_hit(Ballistics.to_m(vp.distance_to(best.position)))


# --- Projétil inimigo acertou o jogador ---
func on_player_hit(dmg: int) -> void:
	Global.player_armor -= dmg
	Global.player_armor = max(Global.player_armor, 0.0)
	goals.on_damage()
	_update_armor_hud()
	# A armadura entra em _current_spread(): levar dano alarga a faixa de queda na hora.
	_refresh_math()
	ArenaFx.flash_sprite(player.get_node_or_null("Body"))
	_fx.kick(8.0)
	ArenaFx.spawn(self, player.global_position, ArenaFx.Kind.EXPLOSION)
	ArenaFx.float_text(self, player.global_position + Vector2(0, -60), "−%d" % dmg, UiTokens.DANGER)

	# Verificar game over
	if Global.player_armor <= 0:
		get_tree().change_scene_to_file("res://scenes/game_over/game_over.tscn")


# --- Inimigo foi destruído (chamado pelo airplane_enemy.gd ou internamente) ---
func on_enemy_destroyed(enemy: Node2D) -> void:
	var reward := 150 if enemy.name == "Boss" else 25
	Global.money += reward
	ArenaFx.spawn(self, enemy.global_position, ArenaFx.Kind.EXPLOSION)
	ArenaFx.float_text(
		self, enemy.global_position + Vector2(0, -30), "+%d ouro" % reward, UiTokens.GOLD
	)

	active_enemies.erase(enemy)
	# Limpar referências inválidas
	var still_alive: Array = []
	for e in active_enemies:
		if e and is_instance_valid(e) and e != enemy:
			still_alive.append(e)
	active_enemies = still_alive

	if active_enemies.size() == 0:
		_on_stage_cleared()


# =============================================================================
#  SISTEMA DE FASES
# =============================================================================


# --- Fase limpa — todos os inimigos mortos ---
func _on_stage_cleared() -> void:
	if stage_cleared:
		return
	stage_cleared = true
	# Recompensar o jogador
	Global.money += 250
	goals.finish()
	if not Global.lab_mode:
		Global.brass += Global.BRASS_PER_WIN
	coach.on_stage_cleared()
	var stars := goals.stars()
	Global.record_stars(Global.current_base_id, Global.current_stage, stars)
	# Deixa a explosão do último inimigo acontecer antes da tela de resultado.
	await get_tree().create_timer(1.0).timeout
	result.show_result(
		stars, goals.goals, goals.states, Global.money - _money_at_start, _is_last_stage()
	)


# --- "Próxima fase" na tela de resultado ---
func _on_next_stage() -> void:
	if not _is_last_stage():
		# Avançar para a próxima fase
		Global.current_stage += 1
		_save_progress(Global.current_stage)
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		_finish_base()


## Base inteira concluída: registra e volta ao mapa.
func _finish_base() -> void:
	_save_progress(_total_stages())
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


## Visual da Oficina: camuflagem nos sprites e bandeirinha na antena.
func _dress_player() -> void:
	Cosmetics.dress_tank([player.get_node("Body"), cannon.get_node("Barrel")])
	var flag := Node2D.new()
	flag.set_script(TankFlagScript)
	flag.position = ANTENNA_TIP
	player.add_child(flag)
	flag.setup(Cosmetics.equipped("flag"))


func _attach_trail(projectile: Node2D) -> void:
	var trail_data := Cosmetics.equipped("trail")
	var trail := Node2D.new()
	trail.set_script(ShotTrailScript)
	trail.target = projectile
	trail.style = trail_data.style
	trail.color = Color(trail_data.color)
	add_child(trail)


func _total_stages() -> int:
	return int(Global.get_base_data(Global.current_base_id).get("total_stages", 3))


func _is_last_stage() -> bool:
	return Global.current_stage >= _total_stages() - 1


## Progresso só cresce: rejogar uma fase antiga (para ganhar mais estrelas) não pode
## apagar as fases já vencidas depois dela.
func _save_progress(stages_done: int) -> void:
	var data: Dictionary = Global.get_base_data(Global.current_base_id)
	var before: int = data.get("stages_cleared", 0)
	Global.update_base_cleared(Global.current_base_id, maxi(before, stages_done))


# --- "Voltar ao Mapa" (pausa ou tela de resultado) ---
func _on_return_to_map() -> void:
	if Global.lab_mode:
		lab._exit()
		return
	# Vencer e voltar pelo resultado conta a fase como feita; abandonar pela pausa não.
	var done := Global.current_stage + (1 if stage_cleared else 0)
	if done >= _total_stages():
		_finish_base()
		return
	_save_progress(done)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


# =============================================================================
#  ATUALIZAÇÃO DA HUD
# =============================================================================


## A HUD, a ajuda, a pausa e os cartões de fase são CanvasLayer irmãos. A ajuda fica
## acima da pausa porque é ela que pode ser aberta com a pausa já no ar (pelo "?").
func _build_hud() -> void:
	hud = ArenaHudScript.new()
	add_child(hud)
	hud.parabola.gear_grabbed.connect(_on_gear_grabbed)
	hud.parabola.gear_dragged.connect(_on_gear_dragged)
	hud.parabola.formula_toggled.connect(func(): _refresh_math.call_deferred())
	hud.help_pressed.connect(_on_help_pressed)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.set_move_hint(move_zone.y > move_zone.x)
	if not is_inf(fuel_m):
		hud.set_fuel(fuel_m)
	# A cor do que é calculado depende do céu: laranja na Terra, azul nos outros.
	var aim: Color = world_theme.aim
	hud.parabola.set_accent(aim)
	hud.formula.set_accent(aim)
	trajectory.aim = aim

	help_overlay = HelpOverlayScript.new()
	add_child(help_overlay)
	help_overlay.setup(UiPanel.create(UiPanel.Kind.MODAL))
	help_overlay.closed.connect(_on_help_closed)

	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)
	pause_menu.layer = 9
	pause_menu.restart_requested.connect(_on_restart_stage)
	pause_menu.return_to_map_requested.connect(_on_return_to_map)

	briefing = StageBriefing.new()
	add_child(briefing)
	briefing.layer = 11

	result = StageResult.new()
	add_child(result)
	result.layer = 11
	result.next_requested.connect(_on_next_stage)
	result.map_requested.connect(_on_return_to_map)


func _on_pause_pressed() -> void:
	if help_overlay and help_overlay.visible:
		return
	if coach and coach.ada.is_talking():
		return
	if briefing.visible or result.visible:
		return
	pause_menu.open()


## Esc chega aqui so quando nenhum modal esta aberto: a ajuda e a pausa tratam a
## acao em _input e chamam set_input_as_handled(), que roda antes do unhandled.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_pause_pressed()


func _on_restart_stage() -> void:
	get_tree().reload_current_scene()


func _update_hud() -> void:
	var ammo = _get_current_ammo()
	var count: int = -1 if Global.lab_mode else ammo_counts[current_ammo_index]
	hud.set_ammo(count, ammo.color, ammo.ammo_name)


func _update_armor_hud() -> void:
	hud.set_armor(Global.player_armor, Global.max_player_armor)


## Usa o nome de exibicao da base ("Base Alpha"), nao o id ("Base_A").
func _update_stage_label() -> void:
	if Global.lab_mode:
		hud.set_lab(Campaign.LAB_WORLDS.get(Global.lab_world, {}).get("name", ""))
		return
	var data: Dictionary = Global.get_base_data(Global.current_base_id)
	var base_name: String = data.get("name", "Base desconhecida")
	var total_stages: int = data.get("total_stages", 3)
	hud.set_stage(
		base_name,
		Campaign.base(Global.current_base_id).chapter,
		Global.current_stage + 1,
		total_stages,
		stage_data.get("title", "")
	)


func _refresh_goals() -> void:
	if hud == null:
		return
	var progress := []
	for i in range(goals.goals.size()):
		progress.append(goals.progress_text(i))
	hud.set_goals(goals.goals, goals.states, progress)


# =============================================================================
#  CALLBACKS DOS BOTÕES DA HUD
# =============================================================================


func _on_switch_ammo() -> void:
	current_ammo_index = (current_ammo_index + 1) % ammo_types.size()
	gravity_override = _stage_gravity()
	_update_hud()
	hud.parabola.flash_gravity()
	_refresh_math()
	AudioManager.play_sfx(SFX_HOVER)

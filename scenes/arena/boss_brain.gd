extends Node2D
## O chefe da ultima fase de cada base: o castelo ganha um nome e uma regra que
## pede a ideia do capitulo para ser vencida.
##
##   shield  -- (Alpha) cupula que so deixa passar bala caindo de cima: vertice alto
##   moving  -- (Bravo, Norte) anda numa faixa: a raiz tem que acompanhar
##   hopping -- (Delta) a cada acerto foge para outro ponto: ande com o tanque
##   gravity -- (Charlie) a cada acerto troca a gravidade do mundo
##   guarded -- (Echo, Foxtrot) escudo que so cai quando os outros inimigos caem
##
## Quem atira: so o chefe com `"fires": true` na fase (Castelo sobre Rodas, da
## Bravo 3, e Castelo Fujao, da Delta 3). O Iglu Blindado (Norte 3) e `moving`,
## mas nao atira; por isso a regra e o dado `fires`, nao o `kind`.
## O tiro e um morteiro avisado: aviso de 1 s com marcador no chao, voo de ~3,2 s
## e uma folga de sobra para o jogador sair andando. So conta tempo por `delta`
## (nada de create_timer, que corre com o jogo pausado).

## Tiro do chefe (so quem tem "fires": true): morteiro de apogeu fixo, avisado.
const SHOT_GRAVITY := 300.0
const SHOT_MUZZLE := Vector2(0, -80)
## Mais alto que isso o tiro some atras do painel do topo; mais baixo, ele raspa o
## pico arredondado da montanha da Delta 3 (a 170 a folga era de 1 px).
const SHOT_APEX_Y := 150.0
const SHOT_WARN_S := 1.0
const SHOT_FIRST_DELAY_S := 3.0
const SHOT_COOLDOWN_S := 3.0
const SHOT_DAMAGE := 10
const DANGER_R := 64.0
## Meia-altura do marcador no chao (so desenho).
const DANGER_RY := 10.0

const SHIELD_R := 120.0
## Centro da cupula: a base do castelo fica 86 px abaixo da origem dele.
const SHIELD_C := Vector2(0, 82)

const ProjectileScript := preload("res://scenes/arena/projectile.gd")

enum Phase { IDLE, WARN, FLIGHT }

var data: Dictionary = {}
var _phase := Phase.IDLE
## Segundos ate o proximo aviso (IDLE).
var _wait := SHOT_FIRST_DELAY_S
## Onde o tanque estava quando o aviso comecou: o morteiro vai para la.
var _target := Vector2.ZERO
var _bullet: Node2D
var _phase_t := 0.0
var _flight_s := 0.0
var _warned := false
var _held_warned := false
var arena: Node2D
var _spot := 0
var _dir := -1.0
var _hits := 0
var _t := 0.0
var _font: Font


func setup(host_arena: Node2D, chief: Dictionary) -> void:
	arena = host_arena
	data = chief
	name = "Brain"
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	z_index = 3


func kind() -> String:
	return data.get("kind", "")


func fires() -> bool:
	return data.get("fires", false)


## Tempo de voo do morteiro: sobe da boca ate o apogeu e cai ate o alvo. Com o
## apogeu fixo, nao depende da distancia horizontal.
static func lob_time(from_y: float, to_y: float) -> float:
	return (
		sqrt(2.0 * (from_y - SHOT_APEX_Y) / SHOT_GRAVITY)
		+ sqrt(2.0 * (to_y - SHOT_APEX_Y) / SHOT_GRAVITY)
	)


static func lob_velocity(from: Vector2, to: Vector2) -> Vector2:
	return Vector2(
		(to.x - from.x) / lob_time(from.y, to.y), -sqrt(2.0 * SHOT_GRAVITY * (from.y - SHOT_APEX_Y))
	)


## Trava de justica: so avisa se o tanque tem faixa, combustivel e espaco para
## sair de um marcador de `need_px` de meia-largura.
static func dodge_ok(zone: Vector2, cannon_x: float, fuel_m: float, need_px: float) -> bool:
	if zone.y <= zone.x or fuel_m < Ballistics.to_m(need_px):
		return false
	return maxf(cannon_x - zone.x, zone.y - cannon_x) >= need_px


func _process(delta: float) -> void:
	_t += delta
	var host := get_parent() as Node2D
	if kind() == "moving" and not arena.stage_cleared:
		var zone: Vector2 = data.get("zone", Vector2(host.position.x, host.position.x))
		host.position.x += _dir * float(data.get("speed", 20.0)) * delta
		if host.position.x < zone.x:
			host.position.x = zone.x
			_dir = 1.0
		elif host.position.x > zone.y:
			host.position.x = zone.y
			_dir = -1.0
	if fires():
		_tick_volley(delta)
	queue_redraw()


func _tick_volley(delta: float) -> void:
	if arena.stage_cleared:
		_cancel_volley()
		return
	match _phase:
		Phase.IDLE:
			_wait -= delta
			if _wait <= 0.0:
				_begin_warning()
		Phase.WARN:
			_phase_t += delta
			if _phase_t >= SHOT_WARN_S:
				_launch()
		Phase.FLIGHT:
			_phase_t += delta
			if not is_instance_valid(_bullet):
				_end_volley()


func _begin_warning() -> void:
	var player = arena.player
	if not is_instance_valid(player):
		_wait = SHOT_COOLDOWN_S
		return
	var cannon_x: float = player.position.x + arena.cannon.position.x
	if not dodge_ok(arena.move_zone, cannon_x, arena.fuel_m, DANGER_R):
		_wait = SHOT_COOLDOWN_S
		if not _held_warned:
			_held_warned = true
			arena.hud.show_toast(
				"Sem combustível para desviar: o chefe segurou o fogo.", UiTokens.EDITABLE
			)
		return
	_target = player.global_position
	_phase = Phase.WARN
	_phase_t = 0.0
	if not _warned:
		_warned = true
		arena.hud.show_toast(
			"O chefe vai atirar: saia do marcador vermelho (A/D).", UiTokens.DANGER
		)


func _launch() -> void:
	if not is_instance_valid(arena.player):
		_end_volley()
		return
	var host := get_parent() as Node2D
	var origin := host.global_position + SHOT_MUZZLE
	var v := lob_velocity(origin, _target)
	var p = ProjectileScript.new()
	p.position = origin
	p.velocity = v
	p.gravity = SHOT_GRAVITY
	p.bullet_color = UiTokens.ENEMY_SHOT
	p.damage = SHOT_DAMAGE
	p.is_enemy_projectile = true
	p.player_node = arena.player
	p.obstacle_polygons = arena.get_obstacle_polygons()
	# Sem a meta "shot": a arena e a Ada so tratam como tiro do jogador quem a tem.
	p.set_meta("chief_shot", true)
	arena.add_child(p)
	ArenaFx.spawn(arena, origin, ArenaFx.Kind.MUZZLE, v.normalized())
	_bullet = p
	_phase = Phase.FLIGHT
	_phase_t = 0.0
	_flight_s = lob_time(origin.y, _target.y)


func _end_volley() -> void:
	_phase = Phase.IDLE
	_phase_t = 0.0
	_wait = SHOT_COOLDOWN_S


## Fase vencida, chefe derrubado ou saida da cena: nenhuma bala pendente fica.
func _cancel_volley() -> void:
	if is_instance_valid(_bullet):
		_bullet.queue_free()
	_bullet = null
	_end_volley()


func _exit_tree() -> void:
	_cancel_volley()


## Motivo para a bala nao causar dano ("" = passa). Chamado antes do dano.
func blocks(bullet: Node2D) -> String:
	match kind():
		"shield":
			if bullet == null:
				return ""
			var v: Vector2 = bullet.velocity
			var descent := rad_to_deg(atan2(v.y, absf(v.x)))
			var need: float = data.get("min_descent", 35.0)
			if descent < need:
				return (
					"o escudo desviou! a bala caiu a %d°, precisa de %d°"
					% [maxi(0, roundi(descent)), roundi(need)]
				)
		"guarded":
			if _guards_alive() > 0:
				return "escudo ligado! derrube os outros %d inimigos primeiro" % _guards_alive()
	return ""


## Depois de um acerto que causou dano.
func on_hit() -> void:
	_hits += 1
	match kind():
		"hopping":
			var spots: Array = data.get("spots", [])
			if spots.is_empty():
				return
			_spot = (_spot + 1) % spots.size()
			var host := get_parent() as Node2D
			var tw := host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(host, "position:x", float(spots[_spot]), 0.6)
			arena.hud.show_toast(
				"O castelo fugiu! Ande com o tanque e mire de novo.", UiTokens.EDITABLE
			)
		"gravity":
			var list: Array = data.get("list", [])
			if list.is_empty():
				return
			arena.set_world_gravity(float(list[_hits % list.size()]))


func _guards_alive() -> int:
	var n := 0
	for e in arena.active_enemies:
		if is_instance_valid(e) and e != get_parent():
			n += 1
	return n


func _shield_on() -> bool:
	return kind() == "shield" or (kind() == "guarded" and _guards_alive() > 0)


func _draw() -> void:
	if _shield_on():
		var a := 0.22 + 0.06 * sin(_t * 3.0)
		var col := UiTokens.CALCULATED if kind() == "shield" else UiTokens.DANGER
		draw_arc(SHIELD_C, SHIELD_R, PI, TAU, 40, Color(col, a + 0.35), 3.0)
		# So a metade de cima: a cupula se apoia no chao.
		var dome := PackedVector2Array()
		for i in range(41):
			dome.append(SHIELD_C + Vector2.from_angle(PI + PI * i / 40.0) * SHIELD_R)
		draw_colored_polygon(dome, Color(col, a * 0.35))
	_draw_warning()
	var title := "CHEFE · " + str(data.get("name", ""))
	var size_px := UiTokens.FONT_SM
	var w := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var at := Vector2(-w * 0.5, -122)
	draw_string_outline(
		_font,
		at,
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size_px,
		UiTokens.TEXT_OUTLINE_SIZE + 2,
		UiTokens.TEXT_OUTLINE
	)
	draw_string(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UiTokens.GOLD)


## "!" sobre o castelo e o marcador no chao, do aviso ate o impacto. O marcador
## enche de 0 a 100 % durante o voo (contagem regressiva).
func _draw_warning() -> void:
	if _phase == Phase.IDLE:
		return
	var on := int(_t * 8.0) % 2 == 0
	var col := Color(UiTokens.DANGER, 1.0 if on else 0.55)
	if _phase == Phase.WARN:
		var at := Vector2(-8, -150)
		draw_string_outline(
			_font,
			at,
			"!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			UiTokens.FONT_XL,
			UiTokens.TEXT_OUTLINE_SIZE + 2,
			UiTokens.TEXT_OUTLINE
		)
		draw_string(_font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_XL, col)
	var c := to_local(Vector2(_target.x, Campaign.GROUND_Y))
	var ring := PackedVector2Array()
	var fill := PackedVector2Array()
	var progress := 0.0
	if _phase == Phase.FLIGHT and _flight_s > 0.0:
		progress = clampf(_phase_t / _flight_s, 0.0, 1.0)
	for i in range(32):
		var dir := Vector2.from_angle(TAU * i / 32.0)
		ring.append(c + Vector2(dir.x * DANGER_R, dir.y * DANGER_RY))
		fill.append(c + Vector2(dir.x * DANGER_R, dir.y * DANGER_RY) * progress)
	ring.append(ring[0])
	draw_colored_polygon(ring, Color(UiTokens.DANGER, 0.18))
	if progress > 0.05:
		draw_colored_polygon(fill, Color(UiTokens.DANGER, 0.45))
	draw_polyline(ring, col, 3.0)
	var y := 0.0
	while y < 120.0:
		draw_line(c - Vector2(0, y), c - Vector2(0, minf(y + 10.0, 120.0)), col, 3.0)
		y += 20.0

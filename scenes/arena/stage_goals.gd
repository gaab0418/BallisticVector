class_name StageGoals
extends RefCounted
## Acompanha os desafios das estrelas de uma fase, a partir de eventos que a
## arena informa (tiro, acerto, dano, movimento, engrenagem girada).
##
## A primeira estrela e sempre vencer; as outras duas vem de Campaign. Estado
## ao vivo de cada desafio:
##   PENDING -- ainda da para cumprir
##   DONE    -- cumprido
##   FAILED  -- perdido nesta tentativa (ex.: passou do limite de tiros)

enum State { PENDING, DONE, FAILED }

signal changed

var goals: Array = []
var states: Array = []
var shots := 0

var _first_angle := NAN
var _low_twin := false
var _high_twin := false
var _popped_rising := false
var _popped_falling := false
var _drone_rising := false
var _drone_falling := false


func setup(goal_list: Array) -> void:
	goals = goal_list.duplicate(true)
	states.clear()
	for g in goals:
		states.append(State.PENDING)


func on_fire(angle_deg: float) -> void:
	shots += 1
	if is_nan(_first_angle):
		_first_angle = angle_deg
	for i in range(goals.size()):
		var g: Dictionary = goals[i]
		match g.type:
			"max_shots":
				if shots > int(g.value):
					_mark(i, State.FAILED)
			"same_angle":
				if absf(angle_deg - _first_angle) > 0.75:
					_mark(i, State.FAILED)


## `vertex_y` = altura (m) do vertice daquele tiro (NAN se nao havia vertice).
func on_boss_hit(angle_deg: float, power: float, moved_m: float, vertex_y: float = NAN) -> void:
	for i in range(goals.size()):
		var g: Dictionary = goals[i]
		match g.type:
			"angle_hit":
				if angle_deg >= g.min and angle_deg <= g.max:
					_mark(i, State.DONE)
			"power_hit":
				if power <= g.max + 0.005:
					_mark(i, State.DONE)
			"move_hit":
				if moved_m >= g.value:
					_mark(i, State.DONE)
			"vertex_band":
				if not is_nan(vertex_y) and vertex_y >= g.min and vertex_y <= g.max:
					_mark(i, State.DONE)
			"twin_angles":
				if angle_deg < 45.0:
					_low_twin = true
				elif angle_deg > 45.0:
					_high_twin = true
				if _low_twin and _high_twin:
					_mark(i, State.DONE)


## `dist_m` = distancia entre o ponto do acerto e o vertice daquele tiro.
func on_plane_hit(dist_m: float) -> void:
	for i in range(goals.size()):
		var g: Dictionary = goals[i]
		if g.type == "vertex_hit" and dist_m <= g.value:
			_mark(i, State.DONE)


## Balao estourado: `rising` = a bala ainda subia (antes do vertice).
func on_balloon_hit(rising: bool) -> void:
	if rising:
		_popped_rising = true
	else:
		_popped_falling = true
	for i in range(goals.size()):
		if goals[i].type == "up_down" and _popped_rising and _popped_falling:
			_mark(i, State.DONE)


## Drone derrubado: `rising` = a bala ainda subia (primeiro encontro com a reta).
func on_drone_hit(rising: bool) -> void:
	if rising:
		_drone_rising = true
	else:
		_drone_falling = true
	for i in range(goals.size()):
		match goals[i].type:
			"intercept_up":
				if rising:
					_mark(i, State.DONE)
			"intercept_both":
				if _drone_rising and _drone_falling:
					_mark(i, State.DONE)


## Um alvo foi acertado por uma bala que ja tinha quicado no gelo.
func on_bounce_hit() -> void:
	for i in range(goals.size()):
		if goals[i].type == "bounce_hit":
			_mark(i, State.DONE)


## A bala parou no chao em `x_m` (metros da regua).
func on_landed(x_m: float) -> void:
	for i in range(goals.size()):
		var g: Dictionary = goals[i]
		if g.type == "land_zone" and x_m >= g.min and x_m <= g.max:
			_mark(i, State.DONE)


func on_damage() -> void:
	_fail_type("no_damage")


func on_gravity_touched() -> void:
	_fail_type("keep_gravity")


## No fim da fase, o que so dependia de "nao errar" vira cumprido.
func finish() -> void:
	for i in range(goals.size()):
		if states[i] != State.PENDING:
			continue
		match goals[i].type:
			"max_shots", "no_damage", "keep_gravity", "same_angle":
				states[i] = State.DONE
			_:
				states[i] = State.FAILED
	changed.emit()


## Estrelas ganhas: 1 por vencer + 1 por desafio cumprido.
func stars() -> int:
	var n := 1
	for s in states:
		if s == State.DONE:
			n += 1
	return n


## Texto do contador ao lado de "Vença com até N tiros".
func progress_text(i: int) -> String:
	var g: Dictionary = goals[i]
	if g.type == "max_shots":
		return "%d/%d" % [shots, int(g.value)]
	return ""


func _fail_type(type_name: String) -> void:
	for i in range(goals.size()):
		if goals[i].type == type_name:
			_mark(i, State.FAILED)


func _mark(i: int, state: int) -> void:
	if states[i] == state or states[i] == State.DONE:
		return
	states[i] = state
	changed.emit()

extends Node2D
## Duelo: dois tanques em lados opostos, um tiro por vez, sem avioes nem
## castelo. Vence quem zerar a blindagem do outro.
##
## Cada jogador ve a propria equacao: o eixo do jogador 2 e espelhado (o x dele
## cresce para a esquerda), entao os dois atiram "para a frente" com a mesma
## conta. A mira so mostra o comeco da curva; o resto e com os numeros (o
## alcance da equacao contra a distancia ate o outro tanque, escrita na regua).
##
## A montanha do meio e sorteada a cada partida e ganha crateras com os tiros.
## Contra a Ada, ela calcula o tiro com Ballistics e erra de proposito conforme
## a dificuldade.

const HULL_TEX := preload("res://assets/sprites/tank_hull.png")
const BARREL_TEX := preload("res://assets/sprites/tank_barrel.png")
const RockVisualScript = preload("res://scenes/arena/rock_visual.gd")
const BackdropScript = preload("res://scenes/arena/arena_backdrop.gd")
const TerrainScript = preload("res://scenes/arena/terrain.gd")

const W := 1280.0
const GROUND_Y := Campaign.GROUND_Y
## Munhao do jogador 1; o do jogador 2 e o espelho dele.
const PIVOT := Vector2(104, 602)
const SPEED_PX := 800.0
const GRAVITY_PX := 500.0
const MAX_HP := 100
const DIRECT_DMG := 34
const SPLASH_R := 90.0
const SPLASH_DMG := 22.0
const TANK_HIT_R := 38.0
const CRATER_R := 34.0
const TURN_TIME := 30.0
## A mira mostra so este pedaco (m) da curva: o resto o jogador calcula.
const AIM_PREVIEW_M := 4.0
const ANGLE_RATE := 30.0
const POWER_RATE := 0.35
## Erro de forca da Ada, por dificuldade (fracao para mais ou para menos).
const ADA_ERROR := {"easy": 0.12, "medium": 0.06, "hard": 0.025}

const SFX_FIRE := "res://assets/audio/cannon_fire.ogg"
const SFX_HIT := "res://assets/audio/cannon_hit_cannon.ogg"
const SFX_CLICK := "res://assets/audio/menu_click.ogg"

var players: Array = []
var turn := 0
var vs_ada := false
var ada_level := "medium"
var world: Dictionary = UiTokens.WORLD_EARTH

var _mountains: Array = []
var _bullet: Dictionary = {}
var _timer := TURN_TIME
var _waiting := false
var _over := false
var _font: Font
var _ada_think := 0.0
var _ada_target := Vector2.ZERO

var _hud: CanvasLayer
var _turn_label: Label
var _eq_label: Label
var _info_label: Label
var _timer_label: Label
var _bars: Array = []
var _end_panel: PanelContainer
var _end_title: Label
var _end_text: Label
var _fire_btn: Button


func _ready() -> void:
	randomize()
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	vs_ada = Global.duel_mode == "ada"
	ada_level = Global.duel_level
	world = [UiTokens.WORLD_EARTH, UiTokens.WORLD_ICE, UiTokens.WORLD_MARS].pick_random()
	var seed_value := randi()
	# Cenario abaixo do z 0: o _draw daqui (mira, regua, bala) fica por cima.
	var backdrop := Node2D.new()
	backdrop.set_script(BackdropScript)
	backdrop.z_index = -10
	add_child(backdrop)
	backdrop.setup(world, GROUND_Y, seed_value)
	_build_mountains()
	var terrain := Node2D.new()
	terrain.set_script(TerrainScript)
	terrain.z_index = -5
	add_child(terrain)
	terrain.setup(world, GROUND_Y, seed_value + 5)
	players = [
		_make_player(0, "Jogador 1", UiTokens.EDITABLE),
		_make_player(1, "Ada" if vs_ada else "Jogador 2", UiTokens.CALCULATED),
	]
	_build_hud()
	AudioManager.play_bgm("res://assets/audio/Battle.mp3")
	_start_turn()


# ═════════════════════════════════════════════════════════════════════
#  MONTAGEM
# ═════════════════════════════════════════════════════════════════════


func _build_mountains() -> void:
	var count := randi_range(1, 2)
	for i in range(count):
		var cx := (
			randf_range(520.0, 760.0) if count == 1 else (470.0 + i * 340.0 + randf_range(-40, 40))
		)
		var h := randf_range(150.0, 300.0)
		var half := randf_range(70.0, 110.0)
		var peaks := [
			Vector2(-half, 0),
			Vector2(-half * 0.2, -h),
			Vector2(half * 0.25, -h * 0.94),
			Vector2(half, 0)
		]
		var poly := PackedVector2Array()
		for p in Campaign.rounded(peaks):
			poly.append(Vector2(cx, 720.0) + p)
		var visual := Node2D.new()
		visual.set_script(RockVisualScript)
		visual.z_index = -6
		add_child(visual)
		_mountains.append({"poly": poly, "visual": visual})
		_redraw_mountain(_mountains.size() - 1)


## O mesmo desenho de rocha da arena, com o poligono entregue direto (aqui a
## colisao e so o poligono, sem corpo de fisica).
func _redraw_mountain(i: int) -> void:
	var m: Dictionary = _mountains[i]
	var visual: Node2D = m.visual
	visual.set("_poly", m.poly)
	visual.set("rock_colors", world.rock)
	visual.queue_redraw()


func _make_player(index: int, display_name: String, col: Color) -> Dictionary:
	var root := Node2D.new()
	root.z_index = 1
	root.position = Vector2(88, 607) if index == 0 else Vector2(W - 88, 607)
	if index == 1:
		root.scale = Vector2(-1, 1)
	add_child(root)
	var cannon := Node2D.new()
	cannon.position = Vector2(16, -5)
	root.add_child(cannon)
	var barrel := Sprite2D.new()
	barrel.texture = BARREL_TEX
	barrel.centered = false
	barrel.offset = Vector2(10, -21)
	barrel.scale = Vector2(0.25, 0.25)
	cannon.add_child(barrel)
	var body := Sprite2D.new()
	body.texture = HULL_TEX
	body.position = Vector2(0, 6)
	body.scale = Vector2(0.25, 0.25)
	root.add_child(body)
	if index == 0:
		Cosmetics.dress_tank([body, barrel])
	else:
		body.modulate = Color(0.75, 0.85, 1.15)
		barrel.modulate = body.modulate
	return {
		"name": display_name,
		"color": col,
		"root": root,
		"cannon": cannon,
		"body": body,
		"hp": MAX_HP,
		"angle": 45.0,
		"power": 0.7,
		"last": {},
	}


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))
	_hud.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -330
	top.offset_right = 330
	top.offset_top = 10
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", UiTokens.GAP)
	col.add_child(head)
	_turn_label = Label.new()
	_turn_label.theme_type_variation = &"TitleLabel"
	head.add_child(_turn_label)
	_timer_label = Label.new()
	_timer_label.theme_type_variation = &"CaptionLabel"
	head.add_child(_timer_label)
	_eq_label = Label.new()
	_eq_label.theme_type_variation = &"ResultLabel"
	_eq_label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_eq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_eq_label)
	_info_label = Label.new()
	_info_label.theme_type_variation = &"CaptionLabel"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_info_label)

	for i in range(2):
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))
		_hud.add_child(box)
		var v := VBoxContainer.new()
		box.add_child(v)
		var n := Label.new()
		n.text = players[i].name
		n.theme_type_variation = &"HeadingLabel"
		n.add_theme_color_override("font_color", players[i].color)
		v.add_child(n)
		var bar := UiStatBar.new()
		bar.setup("shield", Vector2(150, 22))
		v.add_child(bar)
		bar.set_value(MAX_HP, MAX_HP)
		_bars.append(bar)
		box.position = Vector2(14, 12) if i == 0 else Vector2(W - 240, 12)
		box.custom_minimum_size = Vector2(226, 0)

	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))
	_hud.add_child(foot)
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_left = -330
	foot.offset_right = 330
	foot.offset_top = -64
	foot.offset_bottom = -6
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	foot.add_child(row)
	row.add_child(_step_button("ângulo −", func(): _nudge(-1.0, 0.0)))
	row.add_child(_step_button("ângulo +", func(): _nudge(1.0, 0.0)))
	row.add_child(_step_button("força −", func(): _nudge(0.0, -0.02)))
	row.add_child(_step_button("força +", func(): _nudge(0.0, 0.02)))
	_fire_btn = UiButton.create("ATIRAR", UiButton.Kind.PRIMARY)
	_fire_btn.custom_minimum_size = Vector2(120, 40)
	_fire_btn.pressed.connect(_fire)
	row.add_child(_fire_btn)
	var keys := Label.new()
	keys.text = "↑↓ ângulo · ←→ força · Espaço atira"
	keys.theme_type_variation = &"CaptionLabel"
	keys.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	_hud.add_child(keys)
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.offset_left = -330
	keys.offset_right = 330
	keys.offset_top = -92
	keys.offset_bottom = -68
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var quit := UiButton.create("Sair", UiButton.Kind.SECONDARY)
	quit.custom_minimum_size = Vector2(90, 40)
	quit.pressed.connect(_to_menu)
	_hud.add_child(quit)
	quit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	quit.offset_left = 14
	quit.offset_top = -54
	quit.offset_right = 104
	quit.offset_bottom = -14

	_build_end_panel()


func _step_button(text: String, action: Callable) -> Button:
	var b := UiButton.create(text, UiButton.Kind.SECONDARY)
	b.custom_minimum_size = Vector2(98, 40)
	b.pressed.connect(action)
	return b


func _build_end_panel() -> void:
	var center := CenterContainer.new()
	_hud.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.MODAL))
	_end_panel.visible = false
	center.add_child(_end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTokens.GAP)
	_end_panel.add_child(v)
	_end_title = Label.new()
	_end_title.theme_type_variation = &"TitleLabel"
	_end_title.add_theme_font_size_override("font_size", UiTokens.FONT_TITLE)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)
	_end_text = Label.new()
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_text.custom_minimum_size = Vector2(440, 0)
	v.add_child(_end_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.GAP)
	v.add_child(row)
	var again := UiButton.create("REVANCHE", UiButton.Kind.PRIMARY, null, true)
	again.custom_minimum_size = Vector2(190, 52)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	row.add_child(again)
	var menu := UiButton.create("MENU", UiButton.Kind.SECONDARY, null, true)
	menu.custom_minimum_size = Vector2(150, 52)
	menu.pressed.connect(_to_menu)
	row.add_child(menu)


# ═════════════════════════════════════════════════════════════════════
#  TURNOS
# ═════════════════════════════════════════════════════════════════════


func _ada_turn() -> bool:
	return vs_ada and turn == 1


func _start_turn() -> void:
	_waiting = false
	_timer = TURN_TIME
	var p: Dictionary = players[turn]
	_turn_label.text = ("Vez da " if _ada_turn() else "Vez do ") + p.name
	_turn_label.add_theme_color_override("font_color", p.color)
	_fire_btn.disabled = _ada_turn()
	if _ada_turn():
		_ada_think = 1.4
		_ada_target = _ada_plan()
	_refresh()


func _process(delta: float) -> void:
	queue_redraw()
	if _over:
		return
	if not _bullet.is_empty():
		_step_bullet(delta)
		return
	if _waiting:
		return
	if _ada_turn():
		_ada_step(delta)
		return
	var dir_a := 0.0
	var dir_p := 0.0
	if Input.is_action_pressed("ui_up"):
		dir_a += 1.0
	if Input.is_action_pressed("ui_down"):
		dir_a -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir_p += 1.0
	if Input.is_action_pressed("ui_left"):
		dir_p -= 1.0
	var fine := 0.25 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	if dir_a != 0.0 or dir_p != 0.0:
		_nudge(dir_a * ANGLE_RATE * fine * delta, dir_p * POWER_RATE * fine * delta)
	if Input.is_action_just_pressed("ui_accept"):
		_fire()
	_timer -= delta
	_timer_label.text = "%d s" % ceili(maxf(_timer, 0.0))
	if _timer <= 0.0:
		var at := _to_screen(turn, PIVOT) + Vector2(-60 if turn == 1 else 0, -90)
		ArenaFx.float_text(self, at, "tempo esgotado!", UiTokens.DANGER)
		_end_turn()


func _nudge(d_angle: float, d_power: float) -> void:
	if _over or _waiting or not _bullet.is_empty() or _ada_turn():
		return
	var p: Dictionary = players[turn]
	p.angle = clampf(p.angle + d_angle, 5.0, 85.0)
	p.power = clampf(p.power + d_power, 0.2, 1.0)
	_refresh()


## Tiro no referencial do jogador: x para a frente, zero no munhao dele.
func _shot_of(i: int) -> Dictionary:
	var p: Dictionary = players[i]
	return Ballistics.shot(p.angle, SPEED_PX * p.power, GRAVITY_PX, PIVOT, PIVOT.x, GROUND_Y)


## Do referencial do jogador `i` para a tela (o 2 e espelhado).
func _to_screen(i: int, v: Vector2) -> Vector2:
	return v if i == 0 else Vector2(W - v.x, v.y)


func _enemy_distance_m(i: int) -> float:
	var other: Dictionary = players[1 - i]
	var ex: float = other.root.position.x
	var mine := absf(ex - (PIVOT.x if i == 0 else W - PIVOT.x))
	return Ballistics.to_m(mine)


func _refresh() -> void:
	var p: Dictionary = players[turn]
	var s := _shot_of(turn)
	_eq_label.text = (
		"y = %s %s %s"
		% [
			Ballistics.term(s.a, 3, "x²", true),
			Ballistics.term(s.b, 2, "x"),
			Ballistics.term(s.c, 2, "")
		]
	)
	var r := Ballistics.root(s)
	_info_label.text = (
		"ângulo %d° · força %d%% · alcance %s m · o outro tanque está a %s m"
		% [
			roundi(p.angle),
			roundi(p.power * 100.0),
			Ballistics.fmt(r),
			Ballistics.fmt(_enemy_distance_m(turn))
		]
	)
	for i in range(2):
		var cannon: Node2D = players[i].cannon
		cannon.rotation = -deg_to_rad(players[i].angle)


func _fire() -> void:
	if _over or _waiting or not _bullet.is_empty():
		return
	var p: Dictionary = players[turn]
	var s := _shot_of(turn)
	p.last = s
	var dir: Vector2 = Vector2.RIGHT.rotated(-deg_to_rad(p.angle)) * SPEED_PX * p.power
	if turn == 1:
		dir.x = -dir.x
	var start := _to_screen(turn, PIVOT)
	_bullet = {"pos": start, "vel": dir, "from": turn, "trail": PackedVector2Array([start])}
	AudioManager.play_sfx(SFX_FIRE)
	ArenaFx.spawn(self, start, ArenaFx.Kind.MUZZLE, dir.normalized())


func _step_bullet(delta: float) -> void:
	var b := _bullet
	var steps := 3
	for _k in range(steps):
		var dt := delta / steps
		b.vel.y += GRAVITY_PX * dt
		b.pos += b.vel * dt
		var pos: Vector2 = b.pos
		var trail: PackedVector2Array = b.trail
		trail.append(pos)
		b.trail = trail
		if pos.x < -40.0 or pos.x > W + 40.0 or pos.y > 760.0:
			ArenaFx.float_text(
				self, Vector2(clampf(pos.x, 60.0, W - 200.0), 300.0), "saiu do mapa!", UiTokens.TEXT
			)
			_land(pos, false)
			return
		var target: Dictionary = players[1 - int(b.from)]
		var tpos: Vector2 = target.root.position
		if pos.distance_to(tpos) < TANK_HIT_R:
			_damage(1 - int(b.from), DIRECT_DMG, pos)
			_land(pos, true)
			return
		for i in range(_mountains.size()):
			if Geometry2D.is_point_in_polygon(pos, _mountains[i].poly):
				_crater(i, pos)
				_land(pos, true)
				return
		if pos.y >= GROUND_Y:
			_land(Vector2(pos.x, GROUND_Y), true)
			return


## A bala parou: explosao com dano por proximidade (o tiro direto ja contou).
func _land(pos: Vector2, explode: bool) -> void:
	var from := int(_bullet.from)
	_bullet = {}
	if explode:
		AudioManager.play_sfx(SFX_HIT)
		ArenaFx.spawn(self, pos, ArenaFx.Kind.EXPLOSION)
		for i in range(2):
			var d: float = pos.distance_to(players[i].root.position)
			if d > TANK_HIT_R and d < SPLASH_R:
				_damage(i, roundi(SPLASH_DMG * (1.0 - d / SPLASH_R)), pos)
		if from == 0 or not vs_ada:
			var miss := Ballistics.to_m(absf(pos.x - players[1 - from].root.position.x))
			if miss > 1.0:
				ArenaFx.float_text(
					self,
					pos + Vector2(-80, -50),
					"a %s m do tanque" % Ballistics.fmt(miss),
					UiTokens.TEXT
				)
	_end_turn()


func _damage(i: int, amount: int, at: Vector2) -> void:
	if amount <= 0:
		return
	var p: Dictionary = players[i]
	p.hp = maxi(0, p.hp - amount)
	_bars[i].set_value(p.hp, MAX_HP)
	ArenaFx.flash_sprite(p.body)
	ArenaFx.float_text(self, at + Vector2(-20, -60), "−%d" % amount, UiTokens.DANGER)
	if p.hp <= 0:
		_finish(1 - i)


func _crater(i: int, at: Vector2) -> void:
	var circle := PackedVector2Array()
	for k in range(16):
		circle.append(at + Vector2.from_angle(TAU * k / 16.0) * CRATER_R)
	var pieces := Geometry2D.clip_polygons(_mountains[i].poly, circle)
	var best := PackedVector2Array()
	var best_area := 0.0
	# A bala para na borda, entao o circulo nunca fica todo dentro: nao ha
	# buraco, so pedacos; fica o maior.
	for piece in pieces:
		var area := _area(piece)
		if area > best_area:
			best_area = area
			best = piece
	_mountains[i].poly = best
	_redraw_mountain(i)


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in range(poly.size()):
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


func _end_turn() -> void:
	if _over:
		return
	_waiting = true
	await get_tree().create_timer(1.0).timeout
	if _over:
		return
	turn = 1 - turn
	_start_turn()


func _finish(winner: int) -> void:
	if _over:
		return
	_over = true
	var w: Dictionary = players[winner]
	_end_title.text = "%s venceu!" % w.name
	_end_title.add_theme_color_override("font_color", w.color)
	if vs_ada and winner == 0:
		Global.brass += 50
		Global.unlock_achievement("duel_win")
		Global.save_game()
		_end_text.text = "Você venceu a Ada! +50 de latão para a Oficina."
	elif vs_ada:
		_end_text.text = (
			"A Ada acertou a conta primeiro. "
			+ "Compare o alcance com a distância e tente de novo!"
		)
	else:
		_end_text.text = "Duelo decidido na parábola. Querem a revanche?"
	await get_tree().create_timer(1.0).timeout
	_end_panel.visible = true


func _to_menu() -> void:
	AudioManager.play_sfx(SFX_CLICK)
	get_tree().change_scene_to_file("res://scenes/menu_play/menu_play.tscn")


# ═════════════════════════════════════════════════════════════════════
#  ADA (adversaria)
# ═════════════════════════════════════════════════════════════════════


## Procura o tiro que cai no tanque do jogador sem bater na montanha e erra a
## forca de proposito, conforme a dificuldade. Devolve (angulo, forca).
func _ada_plan() -> Vector2:
	var goal := _enemy_distance_m(1)
	var best := Vector2(45.0, 0.7)
	var best_err := INF
	for a in range(20, 80, 2):
		for p100 in range(25, 101):
			var s := Ballistics.shot(
				a, SPEED_PX * p100 / 100.0, GRAVITY_PX, PIVOT, PIVOT.x, GROUND_Y
			)
			var r := Ballistics.root(s)
			if is_nan(r):
				continue
			var err := absf(r - goal)
			if err < best_err and _clear_path(s, r):
				best_err = err
				best = Vector2(a, p100 / 100.0)
	var miss: float = ADA_ERROR.get(ada_level, 0.06)
	best.y = clampf(best.y * (1.0 + randf_range(-miss, miss)), 0.2, 1.0)
	return best


func _clear_path(s: Dictionary, r: float) -> bool:
	var x: float = s.x_tank
	while x < r - 0.3:
		x += 0.2
		var p := _to_screen(1, Ballistics.point_px(s, x))
		for m in _mountains:
			if Geometry2D.is_point_in_polygon(p, m.poly):
				return false
	return true


## A Ada gira o canhao ate o tiro planejado antes de atirar, para a crianca ver.
func _ada_step(delta: float) -> void:
	var p: Dictionary = players[1]
	p.angle = move_toward(p.angle, _ada_target.x, 40.0 * delta)
	p.power = move_toward(p.power, _ada_target.y, 0.5 * delta)
	_refresh()
	_timer_label.text = "pensando..."
	_ada_think -= delta
	if (
		_ada_think <= 0.0
		and is_equal_approx(p.angle, _ada_target.x)
		and is_equal_approx(p.power, _ada_target.y)
	):
		_fire()


# ═════════════════════════════════════════════════════════════════════
#  DESENHO (mira curta, regua de distancia, rastro)
# ═════════════════════════════════════════════════════════════════════


func _draw() -> void:
	if not _over and _bullet.is_empty() and not _waiting:
		_draw_aim()
		_draw_distance()
	if not _bullet.is_empty():
		var trail: PackedVector2Array = _bullet.trail
		if trail.size() > 1:
			draw_polyline(trail, Color(players[int(_bullet.from)].color, 0.7), 2.0)
		draw_circle(_bullet.pos, 5.0, UiTokens.NIGHT_950, true, -1.0, false)
		draw_circle(_bullet.pos, 3.5, UiTokens.BRASS, true, -1.0, false)


func _draw_aim() -> void:
	var p: Dictionary = players[turn]
	var col: Color = p.color
	# O ultimo tiro deste jogador, apagado: ajuda a corrigir o proximo.
	var last: Dictionary = p.last
	if not last.is_empty():
		_poly_curve(last, Color(col, 0.22), 2.0, Ballistics.root(last))
	var s := _shot_of(turn)
	_poly_curve(s, col, 3.0, s.x_tank + AIM_PREVIEW_M)


func _poly_curve(s: Dictionary, col: Color, width: float, x_end: float) -> void:
	if is_nan(x_end):
		x_end = 30.0
	var pts := PackedVector2Array()
	var x: float = s.x_tank
	while x <= x_end:
		pts.append(_to_screen(turn, Ballistics.point_px(s, x)))
		x += 0.15
	if pts.size() > 1:
		draw_polyline(pts, col, width)


## Regua no chao, do munhao de quem joga ate o outro tanque, com a distancia.
func _draw_distance() -> void:
	var from := _to_screen(turn, PIVOT).x
	var to: float = players[1 - turn].root.position.x
	var y := GROUND_Y + 22.0
	draw_line(Vector2(from, y), Vector2(to, y), Color(UiTokens.TEXT, 0.5), 2.0)
	var step := Ballistics.to_px(1.0) * (1.0 if to > from else -1.0)
	var k := 0
	var x := from
	while (to - x) * signf(step) >= 0.0:
		var tall := k % 5 == 0
		draw_line(
			Vector2(x, y - (8.0 if tall else 4.0)), Vector2(x, y), Color(UiTokens.TEXT, 0.6), 1.0
		)
		x += step
		k += 1
	var text := "%s m" % Ballistics.fmt(_enemy_distance_m(turn))
	var at := Vector2((from + to) * 0.5 - 30.0, y + 26.0)
	draw_string_outline(
		_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_MD, 6, UiTokens.TEXT_OUTLINE
	)
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_MD, UiTokens.TEXT)

extends SceneTree
## Testes automaticos do Ballistic Vector, rodados pela CI.
##
##     BV_SAVE_PATH=/tmp/teste.cfg godot --headless --script res://tools/tests/test_runner.gd
##
## Verificam:
##   1. todo script do projeto compila;
##   2. todo obstaculo de toda fase e um poligono valido (colisao e desenho);
##   3. todo alvo de toda fase e atingivel (inclusive os chefes em cada posicao
##      e gravidade, os drones na rota e o balao do quique), e as metas de
##      vertice e de zona de pouso sao cumpriveis;
##   4. a bala real (projectile.gd) cai onde a HUD diz (Ballistics.root);
##   5. cada tela principal abre sem travar;
##   5b. os botoes do mapa e do menu abrem o que prometem (Loja, Oficina,
##      Caderno, ilhas, Duelo) e o Duelo aceita um tiro;
##   6. o progresso salvo volta igual ao carregar (e o kit de emergencia aparece).
## Sai com codigo 1 se qualquer teste falhar. BV_SAVE_PATH evita tocar no save
## de quem joga na mesma maquina.

const BOSS_R := 85.0
const SMALL_R := 35.0
## Tolerancia da queda real contra a raiz da HUD (a HUD mostra 0,1 m).
const LANDING_TOLERANCE_M := 0.2

var failures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_scripts_compile()
	_test_obstacles_valid()
	_test_stages_winnable()
	await _test_landing_matches_hud()
	await _test_scenes_open()
	await _test_buttons()
	_test_save_roundtrip()
	if failures.is_empty():
		print("TODOS OS TESTES PASSARAM")
		quit(0)
		return
	for f in failures:
		printerr("FALHA: ", f)
	quit(1)


func _fail(msg: String) -> void:
	failures.append(msg)


# ── 1. Compilacao ────────────────────────────────────────────────────


func _test_scripts_compile() -> void:
	for path in _walk("res://"):
		var script = load(path)
		if script == null:
			_fail("script nao carrega: " + path)
	print("ok: scripts compilam")


func _walk(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "addons":
			out += _walk(dir.path_join(d))
	return out


# ── 2. Poligonos ─────────────────────────────────────────────────────


func _test_obstacles_valid() -> void:
	for base_id in Campaign.BASES:
		var stages: Array = Campaign.BASES[base_id].stages
		for i in range(stages.size()):
			for o in stages[i].obstacles:
				if Geometry2D.triangulate_polygon(Campaign.rounded(o.poly)).is_empty():
					_fail("obstaculo invalido em %s/%d" % [base_id, i + 1])
	print("ok: obstaculos validos")


# ── 3. Fases venciveis ───────────────────────────────────────────────


func _test_stages_winnable() -> void:
	for base_id in Campaign.BASES:
		var stages: Array = Campaign.BASES[base_id].stages
		for i in range(stages.size()):
			_check_stage("%s/%d" % [base_id, i + 1], stages[i])
	print("ok: fases verificadas")


func _check_stage(label: String, st: Dictionary) -> void:
	var polys := []
	for o in st.obstacles:
		var gp := PackedVector2Array()
		for p in Campaign.rounded(o.poly):
			gp.append(o.pos + p)
		polys.append(gp)
	var band_goal := {}
	for goal in st.goals:
		if goal.type == "vertex_band":
			band_goal = goal
	var band_ok := band_goal.is_empty()
	for t in _targets(st):
		var hits := _count_hits(t.get("stage", st), polys, t, band_goal)
		if hits.x == 0:
			_fail("%s: %s inalcancavel" % [label, t.name])
		if hits.y > 0:
			band_ok = true
	if not band_ok:
		_fail("%s: meta de vertice impossivel" % label)
	for goal in st.goals:
		if goal.type == "land_zone" and not _zone_reachable(st, polys, goal):
			_fail("%s: zona de pouso impossivel" % label)


func _targets(st: Dictionary) -> Array:
	var out := []
	if st.get("boss_x", 1100.0) >= 0.0:
		var chief: Dictionary = st.get("chief", {})
		var xs: Array = [st.boss_x]
		match chief.get("kind", ""):
			"moving":
				xs = [chief.zone.x, chief.zone.y]
			"hopping":
				xs = chief.spots
		var steep: float = (
			chief.get("min_descent", -90.0) if chief.get("kind", "") == "shield" else -90.0
		)
		for x in xs:
			var bp := Vector2(x, Campaign.GROUND_Y + 4.0 - 86.0)
			var t := {
				"name": "castelo em x=%d" % x,
				"p": bp,
				"r": BOSS_R,
				"boss": true,
				"steep_deg": steep
			}
			out.append(t)
		if chief.get("kind", "") == "gravity":
			for g in chief.list:
				var alt := st.duplicate()
				alt.gravity = g
				var bp := Vector2(st.boss_x, Campaign.GROUND_Y + 4.0 - 86.0)
				out.append({"name": "castelo com g=%d" % g, "p": bp, "r": BOSS_R, "stage": alt})
	if st.has("route"):
		var pts := []
		for x in range(400, 1240, 40):
			var xm := Ballistics.to_m(x - Campaign.ORIGIN_X)
			pts.append(
				Vector2(x, Campaign.GROUND_Y - Ballistics.to_px(st.route.x * xm + st.route.y))
			)
		out.append({"name": "drone na rota", "pts": pts, "r": SMALL_R})
	for b in st.get("balloons", []):
		var p := Vector2(b.x, Campaign.GROUND_Y - Ballistics.to_px(b.y))
		out.append({"name": "balao", "p": p, "r": SMALL_R})
	for x in st.get("bunkers", []):
		var p := Vector2(x, Campaign.GROUND_Y - 14.0)
		out.append({"name": "bunker", "p": p, "r": SMALL_R, "steep_deg": 40.0})
	return out


## Algum tiro (direto) cai dentro do intervalo, sem bater antes.
func _zone_reachable(st: Dictionary, polys: Array, goal: Dictionary) -> bool:
	for s in _shots(st):
		var r := Ballistics.root(s)
		if is_nan(r) or r < goal.min or r > goal.max:
			continue
		var clear := true
		var x: float = s.x_tank
		while x < r and clear:
			x += 0.1
			for poly in polys:
				if Geometry2D.is_point_in_polygon(Ballistics.point_px(s, x), poly):
					clear = false
		if clear:
			return true
	return false


## Todos os tiros que a crianca consegue dar na fase (forca travada = uma so).
func _shots(st: Dictionary) -> Array:
	var out := []
	var zone: Vector2 = st.get("move_zone", Vector2(104, 104))
	var th: float = st.get("tank_height", 0.0)
	var powers := range(5, 101, 4)
	if st.has("power_lock"):
		powers = [roundi(st.power_lock * 100.0)]
	for ammo in [[800.0, 500.0], [900.0, 300.0]]:
		var g: float = st.get("gravity", ammo[1])
		var x := zone.x
		while x <= zone.y:
			var pivot := Vector2(x, 602.0 - Ballistics.to_px(th))
			for a10 in range(-690, 690, 20):
				for p100 in powers:
					var speed: float = ammo[0] * p100 / 100.0
					out.append(
						Ballistics.shot(
							a10 / 10.0, speed, g, pivot, Campaign.ORIGIN_X, Campaign.GROUND_Y
						)
					)
			x += 30.0
	return out


## x = tiros que acertam o alvo; y = tiros que acertam o castelo cumprindo a
## meta de vertice (se houver).
func _count_hits(st: Dictionary, polys: Array, t: Dictionary, band_goal: Dictionary) -> Vector2i:
	var found := Vector2i.ZERO
	var e: float = st.get("bounce", 0.0)
	for s in _shots(st):
		var hit := _hits(s, polys, t)
		# No gelo vale tambem acertar depois do quique.
		if not hit and e > 0.0 and _clear_until_root(s, polys):
			var s2 := Ballistics.bounce(s, e)
			hit = not s2.is_empty() and _hits(s2, polys, t)
		if not hit:
			continue
		found.x += 1
		if t.get("boss", false) and not band_goal.is_empty() and Ballistics.has_arc(s):
			var vy := Ballistics.vertex(s).y
			if vy >= band_goal.min and vy <= band_goal.max:
				found.y += 1
	return found


func _clear_until_root(s: Dictionary, polys: Array) -> bool:
	var r := Ballistics.root(s)
	if is_nan(r) or Ballistics.point_px(s, r).x > 1300.0:
		return false
	var x: float = s.x_tank
	while x < r - 0.1:
		x += 0.1
		for poly in polys:
			if Geometry2D.is_point_in_polygon(Ballistics.point_px(s, x), poly):
				return false
	return true


func _hits(s: Dictionary, polys: Array, t: Dictionary) -> bool:
	var x: float = s.x_tank
	var prev := Ballistics.point_px(s, x)
	var pts: Array = t.get("pts", [t.get("p", Vector2.INF)])
	while x < 30.0:
		x += 0.08
		var p := Ballistics.point_px(s, x)
		if p.y > Campaign.GROUND_Y + 2.0 or p.y < -80.0 or p.x > 1300.0:
			return false
		for tp in pts:
			if p.distance_to(tp) < t.r:
				var d := p - prev
				return rad_to_deg(atan2(d.y, absf(d.x))) >= t.get("steep_deg", -90.0)
		for poly in polys:
			if Geometry2D.is_point_in_polygon(p, poly):
				return false
		prev = p
	return false


# ── 4. Queda real contra a HUD ───────────────────────────────────────


func _test_landing_matches_hud() -> void:
	# Caminhos livres: a bala cai no chao, sem montanha no meio.
	for c in [["Base_C", 1, 45.0, 0.5], ["Base_A", 0, 60.0, 0.3]]:
		var err: float = await _landing_error(c[0], c[1], c[2], c[3])
		if absf(err) > LANDING_TOLERANCE_M:
			_fail("queda real a %.2f m da HUD em %s/%d" % [err, c[0], c[1] + 1])
	print("ok: queda real confere com a HUD")


func _landing_error(base_id: String, stage: int, angle: float, power: float) -> float:
	var g = root.get_node("Global")
	g.lab_mode = false
	g.current_base_id = base_id
	g.current_stage = stage
	g.ammo_inventory = {"Enferrujada": 25, "Perfurante": 10}
	g.tutorial_done = true
	change_scene_to_file("res://scenes/arena/arena.tscn")
	for _i in range(10):
		await process_frame
	var a = current_scene
	# A abertura da Ada pausa o jogo: sem fechar, a bala nao sai do lugar.
	if a.coach.ada.is_talking():
		a.coach.ada._finish()
	await create_timer(0.1).timeout
	for e in a.active_enemies.duplicate():
		if not e.has_meta("is_boss"):
			a.active_enemies.erase(e)
			e.queue_free()
	# Perfurante: desvio de mira minimo.
	a.current_ammo_index = 1
	a.gravity_override = a._stage_gravity()
	a.cannon.rotation = -deg_to_rad(angle)
	a.current_power = power
	var hud_root := Ballistics.root(a.current_shot())
	a._fire_projectile()
	var proj: Node2D = null
	for ch in a.get_children():
		if ch.get_script() == a.ProjectileScript:
			proj = ch
	var last := Vector2.ZERO
	var t := 0.0
	while is_instance_valid(proj) and t < 8.0:
		last = proj.position
		await process_frame
		t += 1.0 / 60.0
	return Ballistics.to_m(last.x - Campaign.ORIGIN_X) - hud_root


# ── 5. Telas abrem ───────────────────────────────────────────────────


func _test_scenes_open() -> void:
	var g = root.get_node("Global")
	for path in [
		"res://scenes/menu_play/menu_play.tscn",
		"res://scenes/war_map/war_map.tscn",
		"res://scenes/victory/victory.tscn",
		"res://scenes/game_over/game_over.tscn",
		"res://scenes/duel/duel.tscn",
	]:
		change_scene_to_file(path)
		await create_timer(0.3).timeout
		if current_scene == null:
			_fail("tela nao abriu: " + path)
	for base_id in Campaign.BASES:
		g.current_base_id = base_id
		g.current_stage = 0
		change_scene_to_file("res://scenes/arena/arena.tscn")
		await create_timer(0.3).timeout
		if current_scene == null or current_scene.get("hud") == null:
			_fail("arena nao abriu: " + base_id)
	g.lab_mode = true
	change_scene_to_file("res://scenes/arena/arena.tscn")
	await create_timer(0.3).timeout
	if current_scene == null or current_scene.get("lab") == null:
		_fail("laboratorio nao abriu")
	g.lab_mode = false
	print("ok: telas abrem")


# ── 5b. Botoes ───────────────────────────────────────────────────────


func _open_modals(scene: Node) -> int:
	var n := 0
	for c in scene.get_children():
		if c is CanvasLayer and c.get("window") != null and c.visible:
			n += 1
	return n


func _close_modals(scene: Node) -> void:
	for c in scene.get_children():
		if c is CanvasLayer and c.get("window") != null and c.visible:
			c.close()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


## Dispara o `pressed` de cada botao, como um clique: um botao ligado a algo que
## ainda nao existe (ou que da erro) deixa de abrir a janela e o teste acusa.
func _test_buttons() -> void:
	var g = root.get_node("Global")
	g.reset_progress()
	g.tutorial_done = true
	g.map_intro_done = true
	# A abertura da Ada no teste das arenas deixa a arvore pausada.
	paused = false
	change_scene_to_file("res://scenes/war_map/war_map.tscn")
	await _frames(20)
	var map := current_scene
	for btn_name in ["ShopButton", "WorkshopButton", "NotebookButton"]:
		var b: Button = map.get_node_or_null(btn_name)
		if b == null:
			_fail("mapa sem o botao " + btn_name)
			continue
		b.pressed.emit()
		await _frames(5)
		if _open_modals(map) == 0:
			_fail("o botao %s do mapa nao abriu a janela" % btn_name)
		_close_modals(map)
		await _frames(3)
	map.get_node("NotebookButton").pressed.emit()
	await _frames(3)
	var nb = map.notebook
	var before: String = nb._counter.text
	nb._next.pressed.emit()
	await create_timer(0.5).timeout
	if nb._counter.text == before:
		_fail("o caderno nao virou a pagina")
	nb._badge_btn.button_pressed = true
	await _frames(3)
	if not nb._badges.visible:
		_fail("os selos do caderno nao abriram")
	nb.close()
	var page: int = map._table.current_page()
	map._next_page_btn.pressed.emit()
	await create_timer(0.9).timeout
	if map._table.current_page() != page + 1:
		_fail("o botao de rota nao levou para a proxima tela do mapa")

	map._markers["Base_A"].pressed.emit()
	await _frames(5)
	if not map.attack_modal.visible:
		_fail("clicar na Base Alpha nao abriu a escolha de fase")
	map._on_cancel_popup()
	change_scene_to_file("res://scenes/menu_play/menu_play.tscn")
	await _frames(20)
	var menu := current_scene
	var duel_btn: Button = menu._buttons[7]
	duel_btn.pressed.emit()
	await _frames(5)
	var opened := false
	for c in menu.find_children("*", "CanvasLayer", true, false):
		if c.get("window") != null and c.visible:
			opened = true
	if not opened:
		_fail("o botao DUELO do menu nao abriu a escolha")
	menu._start_duel("ada", "easy")
	await _frames(20)
	var duel := current_scene
	if duel == null or duel.get("players") == null:
		_fail("o duelo nao abriu")
	else:
		duel._fire()
		await create_timer(0.3).timeout
		if duel._bullet.is_empty() and not duel._waiting:
			_fail("o duelo nao disparou")
	g.reset_progress()
	print("ok: botoes do mapa, do menu e do duelo")


# ── 6. Salvar e carregar ─────────────────────────────────────────────


func _test_save_roundtrip() -> void:
	var g = root.get_node("Global")
	g.reset_progress()
	g.money = 321
	g.record_stars("Base_B", 1, 2)
	g.update_base_cleared("Base_B", 2)
	g.money = 0
	g.bases["Base_B"]["stars"] = [0, 0, 0]
	g.load_game()
	if g.money != 321 or g.bases["Base_B"]["stars"][1] != 2:
		_fail("o save nao voltou igual (ouro %d)" % g.money)
	if g.bases["Base_B"]["stages_cleared"] != 2:
		_fail("fases vencidas nao voltaram do save")
	g.money = 0
	g.ammo_inventory = {"Enferrujada": 0, "Perfurante": 0}
	if not g.grant_emergency_ammo() or g.total_ammo() <= 0:
		_fail("kit de emergencia nao apareceu sem municao e sem ouro")
	g.reset_progress()
	print("ok: salvar, carregar e kit de emergencia")

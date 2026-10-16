extends SceneTree
## Testes automaticos do Ballistic Vector, rodados pela CI.
##
##     BV_SAVE_PATH=/tmp/teste.cfg godot --headless --script res://tools/tests/test_runner.gd
##
## Protegem as garantias pedagogicas do jogo, nao so "o codigo compila":
##   1. todo script do projeto compila;
##   2. todo obstaculo de toda fase e um poligono valido (colisao e desenho);
##   3. todo alvo de toda fase e atingivel, e as metas de vertice sao cumpriveis;
##   4. a bala real (projectile.gd) cai onde a HUD diz (Ballistics.root);
##   5. cada tela principal abre sem travar;
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
		var hits := _count_hits(st, polys, t, band_goal)
		if hits.x == 0:
			_fail("%s: %s inalcancavel" % [label, t.name])
		if hits.y > 0:
			band_ok = true
	if not band_ok:
		_fail("%s: meta de vertice impossivel" % label)


func _targets(st: Dictionary) -> Array:
	var out := []
	if st.get("boss_x", 1100.0) >= 0.0:
		var bp := Vector2(st.boss_x, Campaign.GROUND_Y + 4.0 - 86.0)
		out.append({"name": "castelo", "p": bp, "r": BOSS_R, "boss": true})
	for b in st.get("balloons", []):
		var p := Vector2(b.x, Campaign.GROUND_Y - Ballistics.to_px(b.y))
		out.append({"name": "balao", "p": p, "r": SMALL_R})
	for x in st.get("bunkers", []):
		var p := Vector2(x, Campaign.GROUND_Y - 14.0)
		out.append({"name": "bunker", "p": p, "r": SMALL_R, "steep": true})
	return out


## x = tiros que acertam o alvo; y = tiros que acertam o castelo cumprindo a
## meta de vertice (se houver).
func _count_hits(st: Dictionary, polys: Array, t: Dictionary, band_goal: Dictionary) -> Vector2i:
	var found := Vector2i.ZERO
	var zone: Vector2 = st.get("move_zone", Vector2(104, 104))
	var th: float = st.get("tank_height", 0.0)
	for ammo in [[800.0, 500.0], [900.0, 300.0]]:
		var g: float = st.get("gravity", ammo[1])
		var x := zone.x
		while x <= zone.y:
			var pivot := Vector2(x, 602.0 - Ballistics.to_px(th))
			for a10 in range(-690, 690, 20):
				for p100 in range(5, 101, 4):
					var speed: float = ammo[0] * p100 / 100.0
					var s := Ballistics.shot(
						a10 / 10.0, speed, g, pivot, Campaign.ORIGIN_X, Campaign.GROUND_Y
					)
					if not _hits(s, polys, t):
						continue
					found.x += 1
					if t.get("boss", false) and not band_goal.is_empty() and Ballistics.has_arc(s):
						var vy := Ballistics.vertex(s).y
						if vy >= band_goal.min and vy <= band_goal.max:
							found.y += 1
			x += 30.0
	return found


func _hits(s: Dictionary, polys: Array, t: Dictionary) -> bool:
	var x: float = s.x_tank
	var prev := Ballistics.point_px(s, x)
	while x < 30.0:
		x += 0.08
		var p := Ballistics.point_px(s, x)
		if p.y > Campaign.GROUND_Y + 2.0 or p.y < -80.0 or p.x > 1300.0:
			return false
		if p.distance_to(t.p) < t.r:
			if not t.get("steep", false):
				return true
			var d := p - prev
			return rad_to_deg(atan2(d.y, absf(d.x))) >= 40.0
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
	change_scene_to_file("res://scenes/arena/arena.tscn")
	for _i in range(10):
		await process_frame
	var a = current_scene
	a.briefing.close()
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

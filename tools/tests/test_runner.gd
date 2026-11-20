# gdlint: disable=max-file-lines
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
##   6. o progresso salvo volta igual ao carregar (e o kit de emergencia aparece);
##   7. as falas da Ada: abertura curta da fase, dica no 1o limiar de erros,
##      missoes na estrela e tom dos textos (sem "!" nem diminutivo gratuito);
##   8. o morteiro avisado dos chefes que atiram: conta, justica (da para
##      desviar andando) e as regras de parada (pausa, chefe derrubado, vitoria).
## Sai com codigo 1 se qualquer teste falhar ou ocorrer SCRIPT ERROR. BV_SAVE_PATH
## evita tocar no save de quem joga na mesma maquina.

const BOSS_R := 85.0
const SMALL_R := 35.0
## Tolerancia da queda real contra a raiz da HUD (a HUD mostra 0,1 m).
const LANDING_TOLERANCE_M := 0.2

var failures: Array = []
var _script_errors := ScriptErrorLogger.new()


## Conta os erros de script (SCRIPT ERROR). Um erro de execucao so aborta a funcao
## de teste em curso e o runner seguia verde; avisos e o vazamento de objetos no
## encerramento nao sao do tipo script, entao nao entram na conta.
class ScriptErrorLogger:
	extends Logger
	var messages: Array = []

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array
	) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			messages.append(
				"%s (%s:%d): %s" % [function, file, line, rationale if rationale else code]
			)


## Carregado em _run(): o boss_brain usa o projectile, que usa o AudioManager, e
## um preload aqui compilaria antes de os autoloads existirem.
var boss_brain: GDScript


func _initialize() -> void:
	OS.add_logger(_script_errors)
	_run.call_deferred()


func _run() -> void:
	boss_brain = load("res://scenes/arena/boss_brain.gd")
	_test_scripts_compile()
	_test_obstacles_valid()
	_test_stages_winnable()
	_test_alpha_content()
	_test_shot_budget()
	await _test_landing_matches_hud()
	await _test_scenes_open()
	await _test_buttons()
	_test_save_roundtrip()
	_test_ada_intro()
	await _test_ada_in_arena()
	_test_text_tone()
	await _test_help_tone()
	await _test_qa_adversarial()
	_test_chief_volley_math()
	await _test_chief_volley_live()
	await _test_legibility()
	_test_onboarding_flags()
	_test_angle_hit_reachable()
	await _test_alpha1_without_old_tutorial()
	await _test_practice_arena()
	await _test_tutorial_modal()
	for msg in _script_errors.messages:
		_fail("erro de script durante os testes: " + msg)
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
	if st.has("tanks"):
		for x in [st.tanks.zone.x, st.tanks.zone.y]:
			out.append({"name": "tanque em x=%d" % x, "p": Vector2(x, 630.0), "r": SMALL_R})
	for b in st.get("balloons", []):
		var p := Vector2(b.x, Campaign.GROUND_Y - Ballistics.to_px(b.y))
		out.append({"name": "balao", "p": p, "r": SMALL_R})
	for x in st.get("bunkers", []):
		var p := Vector2(x, Campaign.GROUND_Y - 14.0)
		out.append({"name": "bunker", "p": p, "r": SMALL_R, "steep_deg": 40.0})
	return out


## T17: a Alpha 2 ganha um tanque inimigo e a Alpha 3 um balao, as duas com
## combustivel; a Alpha 1 fica como estava.
func _test_alpha_content() -> void:
	var a2 := Campaign.stage("Base_A", 1)
	var a3 := Campaign.stage("Base_A", 2)
	if a2.get("tanks", {}) != {"count": 1, "zone": Vector2(740, 880)}:
		_fail("T17: A2 sem o tanque inimigo em 740-880")
	if a3.get("balloons", []) != [Vector2(620, 4.0)]:
		_fail("T17: A3 sem o balao em (620; 4,0 m)")
	for st in [a2, a3]:
		if st.get("move_zone", Vector2.ZERO) != Vector2(40, 250) or st.get("fuel_m", 0.0) != 3.0:
			_fail("T17: %s sem combustivel 40-250 e 3 m" % st.title)
	var a2_shots := 0
	for goal in a2.goals:
		if goal.type == "max_shots":
			a2_shots = goal.value
	if a2_shots != 9:
		_fail("T17: A2 max_shots = %d, esperado 9" % a2_shots)
	var a1 := Campaign.stage("Base_A", 0)
	if a1.has("move_zone") or a1.has("fuel_m") or a1.has("tanks") or a1.has("balloons"):
		_fail("T17: a Alpha 1 devia ficar intacta")


## T19: o limite de tiros de toda fase cobre as vidas dos alvos (castelo, avioes,
## baloes, 2 por bunker, drones e 2 por tanque inimigo).
func _test_shot_budget() -> void:
	for base_id in Campaign.BASES:
		var stages: Array = Campaign.BASES[base_id].stages
		for i in range(stages.size()):
			var st: Dictionary = stages[i]
			for goal in st.goals:
				if goal.type != "max_shots":
					continue
				var lives: int = st.get("boss_hp", 3) + st.get("planes", 0)
				lives += st.get("balloons", []).size() + 2 * st.get("bunkers", []).size()
				lives += st.get("drones", 0) + 2 * st.get("tanks", {}).get("count", 0)
				if goal.value < lives:
					_fail(
						"T19: %s/%d max_shots %d < %d vidas" % [base_id, i + 1, goal.value, lives]
					)


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


## Todos os tiros que o jogador consegue dar na fase (forca travada = uma so).
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


# ── 7. Falas da Ada ──────────────────────────────────────────────────


## O script da Ada usa o autoload Global: so carrega depois que os autoloads
## existem (um preload no topo do runner nao compila).
func _coach_script() -> GDScript:
	return load("res://scenes/arena/ada_coach.gd")


## Todas as fases da campanha, como [rotulo, dados].
func _all_stages() -> Array:
	var out := []
	for base_id in Campaign.BASES:
		var stages: Array = Campaign.BASES[base_id].stages
		for i in range(stages.size()):
			out.append(["%s/%d" % [base_id, i + 1], stages[i]])
	return out


func _test_ada_intro() -> void:
	var chief_texts := []
	for entry in _all_stages():
		var label: String = entry[0]
		var st: Dictionary = entry[1]
		var lines: Array = _coach_script().intro_lines_for(st, "CAP")
		var expected := 2 if st.has("chief") else 1
		if lines.size() != expected:
			_fail("abertura de %s com %d falas (esperado %d)" % [label, lines.size(), expected])
			continue
		for l in lines:
			var text: String = l.text
			if text.strip_edges() == "":
				_fail("abertura de %s com fala vazia" % label)
			if (
				(st.tip != "" and st.tip in text)
				or "Dica" in text
				or "★" in text
				or "estrela" in text
				or l.get("caption", "") == "MISSÕES"
			):
				_fail("abertura de %s traz dica ou missoes: %s" % [label, text])
		if lines[0].text.length() > 100:
			_fail("1a fala de %s com %d caracteres" % [label, lines[0].text.length()])
		if st.has("chief"):
			chief_texts.append(lines[1].text)
			if lines[1].text.length() > 130:
				_fail("aviso de chefe de %s com %d caracteres" % [label, lines[1].text.length()])
			if not _coach_script().CHIEF_RULES.has(st.chief.kind):
				_fail("chefe %s sem regra em CHIEF_RULES (%s)" % [label, st.chief.kind])
	var first: Array = _coach_script().intro_lines_for(Campaign.BASES.Base_A.stages[1], "CAP")
	var want_first := [
		{
			"text": "Ângulos complementares, como 30° e 60°, levam a bala quase ao mesmo lugar.",
			"expr": "happy",
			"caption": "CAP",
		}
	]
	if first != want_first:
		_fail("abertura da A2 diferente do esperado: %s" % [first])
	var boss: Array = _coach_script().intro_lines_for(Campaign.BASES.Base_A.stages[2], "CAP")
	if boss.size() != 2:
		_fail("abertura da A3 sem o aviso de chefe")
	else:
		var want_rule := (
			"Fortaleza do Escudo: a cúpula que eu projetei só deixa passar bala caindo de cima. "
			+ "Suba bem o vértice."
		)
		if boss[1].text != want_rule or boss[1].caption != "CHEFE" or boss[1].expr != "surprised":
			_fail("aviso de chefe da A3 diferente do esperado: %s" % [boss[1]])
	_check_intro_edge_cases()
	print("ok: abertura curta da Ada")


func _check_intro_edge_cases() -> void:
	var castle := {"name": "Castelo X", "kind": "shield"}
	var odd := {"name": "Castelo X", "kind": "laser"}
	var fallback: String = _coach_script().CHIEF_FALLBACK
	# [nome, fase, textos esperados, comparacao, legenda esperada da 1a fala]
	var cases := [
		["licao vazia", {"lesson": ""}, [], "exato", ""],
		["licao so com espacos", {"lesson": "   "}, [], "exato", ""],
		["sem pontuacao", {"lesson": "Sem ponto final"}, ["Sem ponto final"], "exato", "CAP"],
		["duas frases", {"lesson": "Uma. Duas."}, ["Uma."], "exato", "CAP"],
		[
			"so chefe",
			{"lesson": "", "chief": castle},
			["Castelo X: a cúpula"],
			"comeca_com",
			"CHEFE"
		],
		[
			"chefe sem regra",
			{"lesson": "", "chief": odd},
			["Castelo X: " + fallback],
			"exato",
			"CHEFE"
		],
	]
	for c in cases:
		var lines: Array = _coach_script().intro_lines_for(c[1], "CAP")
		var want: Array = c[2]
		if lines.size() != want.size():
			_fail("abertura (%s) com %d falas (esperado %d)" % [c[0], lines.size(), want.size()])
			continue
		for i in range(want.size()):
			var text: String = lines[i].text
			var ok: bool = text.begins_with(want[i]) if c[3] == "comeca_com" else text == want[i]
			if not ok:
				_fail("abertura (%s): '%s'" % [c[0], text])
		if not lines.is_empty() and lines[0].caption != c[4]:
			_fail("abertura (%s) com legenda '%s'" % [c[0], lines[0].caption])


## Abre a arena da Base Alpha, fase 2 (indice 1), com a abertura da Ada fechada.
func _open_ada_arena() -> Node:
	var g = root.get_node("Global")
	g.lab_mode = false
	g.current_base_id = "Base_A"
	g.current_stage = 1
	g.ammo_inventory = {"Enferrujada": 25, "Perfurante": 10}
	g.tutorial_done = true
	change_scene_to_file("res://scenes/arena/arena.tscn")
	await _frames(10)
	var a = current_scene
	if a.coach.ada.is_talking():
		a.coach.ada._finish()
	a.coach.ada.hide_now()
	return a


func _test_ada_in_arena() -> void:
	var a = await _open_ada_arena()
	await _check_goals_in_star(a)
	await _check_tip_after_misses(a)
	await _check_no_bubble_without_lesson(a)
	await _check_tip_resets_in_new_arena()
	paused = false
	print("ok: falas da Ada na arena")


## T12: as missoes ficam no botao de estrela (3 linhas: castelo + 2 desafios).
func _check_goals_in_star(a: Node) -> void:
	a.hud.goals_pressed.emit()
	await _frames(3)
	if not a.briefing.visible:
		_fail("a estrela nao abriu o cartao de missoes")
	elif a.briefing._goals.get_child_count() != 3:
		_fail("cartao de missoes com %d linhas" % a.briefing._goals.get_child_count())
	a.briefing.close()
	await _frames(3)


## Tres erros seguidos: a Ada para de falar e pensa em voz alta.
func _miss_times(coach: Node, n: int, pos: Vector2, hit_obstacle: bool) -> void:
	for _i in range(n):
		coach.on_fire()
		coach.on_shot_ended(pos, hit_obstacle)


## T8 a T11: 1o limiar = tip da fase; depois, a dica do ultimo tiro.
func _check_tip_after_misses(a: Node) -> void:
	var coach = a.coach
	var short := Vector2(300, 652)
	var short_tip := "Faltou alcance. Aumente a força ou aproxime o ângulo de 45°."
	var stage_tip := "Acerte o castelo duas vezes: uma abaixo de 45° e outra acima."
	# T8: so no 3o erro, e e a tip da fase.
	_miss_times(coach, 2, short, false)
	if coach.ada.visible:
		_fail("a Ada falou antes do 3o erro seguido")
	_miss_times(coach, 1, short, false)
	if coach.ada._mode != "pop" or coach.ada._text.text != stage_tip:
		_fail("1o limiar sem a tip da fase: '%s'" % coach.ada._text.text)
	# T9: limiares seguintes usam a dica do tiro.
	coach.ada.hide_now()
	_miss_times(coach, 3, short, false)
	if coach.ada._text.text != short_tip:
		_fail("2o limiar sem a dica do tiro: '%s'" % coach.ada._text.text)
	coach.ada.hide_now()
	_miss_times(coach, 3, Vector2(560, 500), true)
	var mountain := "A montanha bloqueou o tiro. Suba o vértice: mais ângulo ou mais força."
	if coach.ada._text.text != mountain:
		_fail("3o limiar sem a dica da montanha: '%s'" % coach.ada._text.text)
	# T10: um acerto zera a sequencia.
	coach.ada.hide_now()
	_miss_times(coach, 2, short, false)
	coach.on_fire()
	coach.on_hit()
	coach.on_shot_ended(short, false)
	_miss_times(coach, 1, short, false)
	if coach.ada.visible:
		_fail("o acerto nao zerou a sequencia de erros")
	_miss_times(coach, 2, short, false)
	if coach.ada._mode != "pop":
		_fail("3 erros depois do acerto nao geraram dica")
	# T11: fase sem tip cai na dica do tiro, nunca em texto vazio.
	coach.ada.hide_now()
	a.stage_data = a.stage_data.duplicate()
	a.stage_data["tip"] = ""
	coach._stage_tip_given = false
	_miss_times(coach, 3, short, false)
	if coach.ada._text.text != short_tip:
		_fail("fase sem tip com texto inesperado: '%s'" % coach.ada._text.text)
	coach.ada.hide_now()


## T7: fase sem licao e sem chefe nao abre balao nem pausa o jogo a toa
## (`ada.say([])` pausaria e despausaria a arvore).
func _check_no_bubble_without_lesson(a: Node) -> void:
	# O fim da abertura despausa em diferido: espera antes de olhar a pausa.
	await _frames(3)
	paused = false
	a.stage_data = a.stage_data.duplicate()
	a.stage_data["lesson"] = ""
	a.coach.start_stage()
	if paused:
		_fail("fase sem licao chamou ada.say([]) e pausou o jogo")
	if a.coach.ada.visible or a.coach.ada._mode != "":
		_fail("fase sem licao abriu balao da Ada")
	await _frames(3)
	paused = false


## m4: `_stage_tip_given` reinicia numa arena nova (a tip vale de novo no 1o limiar).
func _check_tip_resets_in_new_arena() -> void:
	var stage_tip := "Acerte o castelo duas vezes: uma abaixo de 45° e outra acima."
	for round_n in range(2):
		var a = await _open_ada_arena()
		_miss_times(a.coach, 3, Vector2(300, 652), false)
		if a.coach.ada._text.text != stage_tip:
			_fail(
				(
					"arena nova %d sem a tip da fase no 1o limiar: '%s'"
					% [round_n, a.coach.ada._text.text]
				)
			)
		a.coach.ada.hide_now()
	paused = false


## Palavras que o publico (ensino medio) leria como infantis.
const TONE_BANNED := [
	"rapidinho",
	"pouquinho",
	"pertinho",
	"fraquinha",
	"fininha",
	"baixinho",
	"pontinhos",
	"setinha",
	"igualzinho",
	"instantinho",
	"devagarinho",
	"barquinho",
	"sorriso",
]


## Devolve o que quebra o tom em `text` ("" se estiver tudo certo).
func _tone_problem(text: String) -> String:
	if "!" in text:
		return "tem '!'"
	var low := text.to_lower()
	for w in TONE_BANNED:
		if w in low:
			return "tem '%s'" % w
	return ""


func _test_text_tone() -> void:
	var texts := {}
	for entry in _all_stages():
		texts[entry[0] + " lesson"] = entry[1].lesson
		texts[entry[0] + " tip"] = entry[1].tip
	var pages: Array = load("res://scripts/notebook.gd").PAGES
	for i in range(pages.size()):
		texts["caderno %d" % (i + 1)] = pages[i].text
	var rules: Dictionary = _coach_script().CHIEF_RULES
	for kind in rules:
		texts["chefe " + kind] = rules[kind]
	texts["chefe (fallback)"] = _coach_script().CHIEF_FALLBACK
	var says: Array = load("res://scripts/ui/stage_result.gd").ADA_SAYS
	for i in range(says.size()):
		texts["resultado %d" % (i + 1)] = says[i]
	for key in texts:
		var problem := _tone_problem(texts[key])
		if problem != "":
			_fail("tom em %s: %s (%s)" % [key, problem, texts[key]])
	print("ok: tom dos textos")


func _test_help_tone() -> void:
	var help: Node = load("res://scripts/help_overlay.gd").new()
	root.add_child(help)
	await _frames(1)
	for node in help.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			var problem := _tone_problem(node.text)
			if problem != "":
				_fail("tom na ajuda: %s (%s)" % [problem, node.text])
	help.queue_free()
	await _frames(1)
	print("ok: tom da ajuda")


# ═════════════════════════════════════════════════════════════════════
#  8. QA adversarial da task ada-tom
# ═════════════════════════════════════════════════════════════════════


func _test_qa_adversarial() -> void:
	_check_qa_intro_inputs()
	await _check_qa_alternating_misses()
	await _check_qa_reopen_stage()
	print("ok: QA adversarial da Ada")


## CA1/CA5: licoes estranhas e chefe sem regra nunca viram fala vazia nem passam de 2 falas.
func _check_qa_intro_inputs() -> void:
	var chief := {"name": "Boss", "kind": "inexistente"}
	var lessons := [
		"Espere... agora mire.", "...", "?", "Uma so frase sem ponto", "a" + "b".repeat(500)
	]
	for lesson in lessons:
		for with_chief in [false, true]:
			var st := {"lesson": lesson, "tip": "DICA-SECRETA"}
			if with_chief:
				st["chief"] = chief
			var lines: Array = _coach_script().intro_lines_for(st, "CAP")
			if lines.size() > (2 if with_chief else 1):
				_fail("QA: licao '%s' gerou %d falas" % [lesson.left(20), lines.size()])
			for l in lines:
				if String(l.text).strip_edges() == "" or "DICA-SECRETA" in l.text:
					_fail("QA: fala vazia ou com dica para licao '%s'" % lesson.left(20))
	var no_lesson_key: Array = _coach_script().intro_lines_for({}, "CAP")
	if not no_lesson_key.is_empty():
		_fail("QA: fase sem chaves gerou falas")
	var boss_only: Array = _coach_script().intro_lines_for({"chief": chief}, "CAP")
	if boss_only.size() != 1 or not boss_only[0].text.begins_with("Boss: "):
		_fail("QA: chefe sem licao e sem regra: %s" % [boss_only])


## CA2: erro, acerto, erro, ... nunca chega a 3 erros seguidos, entao a Ada fica calada.
func _check_qa_alternating_misses() -> void:
	var a = await _open_ada_arena()
	var short := Vector2(300, 652)
	for _i in range(6):
		a.coach.on_fire()
		a.coach.on_shot_ended(short, false)
		a.coach.on_fire()
		a.coach.on_hit()
		a.coach.on_shot_ended(short, false)
		a.coach.on_fire()
		a.coach.on_shot_ended(short, false)
	if a.coach.ada.visible:
		_fail("QA: erro/acerto/erro alternados dispararam dica")
	_miss_times(a.coach, 3, short, false)
	if a.coach.ada._mode != "pop":
		_fail("QA: 3 erros seguidos depois da alternancia sem dica")
	a.coach.ada.hide_now()
	paused = false


## CA1: reabrir a fase repete a mesma abertura curta, sem acumular falas.
func _check_qa_reopen_stage() -> void:
	var g = root.get_node("Global")
	for round_n in range(3):
		g.lab_mode = false
		g.current_base_id = "Base_B"
		g.current_stage = 2
		g.tutorial_done = true
		paused = false
		change_scene_to_file("res://scenes/arena/arena.tscn")
		await _frames(10)
		var coach = current_scene.coach
		var lines: Array = coach._intro_lines()
		if lines.size() > 2:
			_fail("QA: reabertura %d com %d falas" % [round_n, lines.size()])
		if not coach.ada.is_talking():
			_fail("QA: reabertura %d sem fala de abertura" % round_n)
		coach.ada._finish()
		coach.ada.hide_now()
	paused = false


# ── 8. Morteiro do chefe ─────────────────────────────────────────────

## Centro do tanque do jogador e boca do castelo (y global), como na arena.
const TANK_Y := 607.0
const MUZZLE_Y := 490.0
## Distancia em que a bala acerta o tanque (projectile.gd::HIT_RADIUS_PLAYER).
const PLAYER_HIT_R := 40.0
## Canhao 16 px a direita do centro do tanque (arena.tscn).
const CANNON_DX := 16.0


## Voa a bala como o projectile.gd (Euler semi-implicito) ate o chao.
func _simulate_lob(from: Vector2, to: Vector2, dt: float, polys: Array) -> Dictionary:
	var vel: Vector2 = boss_brain.lob_velocity(from, to)
	var pos := from
	var path := PackedVector2Array()
	var hit_mountain := false
	while pos.y < Campaign.GROUND_Y and pos.x > -50.0 and pos.x < 1350.0 and path.size() < 2000:
		vel.y += boss_brain.SHOT_GRAVITY * dt
		pos += vel * dt
		path.append(pos)
		for poly in polys:
			if Geometry2D.is_point_in_polygon(pos, poly):
				hit_mountain = true
	return {"path": path, "mountain": hit_mountain}


func _min_dist(path: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for q in path:
		best = minf(best, q.distance_to(p))
	return best


func _mountain_polys(st: Dictionary) -> Array:
	var polys := []
	for o in st.obstacles:
		var gp := PackedVector2Array()
		for p in Campaign.rounded(o.poly):
			gp.append(o.pos + p)
		polys.append(gp)
	return polys


## Fases cujo chefe atira: [[base, indice, fase]].
func _firing_stages() -> Array:
	var out := []
	for base_id in Campaign.BASES:
		var stages: Array = Campaign.BASES[base_id].stages
		for i in range(stages.size()):
			if stages[i].get("chief", {}).get("fires", false):
				out.append([base_id, i, Campaign.stage(base_id, i)])
	return out


func _chief_xs(chief: Dictionary) -> Array:
	if chief.kind == "hopping":
		return chief.spots
	var xs := []
	var x: float = chief.zone.x
	while x <= chief.zone.y:
		xs.append(x)
		x += 20.0
	return xs


func _test_chief_volley_math() -> void:
	var t: float = boss_brain.lob_time(MUZZLE_Y, TANK_Y)
	if absf(t - 3.250) > 0.005:
		_fail("T1: tempo de voo do morteiro %.3f s, esperado 3,250" % t)
	var v: Vector2 = boss_brain.lob_velocity(Vector2(1200, MUZZLE_Y), Vector2(24, TANK_Y))
	if v.distance_to(Vector2(-361.8, -451.7)) > 0.5:
		_fail("T2: velocidade de lancamento %s, esperado (-361.8, -451.7)" % str(v))
	var still := _simulate_lob(Vector2(1200, MUZZLE_Y), Vector2(24, TANK_Y), 1.0 / 60.0, [])
	var target := Vector2(24, TANK_Y)
	if _min_dist(still.path, target) >= PLAYER_HIT_R:
		_fail("T3: o tanque parado nao leva o tiro")
	for dx in [boss_brain.DANGER_R, 2.0 * boss_brain.DANGER_R]:
		if _min_dist(still.path, target + Vector2(dx, 0)) < PLAYER_HIT_R:
			_fail("T4: andar %d px para o lado nao salva" % int(dx))
	_test_volley_sweep()
	var wait: float = boss_brain.SHOT_WARN_S + t
	# Carregado na hora: preload da arena nao compila antes dos autoloads existirem.
	var move_speed: float = load("res://scenes/arena/arena.gd").MOVE_SPEED
	var need: float = 3.0 * boss_brain.DANGER_R / move_speed
	if wait < need:
		_fail("T6: aviso + voo %.2f s < %.2f s para sair do marcador" % [wait, need])
	_test_dodge_lock()
	_test_firing_data()
	_test_chief_fires_speech()
	if boss_brain.SHOT_WARN_S < 0.5 or boss_brain.SHOT_COOLDOWN_S <= 0.0:
		_fail("T24: aviso curto demais ou sem pausa entre tiros")
	print("ok: morteiro do chefe (conta, justica e dados)")


## T5: toda posicao do chefe contra toda posicao do tanque, a 60 e a 30 fps.
func _test_volley_sweep() -> void:
	var worst := {"60": INF, "30": INF}
	var checked := 0
	for entry in _firing_stages():
		var st: Dictionary = entry[2]
		var polys := _mountain_polys(st)
		var zone: Vector2 = st.move_zone
		for cx in _chief_xs(st.chief):
			var from := Vector2(cx, MUZZLE_Y)
			var cannon := zone.x
			while cannon <= zone.y:
				var to := Vector2(cannon - CANNON_DX, TANK_Y)
				for dt in [1.0 / 60.0, 1.0 / 30.0]:
					var key := "60" if dt < 0.02 else "30"
					var sim := _simulate_lob(from, to, dt, polys)
					var label := (
						"%s/%d chefe %d canhao %d %s fps"
						% [entry[0], entry[1] + 1, cx, cannon, key]
					)
					checked += 1
					if sim.mountain:
						_fail("T5: a bala bate na montanha (%s)" % label)
					if _min_dist(sim.path, to) >= PLAYER_HIT_R:
						_fail("T5: o tiro nao acerta o tanque parado (%s)" % label)
					for k in [1.0, 2.0]:
						for side in [-1.0, 1.0]:
							var off := Vector2(side * k * boss_brain.DANGER_R, 0)
							var d := _min_dist(sim.path, to + off)
							worst[key] = minf(worst[key], d - PLAYER_HIT_R)
							if d < PLAYER_HIT_R:
								_fail("T5: sair do marcador nao salva (%s, %d)" % [label, off.x])
				cannon += 10.0
	if checked == 0:
		_fail("T5: nenhuma fase com chefe que atira")
	print(
		(
			"ok: pior folga fora do marcador: %.1f px a 60 fps, %.1f px a 30 fps"
			% [worst["60"], worst["30"]]
		)
	)


func _test_dodge_lock() -> void:
	var one_dodge := Ballistics.to_m(boss_brain.DANGER_R)
	var cases := [
		[Vector2(40, 250), 40.0, 12.0, true],
		[Vector2(40, 250), 145.0, 1.0, false],
		[Vector2(40, 250), 145.0, one_dodge, true],
		[Vector2(1, 0), 104.0, INF, false],
		[Vector2(40, 150), 95.0, INF, false],
		[Vector2(40, 330), 330.0, INF, true],
	]
	for i in range(cases.size()):
		var c: Array = cases[i]
		var got: bool = boss_brain.dodge_ok(c[0], c[1], c[2], boss_brain.DANGER_R)
		if got != c[3]:
			_fail("T7: dodge_ok caso %d deu %s, esperado %s" % [i + 1, got, c[3]])


func _test_firing_data() -> void:
	var fires := []
	for base_id in Campaign.BASES:
		var stages: Array = Campaign.BASES[base_id].stages
		for i in range(stages.size()):
			var brain := Node2D.new()
			brain.set_script(boss_brain)
			brain.data = stages[i].get("chief", {})
			if brain.fires():
				fires.append("%s/%d" % [base_id, i + 1])
			brain.free()
	fires.sort()
	if fires != ["Base_B/3", "Base_D/3"]:
		_fail("T15: quem atira = %s, esperado Base_B/3 e Base_D/3" % str(fires))
	for entry in _firing_stages():
		var st: Dictionary = entry[2]
		var label := "%s/%d" % [entry[0], entry[1] + 1]
		if st.has("tank_height"):
			_fail("T8: %s tem plato, o desvio nao e garantido" % label)
		var zone: Vector2 = st.get("move_zone", Vector2(1, 0))
		if zone.y - zone.x < 2.0 * boss_brain.DANGER_R:
			_fail("T8: %s sem espaco para desviar" % label)
		if st.get("fuel_m", INF) < Ballistics.to_m(boss_brain.DANGER_R):
			_fail("T8: %s sem combustivel para um desvio" % label)
		if entry[0] == "Base_B" and (st.get("fuel_m", INF) != 12.0 or zone != Vector2(40, 250)):
			_fail("T8: a Bravo 3 devia ter 12 m e faixa 40-250")


## T21-T23: a Ada avisa que o chefe revida, so no chefe com `fires`.
func _test_chief_fires_speech() -> void:
	var coach := _coach_script()
	var suffix := " Ele revida: saia do marcador."
	for key in [["Base_B", 2], ["Base_D", 2]]:
		var lines: Array = coach.intro_lines_for(Campaign.BASES[key[0]].stages[key[1]], "CAP")
		var text: String = lines[1].text
		if not text.ends_with(suffix) or text.length() > 130 or text.contains("!"):
			_fail(
				"T21: fala do chefe %s sem o aviso ou fora do limite (%d)" % [key[0], text.length()]
			)
		if lines.size() != 2 or lines[1].caption != "CHEFE":
			_fail("T21: fala do chefe %s mudou de forma" % key[0])
	var no_fire: Array = [
		Campaign.BASES.Base_N.stages[2],
		Campaign.BASES.Base_A.stages[2],
		{"lesson": "", "chief": {"name": "Castelo X", "kind": "moving", "fires": false}},
	]
	for st in no_fire:
		for line in coach.intro_lines_for(st, "CAP"):
			if line.text.contains("revida"):
				_fail("T22: chefe sem fires revida na fala: %s" % line.text)
	if coach.CHIEF_FIRES_SUFFIX != "Ele revida: saia do marcador.":
		_fail("T23: texto do aviso mudou")
	for w in TONE_BANNED:
		if coach.CHIEF_FIRES_SUFFIX.to_lower().contains(w):
			_fail("T23: palavra banida no aviso: " + w)


# ── 8b. Morteiro ao vivo ─────────────────────────────────────────────


## Abre a arena, fecha a Ada, congela quem nao e o castelo e segura o ciclo
## automatico do chefe. Devolve a arena.
func _open_arena(base_id: String, stage: int) -> Node:
	var g = root.get_node("Global")
	g.lab_mode = false
	g.current_base_id = base_id
	g.current_stage = stage
	g.ammo_inventory = {"Enferrujada": 25, "Perfurante": 10}
	g.tutorial_done = true
	g.reset_armor()
	paused = false
	change_scene_to_file("res://scenes/arena/arena.tscn")
	for _i in range(10):
		await process_frame
	var a = current_scene
	if a.coach.ada.is_talking():
		a.coach.ada._finish()
	# _finish() despausa com set_deferred: espera o quadro para nao despausar depois.
	await process_frame
	paused = false
	for e in a.active_enemies:
		if not e.has_meta("is_boss"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	_brain(a)._wait = 999.0
	return a


func _boss(a: Node) -> Node2D:
	for e in a.active_enemies:
		if e.has_meta("is_boss"):
			return e
	return null


func _brain(a: Node) -> Node:
	return _boss(a).get_node("Brain")


func _chief_shots(a: Node) -> Array:
	var out := []
	for ch in a.get_children():
		if ch.has_meta("chief_shot") and not ch.is_queued_for_deletion():
			out.append(ch)
	return out


func _secs(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


## Espera a bala do chefe aparecer (ate `limit` s). Devolve-a ou null.
func _wait_shot(a: Node, limit: float) -> Node:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		var shots := _chief_shots(a)
		if not shots.is_empty():
			return shots[0]
		await process_frame
	return null


func _wait_no_shot(a: Node, limit: float) -> void:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end and not _chief_shots(a).is_empty():
		await process_frame
	await _frames(2)


func _goal_state(a: Node, type_name: String) -> int:
	for i in range(a.goals.goals.size()):
		if a.goals.goals[i].type == type_name:
			return a.goals.states[i]
	return -1


func _test_chief_volley_live() -> void:
	var g = root.get_node("Global")
	var phase = boss_brain.Phase

	# T9: o tanque parado leva o tiro.
	var a = await _open_arena("Base_B", 2)
	var brain := _brain(a)
	brain._begin_warning()
	if brain._phase != phase.WARN or brain._target != Vector2(88, TANK_Y):
		_fail("T9: aviso nao comecou no tanque (%s)" % str(brain._target))
	var shot := await _wait_shot(a, 1.8)
	if shot == null:
		_fail("T9: a bala nao saiu depois do aviso")
	else:
		if shot.damage != boss_brain.SHOT_DAMAGE or shot.bullet_color != UiTokens.ENEMY_SHOT:
			_fail("T9: bala com dano ou cor errados")
		if shot.has_meta("shot"):
			_fail("T9: a bala do chefe nao pode levar a meta shot do jogador")
		await _wait_no_shot(a, 5.0)
		if not is_equal_approx(g.player_armor, 90.0):
			_fail("T9: armadura %.1f, esperado 90" % g.player_armor)
		if _goal_state(a, "no_damage") != a.goals.State.FAILED:
			_fail("T9: a meta no_damage devia falhar")

	# T10: andar para fora do marcador salva.
	a = await _open_arena("Base_B", 2)
	_brain(a)._begin_warning()
	a.player.position.x += boss_brain.DANGER_R
	await _wait_shot(a, 1.8)
	await _wait_no_shot(a, 5.0)
	if not is_equal_approx(g.player_armor, 100.0):
		_fail("T10: levou dano mesmo desviando (%.1f)" % g.player_armor)

	# T11: a pausa congela a bala.
	a = await _open_arena("Base_B", 2)
	_brain(a)._begin_warning()
	shot = await _wait_shot(a, 1.8)
	if shot == null:
		_fail("T11: a bala nao saiu")
	else:
		var before: Vector2 = shot.position
		paused = true
		await _secs(0.5)
		if shot.position.distance_to(before) > 0.01 or _brain(a)._phase != phase.FLIGHT:
			_fail("T11: a bala andou com o jogo pausado")
		paused = false
		a.player.position.x += boss_brain.DANGER_R
		await _wait_no_shot(a, 5.0)
		if not is_equal_approx(g.player_armor, 100.0):
			_fail("T11: dano depois da pausa (%.1f)" % g.player_armor)

	# T12: chefe derrubado com outros inimigos vivos.
	a = await _open_arena("Base_B", 2)
	_brain(a)._begin_warning()
	await _wait_shot(a, 1.8)
	var boss := _boss(a)
	boss.set_meta("hp", 1)
	a.on_enemy_hit(boss, 1)
	await _frames(2)
	if not _chief_shots(a).is_empty():
		_fail("T12: a bala continuou depois de o chefe cair")
	await _secs(3.5)
	if not is_equal_approx(g.player_armor, 100.0) or a.stage_cleared:
		_fail("T12: dano ou vitoria depois de derrubar o chefe")

	# T13: fase vencida.
	a = await _open_arena("Base_B", 2)
	brain = _brain(a)
	brain._begin_warning()
	await _wait_shot(a, 1.8)
	a._on_stage_cleared()
	await _frames(2)
	if not _chief_shots(a).is_empty():
		_fail("T13: a bala do chefe sobreviveu a vitoria")
	a.on_player_hit(8)
	if not is_equal_approx(g.player_armor, 100.0):
		_fail("T13: dano depois da vitoria (%.1f)" % g.player_armor)
	for _i in range(900):
		brain._process(1.0 / 60.0)
	if not _chief_shots(a).is_empty() or brain._phase != phase.IDLE:
		_fail("T13: o chefe atirou depois da vitoria")

	# T14: o Iglu (moving sem fires) nao atira e continua andando.
	a = await _open_arena("Base_N", 2)
	brain = _brain(a)
	for _i in range(900):
		brain._process(1.0 / 60.0)
	var bx := _boss(a).position.x
	if not _chief_shots(a).is_empty() or brain._phase != phase.IDLE:
		_fail("T14: o Iglu atirou")
	if bx < 900.0 or bx > 975.0:
		_fail("T14: o Iglu saiu da faixa (%.0f)" % bx)

	# T16: ciclo automatico do hopping.
	a = await _open_arena("Base_D", 2)
	brain = _brain(a)
	brain._wait = boss_brain.SHOT_FIRST_DELAY_S
	for _i in range(185):
		brain._process(1.0 / 60.0)
	if brain._phase != phase.WARN or brain._target != a.player.global_position:
		_fail("T16: o primeiro aviso nao veio no tempo")
	for _i in range(62):
		brain._process(1.0 / 60.0)
	if _chief_shots(a).is_empty():
		_fail("T16: a bala nao saiu depois do aviso")

	# T17: a pausa durante o aviso segura a bala.
	a = await _open_arena("Base_B", 2)
	brain = _brain(a)
	brain._begin_warning()
	paused = true
	await _secs(1.5)
	if brain._phase != phase.WARN or not _chief_shots(a).is_empty():
		_fail(
			(
				"T17: o aviso andou com o jogo pausado (fase %d, balas %d)"
				% [brain._phase, _chief_shots(a).size()]
			)
		)
	paused = false

	# T18: sem combustivel o chefe segura o fogo.
	a = await _open_arena("Base_B", 2)
	brain = _brain(a)
	a.fuel_m = 0.5
	brain._begin_warning()
	await _frames(2)
	if brain._phase != phase.IDLE or not _chief_shots(a).is_empty():
		_fail("T18: o chefe atirou sem combustivel para desviar")

	# T20: sem tanque, sem aviso e sem erro.
	a = await _open_arena("Base_B", 2)
	brain = _brain(a)
	a.player.queue_free()
	await _frames(1)
	brain._begin_warning()
	if brain._phase != phase.IDLE or not _chief_shots(a).is_empty():
		_fail("T20: avisou sem jogador")
	g.reset_progress()
	g.reset_armor()
	print("ok: morteiro do chefe ao vivo")


# ── 9. Legibilidade e HUD ────────────────────────────────────────────


func _test_legibility() -> void:
	_test_theme_compiled_is_current()
	await _test_line_spacing_through_canvas_layer()
	_test_font_spacing_applied()
	await _test_hud_gears_and_formula()
	await _test_overflow()
	await _test_hud_icon_buttons_and_strip()
	await _test_help_diagram_labels_fit()
	print("ok: legibilidade e HUD")


## T1: o .tres carregado e o que UiTheme.build() montaria agora. Reprova se
## alguem mexer em UiTokens/UiTheme e esquecer de regenerar o tema.
func _test_theme_compiled_is_current() -> void:
	var built := UiTheme.build()
	var loaded := ThemeDB.get_project_theme()
	for type_name in built.get_type_list():
		for c in built.get_constant_list(type_name):
			var want := built.get_constant(c, type_name)
			var got := loaded.get_constant(c, type_name)
			if want != got:
				_fail("tema desatualizado: %s/%s = %d, esperado %d" % [type_name, c, got, want])
		for c in built.get_color_list(type_name):
			if built.get_color(c, type_name) != loaded.get_color(c, type_name):
				_fail("tema desatualizado: cor %s/%s" % [type_name, c])
		for c in built.get_font_size_list(type_name):
			if built.get_font_size(c, type_name) != loaded.get_font_size(c, type_name):
				_fail("tema desatualizado: corpo %s/%s" % [type_name, c])
	for pair in [["Label", "line_spacing"], ["TooltipLabel", "line_spacing"]]:
		if loaded.get_constant(pair[1], pair[0]) != UiTokens.LINE_SPACING:
			_fail("%s/%s do tema compilado nao e %d" % [pair[0], pair[1], UiTokens.LINE_SPACING])
	if loaded.get_constant("line_separation", "RichTextLabel") != UiTokens.LINE_SPACING:
		_fail("RichTextLabel/line_separation do tema compilado nao e %d" % UiTokens.LINE_SPACING)


## T2: a entrelinha chega a uma variacao de Label dentro de um CanvasLayer.
func _test_line_spacing_through_canvas_layer() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	label.theme_type_variation = &"InkLabel"
	layer.add_child(label)
	await _frames(2)
	var got := label.get_theme_constant("line_spacing")
	if got != UiTokens.LINE_SPACING:
		_fail(
			(
				"InkLabel em CanvasLayer com line_spacing %d, esperado %d"
				% [got, UiTokens.LINE_SPACING]
			)
		)
	layer.queue_free()


## T3: espaco entre palavras e entre letras de fato chegam a fonte.
func _test_font_spacing_applied() -> void:
	var base: Font = load(UiTokens.FONT_BODY_PATH)
	var fonts := {
		"body_font()": UiTheme.body_font(),
		"body_font(bold)": UiTheme.body_font(UiTokens.WEIGHT_BOLD),
		"fonte padrao do tema": ThemeDB.get_project_theme().default_font,
	}
	for label in fonts:
		var f: Font = fonts[label]
		var words := _text_w(f, "a b") - _text_w(base, "a b")
		# Piso fixo, independente do token: voltar a WORD_SPACING 0 tem que reprovar.
		if words < MIN_WORD_SPACING_PX:
			_fail(
				(
					"%s: 'a b' ficou %.1f px mais largo que a VT323 pura, minimo %d"
					% [label, words, MIN_WORD_SPACING_PX]
				)
			)
	var default_font := ThemeDB.get_project_theme().default_font
	if not (default_font is FontVariation) or default_font.spacing_space != UiTokens.WORD_SPACING:
		_fail(
			(
				"a fonte padrao do tema nao e FontVariation com spacing_space %d"
				% UiTokens.WORD_SPACING
			)
		)


const MIN_WORD_SPACING_PX := 4


func _text_w(font: Font, text_value: String) -> float:
	return font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x


## Abre a arena com a Ada fechada e o jogo despausado.
func _open_arena_hud(base_id: String, stage: int) -> Node:
	var g = root.get_node("Global")
	g.lab_mode = false
	g.current_base_id = base_id
	g.current_stage = stage
	g.ammo_inventory = {"Enferrujada": 25, "Perfurante": 10}
	g.tutorial_done = true
	paused = false
	change_scene_to_file("res://scenes/arena/arena.tscn")
	await _frames(10)
	var a := current_scene
	if a.coach.ada.is_talking():
		a.coach.ada._finish()
	await _frames(3)
	paused = false
	return a


func _hud_view(
	angle: float, power: float, speed_px: float, grav_px: float, effects: Array
) -> Dictionary:
	var pivot := Vector2(Campaign.ORIGIN_X + 100.0, 602.0)
	var s := Ballistics.shot(angle, speed_px, grav_px, pivot, Campaign.ORIGIN_X, Campaign.GROUND_Y)
	return {"angle_deg": angle, "power": power, "shot": s, "effects": effects}


func _on_screen(rect: Rect2) -> bool:
	return root.get_visible_rect().grow(1).encloses(rect)


## O HBoxContainer interno de um botao de icone cabe no botao (filho com
## FULL_RECT nao faz o botao crescer, o conteudo estoura sem aviso).
func _inner_fits(btn: Button) -> bool:
	for c in btn.get_children():
		if c is HBoxContainer:
			var need: Vector2 = c.get_combined_minimum_size()
			return need.x <= btn.size.x and need.y <= btn.size.y
	return false


func _test_hud_gears_and_formula() -> void:
	var a := await _open_arena_hud("Base_D", 0)
	var hud = a.hud
	var p = hud.parabola
	var abc := ["abc", "abc", "abc"]

	# T4: pior caso (69 graus, 100%, Jupiter, 3 chips por celula).
	p.set_state(_hud_view(69.0, 1.0, 900.0, 1240.0, abc))
	await _frames(5)
	var panel: Rect2 = p.get_global_rect()
	# As celulas pedem o que o valor mais largo (24,8 m/s2 em VT323 28) precisa, mais
	# que GEAR_WIDTH, e a HUD acomoda (CENTER_SHIFT). O que nao pode e uma celula
	# vazar do painel, ou o painel empurrar um vizinho.
	var neighbors := {
		"a insignia da fase": hud._badge,
		"o botao de pausa": hud._left_col,
		"a estrela e o placar": hud._right_row,
		"o botao do modo chute": hud.guess_btn,
	}
	for label in neighbors:
		var other: Control = neighbors[label]
		if other.visible and panel.intersects(other.get_global_rect()):
			_fail("T4: o painel da parabola cruza %s" % label)
		if other.visible and not _on_screen(other.get_global_rect()):
			_fail("T4: %s fica fora da tela" % label)
	if not _on_screen(panel):
		_fail("T4: o painel da parabola esta fora da tela")

	# T5: os resultados mais largos cabem em RESULT_WIDTH.
	var cases := [
		_hud_view(-30.0, 0.5, 800.0, 490.0, abc),
		_hud_view(45.0, 0.5, 800.0, Campaign.G_INVERTED, abc),
		_hud_view(45.0, 0.5, 900.0, 80.0, abc),
	]
	for view in cases:
		p.set_state(view)
		await _frames(3)
		for value in [p._height_value, p._range_value]:
			var need: float = value.get_parent().get_combined_minimum_size().x
			if need > p.RESULT_WIDTH:
				_fail(
					"T5: resultado '%s' pede %.1f px, cabe %d" % [value.text, need, p.RESULT_WIDTH]
				)

	# T9: icone no lugar do nome, com tooltip.
	p.set_state(_hud_view(45.0, 0.75, 800.0, 490.0, abc))
	await _frames(3)
	var icons := ["angle", "force", "planet"]
	var names := ["Ângulo", "Força", "Gravidade"]
	for i in range(3):
		var gear = p._gears[i]
		if gear.name_icon == null or gear.name_icon.icon != icons[i]:
			_fail("T9: celula %d sem o icone %s" % [i, icons[i]])
			continue
		if not gear.name_icon.tooltip_text.begins_with(names[i]):
			_fail("T9: tooltip da celula %d e '%s'" % [i, gear.name_icon.tooltip_text])
		if gear.name_icon.mouse_filter != Control.MOUSE_FILTER_PASS:
			_fail("T9: icone da celula %d precisa de MOUSE_FILTER_PASS para o tooltip" % i)
		for label in gear.find_children("*", "Label", true, false):
			var up: String = label.text.to_upper()
			var named: bool = (
				up.contains("ÂNGULO") or up.contains("FORÇA") or up.contains("GRAVIDADE")
			)
			if label.is_visible_in_tree() and named:
				_fail("T9: a celula %d ainda escreve o nome ('%s')" % [i, label.text])

	# T10: percentual da Forca ao lado do icone, nos limites.
	for pair in [[0.05, "5%"], [0.75, "75%"], [1.0, "100%"]]:
		p.set_state(_hud_view(45.0, pair[0], 800.0, 490.0, abc))
		await _frames(2)
		var force = p._gears[1]
		if force.detail == null or force.detail.text != pair[1] or not force.detail.visible:
			_fail("T10: detalhe da Forca com power %.2f nao e '%s'" % [pair[0], pair[1]])
	p.set_state(_hud_view(45.0, 0.75, 800.0, 490.0, abc))
	await _frames(2)
	if p._gears[1].name_icon.tooltip_text != "Força: 75%":
		_fail("T10: tooltip da Forca e '%s'" % p._gears[1].name_icon.tooltip_text)
	for i in [0, 2]:
		if p._gears[i].detail != null and p._gears[i].detail.visible:
			_fail("T10: a celula %d nao deveria ter detalhe visivel" % i)

	# T11: bandeja de chips separada do icone.
	var angle_gear = p._gears[0]
	var effect_cases := [
		["ab", [true, true, false]], ["a", [true, false, false]], ["abc", [true, true, true]]
	]
	for case in effect_cases:
		angle_gear.set_effects(case[0])
		await _frames(3)
		var seen := []
		for chip in angle_gear._chips:
			seen.append(chip.visible)
		if seen != case[1]:
			_fail("T11: chips para '%s' = %s, esperado %s" % [case[0], seen, case[1]])
		if angle_gear.tray == null or not angle_gear.tray.visible:
			_fail("T11: bandeja some com '%s'" % case[0])
		else:
			var gap: float = (
				angle_gear.tray.get_global_rect().position.x
				- angle_gear.name_icon.get_global_rect().end.x
			)
			if gap < UiTokens.GAP_SM:
				_fail("T11: bandeja a %.1f px do icone, minimo %d" % [gap, UiTokens.GAP_SM])
	angle_gear.set_effects("")
	await _frames(2)
	if angle_gear.tray != null and angle_gear.tray.visible:
		_fail("T11: bandeja vazia deveria sumir")

	# T12: tooltip da bandeja (funcao pura).
	var tips := {
		"a": "Mexe no a da equação",
		"ab": "Mexe no a e no b da equação",
		"abc": "Mexe no a, no b e no c da equação",
		"": "",
	}
	for letters in tips:
		var got: String = GearWidget.effects_tooltip(letters)
		if got != tips[letters]:
			_fail("T12: tooltip de '%s' e '%s'" % [letters, got])

	# T13: "Ver conta" por clique, com icone e tecla.
	var fb: Button = p.formula_button
	if fb == null:
		_fail("T13: ParabolaHud.formula_button nao existe")
	else:
		hud.formula.visible = false
		if fb.text != "":
			_fail("T13: o botao 'Ver conta' ainda tem texto '%s'" % fb.text)
		var keycaps := fb.find_children("*", "UiKeycap", true, false)
		if keycaps.size() != 1 or keycaps[0].text != "F":
			_fail("T13: o botao 'Ver conta' precisa de um keycap F")
		var has_formula_icon := false
		for ic in fb.find_children("*", "UiIcon", true, false):
			has_formula_icon = has_formula_icon or ic.icon == "formula"
		if not has_formula_icon:
			_fail("T13: o botao 'Ver conta' precisa do UiIcon 'formula'")
		for label in fb.find_children("*", "Label", true, false):
			if label.text.contains("ƒ"):
				_fail("T13: o ƒ nao pode ser caractere de fonte")
		if not fb.tooltip_text.contains("(F)"):
			_fail("T13: tooltip do 'Ver conta' sem '(F)': '%s'" % fb.tooltip_text)
		fb.pressed.emit()
		if not hud.formula.visible:
			_fail("T13: clicar em 'Ver conta' nao abriu a gaveta")
		fb.pressed.emit()
		if hud.formula.visible:
			_fail("T13: o segundo clique nao fechou a gaveta")
		# T15, parte do formula_button.
		await _frames(3)
		if not _inner_fits(fb):
			_fail("T15: o conteudo do 'Ver conta' estoura o botao")

	# T14: tecla F abre a gaveta, e F na pausa nao faz nada.
	hud.formula.visible = false
	a._formula_was_pressed = true
	a._poll_formula_hotkey()
	if not hud.formula.visible:
		_fail("T14: a tecla F nao abriu a gaveta")
	paused = true
	var before: bool = hud.formula.visible
	a._formula_was_pressed = true
	a._poll_formula_hotkey()
	paused = false
	if hud.formula.visible != before:
		_fail("T14: F durante a pausa mudou a gaveta")
	hud.formula.visible = false


## T6, T7 e T8: nada estoura a tela com o espacamento novo.
func _test_overflow() -> void:
	await _test_ada_bubble_fits()
	await _test_help_fits()
	await _test_formula_drawer_fits()


## T6: todas as falas da campanha cabem na tela, com e sem texto grande.
func _test_ada_bubble_fits() -> void:
	var g = root.get_node("Global")
	var original: bool = g.big_text
	var texts := []
	for base_id in Campaign.BASES:
		for stage in Campaign.BASES[base_id].stages:
			for key in ["lesson", "tip"]:
				if String(stage.get(key, "")) != "":
					texts.append(stage[key])
	# load() em runtime: AdaDialog le o autoload Global, que ainda nao existe ao compilar este script.
	var dialog: CanvasLayer = load("res://scripts/ui/ada_dialog.gd").new()
	root.add_child(dialog)
	for big in [false, true]:
		g.big_text = big
		for t in texts:
			dialog.prompt(t)
			dialog._text.visible_characters = -1
			await _frames(2)
			if not _on_screen(dialog._bubble.get_global_rect()):
				_fail("T6: fala sai da tela (big_text=%s): %s" % [big, String(t).left(50)])
	g.big_text = original
	dialog.queue_free()


## T7: as tres abas da ajuda cabem na tela e o texto cabe na janela.
func _test_help_fits() -> void:
	var a := await _open_arena_hud("Base_A", 0)
	var help = a.help_overlay
	help.open()
	for i in range(3):
		help._show_page(i)
		await _frames(4)
		var win: Rect2 = help.window.get_global_rect()
		if not _on_screen(win):
			_fail("T7: aba %d da ajuda fora da tela (janela %s)" % [i, win])
		for label in help.window.find_children("*", "Label", true, false):
			if label.is_visible_in_tree() and not win.grow(1).encloses(label.get_global_rect()):
				_fail("T7: aba %d, texto fora da janela: '%s'" % [i, String(label.text).left(40)])
				break
	help.close()


## T8: a gaveta "Ver conta" no pior caso nao cobre os botoes da HUD.
func _test_formula_drawer_fits() -> void:
	var a := await _open_arena_hud("Base_A", 0)
	var hud = a.hud
	hud.formula.visible = true
	hud.formula.set_height_line(5.0)
	var pivot := Vector2(Campaign.ORIGIN_X + 100.0, 602.0)
	hud.formula.set_shot(
		Ballistics.shot(45.0, 800.0, 490.0, pivot, Campaign.ORIGIN_X, Campaign.GROUND_Y)
	)
	await _frames(5)
	var rect: Rect2 = hud.formula.get_global_rect()
	if not _on_screen(rect):
		_fail("T8: a gaveta 'Ver conta' sai da tela (%s)" % rect)
	for other in [hud.guess_btn, hud._badge, hud._right_row]:
		if other.visible and rect.intersects(other.get_global_rect()):
			_fail("T8: a gaveta 'Ver conta' cobre %s" % other.name)
	hud.formula.visible = false


## Primeiro UiKeycap descendente de `node` com o texto `key`, ou null.
func _find_keycap(node: Node, key: String) -> UiKeycap:
	for k in node.find_children("*", "UiKeycap", true, false):
		if k.text == key:
			return k
	return null


func _find_icon(node: Node, icon_name: String) -> UiIcon:
	for i in node.find_children("*", "UiIcon", true, false):
		if i.icon == icon_name:
			return i
	return null


## T15 (guess_btn e _goals_btn), T16, T17 e T18: botoes de icone e faixa de baixo.
func _test_hud_icon_buttons_and_strip() -> void:
	var a := await _open_arena_hud("Base_D", 1)
	var hud = a.hud
	var guess: Button = hud.guess_btn

	# T15: o conteudo composto cabe nos botoes de icone.
	await _frames(3)
	for btn in [guess, hud._goals_btn]:
		if not _inner_fits(btn):
			_fail("T15: o conteudo de um botao de icone estoura o botao (%s)" % btn.tooltip_text)

	# T16: modo chute com icone e tecla; a cor segue o estado sem sinal.
	if guess.text != "":
		_fail("T16: o modo chute ainda tem texto '%s'" % guess.text)
	if _find_keycap(guess, "C") == null:
		_fail("T16: o modo chute precisa do keycap C")
	if not guess.tooltip_text.begins_with("Modo chute (C)"):
		_fail("T16: tooltip do modo chute e '%s'" % guess.tooltip_text)
	var target := _find_icon(guess, "target")
	if target == null:
		_fail("T16: o modo chute precisa do icone 'target'")
	else:
		guess.set_pressed_no_signal(true)
		await _frames(2)
		if target.color != UiTokens.EDITABLE:
			_fail("T16: icone do modo chute ligado deveria ser ambar")
		guess.set_pressed_no_signal(false)
		await _frames(2)
		if target.color != UiTokens.TEXT:
			_fail("T16: icone do modo chute desligado deveria ser TEXT")
	guess.button_pressed = true
	if not a.guess_mode:
		_fail("T16: clicar no modo chute nao ligou guess_mode")
	guess.button_pressed = false

	# T17: municao sem "Tab troca" e com a tecla desenhada.
	hud.set_ammo(25, Color.RED, "Enferrujada")
	if hud._ammo_name_label.text != "Enferrujada":
		_fail("T17: nome da municao e '%s'" % hud._ammo_name_label.text)
	var tab := _find_keycap(hud._strip, "Tab")
	if tab == null:
		_fail("T17: falta o keycap Tab na faixa de baixo")
	else:
		if tab.tooltip_text != "Troca a munição (Tab)":
			_fail("T17: tooltip do Tab e '%s'" % tab.tooltip_text)
		if tab.mouse_filter != Control.MOUSE_FILTER_PASS:
			_fail("T17: o keycap Tab precisa de MOUSE_FILTER_PASS para o tooltip")
	if hud._ammo_label.text != "×25":
		_fail("T17: contagem e '%s'" % hud._ammo_label.text)
	hud.set_ammo(0, Color.RED, "Enferrujada")
	if hud._ammo_label.text != "×0":
		_fail("T17: contagem zerada e '%s'" % hud._ammo_label.text)
	if hud._ammo_label.get_theme_color("font_color") != UiTokens.DANGER:
		_fail("T17: contagem zerada deveria ser DANGER")
	hud.set_ammo(-1, Color.RED, "Enferrujada")
	if hud._ammo_label.text != "livre":
		_fail("T17: municao infinita e '%s'" % hud._ammo_label.text)

	# T18: andar e combustivel, nos limites.
	hud.set_move_hint(true)
	await _frames(3)
	var group: Control = hud._move_group
	if not group.visible or _find_keycap(group, "A") == null or _find_keycap(group, "D") == null:
		_fail("T18: o grupo de andar precisa estar visivel com os keycaps A e D")
	if _find_icon(group, "move") == null:
		_fail("T18: o grupo de andar precisa do icone 'move'")
	if group.tooltip_text != "Anda com o tanque (A e D)":
		_fail("T18: tooltip de andar e '%s'" % group.tooltip_text)
	var fuel_cases := [
		[3.46, "combustível 3,5 m"], [0.0, "sem combustível"], [-0.5, "sem combustível"]
	]
	for case in fuel_cases:
		hud.set_fuel(case[0])
		await _frames(2)
		if hud._fuel_label.text != case[1]:
			_fail("T18: combustivel %.2f mostra '%s'" % [case[0], hud._fuel_label.text])
	if not _on_screen(hud._strip.get_global_rect()):
		_fail("T18: a faixa de baixo sai da tela")
	hud.set_move_hint(false)
	if hud._move_group.visible:
		_fail("T18: o grupo de andar deveria sumir")


## T21: os rotulos do diagrama da ajuda ficam dentro do papel, mesmo com o
## espaco entre palavras maior.
func _test_help_diagram_labels_fit() -> void:
	var diagram := ParabolaDiagram.new()
	diagram.custom_minimum_size = Vector2(470, 250)
	diagram.size = Vector2(470, 250)
	diagram.annotate = true
	diagram.span_m = 29.0
	diagram.curves = [
		{"angle": 45.0, "speed": 800.0, "gravity": 500.0, "color": UiTokens.CALCULATED_ON_PAPER}
	]
	root.add_child(diagram)
	await _frames(3)
	if diagram.drawn_texts.is_empty():
		_fail("T21: o diagrama nao desenhou texto nenhum")
	var paper := Rect2(Vector2.ZERO, diagram.size)
	for r in diagram.drawn_texts:
		if r.position.x < 0.0 or r.end.x > paper.end.x:
			_fail(
				(
					"T21: rotulo do diagrama passa da borda do papel (x %.0f a %.0f de %.0f)"
					% [r.position.x, r.end.x, paper.end.x]
				)
			)
	diagram.queue_free()


# ── 8. Flags de primeira vez (enredo e tutorial) ─────────────────────


## Zera as tres flags de primeira vez so em memoria (sem gravar).
func _clear_onboarding(g: Node) -> void:
	g.story_seen = false
	g.tutorial_done = false
	g.tutorial_skipped = false


## Grava um save "a mao", como um arquivo de uma versao anterior do jogo.
## `player` e `bases` sao {chave: valor} e {base_id: {chave: valor}}.
func _write_old_save(g: Node, player: Dictionary, bases: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("player", "money", 150)
	for k in player:
		cfg.set_value("player", k, player[k])
	for base_id in bases:
		for k in bases[base_id]:
			cfg.set_value(base_id, k, bases[base_id][k])
	cfg.save(g.save_path)


func _flags(g: Node) -> Array:
	return [g.story_seen, g.tutorial_done, g.tutorial_skipped]


func _test_onboarding_flags() -> void:
	var g = root.get_node("Global")
	g.reset_progress()
	_check_flags_roundtrip(g)
	_check_old_saves(g)
	_check_onboarding_order(g)
	_check_mark_functions(g)
	_check_reset_keeps_flags(g)
	_clear_onboarding(g)
	g.reset_progress()
	print("ok: flags de primeira vez no save")


## T1 e T2: ida e volta das flags novas, com a versao 2 no arquivo.
func _check_flags_roundtrip(g: Node) -> void:
	g.story_seen = true
	g.tutorial_done = false
	g.tutorial_skipped = true
	g.save_game()
	_clear_onboarding(g)
	g.load_game()
	if _flags(g) != [true, false, true]:
		_fail("T1: flags nao voltaram do save: %s" % [_flags(g)])
	var cfg := ConfigFile.new()
	cfg.load(g.save_path)
	if cfg.get_value("meta", "version", 0) != 2:
		_fail("T1: save sem [meta] version = 2")
	if not cfg.has_section_key("player", "story_seen"):
		_fail("T1: save sem a chave story_seen")
	if not cfg.has_section_key("player", "tutorial_skipped"):
		_fail("T1: save sem a chave tutorial_skipped")
	g.story_seen = true
	g.tutorial_done = true
	g.tutorial_skipped = false
	g.save_game()
	_clear_onboarding(g)
	g.load_game()
	if _flags(g) != [true, true, false] or g.next_onboarding() != "":
		_fail("T2: tutorial concluido nao voltou do save: %s" % [_flags(g)])


## T3 a T8: saves antigos (sem as chaves novas), tipo errado e arquivo ausente.
func _check_old_saves(g: Node) -> void:
	var cases := [
		# [rotulo, player, bases, story_seen, tutorial_skipped, next_onboarding]
		["T3 sem progresso", {"tutorial_done": false}, {}, false, false, "story"],
		[
			"T4 veterano",
			{"tutorial_done": true},
			{"Base_A": {"stages_cleared": 1, "stars": [2, 0, 0]}},
			true,
			false,
			""
		],
		[
			"T5 Modo Professor",
			{"tutorial_done": false, "teacher_mode": true},
			{"Base_C": {"stars": [1, 0, 0]}},
			true,
			true,
			""
		],
		["T6 tutorial antigo sem estrela", {"tutorial_done": true}, {}, true, false, ""],
		[
			"T7 tipo errado",
			{"tutorial_done": false, "story_seen": "sim", "tutorial_skipped": 1},
			{},
			false,
			false,
			"story"
		],
	]
	for c in cases:
		# Sem isto as estrelas de um caso anterior ficam na memoria: o load nao
		# zera as que faltam no arquivo.
		g.reset_progress()
		g.teacher_mode = false
		_clear_onboarding(g)
		g.story_seen = not c[3]
		g.tutorial_skipped = not c[4]
		_write_old_save(g, c[1], c[2])
		g.load_game()
		if g.story_seen != c[3] or g.tutorial_skipped != c[4] or g.next_onboarding() != c[5]:
			_fail(
				(
					"%s: story_seen=%s tutorial_skipped=%s next='%s'"
					% [c[0], g.story_seen, g.tutorial_skipped, g.next_onboarding()]
				)
			)
	g.teacher_mode = false
	# T8: sem arquivo, nada muda e o fluxo comeca pelo enredo.
	DirAccess.remove_absolute(g.save_path)
	_clear_onboarding(g)
	g.load_game()
	if _flags(g) != [false, false, false] or g.next_onboarding() != "story":
		_fail("T8: sem save, flags %s e next '%s'" % [_flags(g), g.next_onboarding()])


## T9: tabela-verdade do proximo passo da primeira vez.
func _check_onboarding_order(g: Node) -> void:
	var table := [
		[[false, false, false], "story"],
		[[true, false, false], "tutorial"],
		[[true, true, false], ""],
		[[true, false, true], ""],
		[[false, true, false], "story"],
	]
	for row in table:
		g.story_seen = row[0][0]
		g.tutorial_done = row[0][1]
		g.tutorial_skipped = row[0][2]
		if g.next_onboarding() != row[1]:
			_fail("T9: %s deu '%s' (esperado '%s')" % [row[0], g.next_onboarding(), row[1]])


## T10 e T11: as funcoes mark_* gravam e respeitam a conclusao.
func _check_mark_functions(g: Node) -> void:
	_clear_onboarding(g)
	g.mark_story_seen()
	g.story_seen = false
	g.load_game()
	if not g.story_seen:
		_fail("mark_story_seen nao gravou no save")
	g.tutorial_skipped = true
	g.mark_tutorial_done()
	_clear_onboarding(g)
	g.load_game()
	if not g.tutorial_done or g.tutorial_skipped:
		_fail("T10: depois de mark_tutorial_done: %s" % [_flags(g)])
	g.mark_tutorial_skipped()
	if g.tutorial_skipped:
		_fail("T11: mark_tutorial_skipped desfez a conclusao do tutorial")
	g.tutorial_done = false
	g.mark_tutorial_skipped()
	g.tutorial_skipped = false
	g.load_game()
	if not g.tutorial_skipped:
		_fail("mark_tutorial_skipped nao gravou no save")


## T12: RECOMECAR zera a campanha, mas nao reapresenta enredo nem tutorial.
func _check_reset_keeps_flags(g: Node) -> void:
	g.story_seen = true
	g.tutorial_done = true
	g.tutorial_skipped = true
	g.money = 999
	g.record_stars("Base_A", 0, 3)
	g.reset_progress()
	_clear_onboarding(g)
	g.load_game()
	if _flags(g) != [true, true, true]:
		_fail("T12: RECOMECAR mexeu nas flags: %s" % [_flags(g)])
	if g.money != 150 or g.total_stars() != 0:
		_fail("T12: RECOMECAR nao zerou ouro (%d) ou estrelas (%d)" % [g.money, g.total_stars()])


# ── 9. Alpha 1 sem o tutorial falado ─────────────────────────────────


## Algum tiro com o angulo do desafio `angle_hit` acerta o castelo sem bater
## antes numa montanha (a estrela precisa ser alcancavel).
func _angle_hit_reachable(st: Dictionary, goal: Dictionary) -> bool:
	var polys := []
	for o in st.obstacles:
		var gp := PackedVector2Array()
		for p in Campaign.rounded(o.poly):
			gp.append(o.pos + p)
		polys.append(gp)
	for t in _targets(st):
		if not t.get("boss", false):
			continue
		for s in _shots(st):
			if s.angle_deg >= goal.min and s.angle_deg <= goal.max and _hits(s, polys, t):
				return true
	return false


## T21 (estrelas): todo desafio de angulo da campanha tem um tiro possivel.
func _test_angle_hit_reachable() -> void:
	for entry in _all_stages():
		for goal in entry[1].goals:
			if goal.type == "angle_hit" and not _angle_hit_reachable(entry[1], goal):
				_fail("%s: desafio de angulo %d-%d impossivel" % [entry[0], goal.min, goal.max])
	# Controle negativo: um angulo que nao chega ao castelo tem que ser acusado.
	var alpha1: Dictionary = Campaign.BASES.Base_A.stages[0]
	if _angle_hit_reachable(alpha1, {"min": 88.0, "max": 90.0}):
		_fail("verificador de angle_hit aceitou 88-90 graus na Alpha 1")
	print("ok: desafios de angulo alcancaveis")


## Pelo script: o segundo aviao da fase ganha um nome automatico (@Node2D@N).
func _is_airplane(e: Node) -> bool:
	var script: Script = e.get_script()
	return script != null and script.resource_path.ends_with("airplane_enemy.gd")


## T21 e T22: a Alpha 1 abre como fase normal e a ajuda nao reativa o tutorial.
func _test_alpha1_without_old_tutorial() -> void:
	var g = root.get_node("Global")
	g.reset_progress()
	g.lab_mode = false
	g.practice_mode = false
	g.tutorial_done = false
	g.save_game()
	g.current_base_id = "Base_A"
	g.current_stage = 0
	paused = false
	change_scene_to_file("res://scenes/arena/arena.tscn")
	await _frames(10)
	var a = current_scene
	if a.coach.has_method("_run_tutorial") or "in_tutorial" in a.coach:
		_fail("T21: o coach ainda tem o tutorial falado")
	for e in a.active_enemies:
		if _is_airplane(e) and e.process_mode == Node.PROCESS_MODE_DISABLED:
			_fail("T21: aviao congelado na Alpha 1")
	var intro: Array = _coach_script().intro_lines_for(a.stage_data, "")
	if not a.coach.ada.is_talking() or a.coach.ada._text.text != intro[0].text:
		_fail("T21: Alpha 1 nao abriu com a fala normal: '%s'" % a.coach.ada._text.text)
	if a.coach.ada.is_talking():
		a.coach.ada._finish()
	await _frames(2)
	# Na pratica a tecla C nao liga o chute (era o papel do in_tutorial).
	g.practice_mode = true
	a._set_guess_mode(true)
	g.practice_mode = false
	if a.guess_mode or a.hud.guess_btn.button_pressed:
		_fail("o chute ligou com practice_mode")
	_check_help_without_tutorial(a, g)
	if g.tutorial_done:
		_fail("T21: a Alpha 1 gravou tutorial_done")
	paused = false
	g.reset_progress()
	print("ok: Alpha 1 sem o tutorial falado")


## T22: nenhum botao da ajuda fala em tutorial, e nada no save muda.
func _check_help_without_tutorial(a: Node, g: Node) -> void:
	var help: Node = a.help_overlay
	if help.has_method("_replay_tutorial"):
		_fail("T22: a ajuda ainda tem _replay_tutorial")
	for node in help.find_children("*", "Button", true, false):
		if "tutorial" in node.text.to_lower():
			_fail("T22: botao da ajuda fala em tutorial: '%s'" % node.text)
	if g.tutorial_done:
		_fail("T22: a ajuda mexeu em tutorial_done")


# ── 10. Arena de pratica do tutorial ─────────────────────────────────

const PRACTICE_OPENING := "Canhão consertado. Antes de partir, vamos calibrar."
const EXIT_QUESTION := "Deseja sair do tutorial?"


## Abre a arena de pratica como o fluxo do tutorial abriria.
func _open_practice(origin: String) -> Node:
	var g = root.get_node("Global")
	g.lab_mode = false
	g.practice_mode = true
	g.tutorial_origin = origin
	paused = false
	change_scene_to_file("res://scenes/arena/arena.tscn")
	await _frames(10)
	return current_scene


## Fecha a fala de abertura (ela pausa o jogo).
func _finish_opening(a: Node) -> void:
	if a.coach.ada.is_talking():
		a.coach.ada._finish()
	await _frames(2)


func _practice_boss(a: Node) -> Node2D:
	for e in a.active_enemies:
		if is_instance_valid(e) and e.has_meta("is_boss"):
			return e
	return null


## Todo o save como {"secao/chave": valor}, para comparar antes e depois.
func _save_snapshot(g: Node) -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {}
	if cfg.load(g.save_path) != OK:
		return out
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			out[section + "/" + key] = cfg.get_value(section, key)
	return out


func _scene_path() -> String:
	return current_scene.scene_file_path if current_scene else ""


func _test_practice_arena() -> void:
	var g = root.get_node("Global")
	g.reset_progress()
	g.map_intro_done = true
	g.story_seen = true
	g.tutorial_done = false
	g.tutorial_skipped = false
	g.save_game()
	_check_practice_stage_reachable()
	await _check_practice_setup()
	await _check_practice_free_shots()
	await _check_practice_keeps_progress()
	await _check_practice_exit_first_run()
	await _check_no_practice_leak()
	await _check_practice_from_menu()
	g.practice_mode = false
	g.tutorial_origin = "first_run"
	paused = false
	g.reset_progress()
	print("ok: arena de pratica")


## T15: o chefe da pratica e alcancavel (mesmo verificador das fases).
func _check_practice_stage_reachable() -> void:
	var before := failures.size()
	var st: Dictionary = load("res://scripts/campaign.gd").practice_stage()
	_check_stage("pratica", st)
	if failures.size() != before:
		_fail("T15: o chefe da pratica nao e alcancavel")
	if Campaign.BASES.has("Practice") or st.get("goals", [1]) != []:
		_fail("T15: a pratica entrou na campanha ou tem desafios")


## T14 e T35: fortaleza em ruinas com 1 HP, sem avioes, HUD da calibragem.
func _check_practice_setup() -> void:
	var a = await _open_practice("first_run")
	if a.get("practice") == null:
		_fail("T14: a arena nao montou a pratica")
		return
	var boss := _practice_boss(a)
	if a.active_enemies.size() != 1 or boss == null:
		_fail("T14: pratica com %d inimigos" % a.active_enemies.size())
	elif boss.get_meta("hp") != 1 or boss.get_meta("max_hp") != 3:
		_fail("T14: chefe com hp %s / max %s" % [boss.get_meta("hp"), boss.get_meta("max_hp")])
	for e in a.active_enemies:
		if _is_airplane(e):
			_fail("T14: aviao na pratica")
	if a.stage_data.get("title", "") != "Calibragem":
		_fail("T14: titulo da pratica '%s'" % a.stage_data.get("title", ""))
	if a.hud._stage_name_label.text != "Calibragem" or a.hud._goals_btn.visible:
		_fail("T14: HUD sem a calibragem ou com a estrela de missoes")
	if a.hud.guess_btn.visible or a.hud._ammo_label.text != "livre":
		_fail("T14: HUD com chute ou sem municao livre")
	var line: String = a.coach.ada._text.text
	if not a.coach.ada.is_talking() or line != PRACTICE_OPENING or "Antes do Norte" in line:
		_fail("T35: abertura da pratica '%s'" % line)
	await _finish_opening(a)


## T16: errar nao termina o tutorial e nao gasta municao, nem com o estoque zerado.
func _check_practice_free_shots() -> void:
	var g = root.get_node("Global")
	for stock in [15, 0]:
		g.ammo_inventory = {"Enferrujada": stock, "Perfurante": 5}
		var a = await _open_practice("first_run")
		await _finish_opening(a)
		a.current_ammo_index = 0
		a.cannon.rotation = 0.6
		a._fire_projectile()
		var proj: Node = null
		for ch in a.get_children():
			if ch.get_script() == a.ProjectileScript:
				proj = ch
		if proj == null:
			_fail("T16: a pratica nao disparou com %d balas no estoque" % stock)
		var t := 0.0
		while is_instance_valid(proj) and t < 5.0:
			await process_frame
			t += 1.0 / 60.0
		await _frames(2)
		if g.tutorial_done or a.stage_cleared:
			_fail("T16: errar o tiro terminou o tutorial")
		if g.ammo_inventory["Enferrujada"] != stock or a.ammo_counts[0] != stock:
			_fail("T16: a pratica gastou municao (%s)" % [g.ammo_inventory])
	g.ammo_inventory = {"Enferrujada": 15, "Perfurante": 5}
	g.save_game()


## T13: derrubar o chefe so muda tutorial_done no save (invariante da pratica).
func _check_practice_keeps_progress() -> void:
	var g = root.get_node("Global")
	var before := _save_snapshot(g)
	var a = await _open_practice("first_run")
	await _finish_opening(a)
	var boss := _practice_boss(a)
	if boss == null:
		_fail("T13: pratica sem chefe")
		return
	a.on_enemy_hit(boss, 1)
	await _frames(3)
	if not g.tutorial_done or not a.coach.ada.is_talking():
		_fail("T13: chefe derrubado sem tutorial_done ou sem a fala final")
	a.coach.ada._finish()
	var after := _save_snapshot(g)
	for key in after:
		var changed: bool = not before.has(key) or before[key] != after[key]
		if changed and key != "player/tutorial_done":
			_fail("T13: a pratica mudou %s no save (%s -> %s)" % [key, before.get(key), after[key]])
	if after.get("player/tutorial_done") != true:
		_fail("T13: tutorial_done nao foi gravado")
	if g.money != 150 or g.brass != 0 or g.total_stars() != 0 or not g.achievements.is_empty():
		_fail("T13: pratica mexeu em ouro, latao, estrelas ou selos em memoria")
	if g.ammo_inventory != {"Enferrujada": 15, "Perfurante": 5}:
		_fail("T13: pratica mexeu na municao: %s" % [g.ammo_inventory])
	await _frames(10)
	if g.practice_mode or _scene_path() != "res://scenes/war_map/war_map.tscn":
		_fail("T13: depois da pratica, cena %s e practice %s" % [_scene_path(), g.practice_mode])
	g.tutorial_done = false
	g.save_game()


## T17: pausar na pratica pede confirmacao; cancelar fica; confirmar sai ao mapa.
func _check_practice_exit_first_run() -> void:
	var g = root.get_node("Global")
	var a = await _open_practice("first_run")
	await _finish_opening(a)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	a._unhandled_input(esc)
	var modal = a.practice.exit_modal
	if not modal.is_confirming() or a.pause_menu.visible:
		_fail("T17: Esc na pratica nao abriu a confirmacao (ou abriu a pausa)")
	var asked := false
	for label in modal.find_children("*", "Label", true, false):
		asked = asked or label.text == EXIT_QUESTION
	if not asked:
		_fail("T17: confirmacao sem o texto '%s'" % EXIT_QUESTION)
	modal._input(esc)
	await _frames(2)
	if modal.visible or not g.practice_mode or g.tutorial_skipped:
		_fail("T17: cancelar a saida nao voltou para a pratica")
	a._on_pause_pressed()
	if not modal.is_confirming() or a.pause_menu.visible:
		_fail("T17: o botao de pausa nao abriu a confirmacao")
	modal.confirm_exit()
	if g.practice_mode or not g.tutorial_skipped or g.tutorial_done:
		_fail("T17: sair confirmado: %s practice=%s" % [_flags(g), g.practice_mode])
	g.tutorial_skipped = false
	g.load_game()
	if not g.tutorial_skipped:
		_fail("T17: tutorial_skipped nao foi gravado")
	await _frames(10)
	if _scene_path() != "res://scenes/war_map/war_map.tscn":
		_fail("T17: sair da pratica levou a %s" % _scene_path())


## T18: depois de sair da pratica, a Alpha 1 abre normal.
func _check_no_practice_leak() -> void:
	var g = root.get_node("Global")
	g.current_base_id = "Base_A"
	g.current_stage = 0
	paused = false
	change_scene_to_file("res://scenes/arena/arena.tscn")
	await _frames(10)
	var a = current_scene
	var planes := 0
	for e in a.active_enemies:
		if _is_airplane(e):
			planes += 1
	if a.stage_data.title != "Primeiro disparo" or planes != 2 or a.get("practice") != null:
		_fail("T18: practice_mode vazou (%s, %d avioes)" % [a.stage_data.title, planes])
	await _finish_opening(a)


## Origem "menu": sair nao grava tutorial_skipped; derrubar o chefe volta ao menu.
func _check_practice_from_menu() -> void:
	var g = root.get_node("Global")
	g.tutorial_done = false
	g.tutorial_skipped = false
	g.save_game()
	var a = await _open_practice("menu")
	await _finish_opening(a)
	a._on_pause_pressed()
	a.practice.exit_modal.confirm_exit()
	await _frames(10)
	if g.tutorial_skipped or g.practice_mode:
		_fail("sair da pratica pelo menu gravou tutorial_skipped")
	if _scene_path() != "res://scenes/menu_play/menu_play.tscn":
		_fail("sair da pratica pelo menu levou a %s" % _scene_path())
	a = await _open_practice("menu")
	await _finish_opening(a)
	a.on_enemy_hit(_practice_boss(a), 1)
	await _frames(3)
	a.coach.ada._finish()
	await _frames(10)
	if not g.tutorial_done or g.practice_mode:
		_fail("T31f: pratica pelo menu sem tutorial_done ou com practice_mode")
	if _scene_path() != "res://scenes/menu_play/menu_play.tscn":
		_fail("T31f: pratica pelo menu terminou em %s" % _scene_path())


# ── 11. Tutorial modal (7 paginas, moldura branca, saida) ────────────

const TUTORIAL_PAGE_7 := (
	"Antes de partir, a Ada testa o canhão " + "numa fortaleza que já caiu. Um acerto derruba."
)
const TUTORIAL_COMMANDS := [
	["Espaço", "dispara"],
	["A e D", "anda, quando há combustível"],
	["Tab", "troca a munição"],
	["Estrela", "missões da fase (três estrelas)"],
	["H", "ajuda"],
]
const HELP_SCRIPT_PATH := "res://scripts/help_overlay.gd"
const TUTORIAL_SHEET_PAGES := [0, 1, 2, 3, 4, 6]


func _test_tutorial_modal() -> void:
	var g = root.get_node("Global")
	var before := _save_snapshot(g)
	_check_tutorial_tokens()
	await _check_tutorial_pages()
	await _check_tutorial_exit()
	await _check_tutorial_footer()
	await _check_tutorial_sheet()
	await _check_tutorial_commands()
	await _check_tutorial_text_size()
	await _check_help_keycap()
	if _save_snapshot(g) != before:
		_fail("o tutorial modal mexeu no save")
	print("ok: tutorial modal")


func _new_tutorial() -> Node:
	var m: Node = load("res://scripts/ui/tutorial_modal.gd").new()
	root.add_child(m)
	await _frames(1)
	return m


func _press(m: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	m._input(ev)


func _free_modal(m: Node) -> void:
	m.queue_free()
	await _frames(1)


## Contador de emissoes de um sinal sem argumentos.
func _count_signal(sig: Signal) -> Array:
	var n := [0]
	sig.connect(func(): n[0] += 1)
	return n


func _visible_label(m: Node, text: String) -> Label:
	for l in m.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text == text:
			return l
	return null


func _find_button(m: Node, text: String) -> Button:
	for b in m.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text == text:
			return b
	return null


func _next_pages(m: Node, n: int) -> void:
	for _i in range(n):
		m.next_page()
	await _frames(1)


## Molduras brancas (UiFrame com fill == branco) visiveis no modal.
func _white_frames(m: Node) -> int:
	var n := 0
	for p in m.find_children("*", "PanelContainer", true, false):
		var box: StyleBox = p.get_theme_stylebox("panel")
		if p.is_visible_in_tree() and box is UiFrame and box.fill == Color("ffffff"):
			n += 1
	return n


## T33 (tokens): SHEET branco, PULSE_FLASH existe e o Kind.SHEET e a moldura branca.
func _check_tutorial_tokens() -> void:
	var tokens := load("res://scripts/ui/ui_tokens.gd") as GDScript
	var consts: Dictionary = tokens.get_script_constant_map()
	if consts.get("SHEET") != Color("ffffff"):
		_fail("T33: UiTokens.SHEET nao e branco (%s)" % str(consts.get("SHEET")))
	if not consts.get("PULSE_FLASH") is Color:
		_fail("T33: UiTokens.PULSE_FLASH nao existe")
	if not UiPanel.Kind.has("SHEET"):
		_fail("T33: UiPanel.Kind.SHEET nao existe")
		return
	var box: UiFrame = UiPanel.create(UiPanel.Kind.get("SHEET"))
	if box.fill != Color("ffffff") or box.rivets:
		_fail("T33: Kind.SHEET nao e uma moldura branca lisa")


## As 7 paginas, o texto da 7 (T35) e a navegacao com limites.
func _check_tutorial_pages() -> void:
	var m := await _new_tutorial()
	var pages: Array = m.PAGES
	if pages.size() != 7:
		_fail("T30: o tutorial tem %d paginas, esperava 7" % pages.size())
	for i in range(pages.size()):
		if str(pages[i].get("title", "")) == "":
			_fail("pagina %d do tutorial sem titulo" % (i + 1))
		var problem := _tone_problem(str(pages[i].get("text", "")))
		if problem != "":
			_fail("tom na pagina %d do tutorial: %s" % [i + 1, problem])
	if pages.size() == 7 and pages[6].get("text", "") != TUTORIAL_PAGE_7:
		_fail("T35: texto da pagina 7 diferente do plano: '%s'" % pages[6].get("text", ""))
	m.open()
	await _frames(2)
	if m.page_index() != 0 or not m.visible:
		_fail("open() nao abriu na pagina 0 (%d)" % m.page_index())
	if paused:
		_fail("o tutorial pausou o jogo por padrao")
	m.prev_page()
	if m.page_index() != 0:
		_fail("prev_page() na pagina 1 saiu do limite (%d)" % m.page_index())
	await _next_pages(m, 6)
	if m.page_index() != 6:
		_fail("next_page() 6x foi para a pagina %d" % m.page_index())
	if _visible_label(m, TUTORIAL_PAGE_7) == null:
		_fail("T35: a pagina 7 nao mostra o texto 'Antes de partir'")
	await _next_pages(m, 1)
	if m.page_index() != 6:
		_fail("next_page() na ultima pagina passou do limite (%d)" % m.page_index())
	m.prev_page()
	if m.page_index() != 5:
		_fail("prev_page() nao voltou (%d)" % m.page_index())
	await _free_modal(m)


## T27, T28 e a semantica herdada da ponte (open_exit_prompt).
func _check_tutorial_exit() -> void:
	var m := await _new_tutorial()
	var done := _count_signal(m.completed)
	var aborted := _count_signal(m.aborted)
	m.open()
	await _next_pages(m, 2)
	m.ask_exit()
	await _frames(2)
	if not m.is_confirming() or _visible_label(m, EXIT_QUESTION) == null:
		_fail("T27: ask_exit() nao mostrou '%s'" % EXIT_QUESTION)
	var focus := m.get_viewport().gui_get_focus_owner()
	if not focus is Button or focus.text != "CONTINUAR O TUTORIAL":
		_fail("T27: o foco da confirmacao nao esta em CONTINUAR O TUTORIAL")
	if _visible_label(m, str(m.PAGES[2].get("text", "?"))) != null:
		_fail("T27: a pagina continuou visivel durante a confirmacao")
	_press(m, "ui_right")
	if m.page_index() != 2:
		_fail("a seta mudou de pagina durante a confirmacao")
	m.cancel_exit()
	await _frames(1)
	if m.is_confirming() or m.page_index() != 2 or not m.visible:
		_fail("T27: cancelar nao voltou ao passo 3 (%d)" % m.page_index())
	if _visible_label(m, str(m.PAGES[2].get("text", "?"))) == null:
		_fail("T27: a pagina 3 nao voltou a aparecer depois de cancelar")
	_press(m, "ui_cancel")
	if not m.is_confirming():
		_fail("T28: Esc na pagina nao pediu a saida")
	_press(m, "ui_cancel")
	if m.is_confirming() or m.page_index() != 2:
		_fail("T28: segundo Esc nao voltou ao passo 3")
	if aborted[0] != 0 or done[0] != 0:
		_fail("sinais emitidos sem confirmar a saida")
	m.ask_exit()
	m.confirm_exit()
	await _frames(1)
	if aborted[0] != 1 or m.visible or m.is_confirming():
		_fail("T29: confirm_exit() nao fechou e emitiu aborted uma vez (%d)" % aborted[0])
	# Modo da arena de pratica: cancelar fecha; depois, no modo normal, so esconde.
	m.open_exit_prompt()
	await _frames(1)
	if not m.is_confirming():
		_fail("open_exit_prompt() nao abriu na confirmacao")
	m.cancel_exit()
	if m.visible:
		_fail("open_exit_prompt(): cancelar nao fechou o modal")
	m.open()
	m.ask_exit()
	m.cancel_exit()
	if not m.visible or m.page_index() != 0:
		_fail("depois do modo da pratica, cancelar fechou o modal normal")
	await _free_modal(m)


## Rodape: contador, ANTERIOR, setas, SAIR e o botao da ultima pagina (T30).
func _check_tutorial_footer() -> void:
	var m := await _new_tutorial()
	var done := _count_signal(m.completed)
	m.open()
	await _frames(2)
	if _visible_label(m, "Passo 1 de 7") == null:
		_fail("rodape sem 'Passo 1 de 7'")
	var prev := _find_button(m, "← ANTERIOR")
	if prev == null or not prev.disabled:
		_fail("ANTERIOR nao esta desabilitado na pagina 1")
	_press(m, "ui_right")
	_press(m, "ui_right")
	await _frames(1)
	if m.page_index() != 2 or _visible_label(m, "Passo 3 de 7") == null:
		_fail("a seta direita nao levou ao passo 3 (%d)" % m.page_index())
	_press(m, "ui_left")
	if m.page_index() != 1:
		_fail("a seta esquerda nao voltou uma pagina")
	var next := _find_button(m, "PRÓXIMO →")
	if next == null:
		_fail("sem o botao PRÓXIMO →")
	else:
		next.pressed.emit()
		if m.page_index() != 2:
			_fail("PRÓXIMO → nao avancou")
	var leave := _find_button(m, "SAIR DO TUTORIAL")
	if leave == null:
		_fail("sem o botao SAIR DO TUTORIAL")
	else:
		leave.pressed.emit()
		if not m.is_confirming():
			_fail("SAIR DO TUTORIAL nao abriu a confirmacao")
		m.cancel_exit()
	await _next_pages(m, 4)
	var last := _find_button(m, "IR PARA A CALIBRAGEM")
	if last == null or _find_button(m, "PRÓXIMO →") != null:
		_fail("T30: a ultima pagina nao troca PRÓXIMO por IR PARA A CALIBRAGEM")
		await _free_modal(m)
		return
	if done[0] != 0:
		_fail("T30: completed emitido antes da hora")
	last.pressed.emit()
	await _frames(1)
	if done[0] != 1 or m.visible:
		_fail("T30: IR PARA A CALIBRAGEM nao emitiu completed uma vez e fechou (%d)" % done[0])
	await _free_modal(m)


## T33: moldura branca nas paginas 1-5 e 7; a 6 e a lista no fundo do modal.
func _check_tutorial_sheet() -> void:
	var m := await _new_tutorial()
	m.open()
	await _frames(2)
	for i in range(7):
		var n := _white_frames(m)
		var want: bool = i in TUTORIAL_SHEET_PAGES
		if want and n < 1:
			_fail("T33: a pagina %d nao tem moldura branca" % (i + 1))
		elif not want and n != 0:
			_fail("T33: a pagina %d (lista de comandos) tem moldura branca" % (i + 1))
		await _next_pages(m, 1)
	await _free_modal(m)


## T34: lista de comandos da pagina 6, com as teclas desenhadas.
func _check_tutorial_commands() -> void:
	var m := await _new_tutorial()
	m.open()
	await _next_pages(m, 5)
	var list: Node = m.find_child("CommandList", true, false)
	if list == null or not list.is_visible_in_tree():
		_fail("T34: a pagina 6 nao mostra a lista de comandos")
		await _free_modal(m)
		return
	var rows := list.get_children()
	if rows.size() != TUTORIAL_COMMANDS.size():
		_fail("T34: %d linhas na lista, esperava 5" % rows.size())
		await _free_modal(m)
		return
	for i in range(rows.size()):
		var text_col: Node = rows[i].get_child(rows[i].get_child_count() - 1)
		var got := [text_col.get_child(0).text, text_col.get_child(1).text]
		if got != TUTORIAL_COMMANDS[i]:
			_fail("T34: linha %d = %s, esperava %s" % [i + 1, str(got), str(TUTORIAL_COMMANDS[i])])
	_check_command_visuals(rows)
	await _free_modal(m)


func _keycap_letters(row: Node) -> Array:
	var out := []
	for c in row.find_children("*", "PanelContainer", true, false):
		for l in c.find_children("*", "Label", true, false):
			out.append(l.text)
	return out


func _check_command_visuals(rows: Array) -> void:
	if rows[0].find_children("*", "TextureRect", true, false).is_empty():
		_fail("T34: Espaco sem o desenho da tecla")
	if rows[2].find_children("*", "TextureRect", true, false).is_empty():
		_fail("T34: Tab sem o desenho da tecla")
	if _keycap_letters(rows[1]) != ["A", "D"]:
		_fail("T34: 'A e D' deveria ter duas teclas, A e D (%s)" % str(_keycap_letters(rows[1])))
	if _keycap_letters(rows[4]) != ["H"]:
		_fail("T34: 'H' deveria ter uma tecla H (%s)" % str(_keycap_letters(rows[4])))
	var star := false
	for n in rows[3].find_children("*", "Control", true, false):
		if n is UiIcon and n.icon == "star":
			star = true
	if not star:
		_fail("T34: 'Estrela' sem o icone de estrela")


## big_text sobe o corpo do texto e a narracao nao quebra o modal.
func _check_tutorial_text_size() -> void:
	var g = root.get_node("Global")
	var big_before: bool = g.big_text
	var narr_before: bool = g.narration
	var m := await _new_tutorial()
	for big in [false, true]:
		g.big_text = big
		m.open()
		await _frames(2)
		var label := _visible_label(m, str(m.PAGES[0].get("text", "?")))
		var want: int = UiTokens.FONT_LG if big else UiTokens.FONT_MD
		if label == null or label.get_theme_font_size("font_size") != want:
			_fail("big_text=%s: corpo do tutorial nao esta em %d" % [str(big), want])
		m.close()
	g.narration = true
	m.open()
	await _next_pages(m, 5)
	m.ask_exit()
	m.cancel_exit()
	m.close()
	g.big_text = big_before
	g.narration = narr_before
	await _free_modal(m)


## T36: a aba "As teclas" da ajuda continua igual depois de extrair keycap().
func _check_help_keycap() -> void:
	var script := load(HELP_SCRIPT_PATH) as GDScript
	var has_keycap := false
	for info in script.get_script_method_list():
		has_keycap = has_keycap or info.name == "keycap"
	if not has_keycap:
		_fail("T36: HelpOverlay.keycap() nao existe")
	var help: Node = script.new()
	root.add_child(help)
	await _frames(1)
	var grid: Node = help._pages[0]
	if grid.get_child_count() != 11:
		_fail("T36: a aba As teclas tem %d linhas, esperava 11" % grid.get_child_count())
	var letters := []
	for row in grid.get_children():
		if row.get_child(0) is PanelContainer:
			var cap: PanelContainer = row.get_child(0)
			letters.append(cap.get_child(0).text)
			if cap.custom_minimum_size != Vector2(44, 40):
				_fail("T36: a tecla com letra mudou de tamanho")
	if letters != ["A", "F", "C", "H"]:
		_fail("T36: teclas com letra da ajuda = %s" % str(letters))
	if has_keycap:
		var cap: Node = script.call("keycap", "Q")
		if not cap is PanelContainer or cap.get_child(0).text != "Q":
			_fail("T36: keycap('Q') nao devolve a tecla com a letra")
	await _free_modal(help)

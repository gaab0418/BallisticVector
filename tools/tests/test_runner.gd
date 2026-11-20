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

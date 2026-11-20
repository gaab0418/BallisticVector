extends Node
## A Engenheira Ada na arena: tutorial da primeira vez, abertura curta de cada
## fase (uma frase da licao e o aviso do chefe), dicas apos erros seguidos,
## parabens por desafio e o botao de estrela. A arena so avisa os eventos (tiro,
## acerto, bala que sumiu); a Ada decide o que dizer.

const MISSES_FOR_TIP := 3
const BAND_LABEL_SECONDS := 12.0

var arena: Node2D
var ada: AdaDialog
var spot: Spotlight
var in_tutorial := false

var _misses := 0
var _hit_since_fire := false
var _hit_in_tutorial := false
var _stage_tip_given := false
var _elapsed := 0.0
var _prev_states: Array = []


func setup(host: Node2D) -> void:
	arena = host
	process_mode = Node.PROCESS_MODE_ALWAYS
	ada = AdaDialog.new()
	host.add_child(ada)
	spot = Spotlight.new()
	host.add_child(spot)
	_prev_states = arena.goals.states.duplicate()
	arena.goals.changed.connect(_on_goals_changed)
	arena.hud.goals_pressed.connect(_on_goals_pressed)


func busy() -> bool:
	return ada.is_talking() or in_tutorial


func _process(delta: float) -> void:
	_elapsed += delta
	# O rotulo "a bala pode cair aqui" so aparece no comeco da fase.
	if _elapsed > BAND_LABEL_SECONDS:
		arena.trajectory.band_label = false


# ═════════════════════════════════════════════════════════════════════
#  INICIO DA FASE
# ═════════════════════════════════════════════════════════════════════


func start_stage() -> void:
	if Global.lab_mode:
		(
			ada
			. say(
				[
					{
						"text": "Esta é a minha oficina. Aqui ninguém atira em você.",
						"expr": "happy",
						"caption": "LABORATÓRIO"
					},
					{
						"text":
						"Atire e veja a tabela: a altura da bala, metro a metro, ao lado da conta.",
						"expr": "thinking"
					},
					{
						"text": "Clique no céu para marcar um alvo e tente acertar em cheio.",
						"expr": "proud"
					},
				]
			)
		)
		return
	if (
		Global.current_base_id == "Base_A"
		and Global.current_stage == 0
		and not Global.tutorial_done
	):
		_run_tutorial()
		return
	var lines := _intro_lines()
	if not lines.is_empty():
		ada.say(lines)


## Como vencer cada tipo de chefe, na fala de abertura (ver BossBrain).
const CHIEF_RULES := {
	"shield": "a cúpula que eu projetei só deixa passar bala caindo de cima. Suba bem o vértice.",
	"moving": "ele não para no lugar. Mire a raiz onde ele vai estar, não onde está agora.",
	"hopping": "a cada acerto ele muda de lugar. Reposicione o tanque e refaça a conta.",
	"gravity":
	"a cada acerto ele troca a gravidade. Confira o novo 'a' da equação antes de atirar.",
	"guarded":
	"o escudo vermelho só cai depois que todos os outros inimigos caírem. Comece por eles.",
}

# gdlint: ignore=max-line-length
const CHIEF_FALLBACK := "este chefe tem uma regra própria. Observe o primeiro tiro antes de gastar munição."


func _intro_lines() -> Array:
	var info: Dictionary = Campaign.base(Global.current_base_id)
	var base_name: String = Global.get_base_data(Global.current_base_id).get("name", "")
	var caption := (
		"%s · %s · FASE %d"
		% [base_name.to_upper(), info.chapter.to_upper(), Global.current_stage + 1]
	)
	return intro_lines_for(arena.stage_data, caption)


## Abertura da fase: so a primeira frase da licao e, se houver chefe, um aviso
## curto. A dica fica para depois de MISSES_FOR_TIP erros seguidos; as missoes,
## para o botao de estrela. Licao vazia e sem chefe devolve lista vazia.
static func intro_lines_for(stage: Dictionary, caption: String) -> Array:
	var lines := []
	var sentences := _sentences(String(stage.get("lesson", "")))
	if not sentences.is_empty():
		lines.append({"text": sentences[0], "expr": "happy", "caption": caption})
	var chief: Dictionary = stage.get("chief", {})
	if not chief.is_empty():
		var rule: String = CHIEF_RULES.get(chief.get("kind", ""), CHIEF_FALLBACK)
		(
			lines
			. append(
				{
					"text": "%s: %s" % [chief.get("name", "Chefe"), rule],
					"expr": "surprised",
					"caption": "CHEFE",
				}
			)
		)
	return lines


static func _sentences(text: String) -> Array:
	var out := []
	var cur := ""
	for i in range(text.length()):
		cur += text[i]
		var end := text[i] in [".", "!", "?"] and (i + 1 >= text.length() or text[i + 1] == " ")
		if end:
			out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


# ═════════════════════════════════════════════════════════════════════
#  TUTORIAL (Base Alpha, fase 1, primeira vez)
# ═════════════════════════════════════════════════════════════════════


func _run_tutorial() -> void:
	in_tutorial = true
	arena.trajectory.band_label = false
	_freeze_enemies(true)
	await _say(
		[
			{
				"text": "Oi, recruta! Eu sou a Engenheira Ada.",
				"expr": "happy",
				"caption": "BEM-VINDO"
			},
			{"text": "Vou te mostrar como este canhão funciona. É rapidinho!", "expr": "proud"},
		]
	)
	var hud = arena.hud
	spot.focus(hud.parabola.gear_rect(0), "orbit")
	ada.prompt(
		"Segure a seta ↑ (ou gire a engrenagem com o mouse) até o ÂNGULO passar de 30°.",
		"neutral",
		"PASSO 1"
	)
	await _until(func(): return arena._angle_deg() >= 30.0)
	ada.hide_now()

	spot.focus(arena.trajectory.curve_rect())
	await _say(
		[
			{
				"text": "Viu a linha mudar? Esse caminho da bala se chama PARÁBOLA.",
				"expr": "surprised"
			}
		]
	)
	spot.focus(_vertex_rect())
	await _say(
		[
			{
				"text": "O losango é o VÉRTICE: o ponto mais alto. O número é a altura máxima.",
				"expr": "thinking"
			}
		]
	)
	spot.focus(_root_rect())
	await _say([_root_line()])
	spot.focus(hud.parabola.equation_rect())
	await _say(
		[
			{
				"text":
				"Aqui em cima está a conta da curva. Os números mudam quando você gira as engrenagens.",
				"expr": "thinking",
			}
		]
	)

	spot.focus(hud.parabola.gear_rect(1), "orbit")
	ada.prompt("Agora aperte → para escolher a FORÇA e use ↑ ↓ para mudar.", "neutral", "PASSO 2")
	var p0: float = arena.current_power
	await _until(func(): return arena.selected_gear == 1 and absf(arena.current_power - p0) > 0.06)
	ada.hide_now()

	spot.focus(_castle_rect())
	ada.prompt("Leve a bandeira até o castelo e aperte ESPAÇO para atirar!", "proud", "PASSO 3")
	_hit_in_tutorial = false
	var shots_before: int = arena.goals.shots
	await _until(func(): return arena.goals.shots > shots_before)
	ada.hide_now()
	spot.clear()
	await _until(func(): return not _player_shot_alive())
	if _hit_in_tutorial:
		await _say([{"text": "Na mosca! A matemática levou a bala até o alvo.", "expr": "proud"}])
	else:
		await _say(
			[
				{
					"text": "Quase! Olhe onde caiu, ajuste e tente de novo. Cada tiro ensina.",
					"expr": "happy"
				}
			]
		)
	await _say(
		[
			{"text": "Os aviões vão acordar agora. Cuidado com as bombas!", "expr": "surprised"},
			{"text": "A ★ lá em cima mostra suas missões. Boa sorte, recruta!", "expr": "proud"},
		]
	)
	_freeze_enemies(false)
	Global.tutorial_done = true
	Global.save_game()
	in_tutorial = false


## Com a raiz fora da tela a bandeira vira uma seta na borda: a fala muda junto.
func _root_line() -> Dictionary:
	var r := Ballistics.root(arena.current_shot())
	if not is_nan(r) and Campaign.ORIGIN_X + Ballistics.to_px(r) > 1240.0:
		var txt := "A setinha diz que a bala cai depois da tela: %s m!" % Ballistics.fmt(r)
		return {"text": txt + " Menos força traz a bandeira de volta.", "expr": "surprised"}
	return {"text": "A bandeira mostra onde a bala cai. Confira na régua do chão!", "expr": "happy"}


func _say(lines: Array) -> void:
	ada.say(lines)
	await ada.finished


func _until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame


func _freeze_enemies(on: bool) -> void:
	for e in arena.active_enemies:
		if is_instance_valid(e) and not e.has_meta("is_boss"):
			e.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _player_shot_alive() -> bool:
	for c in arena.get_children():
		if c.has_meta("shot") and not c.is_queued_for_deletion():
			return true
	return false


func _vertex_rect() -> Rect2:
	var s: Dictionary = arena.current_shot()
	if not Ballistics.has_arc(s):
		return arena.trajectory.curve_rect()
	var p := Ballistics.point_px(s, Ballistics.vertex(s).x)
	return Rect2(p - Vector2(24, 34), Vector2(230, 56))


func _root_rect() -> Rect2:
	var s: Dictionary = arena.current_shot()
	var r := Ballistics.root(s)
	var x: float = s.origin_x_px + Ballistics.to_px(0.0 if is_nan(r) else r)
	x = minf(x, 1180.0)
	return Rect2(Vector2(x - 30, Campaign.GROUND_Y - 60), Vector2(220, 96))


func _castle_rect() -> Rect2:
	for e in arena.active_enemies:
		if is_instance_valid(e) and e.has_meta("is_boss"):
			return Rect2(e.global_position - Vector2(170, 110), Vector2(340, 200))
	return Rect2(Vector2(900, 400), Vector2(300, 250))


# ═════════════════════════════════════════════════════════════════════
#  DURANTE A LUTA
# ═════════════════════════════════════════════════════════════════════


func on_fire() -> void:
	_hit_since_fire = false


func on_hit() -> void:
	_hit_since_fire = true
	_hit_in_tutorial = true
	_misses = 0


## Bala do jogador sumiu (chao, montanha ou fora da tela). Tres erros seguidos
## viram uma dica da Ada: a primeira e a `tip` da fase; as seguintes olham o que
## aconteceu com o ultimo tiro.
func on_shot_ended(pos: Vector2, hit_obstacle: bool) -> void:
	if in_tutorial or _hit_since_fire:
		return
	_misses += 1
	if _misses < MISSES_FOR_TIP:
		return
	_misses = 0
	ada.pop(_next_tip(pos, hit_obstacle), "thinking", 5.5)


## No 1o limiar da fase vale a `tip` da fase; depois (ou sem `tip`), o ultimo tiro.
func _next_tip(pos: Vector2, hit_obstacle: bool) -> String:
	var tip := String(arena.stage_data.get("tip", ""))
	if not _stage_tip_given and tip.strip_edges() != "":
		_stage_tip_given = true
		return tip
	return _tip_for(pos, hit_obstacle)


func _tip_for(pos: Vector2, hit_obstacle: bool) -> String:
	if arena.inverted:
		return "Aqui a curva abre para cima: o vértice é o ponto mais baixo. Leve esse ponto até o alvo."
	if hit_obstacle and pos.y < Campaign.GROUND_Y - 8.0:
		return "A montanha bloqueou o tiro. Suba o vértice: mais ângulo ou mais força."
	var target := _castle_rect().get_center()
	if pos.x < target.x - 60.0:
		return "Faltou alcance. Aumente a força ou aproxime o ângulo de 45°."
	return "Passou do alvo. Reduza um pouco a força."


func on_stage_cleared() -> void:
	if ada.is_talking():
		ada.hide_now()
	ada.pop("Castelo derrubado. Vamos ver as estrelas.", "proud", 2.5)


# ═════════════════════════════════════════════════════════════════════
#  MISSOES (botao de estrela)
# ═════════════════════════════════════════════════════════════════════


func _on_goals_pressed() -> void:
	if arena.stage_cleared or busy() or arena.result.visible or arena.help_overlay.visible:
		return
	var goals: StageGoals = arena.goals
	var progress := []
	for i in range(goals.goals.size()):
		progress.append(goals.progress_text(i))
	arena.briefing.show_stage(
		Global.get_base_data(Global.current_base_id).get("name", ""),
		Campaign.base(Global.current_base_id).chapter,
		Global.current_stage + 1,
		arena.stage_data,
		goals.states,
		progress
	)


## Desafio mudou de estado: a Ada comemora o que foi cumprido; o que foi perdido
## vira um aviso discreto. A estrela do canto da um pulo nos dois casos.
func _on_goals_changed() -> void:
	var goals: StageGoals = arena.goals
	if not arena.stage_cleared:
		for i in range(goals.states.size()):
			if i < _prev_states.size() and goals.states[i] != _prev_states[i]:
				var text := Campaign.goal_text(goals.goals[i])
				if goals.states[i] == StageGoals.State.DONE:
					ada.pop("Desafio cumprido: " + text + ".", "proud", 3.5)
				else:
					arena.hud.show_toast("Desafio perdido: " + text, UiTokens.TEXT_DIM)
				arena.hud.pulse_goals()
	_prev_states = goals.states.duplicate()
	arena._refresh_goals()

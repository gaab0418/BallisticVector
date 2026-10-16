class_name Campaign
extends RefCounted
## Conteudo da campanha: cada base e um capitulo que ensina UMA ideia da
## parabola, e cada fase pratica um pedaco dela.
##
##   Alpha   -- o angulo (45°, angulos complementares, mirar por cima)
##   Bravo   -- a forca (v² na formula: metade da forca, um quarto do alcance)
##   Charlie -- a gravidade (Lua, Jupiter, Marte: o "a" da equacao)
##   Delta   -- a translacao (o tanque anda: so b e c mudam, o a nunca)
##   Echo    -- o vertice e o delta (a linha y = h: 2, 1 ou 0 solucoes)
##   Bonus   -- a Ilha Invertida (gravidade para cima: a > 0, vertice minimo)
##
## Chaves opcionais de uma fase, alem das basicas:
##   height_line -- altura (m) da linha y = h desenhada no mundo
##   balloons    -- [Vector2(x_px, altura_m)] balões amarrados ao chao
##   bunkers     -- [x_px] bunkers enterrados (so quebram com tiro caindo de cima)
##   tanks       -- {"count": n, "zone": Vector2(x1, x2)} tanques inimigos que andam
##   inverted    -- gravidade para cima (a > 0)
##   tank_height -- altura (m) do platô onde o tanque do jogador fica
##
## Toda fase tem tres estrelas. A primeira e vencer; as outras duas sao desafios
## que so se cumprem entendendo a conta (ver StageGoals).
##
## Coordenadas em pixels globais da arena (1280x720). Obstaculos sao poligonos
## com base em y = 720: a parte abaixo do chao (GROUND_Y) fica enterrada. Os
## pontos listados aqui sao os "picos"; a arena arredonda o contorno com
## rounded(), e forma visual e colisao continuam sendo o mesmo poligono.

## Linha do chao. O munhao do canhao fica 50 px (1,0 m) acima dela: o "c" da
## equacao no inicio de toda fase e a altura do canhao, 1 m.
const GROUND_Y: float = 652.0
## Marca 0 da regua: o munhao do canhao na posicao inicial do tanque.
const ORIGIN_X: float = 104.0

# Gravidades em px/s² (50 px = 1 m). Valores reais arredondados.
const G_MOON := 80.0  # 1,6 m/s²
const G_MARS := 185.0  # 3,7 m/s²
const G_EARTH := 490.0  # 9,8 m/s²
const G_JUPITER := 1240.0  # 24,8 m/s²
## Gravidade "para cima" da Ilha Invertida (negativa no motor).
const G_INVERTED := -400.0  # -8 m/s²

## Laboratorio: sem inimigos e sem montanhas; o mundo e escolhido no painel.
const LAB_STAGE := {
	"title": "Laboratório",
	"lesson": "",
	"tip": "",
	"obstacles": [],
	"boss_x": -1.0,
	"planes": 0,
	"plane_hp": 1,
	"goals": [],
}

## Mundos do Laboratorio: nome no botao, tema e gravidade (px/s²; vazio = a da
## municao, como na Terra).
const LAB_WORLDS := {
	"earth": {"name": "Terra", "planet": ""},
	"moon": {"name": "Lua", "planet": "moon", "gravity": G_MOON},
	"mars": {"name": "Marte", "planet": "mars", "gravity": G_MARS},
	"jupiter": {"name": "Júpiter", "planet": "jupiter", "gravity": G_JUPITER},
	"inverted":
	{"name": "Invertido", "planet": "inverted", "gravity": G_INVERTED, "inverted": true},
}


static func lab_stage(world_key: String) -> Dictionary:
	var st := LAB_STAGE.duplicate(true)
	var w: Dictionary = LAB_WORLDS.get(world_key, LAB_WORLDS["earth"])
	st.planet = w.planet
	if w.has("gravity"):
		st.gravity = w.gravity
	if w.get("inverted", false):
		st.inverted = true
		st.tank_height = 5.0
	return st


## Planetas que a engrenagem da gravidade reconhece, para a crianca ligar o
## numero a um lugar de verdade.
const PLANETS := [
	{"name": "Lua", "g": 1.6},
	{"name": "Marte", "g": 3.7},
	{"name": "Vênus", "g": 8.9},
	{"name": "Terra", "g": 9.8},
	{"name": "Júpiter", "g": 24.8},
]

## As tres montanhas da arena original.
const ORIGINAL_MOUNTAINS := [
	{"pos": Vector2(400, 720), "poly": [Vector2(-80, 0), Vector2(0, -280), Vector2(80, 0)]},
	{
		"pos": Vector2(680, 720),
		"poly": [Vector2(-100, 0), Vector2(-30, -340), Vector2(60, -320), Vector2(100, 0)]
	},
	{"pos": Vector2(550, 720), "poly": [Vector2(-60, 0), Vector2(0, -200), Vector2(70, 0)]},
]

const BASES := {
	"Base_A":
	{
		"chapter": "O ângulo",
		"icon": "angle",
		"blurb": "Descubra qual ângulo leva a bala mais longe.",
		"stages":
		[
			{
				"title": "Primeiro disparo",
				"lesson":
				(
					"Gire a engrenagem do ÂNGULO e repare: a curva muda de forma antes "
					+ "mesmo de você atirar. Essa curva é uma parábola!"
				),
				"tip": "Perto de 45° a bala vai mais longe.",
				"obstacles": ORIGINAL_MOUNTAINS,
				"boss_x": 1100.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "angle_hit", "min": 40.0, "max": 50.0},
					{"type": "max_shots", "value": 8},
				],
			},
			{
				"title": "Ângulos gêmeos",
				"lesson":
				(
					"30° e 60° somam 90°. Saindo do chão, ângulos assim caem no MESMO "
					+ "lugar: um faz uma curva baixa, o outro uma curva alta."
				),
				"tip": "Acerte o castelo duas vezes: uma abaixo de 45° e outra acima.",
				"obstacles":
				[
					{
						"pos": Vector2(560, 720),
						"poly":
						[Vector2(-120, 0), Vector2(-20, -150), Vector2(40, -160), Vector2(120, 0)]
					},
				],
				"boss_x": 1000.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "twin_angles"},
					{"type": "max_shots", "value": 7},
				],
			},
			{
				"title": "Por cima do paredão",
				"lesson":
				(
					"O ponto mais alto da parábola se chama VÉRTICE. Para passar por cima "
					+ "de uma montanha alta, o vértice precisa ficar acima dela."
				),
				"tip": "Mire alto: o losango mostra a altura máxima.",
				"obstacles":
				[
					{
						"pos": Vector2(820, 720),
						"poly":
						[Vector2(-70, 0), Vector2(-40, -400), Vector2(30, -420), Vector2(70, 0)]
					},
					{
						"pos": Vector2(420, 720),
						"poly": [Vector2(-70, 0), Vector2(0, -170), Vector2(70, 0)]
					},
				],
				"boss_x": 1110.0,
				"planes": 3,
				"plane_hp": 1,
				"goals":
				[
					{"type": "angle_hit", "min": 55.0, "max": 90.0},
					{"type": "vertex_hit", "value": 1.5},
				],
			},
		],
	},
	"Base_B":
	{
		"chapter": "A força",
		"icon": "force",
		"blurb": "A força conta duas vezes na conta: v².",
		"stages":
		[
			{
				"title": "Meia força",
				"lesson":
				(
					"A força aparece ao quadrado na conta (v²). Com METADE da força, a bala "
					+ "vai só a um QUARTO da distância. Confira na régua!"
				),
				"tip": "O castelo está perto: use pouca força.",
				"obstacles":
				[
					{
						"pos": Vector2(470, 720),
						"poly": [Vector2(-60, 0), Vector2(0, -150), Vector2(60, 0)]
					}
				],
				"boss_x": 760.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "power_hit", "max": 0.6},
					{"type": "max_shots", "value": 6},
				],
			},
			{
				"title": "Mesmo ângulo, outra força",
				"lesson":
				(
					"Deixe o ângulo parado e mexa só na força: o ponto de queda (a raiz) "
					+ "anda pela régua, mas a curva continua começando igual."
				),
				"tip": "Escolha um ângulo e não mexa mais nele.",
				"obstacles":
				[
					{
						"pos": Vector2(500, 720),
						"poly": [Vector2(-60, 0), Vector2(0, -190), Vector2(60, 0)]
					},
					{
						"pos": Vector2(860, 720),
						"poly": [Vector2(-50, 0), Vector2(0, -150), Vector2(50, 0)]
					},
				],
				"boss_x": 1150.0,
				"planes": 3,
				"plane_hp": 1,
				"goals":
				[
					{"type": "same_angle"},
					{"type": "max_shots", "value": 8},
				],
			},
			{
				"title": "Tiro longo",
				"lesson":
				(
					"Para ir o mais longe possível: força no máximo e ângulo perto de 45°. "
					+ "É o ponto máximo da função alcance!"
				),
				"tip": "O castelo está lá no fundo.",
				"obstacles":
				[
					{
						"pos": Vector2(480, 720),
						"poly":
						[Vector2(-90, 0), Vector2(-10, -260), Vector2(50, -250), Vector2(90, 0)]
					},
					{
						"pos": Vector2(830, 720),
						"poly": [Vector2(-80, 0), Vector2(0, -230), Vector2(80, 0)]
					},
				],
				"boss_x": 1180.0,
				"planes": 2,
				"plane_hp": 2,
				"tanks": {"count": 1, "zone": Vector2(960, 1120)},
				"goals":
				[
					{"type": "no_damage"},
					{"type": "max_shots", "value": 9},
				],
			},
		],
	},
	"Base_C":
	{
		"chapter": "A gravidade",
		"icon": "planet",
		"blurb": "Lua, Júpiter, Marte: cada lugar puxa de um jeito.",
		"stages":
		[
			{
				"title": "Na Lua",
				"lesson":
				(
					"Na Lua a gravidade é seis vezes mais fraca que na Terra. O número 'a' "
					+ "da equação fica bem pequeno, a parábola abre e a bala voa longe!"
				),
				"tip": "Use pouca força, senão a bala some no espaço.",
				"planet": "moon",
				"gravity": G_MOON,
				"obstacles":
				[
					{
						"pos": Vector2(520, 720),
						"poly": [Vector2(-90, 0), Vector2(0, -180), Vector2(90, 0)]
					},
				],
				"boss_x": 950.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "power_hit", "max": 0.4},
					{"type": "max_shots", "value": 6},
				],
			},
			{
				"title": "Em Júpiter",
				"lesson":
				(
					"Júpiter puxa duas vezes e meia mais forte que a Terra. O 'a' fica bem "
					+ "negativo, a parábola fecha e o tiro cai pertinho."
				),
				"tip": "O castelo está perto, mas a gravidade é enorme.",
				"planet": "jupiter",
				"gravity": G_JUPITER,
				"obstacles":
				[
					{
						"pos": Vector2(340, 720),
						"poly": [Vector2(-40, 0), Vector2(0, -120), Vector2(40, 0)]
					}
				],
				"boss_x": 600.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "keep_gravity"},
					{"type": "max_shots", "value": 6},
				],
			},
			{
				"title": "Em Marte",
				"lesson":
				(
					"Compare os planetas: quanto MAIOR a gravidade, MENOR o alcance. Na "
					+ "fórmula R = v²·sen(2θ)/g, a gravidade divide."
				),
				"tip": "Marte puxa menos que a Terra e mais que a Lua.",
				"planet": "mars",
				"gravity": G_MARS,
				"obstacles":
				[
					{
						"pos": Vector2(600, 720),
						"poly":
						[Vector2(-110, 0), Vector2(-30, -300), Vector2(40, -310), Vector2(110, 0)]
					},
				],
				"boss_x": 1120.0,
				"planes": 2,
				"plane_hp": 2,
				"bunkers": [900.0],
				"goals":
				[
					{"type": "keep_gravity"},
					{"type": "vertex_hit", "value": 1.5},
				],
			},
		],
	},
	"Base_D":
	{
		"chapter": "Translação",
		"icon": "move",
		"blurb": "Ande com o tanque e a parábola anda junto.",
		"stages":
		[
			{
				"title": "Rodas no chão",
				"lesson":
				(
					"Use A e D para andar com o tanque. A parábola inteira escorrega para o "
					+ "lado: o b e o c mudam, mas o 'a' (a abertura) continua igualzinho!"
				),
				"tip": "Ande até um ponto de onde o tiro passe pela montanha.",
				"move_zone": Vector2(40.0, 420.0),
				"obstacles":
				[
					{
						"pos": Vector2(560, 720),
						"poly":
						[Vector2(-60, 0), Vector2(-20, -330), Vector2(30, -340), Vector2(60, 0)]
					},
				],
				"boss_x": 1000.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "move_hit", "value": 2.0},
					{"type": "max_shots", "value": 6},
				],
			},
			{
				"title": "Fuja das bombas",
				"lesson":
				(
					"Na forma do vértice, y = a(x − h)² + k, o h diz onde fica o vértice. "
					+ "Andar com o tanque muda o h, e os aviões erram o alvo!"
				),
				"tip": "Não fique parado quando um avião passar por cima.",
				"move_zone": Vector2(40.0, 380.0),
				"obstacles":
				[
					{
						"pos": Vector2(520, 720),
						"poly": [Vector2(-60, 0), Vector2(0, -200), Vector2(60, 0)]
					},
					{
						"pos": Vector2(880, 720),
						"poly": [Vector2(-50, 0), Vector2(0, -240), Vector2(50, 0)]
					},
				],
				"boss_x": 1150.0,
				"planes": 2,
				"plane_hp": 2,
				"tanks": {"count": 1, "zone": Vector2(980, 1110)},
				"goals":
				[
					{"type": "no_damage"},
					{"type": "max_shots", "value": 8},
				],
			},
			{
				"title": "Batalha final",
				"lesson":
				(
					"Tudo junto: ângulo, força, gravidade e posição. Leia a equação, confira "
					+ "o vértice e a raiz na régua e mostre que você domina a parábola!"
				),
				"tip": "Planeje: onde a bala vai subir mais e onde vai cair?",
				"move_zone": Vector2(40.0, 330.0),
				"obstacles":
				[
					{
						"pos": Vector2(470, 720),
						"poly":
						[Vector2(-70, 0), Vector2(-20, -300), Vector2(30, -310), Vector2(70, 0)]
					},
					{
						"pos": Vector2(760, 720),
						"poly": [Vector2(-60, 0), Vector2(0, -210), Vector2(60, 0)]
					},
					{
						"pos": Vector2(960, 720),
						"poly": [Vector2(-40, 0), Vector2(0, -150), Vector2(40, 0)]
					},
				],
				"boss_x": 1180.0,
				"planes": 4,
				"plane_hp": 2,
				"goals":
				[
					{"type": "vertex_hit", "value": 1.5},
					{"type": "max_shots", "value": 10},
				],
			},
		],
	},
	"Base_E":
	{
		"chapter": "O vértice e o delta",
		"icon": "target",
		"blurb": "A linha y = h: a bala passa por ela 2, 1 ou 0 vezes?",
		"stages":
		[
			{
				"title": "Na altura certa",
				"lesson":
				(
					"A linha tracejada é y = 5. Onde a parábola cruza a linha, a bala está a "
					+ "5 m de altura. A conta ax² + bx + c = 5 tem DUAS soluções: a bala passa "
					+ "por 5 m subindo e de novo descendo!"
				),
				"tip": "Os pontinhos na linha são as soluções. Estoure os balões!",
				"height_line": 5.0,
				"balloons": [Vector2(700, 5.0), Vector2(860, 5.0), Vector2(1020, 5.0)],
				"obstacles":
				[
					{
						"pos": Vector2(500, 720),
						"poly": [Vector2(-60, 0), Vector2(0, -130), Vector2(60, 0)]
					}
				],
				"boss_x": 1180.0,
				"planes": 0,
				"plane_hp": 1,
				"goals":
				[
					{"type": "up_down"},
					{"type": "max_shots", "value": 8},
				],
			},
			{
				"title": "A muralha",
				"lesson":
				(
					"A muralha tem 7 m. A bala só passa se a parábola chegar a y = 7. Se o "
					+ "delta de ax² + bx + c = 7 der NEGATIVO, a curva nunca chega lá: aumente "
					+ "o ângulo ou a força."
				),
				"tip": "Atrás da muralha tem um bunker: ele só quebra com tiro caindo de cima.",
				"height_line": 7.0,
				"obstacles":
				[
					{
						"pos": Vector2(760, 720),
						"poly":
						[
							Vector2(-55, 0),
							Vector2(-38, -380),
							Vector2(-20, -418),
							Vector2(20, -418),
							Vector2(38, -380),
							Vector2(55, 0),
						]
					},
				],
				"bunkers": [1010.0],
				"boss_x": 1180.0,
				"planes": 1,
				"plane_hp": 1,
				"goals":
				[
					{"type": "vertex_band", "min": 7.0, "max": 8.5},
					{"type": "max_shots", "value": 9},
				],
			},
			{
				"title": "Toque no vértice",
				"lesson":
				(
					"Quando o vértice fica exatamente na linha, a curva só ENCOSTA nela: uma "
					+ "solução só, e o delta vale zero. Acerte um balão bem no ponto mais alto!"
				),
				"tip": 'Ajuste até aparecer "Δ = 0" ao lado da linha.',
				"height_line": 6.0,
				"balloons": [Vector2(640, 6.0), Vector2(980, 6.0)],
				"obstacles":
				[
					{
						"pos": Vector2(820, 720),
						"poly": [Vector2(-60, 0), Vector2(0, -210), Vector2(60, 0)]
					}
				],
				"boss_x": 1160.0,
				"planes": 2,
				"plane_hp": 1,
				"goals":
				[
					{"type": "vertex_hit", "value": 0.6},
					{"type": "max_shots", "value": 8},
				],
			},
		],
	},
	"Base_Z":
	{
		"chapter": "Bônus: a > 0",
		"icon": "planet",
		"blurb": "Gravidade para cima! A parábola abre como um sorriso.",
		"stages":
		[
			{
				"title": "De cabeça para baixo",
				"lesson":
				(
					"Aqui a gravidade puxa para CIMA. O 'a' fica POSITIVO e a parábola abre "
					+ "para cima, como um sorriso. O vértice agora é o ponto mais BAIXO da curva."
				),
				"tip": "Aponte o canhão para baixo: a bala desce, faz a curva e sobe.",
				"planet": "inverted",
				"inverted": true,
				"gravity": G_INVERTED,
				"tank_height": 5.0,
				"balloons": [Vector2(980, 9.0), Vector2(1140, 10.5)],
				"obstacles": [],
				"boss_x": 760.0,
				"planes": 0,
				"plane_hp": 1,
				"goals":
				[
					{"type": "vertex_band", "min": 0.0, "max": 2.5},
					{"type": "max_shots", "value": 7},
				],
			},
			{
				"title": "Sorriso de bala",
				"lesson":
				(
					"Com a > 0 o vértice é um MÍNIMO. Para acertar o castelo no chão, o ponto "
					+ "mais baixo da curva precisa passar por ele."
				),
				"tip": "Pouca força e cano para baixo levam o vértice para perto.",
				"planet": "inverted",
				"inverted": true,
				"gravity": -300.0,
				"tank_height": 3.5,
				"balloons": [Vector2(720, 7.0), Vector2(1190, 9.0)],
				"obstacles":
				[
					{
						"pos": Vector2(470, 720),
						"poly": [Vector2(-50, 0), Vector2(0, -150), Vector2(50, 0)]
					}
				],
				"boss_x": 1040.0,
				"planes": 0,
				"plane_hp": 1,
				"goals":
				[
					{"type": "vertex_band", "min": 0.0, "max": 2.5},
					{"type": "max_shots", "value": 8},
				],
			},
		],
	},
}


## Contorno arredondado de um obstaculo: spline de Catmull-Rom que passa pelos
## pontos originais, entao a altura dos picos se mantem. Visual e colisao usam
## este mesmo poligono.
static func rounded(points: Array, samples: int = 14) -> PackedVector2Array:
	var pts: Array = points.duplicate()
	var out := PackedVector2Array()
	var n := pts.size()
	for i in range(n - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for k in range(samples):
			var t := float(k) / samples
			var t2 := t * t
			var t3 := t2 * t
			var q := (
				0.5
				* (
					2.0 * p1
					+ (p2 - p0) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
				)
			)
			# Nunca abaixo da base: o poligono fecha pela linha y = 0.
			out.append(Vector2(q.x, minf(q.y, 0.0)))
	out.append(pts[n - 1])
	return out


static func base(base_id: String) -> Dictionary:
	return BASES.get(base_id, BASES["Base_A"])


static func stage(base_id: String, index: int) -> Dictionary:
	var stages: Array = base(base_id)["stages"]
	var st: Dictionary = stages[clampi(index, 0, stages.size() - 1)]
	return with_fuel(base_id, st)


## Fora da Delta (que ensina a translacao com faixa livre), o tanque anda pouco:
## um tanque de combustivel por fase, para ajustar a posicao sem virar a licao.
## Alpha fica parada (tutorial) e o plato nao tem chao para andar.
const FUEL_BASES := ["Base_B", "Base_C", "Base_E"]
const FUEL_M := 3.0
const FUEL_ZONE := Vector2(40.0, 250.0)


static func with_fuel(base_id: String, st: Dictionary) -> Dictionary:
	if not base_id in FUEL_BASES or st.has("move_zone") or st.has("tank_height"):
		return st
	var out := st.duplicate()
	out["move_zone"] = FUEL_ZONE
	out["fuel_m"] = FUEL_M
	return out


## Frase curta do desafio, para o briefing, a HUD e a tela de resultado.
static func goal_text(goal: Dictionary) -> String:
	match goal.get("type", ""):
		"angle_hit":
			if goal.max >= 90.0:
				return "Acerte o castelo com ângulo acima de %d°" % roundi(goal.min)
			return "Acerte o castelo com ângulo de %d° a %d°" % [roundi(goal.min), roundi(goal.max)]
		"twin_angles":
			return "Acerte o castelo abaixo e acima de 45°"
		"max_shots":
			return "Vença com até %d tiros" % goal.value
		"vertex_hit":
			return "Acerte um avião ou balão no vértice (±%s m)" % Ballistics.fmt(goal.value)
		"vertex_band":
			return (
				"Acerte o castelo com o vértice entre %s e %s m"
				% [Ballistics.fmt(goal.min), Ballistics.fmt(goal.max)]
			)
		"up_down":
			return "Estoure um balão com a bala subindo e outro descendo"
		"power_hit":
			return "Acerte o castelo com força até %d%%" % roundi(goal.max * 100.0)
		"same_angle":
			return "Vença sem mudar o ângulo"
		"no_damage":
			return "Vença sem levar dano"
		"keep_gravity":
			return "Vença sem mexer na gravidade"
		"move_hit":
			return "Ande %s m e acerte o castelo" % Ballistics.fmt(goal.value)
	return ""


## Planeta mais parecido com uma gravidade em m/s², ou "" se nenhum estiver perto.
static func planet_like(g_m: float) -> String:
	var best := ""
	var best_err := INF
	for p in PLANETS:
		var err: float = absf(g_m - p.g) / p.g
		if err < best_err:
			best_err = err
			best = p.name
	return best if best_err <= 0.12 else ""

class_name Campaign
extends RefCounted
## Conteudo da campanha: cada base e um capitulo que ensina UMA ideia da
## parabola, e cada fase pratica um pedaco dela.
##
##   Alpha   -- o angulo (45°, angulos complementares, mirar por cima)
##   Bravo   -- a forca (v² na formula: metade da forca, um quarto do alcance)
##   Charlie -- a gravidade (Lua, Jupiter, Marte: o "a" da equacao)
##   Delta   -- a translacao (o tanque anda: so b e c mudam, o a nunca)
##
## Antes as tres bases eram a mesma arena com mais avioes. A fisica nao mudou:
## so o cenario, os inimigos e o que se pede do jogador.
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

## Planetas que a engrenagem da gravidade reconhece, para a crianca ligar o
## numero a um lugar de verdade.
const PLANETS := [
	{"name": "Lua", "g": 1.6},
	{"name": "Marte", "g": 3.7},
	{"name": "Vênus", "g": 8.9},
	{"name": "Terra", "g": 9.8},
	{"name": "Júpiter", "g": 24.8},
]

## As tres montanhas da arena original, intactas.
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
				"planes": 3,
				"plane_hp": 2,
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
				"planes": 3,
				"plane_hp": 2,
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
				"planes": 3,
				"plane_hp": 2,
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
}


## Contorno arredondado de um obstaculo: spline de Catmull-Rom passando pelos
## pontos originais. Como a curva passa pelos picos, a altura de cada montanha
## continua a mesma; so os cantos viram curva. Visual e colisao usam ESTE
## poligono, entao continuam identicos.
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
	return stages[clampi(index, 0, stages.size() - 1)]


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
			return "Derrube um avião no vértice (±%s m)" % Ballistics.fmt(goal.value)
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

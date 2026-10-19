class_name Notebook
extends RefCounted
## Paginas do Caderno da Ada: uma por fase. A pagina abre quando a fase e
## vencida (tem estrela). `anim` escolhe a animacao de AnimatedDiagram e `p` os
## parametros dela.

const PAGES := [
	{
		"base": "Base_A", "stage": 0, "title": "A parábola",
		"text": "A bala sobe, perde velocidade, para um instante lá no alto e cai. Esse caminho é uma PARÁBOLA.",
		"formula": "y = ax² + bx + c", "anim": "fly", "p": {"angle": 45.0},
	},
	{
		"base": "Base_A", "stage": 1, "title": "Ângulos gêmeos",
		"text": "30° e 60° somam 90°. Saindo do chão, eles caem no mesmo lugar: um voa baixo, o outro voa alto.",
		"formula": "θ e 90° − θ: mesmo alcance", "anim": "angles", "p": {"list": [30.0, 60.0]},
	},
	{
		"base": "Base_A", "stage": 2, "title": "O vértice",
		"text": "O ponto mais alto da curva é o VÉRTICE. Para passar por cima de uma montanha, ele precisa ficar acima dela.",
		"formula": "x do vértice = −b / 2a", "anim": "fly", "p": {"angle": 60.0, "mark": "vertex"},
	},
	{
		"base": "Base_B", "stage": 0, "title": "A força ao quadrado",
		"text": "A força entra duas vezes na conta. Com o dobro da força, a bala vai QUATRO vezes mais longe!",
		"formula": "força × 2  →  alcance × 4", "anim": "power", "p": {},
	},
	{
		"base": "Base_B", "stage": 1, "title": "Mesmo ângulo, outra força",
		"text": "Com o ângulo parado, a curva sai sempre do mesmo jeito. A força só estica ou encolhe a parábola.",
		"formula": "b = tg θ não muda", "anim": "power_steps", "p": {},
	},
	{
		"base": "Base_B", "stage": 2, "title": "O alcance máximo",
		"text": "Girando o ângulo, o alcance cresce, chega no máximo perto de 45° e depois diminui.",
		"formula": "maior alcance: 45°", "anim": "sweep", "p": {},
	},
	{
		"base": "Base_C", "stage": 0, "title": "Na Lua",
		"text": "Na Lua a gravidade é fraquinha. O 'a' fica pequeno, a parábola abre e a bala voa muito longe.",
		"formula": "a = −g / (2v²cos²θ)", "anim": "gravity", "p": {"from": 80.0, "to": 490.0},
	},
	{
		"base": "Base_C", "stage": 1, "title": "Em Júpiter",
		"text": "Júpiter puxa forte! O 'a' fica bem negativo e a parábola fecha: o tiro cai pertinho.",
		"formula": "g maior → curva mais fechada", "anim": "gravity", "p": {"from": 490.0, "to": 1240.0},
	},
	{
		"base": "Base_C", "stage": 2, "title": "Comparando planetas",
		"text": "Lua, Marte, Terra e Júpiter: quanto maior a gravidade, menor o alcance. A gravidade divide a conta.",
		"formula": "alcance = v²·sen(2θ) / g", "anim": "planets", "p": {},
	},
	{
		"base": "Base_D", "stage": 0, "title": "Translação",
		"text": "Andando com o tanque, a parábola inteira escorrega. O b e o c mudam, mas o 'a' nunca muda!",
		"formula": "a fica igual", "anim": "shift", "p": {},
	},
	{
		"base": "Base_D", "stage": 1, "title": "A forma do vértice",
		"text": "Escrevendo y = a(x − h)² + k, o h diz onde o vértice está e o k diz a altura dele.",
		"formula": "y = a(x − h)² + k", "anim": "shift", "p": {"show_hk": true},
	},
	{
		"base": "Base_D", "stage": 2, "title": "Tudo junto",
		"text": "Ângulo, força, gravidade e posição: cada um mexe num pedaço da conta. Você domina todos!",
		"formula": "y = ax² + bx + c", "anim": "fly", "p": {"angle": 35.0, "wobble": true},
	},
	{
		"base": "Base_E", "stage": 0, "title": "Duas soluções",
		"text": "A linha y = 5 corta a parábola em dois pontos: a bala passa por 5 m subindo e de novo descendo.",
		"formula": "Δ > 0: duas soluções", "anim": "line", "p": {"h": 5.0, "angle": 45.0},
	},
	{
		"base": "Base_E", "stage": 1, "title": "Nenhuma solução",
		"text": "Se a curva fica abaixo da linha, a bala nunca chega àquela altura. O delta dá negativo.",
		"formula": "Δ < 0: nenhuma solução", "anim": "line", "p": {"h": 9.0, "angle": 40.0},
	},
	{
		"base": "Base_E", "stage": 2, "title": "Uma solução",
		"text": "Quando o vértice encosta na linha, a curva só toca nela uma vez. O delta vale zero.",
		"formula": "Δ = 0: uma solução", "anim": "line", "p": {"touch": true, "angle": 50.0},
	},
	{
		"base": "Base_F", "stage": 0, "title": "A reta da rota",
		"text": "O drone voa em linha reta: y = mx + n. O m diz o quanto a reta sobe a cada metro, o n onde ela corta o eixo y.",
		"formula": "y = mx + n", "anim": "intercept", "p": {"m": 0.15, "n": 2.0},
	},
	{
		"base": "Base_F", "stage": 1, "title": "Parábola encontra reta",
		"text": "Onde a bala cruza a rota, as duas contas dão o mesmo y. É só igualar: ax² + bx + c = mx + n.",
		"formula": "ax² + (b − m)x + (c − n) = 0", "anim": "intercept", "p": {"m": -0.1, "n": 7.0},
	},
	{
		"base": "Base_F", "stage": 2, "title": "Tempo de voo",
		"text": "A bala anda sempre a mesma distância para o lado por segundo. Por isso dá para saber QUANDO ela chega no encontro.",
		"formula": "t = x / (v · cos θ)", "anim": "intercept", "p": {"m": 0.1, "n": 3.0, "drone": true},
	},
	{
		"base": "Base_N", "stage": 0, "title": "O quique",
		"text": "No gelo a bala quica e faz uma parábola menor. O 'a' é o mesmo: só a subida de saída diminui.",
		"formula": "a igual, b menor", "anim": "bounce", "p": {},
	},
	{
		"base": "Base_N", "stage": 1, "title": "O intervalo",
		"text": "Cair entre 12 e 15 m é um INTERVALO: a raiz precisa ser maior que 12 e menor que 15.",
		"formula": "12 < raiz < 15", "anim": "zone", "p": {"from": 12.0, "to": 15.0},
	},
	{
		"base": "Base_N", "stage": 2, "title": "O máximo da função",
		"text": "Com a força parada, o alcance é uma função do ângulo. Ela sobe, chega no máximo em 45° e desce.",
		"formula": "alcance máximo em 45°", "anim": "sweep", "p": {},
	},
	{
		"base": "Base_Z", "stage": 0, "title": "Quando a > 0",
		"text": "Com a gravidade para cima, o 'a' fica positivo e a parábola abre para cima, como um sorriso.",
		"formula": "a > 0: boca para cima", "anim": "flip", "p": {},
	},
	{
		"base": "Base_Z", "stage": 1, "title": "O vértice mínimo",
		"text": "Na parábola sorriso, o vértice é o ponto mais BAIXO. É ele que precisa passar pelo alvo.",
		"formula": "a > 0: vértice é o mínimo", "anim": "flip", "p": {"mark": "vertex"},
	},
]


static func page_id(page: Dictionary) -> String:
	return "%s_%d" % [page.base, page.stage]


## A pagina abre quando a fase dela ja foi vencida (ganhou estrela).
static func is_unlocked(page: Dictionary) -> bool:
	var stars: Array = Global.get_base_data(page.base).get("stars", [])
	return page.stage < stars.size() and int(stars[page.stage]) > 0


static func unseen_count() -> int:
	var n := 0
	for page in PAGES:
		if is_unlocked(page) and not Global.notebook_seen.has(page_id(page)):
			n += 1
	return n


static func page_for(base_id: String, stage: int) -> Dictionary:
	for page in PAGES:
		if page.base == base_id and page.stage == stage:
			return page
	return {}

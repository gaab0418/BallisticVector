class_name Ballistics
extends RefCounted
## A matematica do tiro, num lugar so.
##
## Antes a escala pixel->metro existia so na HUD (parabola_hud.gd), a mira
## simulava por Euler com outro passo de tempo e a linha desenhada ficava 54 px
## atras de onde a bala nascia. Tres fontes de verdade que quase concordavam.
## Agora fisica (arena), mira (trajectory_view), HUD e regua leem daqui, entao o
## alcance escrito na tela e o ponto de queda desenhado sao a mesma conta.
##
## Sistema de coordenadas "da crianca", em metros:
##   x -- horizontal, zero na marca 0 da regua (o munhao do canhao no inicio da fase)
##   y -- altura acima do chao
## Nele a trajetoria e exatamente y = a*x^2 + b*x + c. Com o tanque parado no
## zero, a so depende de forca, gravidade e angulo, b e a tangente do angulo e c e
## a altura do canhao -- e o que a HUD ensina.

## Fonte unica da escala. Com 50 px/m os stats caem redondos: Enferrujada
## 16 m/s e 10 m/s² (a Terra), Perfurante 18 m/s e 6 m/s².
const PX_PER_METER: float = 50.0

## Abaixo disto o canhao nao forma arco para cima: nao ha vertice a frente.
const MIN_ARC_DEG: float = 0.5


static func to_m(px: float) -> float:
	return px / PX_PER_METER


static func to_px(m: float) -> float:
	return m * PX_PER_METER


## Estado de um tiro, ja nas unidades da crianca.
##   angle_deg   -- elevacao do cano (positivo = para cima)
##   speed_px    -- velocidade de saida, px/s
##   gravity_px  -- px/s²
##   pivot       -- de onde a bala sai, em coordenadas globais (px)
##   origin_x_px -- x global da marca 0 da regua
##   ground_y_px -- y global do chao
static func shot(
	angle_deg: float,
	speed_px: float,
	gravity_px: float,
	pivot: Vector2,
	origin_x_px: float,
	ground_y_px: float
) -> Dictionary:
	var theta := deg_to_rad(angle_deg)
	var v := to_m(speed_px)
	var g := to_m(gravity_px)
	var xt := to_m(pivot.x - origin_x_px)
	var c0 := to_m(ground_y_px - pivot.y)
	var t := tan(theta)
	var cos2: float = maxf(cos(theta) * cos(theta), 0.0001)
	var a := -g / (2.0 * v * v * cos2)
	return {
		"angle_deg": angle_deg,
		"v": v,
		"g": g,
		"x_tank": xt,
		"h_cannon": c0,
		"t": t,
		# Forma geral y = a x² + b x + c, com o deslocamento do tanque ja expandido.
		"a": a,
		"b": t - 2.0 * a * xt,
		"c": c0 - t * xt + a * xt * xt,
		"origin_x_px": origin_x_px,
		"ground_y_px": ground_y_px,
	}


## Altura (m) da trajetoria na posicao x (m).
static func y_at(s: Dictionary, x: float) -> float:
	return s.a * x * x + s.b * x + s.c


## Ponto da trajetoria em coordenadas globais de tela.
static func point_px(s: Dictionary, x: float) -> Vector2:
	return Vector2(s.origin_x_px + to_px(x), s.ground_y_px - to_px(y_at(s, x)))


## O vertice so conta se estiver a frente do canhao: com o cano apontado para
## baixo a parabola continua tendo vertice, mas atras da bala, e dizer "a bala
## sobe ate aqui" seria mentira. Vale tambem para o Mundo Invertido (a > 0), onde
## o vertice e o ponto mais BAIXO e fica a frente quando o cano aponta para baixo.
static func has_arc(s: Dictionary) -> bool:
	return vertex(s).x > s.x_tank + 0.02


## Parabola "de boca para cima" (a > 0): so acontece com a gravidade invertida.
static func opens_up(s: Dictionary) -> bool:
	return s.a > 0.0


## Vertice (x, y) em metros: x = -b/2a e y = -Δ/4a.
static func vertex(s: Dictionary) -> Vector2:
	var xv: float = -s.b / (2.0 * s.a)
	return Vector2(xv, y_at(s, xv))


static func delta(s: Dictionary) -> float:
	return s.b * s.b - 4.0 * s.a * s.c


## Raiz da frente (onde a bala toca o chao), por Bhaskara: (-b - √Δ) / 2a.
## Com a < 0 e a raiz da direita (a unica a frente); com a > 0 e a primeira
## descida ate o chao. Sem raiz (curva que nunca toca o chao), devolve NAN.
static func root(s: Dictionary) -> float:
	var d := delta(s)
	if d < 0.0:
		return NAN
	var r: float = (-s.b - sqrt(d)) / (2.0 * s.a)
	return r if r > s.x_tank else NAN


static func has_root(s: Dictionary) -> bool:
	return not is_nan(root(s))


## Delta da equacao ax² + bx + c = h: diz quantas vezes a curva passa pela
## altura h (2 se > 0, 1 se = 0 -- o vertice encosta na linha --, 0 se < 0).
static func delta_at(s: Dictionary, h: float) -> float:
	return s.b * s.b - 4.0 * s.a * (s.c - h)


## Os x (a frente do canhao, em ordem) onde a bala esta exatamente na altura h.
static func crossings(s: Dictionary, h: float) -> Array:
	var d := delta_at(s, h)
	if d < 0.0:
		return []
	var r1: float = (-s.b - sqrt(d)) / (2.0 * s.a)
	var r2: float = (-s.b + sqrt(d)) / (2.0 * s.a)
	var out := []
	for r in [minf(r1, r2), maxf(r1, r2)]:
		if r > s.x_tank and not out.has(r):
			out.append(r)
	return out


## Faixa no chao onde a bala pode cair, dado o desvio maximo do cano. Amostrado,
## e nao so nas pontas: o alcance passa por um maximo perto de 45°, e se esse
## angulo estiver dentro do intervalo e la que a faixa termina.
static func landing_band(
	angle_deg: float,
	spread_deg: float,
	speed_px: float,
	gravity_px: float,
	pivot: Vector2,
	origin_x_px: float,
	ground_y_px: float
) -> Vector2:
	var lo := INF
	var hi := -INF
	var samples := 16
	for i in range(samples + 1):
		var ang := angle_deg - spread_deg + 2.0 * spread_deg * float(i) / samples
		var s := shot(ang, speed_px, gravity_px, pivot, origin_x_px, ground_y_px)
		var r := root(s)
		if is_nan(r):
			continue
		lo = minf(lo, r)
		hi = maxf(hi, r)
	if lo > hi:
		return Vector2(1, 0)
	return Vector2(lo, hi)


## Quais coeficientes (a, b, c) cada engrenagem -- angulo, forca, gravidade --
## mexe AGORA, medido mexendo um pouquinho em cada uma. Com o tanque no zero:
## angulo -> a e b; forca e gravidade -> so a. Com o tanque fora do zero,
## tudo passa a mexer em b e c tambem. E o que os chips "a b c" da HUD mostram.
static func gear_effects(
	angle_deg: float, speed_px: float, gravity_px: float, pivot: Vector2, ox: float, gy: float
) -> Array:
	var base := shot(angle_deg, speed_px, gravity_px, pivot, ox, gy)
	var probes := [
		shot(angle_deg + 0.5, speed_px, gravity_px, pivot, ox, gy),
		shot(angle_deg, speed_px * 1.01, gravity_px, pivot, ox, gy),
		shot(angle_deg, speed_px, gravity_px * 1.01, pivot, ox, gy),
	]
	var out := []
	for p in probes:
		var letters := ""
		for k in ["a", "b", "c"]:
			if absf(p[k] - base[k]) > 1e-6 * maxf(1.0, absf(base[k])):
				letters += k
		out.append(letters)
	return out


# ═════════════════════════════════════════════════════════════════════
#  FORMATACAO -- numeros em portugues, com virgula e sinal de menos de verdade
# ═════════════════════════════════════════════════════════════════════


static func fmt(value: float, decimals: int = 1) -> String:
	var txt := ("%." + str(decimals) + "f") % absf(value)
	txt = txt.replace(".", ",")
	# "−0,0" para um numero que arredondou para zero confunde: some o sinal.
	if value < 0.0 and txt.replace("0", "").replace(",", "") != "":
		return "−" + txt
	return txt


## Um termo do polinomio ja com o sinal separado: "+ 0,62x", "− 0,03x²".
## O primeiro termo leva o sinal colado ("−0,027x²").
static func term(value: float, decimals: int, suffix: String, first: bool = false) -> String:
	var mag := fmt(absf(value), decimals) + suffix
	if first:
		return ("−" if value < 0.0 else "") + mag
	return ("− " if value < 0.0 else "+ ") + mag

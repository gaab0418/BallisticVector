extends Node2D
## Fundo da arena: ceu em faixas, estrelas, um disco no ceu, duas cordilheiras
## ao longe e nuvens em parallax.
##
## Substitui o ColorRect de cor aleatoria. Tudo e desenhado em codigo com a
## paleta do tema do planeta (UiTokens.WORLD_*), em blocos de UiTokens.PX * 2
## pixels: e o mesmo grao de pixel art das molduras da HUD.
##
## O ceu e "posterizado" -- faixas de cor solida em vez de gradiente liso --
## porque gradiente suave denuncia arte digital no meio de sprites de pixel art.

const WIDTH := 1280.0
const SKY_BANDS := 22
const STAR_COUNT := 70
const CLOUD_COUNT := 7

var theme_colors: Dictionary = UiTokens.WORLD_EARTH
var horizon_y := 652.0
var _seed := 7
var _clouds: Array = []
var _time := 0.0
# Cordilheiras calculadas uma vez em setup(): so as nuvens e as estrelas mudam
# a cada quadro, e refazer a subdivisao com RNG 60 vezes por segundo era gasto.
var _far := {}
var _mid := {}


func setup(world: Dictionary, ground_y: float, seed_value: int) -> void:
	theme_colors = world
	horizon_y = ground_y
	_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_clouds.clear()
	for i in range(CLOUD_COUNT):
		(
			_clouds
			. append(
				{
					"x": rng.randf_range(0.0, WIDTH),
					"y": rng.randf_range(60.0, horizon_y * 0.55),
					"w": rng.randf_range(90.0, 220.0),
					# Nuvem mais alta = mais longe = mais devagar: e o parallax.
					"speed": rng.randf_range(3.0, 9.0),
				}
			)
		)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_disc()
	_draw_range(_far, theme_colors.far)
	_draw_clouds()
	_draw_range(_mid, theme_colors.mid)


func _draw_sky() -> void:
	var sky: Array = theme_colors.sky
	var band_h := ceilf(horizon_y / SKY_BANDS)
	for i in range(SKY_BANDS):
		var t := float(i) / (SKY_BANDS - 1)
		draw_rect(Rect2(0, i * band_h, WIDTH, band_h + 1), _sky_at(sky, t))


## Tres trechos de interpolacao entre as quatro cores do tema. O brilho do
## horizonte fica concentrado no ultimo quinto do ceu, como num por do sol.
func _sky_at(sky: Array, t: float) -> Color:
	if t < 0.55:
		return sky[0].lerp(sky[1], t / 0.55)
	if t < 0.85:
		return sky[1].lerp(sky[2], (t - 0.55) / 0.3)
	return sky[2].lerp(sky[3], (t - 0.85) / 0.15)


func _draw_stars() -> void:
	var amount: float = theme_colors.get("stars", 0.0)
	if amount <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 3
	var px := float(UiTokens.PX)
	for i in range(int(STAR_COUNT * amount)):
		var p := Vector2(rng.randf_range(0, WIDTH), rng.randf_range(0, horizon_y * 0.6))
		# Cintilar devagar: cada estrela tem a sua fase.
		var tw := 0.55 + 0.45 * sin(_time * 1.3 + i * 1.7)
		var col := Color(UiTokens.STAR_LIGHT, tw * (0.3 + 0.7 * (1.0 - p.y / horizon_y)))
		var s := px * (2.0 if i % 9 == 0 else 1.0)
		draw_rect(Rect2(p.snapped(Vector2(px, px)), Vector2(s, s)), col)


## Sol baixo no crepusculo, a Terra vista da Lua, o Sol palido de Marte. Disco
## em degraus de pixel (circulos concentricos), sem anti-aliasing.
func _draw_disc() -> void:
	var col: Color = theme_colors.disc
	var c := Vector2(WIDTH * 0.74, horizon_y * 0.58)
	draw_circle(c, 46.0, Color(col, 0.12), true, -1.0, false)
	draw_circle(c, 36.0, Color(col, 0.22), true, -1.0, false)
	draw_circle(c, 26.0, col, true, -1.0, false)
	draw_circle(c + Vector2(-7, -7), 9.0, UiTokens.SHINE, true, -1.0, false)


## Cordilheira por deslocamento do ponto medio, com semente fixa: a mesma fase
## sempre tem o mesmo horizonte, e cada fase tem o seu. Devolve o poligono e os
## picos (onde vai a aresta clara do lado da luz).
func _build_range(height: float, rough: float, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := 64
	var hs := PackedFloat32Array()
	hs.resize(n + 1)
	hs[0] = rng.randf_range(0.3, 0.8)
	hs[n] = rng.randf_range(0.3, 0.8)
	_subdivide(hs, 0, n, rough, rng)

	var step := WIDTH / n
	var px := float(UiTokens.PX * 2)
	var poly := PackedVector2Array()
	poly.append(Vector2(0, horizon_y + 4))
	for i in range(n + 1):
		poly.append(Vector2(i * step, horizon_y - hs[i] * height).snapped(Vector2(px, px)))
	poly.append(Vector2(WIDTH, horizon_y + 4))

	var peaks := PackedVector2Array()
	for i in range(1, n):
		if hs[i] > hs[i - 1] and hs[i] > hs[i + 1]:
			peaks.append(Vector2(i * step, horizon_y - hs[i] * height))
	return {"poly": poly, "peaks": peaks, "step": step}


func _draw_range(data: Dictionary, col: Color) -> void:
	if data.is_empty():
		return
	draw_colored_polygon(data.poly, col)
	# Picos com uma aresta clara do lado da luz, como no camp.jpg.
	var light := col.lightened(0.18)
	var step: float = data.step
	for p in data.peaks:
		draw_line(p, p + Vector2(-step * 0.9, step * 0.72), light, float(UiTokens.PX * 2))


func _subdivide(
	hs: PackedFloat32Array, a: int, b: int, rough: float, rng: RandomNumberGenerator
) -> void:
	if b - a < 2:
		return
	var m := int((a + b) / 2.0)
	hs[m] = clampf((hs[a] + hs[b]) * 0.5 + rng.randf_range(-rough, rough), 0.05, 1.0)
	_subdivide(hs, a, m, rough * 0.55, rng)
	_subdivide(hs, m, b, rough * 0.55, rng)


func _draw_clouds() -> void:
	var px := float(UiTokens.PX * 2)
	for c in _clouds:
		var w: float = c.w
		var y: float = c.y
		var x0: float = c.x
		var speed: float = c.speed
		var x := fposmod(x0 + _time * speed, WIDTH + w * 2.0) - w
		# Tres faixas empilhadas e escalonadas: nuvem de pixel art.
		draw_rect(Rect2(Vector2(x, y).snapped(Vector2(px, px)), Vector2(w, px * 2)), UiTokens.CLOUD)
		draw_rect(
			Rect2(
				Vector2(x + w * 0.15, y - px * 2).snapped(Vector2(px, px)),
				Vector2(w * 0.55, px * 2)
			),
			UiTokens.CLOUD
		)
		draw_rect(
			Rect2(Vector2(x + w * 0.3, y + px * 2).snapped(Vector2(px, px)), Vector2(w * 0.6, px)),
			UiTokens.CLOUD
		)

class_name ArenaFx
extends Node2D
## Efeitos curtos da arena: clarao do disparo, poeira de impacto, explosao e
## numero flutuante. Cada efeito e um no que se desenha e se apaga sozinho.
##
## Todos duram menos de um segundo e ficam longe da linha de mira na maior
## parte do tempo: feedback sem atrapalhar a leitura da parabola.
##
## Particulas sao quadrados no grao de pixel da HUD (UiTokens.PX), em vez de
## GPUParticles2D, que no GL Compatibility tem limites e aqui seria exagero.

enum Kind { MUZZLE, DUST, EXPLOSION, SPARK }

const LIFE := {Kind.MUZZLE: 0.25, Kind.DUST: 0.6, Kind.EXPLOSION: 0.8, Kind.SPARK: 0.35}

var kind := Kind.DUST
var direction := Vector2.RIGHT
var _t := 0.0
var _parts: Array = []


static func spawn(parent: Node, at: Vector2, fx_kind: int, dir: Vector2 = Vector2.UP) -> void:
	var fx := ArenaFx.new()
	fx.kind = fx_kind
	fx.direction = dir
	fx.position = at
	fx.z_index = 5
	parent.add_child(fx)


## Numero ou palavra que sobe e some ("−8", "+25 G").
static func float_text(parent: Node, at: Vector2, text: String, col: Color) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"OverlayLabel"
	label.add_theme_color_override("font_color", col)
	label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	label.position = at - Vector2(20, 20)
	label.z_index = 6
	parent.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 46.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(label.queue_free)


## Flash branco de dano: estoura o sprite para branco e volta em 0,15 s. Por
## tween, entao some sozinho se o sprite for destruido no meio.
static func flash_sprite(sprite: CanvasItem) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.modulate = UiTokens.HIT_FLASH
	var tw := sprite.create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(sprite, "modulate", UiTokens.NO_TINT, 0.05)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := 10
	match kind:
		Kind.EXPLOSION:
			count = 26
		Kind.MUZZLE:
			count = 8
		Kind.SPARK:
			count = 8
	for i in range(count):
		var ang := rng.randf_range(-PI, PI)
		var speed := rng.randf_range(30.0, 140.0)
		var vel := Vector2.RIGHT.rotated(ang) * speed
		if kind == Kind.MUZZLE:
			vel = direction.rotated(rng.randf_range(-0.5, 0.5)) * rng.randf_range(60.0, 180.0)
		elif kind == Kind.DUST:
			vel = Vector2(rng.randf_range(-70, 70), rng.randf_range(-110, -20))
		_parts.append({"p": Vector2.ZERO, "v": vel, "s": rng.randi_range(1, 3)})


func _process(delta: float) -> void:
	_t += delta
	var life: float = LIFE[kind]
	if _t >= life:
		queue_free()
		return
	for part in _parts:
		part.p += part.v * delta
		part.v *= 0.9
		if kind == Kind.DUST:
			part.v.y += 160.0 * delta
	queue_redraw()


func _draw() -> void:
	var life: float = LIFE[kind]
	var k := _t / life
	var px := float(UiTokens.PX)
	if kind == Kind.MUZZLE or kind == Kind.EXPLOSION:
		var r := (14.0 if kind == Kind.MUZZLE else 34.0) * (1.0 - k)
		draw_circle(Vector2.ZERO, r, Color(UiTokens.FIRE_HOT, 1.0 - k), true, -1.0, false)
		draw_circle(Vector2.ZERO, r * 0.6, Color(UiTokens.FIRE, 1.0 - k), true, -1.0, false)
	for part in _parts:
		var col := _color(k)
		var s: float = px * part.s * (2.0 if kind == Kind.EXPLOSION else 1.0)
		var at: Vector2 = part.p
		draw_rect(Rect2(at.snapped(Vector2(px, px)), Vector2(s, s)), col)


func _color(k: float) -> Color:
	match kind:
		Kind.DUST:
			return Color(UiTokens.DUST, 1.0 - k)
		Kind.SPARK:
			return Color(UiTokens.FIRE_HOT, 1.0 - k)
		Kind.EXPLOSION:
			return Color(UiTokens.FIRE if k < 0.35 else UiTokens.SMOKE, 1.0 - k)
	return Color(UiTokens.SMOKE, 1.0 - k)

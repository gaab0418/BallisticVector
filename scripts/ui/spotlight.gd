class_name Spotlight
extends CanvasLayer
## Holofote do tutorial: escurece a tela inteira menos um retangulo, com um anel
## ambar pulsando em volta e uma maozinha de pixel art apontando para ele.
##
## Clique atravessa (mouse_filter IGNORE): ela consegue mexer no que esta aceso.
##
## Modos da maozinha:
##   "point" -- aponta de baixo, balancando
##   "orbit" -- da voltas em volta do alvo, como quem gira uma manivela

## Maozinha de dedo em pe, 12x14. Mesmo esquema de cores da Ada.
const HAND := [
	"....KK......",
	"...KWWK.....",
	"...KWWK.....",
	"...KWWK.....",
	"...KWWKKK...",
	".KKKWWKWWKK.",
	"KWWKWWKWWKWK",
	"KWWWWWWWWWWK",
	"KWWWWWWWWWWK",
	".KWWWWWWWWWK",
	".KWWWWWWWWK.",
	"..KWWWWWWWK.",
	"...KWWWWWK..",
	"...KKKKKKK..",
]
const HAND_PX := 3.0

var target := Rect2()
var mode := "point"
var _canvas: Control
var _t := 0.0


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func focus(rect: Rect2, hand_mode: String = "point") -> void:
	target = rect.grow(8.0)
	mode = hand_mode
	visible = true
	_canvas.queue_redraw()


func clear() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_canvas.queue_redraw()


func _draw_canvas() -> void:
	var full := _canvas.size
	var r := target
	var dim := UiTokens.SPOTLIGHT_DIM
	# Quatro retangulos em volta do buraco: o buraco fica limpo.
	_canvas.draw_rect(Rect2(0, 0, full.x, r.position.y), dim)
	_canvas.draw_rect(Rect2(0, r.end.y, full.x, full.y - r.end.y), dim)
	_canvas.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	_canvas.draw_rect(Rect2(r.end.x, r.position.y, full.x - r.end.x, r.size.y), dim)

	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var ring := r.grow(4.0 + pulse * 4.0)
	_canvas.draw_rect(ring, Color(UiTokens.EDITABLE, 0.5 + pulse * 0.5), false, 3.0)

	var c := r.get_center()
	var at := Vector2.ZERO
	if mode == "orbit":
		var rad := maxf(r.size.x, r.size.y) * 0.5 + 18.0
		at = c + Vector2(cos(_t * 2.6), sin(_t * 2.6)) * rad
	else:
		at = Vector2(c.x, r.end.y + 10.0 + absf(sin(_t * 4.0)) * 10.0)
	_draw_hand(at)


## Desenha a maozinha com a ponta do dedo em `tip`.
func _draw_hand(tip: Vector2) -> void:
	var origin := tip - Vector2(4.5, 0) * HAND_PX
	for y in range(HAND.size()):
		var row: String = HAND[y]
		for x in range(row.length()):
			var ch := row[x]
			if ch == ".":
				continue
			var col := UiTokens.NIGHT_950 if ch == "K" else UiTokens.TEXT_HOVER
			_canvas.draw_rect(
				Rect2(origin + Vector2(x, y) * HAND_PX, Vector2(HAND_PX, HAND_PX)), col
			)

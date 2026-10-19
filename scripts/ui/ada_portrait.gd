class_name AdaPortrait
extends Control
## Retrato da Engenheira Ada em pixel art 32x32, desenhado a partir de um mapa
## de caracteres (cada letra = 1 pixel, cores de UiTokens).
##
## Expressoes trocam so olhos e boca por cima da base. Pisca sozinha, mexe a
## boca enquanto fala e balanca um pixel.

const SIZE := 32

const BASE := [
	"...........KKKKKKKKKK...........",
	".........KKOOOOOOOOOOKK.........",
	"........KOOOOOOOOOOOOOOK........",
	".......KOOOOOOOOOOOOOOOOK.......",
	"......KOOOoooooooooooooOOK......",
	"......KOKKKKKKKKKKKKKKKKOK......",
	".....KOKGGGGGGKKKKGGGGGGKOK.....",
	".....KOKGLLLLGKggKGLLLLGKOK.....",
	".....KOKGLWLLGKggKGLWLLGKOKhK...",
	".....KHKGLLLLGgggKGLLLLGKHKHhK..",
	".....KHKKGGGGKKKKKKGGGGKKHKHHhK.",
	".....KHHSSSSSSSSSSSSSSSSHHKHHHhK",
	".....KHSSSSSSSSSSSSSSSSSSHKKHHhK",
	".....KHSSKKKKSSSSSSKKKKSSHK.KHhK",
	".....KSSSSSSSSSSSSSSSSSSSSK..KhK",
	".....KSSSWWEESSSSSSWWEESSSK...K.",
	".....KSSSWEEESSSSSSWEEESSSK.....",
	".....KsSSSSSSSSSsSSSSSSSSsK.....",
	".....KsRRSSSSSSSsSSSSSSRRsK.....",
	"......KSSSSSSSSSSSSSSSSSSK......",
	"......KSSSSSSKMMMMKSSSSSSK......",
	".......KSSSSSSKKKKSSSSSSK.......",
	"........KKSSSSSSSSSSSSKK........",
	"..........KKsSSSSSSsKK..........",
	"...........KKssssssKK...........",
	".........KKKOKssssKOKKK.........",
	".......KKOOOOOKKKKOOOOOKK.......",
	"......KOOOOOOOOOOOOOOOOOOK......",
	".....KOOOoOOOOOOOOOOYYOOOOK.....",
	".....KOOOoOOOOOOOOOYYYYOOOK.....",
	"....KOOOOoOOOOOOOOOOYYOOOOOK....",
	"....KOOOOoOOOOOOOOOOOOOOOOOK....",
]

## Remendos por expressao: linha -> [coluna inicial, pixels].
const MOUTHS := {
	"neutral": {},
	"happy": {20: [13, "KMMMMK"], 21: [13, "KMMMMK"], 22: [14, "KKKK"]},
	"proud": {20: [13, "KMMMMK"], 21: [13, "KMMMMK"], 22: [14, "KKKK"]},
	"surprised": {20: [13, "SSKKSS"], 21: [13, "SKMMKS"], 22: [14, "SKKS"]},
	"thinking": {20: [13, "SSKKKK"], 21: [13, "SSSSSS"]},
	"talk": {20: [13, "KKKKKK"], 21: [13, "KMRRMK"], 22: [14, "KKKK"]},
}
const EYES := {
	"blink": {15: [9, "SSSS"], 16: [9, "KKKK"], -15: [19, "SSSS"], -16: [19, "KKKK"]},
	"proud": {15: [9, "SKKS"], 16: [9, "KSSK"], -15: [19, "SKKS"], -16: [19, "KSSK"]},
	"thinking": {15: [9, "WEEW"], 16: [9, "WWWW"], -15: [19, "WEEW"], -16: [19, "WWWW"]},
	"surprised": {15: [9, "WEEW"], 16: [9, "WEEW"], -15: [19, "WEEW"], -16: [19, "WEEW"]},
}

@export var expression := "neutral":
	set(value):
		expression = value
		queue_redraw()
var talking := false

var _t := 0.0
var _blink_at := 2.5
var _blinking := 0.0


static func palette() -> Dictionary:
	return {
		"K": UiTokens.NIGHT_950,
		"O": UiTokens.ADA_UNIFORM,
		"o": UiTokens.ADA_UNIFORM_DARK,
		"G": UiTokens.BRASS,
		"g": UiTokens.BRASS_DARK,
		"L": UiTokens.CALCULATED,
		"W": UiTokens.TEXT_HOVER,
		"H": UiTokens.ADA_HAIR,
		"h": UiTokens.ADA_HAIR_DARK,
		"S": UiTokens.ADA_SKIN,
		"s": UiTokens.ADA_SKIN_DARK,
		"R": UiTokens.ADA_CHEEK,
		"E": UiTokens.INK,
		"M": UiTokens.ADA_MOUTH,
		"Y": UiTokens.EDITABLE,
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(SIZE * 4, SIZE * 4)


func _process(delta: float) -> void:
	_t += delta
	if _blinking > 0.0:
		_blinking -= delta
	elif _t >= _blink_at:
		_blinking = 0.12
		_blink_at = _t + randf_range(2.2, 4.5)
	queue_redraw()


func _draw() -> void:
	var px := floorf(minf(size.x, size.y) / SIZE)
	var origin := ((size - Vector2(SIZE, SIZE) * px) * 0.5).floor()
	# Respira: um pixel para cima e para baixo, devagar.
	origin.y += px if fmod(_t, 2.4) > 1.2 else 0.0
	var rows: Array = BASE.duplicate()
	_patch(rows, _mouth_patch())
	_patch(rows, _eye_patch())
	var pal := palette()
	for y in range(SIZE):
		var row: String = rows[y]
		for x in range(SIZE):
			var c := row[x]
			if pal.has(c):
				draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), pal[c])


func _mouth_patch() -> Dictionary:
	if talking and fmod(_t, 0.22) < 0.11:
		return MOUTHS.talk
	return MOUTHS.get(expression, MOUTHS.neutral)


func _eye_patch() -> Dictionary:
	if _blinking > 0.0:
		return EYES.blink
	return EYES.get(expression, {})


## Aplica um remendo. Chave negativa = mesma linha, segundo olho.
static func _patch(rows: Array, patch: Dictionary) -> void:
	for key in patch:
		var y: int = absi(key)
		var spec: Array = patch[key]
		var col: int = spec[0]
		var px: String = spec[1]
		var row: String = rows[y]
		rows[y] = row.substr(0, col) + px + row.substr(col + px.length())

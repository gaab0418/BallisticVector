class_name BaseMarker
extends Button
## Uma base no mapa de guerra: o castelo desenhado no papel e uma plaqueta com
## nome, capitulo e uma medalha por fase.
##
## Antes a base era um sprite de 64 px com "Fase 1/3" em corpo 14 por cima da
## arte do mapa -- ilegivel. Agora o estado e lido por tres sinais ao mesmo
## tempo, nenhum so de cor:
##   bloqueada   -- castelo apagado + cadeado + "termine a base anterior"
##   disponivel  -- seta ambar pulsando sobre o castelo + "proxima: fase N"
##   conquistada -- bandeira no castelo + medalhas cheias
##
## E um Button (flat) para ganhar de graca foco por teclado, hover e clique.

enum State { LOCKED, OPEN, DONE }

const CASTLE := 80.0
const PLAQUE_W := 150.0
const MEDAL := 18.0
const FLAG_TEX := preload("res://assets/sprites/cartography/Default/flag.png")

var base_id := ""
var state := State.OPEN
var stars: Array = [0, 0, 0]
var _tex: Texture2D
var _flip := false
var _hot := false
var _t := 0.0
var _name: Label
var _chapter: Label
var _status: Label
var _medals: Array = []
var _plaque: PanelContainer


func setup(id: String, tex: Texture2D, flip: bool, display_name: String, chapter: String) -> void:
	base_id = id
	_tex = tex
	_flip = flip
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(PLAQUE_W, CASTLE + 80.0)
	size = custom_minimum_size
	# Sem fundo nem anel de foco do tema: o realce e desenhado em _draw.
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())

	_plaque = PanelContainer.new()
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plaque_style := UiPanel.create(UiPanel.Kind.HUD)
	plaque_style.set_content_margin_all(UiTokens.PX * 2 + 3)
	_plaque.add_theme_stylebox_override("panel", plaque_style)
	_plaque.position = Vector2(0, CASTLE - 4.0)
	_plaque.custom_minimum_size = Vector2(PLAQUE_W, 0)
	add_child(_plaque)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(col)

	_name = Label.new()
	_name.text = display_name.to_upper()
	_name.theme_type_variation = &"TitleLabel"
	_name.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)

	_chapter = Label.new()
	_chapter.text = chapter
	_chapter.theme_type_variation = &"CaptionLabel"
	_chapter.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_chapter)

	var medals := HBoxContainer.new()
	medals.alignment = BoxContainer.ALIGNMENT_CENTER
	medals.add_theme_constant_override("separation", 4)
	medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(medals)
	for i in range(3):
		var m := UiIcon.make("star_empty", UiTokens.TEXT_DISABLED, MEDAL)
		medals.add_child(m)
		_medals.append(m)

	_status = Label.new()
	_status.theme_type_variation = &"CaptionLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(_set_hot.bind(false))
	focus_entered.connect(_set_hot.bind(true))
	focus_exited.connect(_set_hot.bind(false))


func set_progress(new_state: int, base_stars: Array, cleared: int, total: int) -> void:
	state = new_state
	stars = base_stars
	for i in range(_medals.size()):
		var n: int = stars[i] if i < stars.size() else 0
		var m: UiIcon = _medals[i]
		m.icon = "star" if n > 0 else "star_empty"
		m.color = _medal_color(n)
	match state:
		State.LOCKED:
			_status.text = "bloqueada"
			_status.add_theme_color_override("font_color", UiTokens.TEXT_DISABLED)
		State.DONE:
			_status.text = "conquistada!"
			_status.add_theme_color_override("font_color", UiTokens.SUCCESS)
		_:
			_status.text = "próxima: fase %d" % (cleared + 1)
			_status.tooltip_text = "de %d fases" % total
			_status.add_theme_color_override("font_color", UiTokens.EDITABLE)
	queue_redraw()


## Uma estrela = bronze, duas = prata, tres = ouro: a medalha diz o quanto a
## crianca dominou a fase, e da vontade de voltar para completar.
static func _medal_color(n: int) -> Color:
	match n:
		1:
			return UiTokens.MEDAL_BRONZE
		2:
			return UiTokens.MEDAL_SILVER
		3:
			return UiTokens.MEDAL_GOLD
	return UiTokens.TEXT_DISABLED


func _set_hot(on: bool) -> void:
	_hot = on
	var tw := create_tween()
	tw.tween_property(_plaque, "position:y", CASTLE - (10.0 if on else 4.0), UiTokens.ANIM_FAST)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if state == State.OPEN or _hot:
		queue_redraw()


func _draw() -> void:
	var c := Vector2(PLAQUE_W * 0.5, CASTLE * 0.55)
	var bob := sin(_t * 4.0) * 3.0
	# Aureola ambar no hover/foco, em aneis de pixel.
	if _hot and state != State.LOCKED:
		for r in [50.0, 43.0, 36.0]:
			draw_circle(c, r, Color(UiTokens.EDITABLE, 0.12), true, -1.0, false)

	var tint := UiTokens.NO_TINT
	if state == State.LOCKED:
		tint = UiTokens.MAP_LOCKED
	elif state == State.DONE:
		tint = UiTokens.BASE_DONE
	var scale_k := 1.08 if _hot else 1.0
	var sz := Vector2(CASTLE, CASTLE) * scale_k
	var rect := Rect2(c - sz * 0.5, sz)
	if _flip:
		draw_set_transform(Vector2(c.x * 2.0, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect(_tex, rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	match state:
		State.LOCKED:
			UiIcon.paint(
				self, "lock", Rect2(c - Vector2(16, 6), Vector2(32, 32)), UiTokens.TEXT_DIM
			)
		State.DONE:
			draw_texture_rect(FLAG_TEX, Rect2(c + Vector2(10, -66), Vector2(44, 44)), false)
		_:
			# Seta pulsando: "e aqui que voce vai agora".
			draw_set_transform(c + Vector2(0, -52 + bob), PI, Vector2.ONE)
			UiIcon.paint(
				self, "arrow_up", Rect2(Vector2(-12, -12), Vector2(24, 24)), UiTokens.EDITABLE
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

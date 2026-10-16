class_name AdaDialog
extends CanvasLayer
## A Engenheira Ada falando: retrato + balao de papel com maquina de escrever.
##
## Tres jeitos de falar:
##   say()    -- conversa que pausa o jogo; Espaco/Enter/clique avanca, Esc pula
##   pop()    -- recado rapido que some sozinho, sem pausar (dicas, parabens)
##   prompt() -- instrucao que fica na tela ate alguem chamar hide_now(): usada
##               no tutorial enquanto a crianca faz o que foi pedido

signal finished

const BUBBLE_W := 500.0
const PORTRAIT := 120.0

var _root: Control
var _dock: HBoxContainer
var _portrait: AdaPortrait
var _bubble: PanelContainer
var _text: Label
var _caption: Label
var _hint: Label
var _skip: Button
var _lines: Array = []
var _shown := 0.0
var _mode := ""
var _blocking := false
var _pop_left := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 0)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)

	var frame := PanelContainer.new()
	var style := UiPanel.create(UiPanel.Kind.MODAL)
	style.set_content_margin_all(UiTokens.PX * 4 + 2)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_vertical = Control.SIZE_SHRINK_END
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)
	_portrait = AdaPortrait.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	col.add_child(_portrait)
	var name_tag := Label.new()
	name_tag.text = "ENG. ADA"
	name_tag.theme_type_variation = &"TitleLabel"
	name_tag.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_tag)

	# Rabicho do balao, apontando para a Ada.
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(18, 0)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(_draw_tail.bind(tail))
	_dock.add_child(tail)

	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	_bubble.custom_minimum_size = Vector2(BUBBLE_W, 0)
	_bubble.size_flags_vertical = Control.SIZE_SHRINK_END
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.gui_input.connect(_on_bubble_input)
	_dock.add_child(_bubble)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	_bubble.add_child(inner)
	_caption = Label.new()
	_caption.theme_type_variation = &"InkLabel"
	_caption.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	_caption.add_theme_color_override("font_color", UiTokens.EDITABLE_ON_PAPER)
	inner.add_child(_caption)
	_text = Label.new()
	_text.theme_type_variation = &"InkLabel"
	_text.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BUBBLE_W - 48.0, 0)
	inner.add_child(_text)
	var foot := HBoxContainer.new()
	inner.add_child(foot)
	_hint = Label.new()
	_hint.theme_type_variation = &"InkLabel"
	_hint.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_hint)
	_skip = UiButton.create("Pular", UiButton.Kind.SECONDARY)
	_skip.custom_minimum_size = Vector2(90, 30)
	_skip.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	_skip.pressed.connect(_finish)
	foot.add_child(_skip)
	visible = false


## Conversa que pausa o jogo. `lines` = [{"text", "expr", "caption"?}].
func say(lines: Array) -> void:
	_lines = lines.duplicate()
	_mode = "say"
	_blocking = true
	get_tree().paused = true
	_place(true)
	_next_line()


## Recado rapido: aparece, fica `seconds` e some, sem pausar nada.
func pop(text: String, expr: String = "happy", seconds: float = 4.0) -> void:
	if _mode == "say" or _mode == "prompt":
		return
	_lines = [{"text": text, "expr": expr}]
	_mode = "pop"
	_blocking = false
	_pop_left = seconds
	_place(false)
	_next_line()


## Instrucao que fica ate hide_now(): o jogo continua rodando.
func prompt(text: String, expr: String = "neutral", caption: String = "") -> void:
	_lines = [{"text": text, "expr": expr, "caption": caption}]
	_mode = "prompt"
	_blocking = false
	_place(true)
	_next_line()


func hide_now() -> void:
	_mode = ""
	visible = false


func is_talking() -> bool:
	return visible and _mode == "say"


## Fica na lateral esquerda, abaixo da insignia da fase, para nao tapar o tanque.
func _place(_bottom: bool) -> void:
	visible = true
	_dock.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_dock.offset_left = 16.0
	_dock.offset_top = 150.0
	_skip.visible = _mode == "say"
	_dock.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dock, "modulate:a", 1.0, UiTokens.ANIM_FAST)


func _next_line() -> void:
	if _lines.is_empty():
		_finish()
		return
	var line: Dictionary = _lines.pop_front()
	_text.text = line.text
	_text.visible_characters = 0
	_caption.text = line.get("caption", "")
	_caption.visible = _caption.text != ""
	_portrait.expression = line.get("expr", "neutral")
	_shown = 0.0
	_hint.text = ""


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var total := _text.get_total_character_count()
	if _text.visible_characters < total and _text.visible_characters >= 0:
		_shown += delta * UiTokens.TYPE_SPEED
		_text.visible_characters = mini(int(_shown), total)
	var typing := _text.visible_characters >= 0 and _text.visible_characters < total
	_portrait.talking = typing
	if _mode == "say" and not typing:
		var more := "  »" if fmod(_t, 0.8) < 0.5 else ""
		_hint.text = (
			("Espaço para continuar" if not _lines.is_empty() else "Espaço para jogar") + more
		)
	if _mode == "pop" and not typing:
		_pop_left -= delta
		if _pop_left <= 0.0:
			hide_now()


func _input(event: InputEvent) -> void:
	if not visible or _mode != "say":
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


func _on_bubble_input(event: InputEvent) -> void:
	if _mode == "say" and event is InputEventMouseButton and event.pressed:
		_advance()


## Primeiro toque completa a frase; o segundo passa para a proxima.
func _advance() -> void:
	if (
		_text.visible_characters >= 0
		and _text.visible_characters < _text.get_total_character_count()
	):
		_text.visible_characters = -1
		return
	_next_line()


func _finish() -> void:
	var was_blocking := _blocking
	_lines.clear()
	_mode = ""
	_blocking = false
	visible = false
	# Despausa no quadro seguinte: o Espaco que fechou a conversa nao pode
	# disparar o canhao (a arena le o teclado por polling).
	if was_blocking:
		get_tree().set_deferred("paused", false)
	finished.emit()


func _draw_tail(tail: Control) -> void:
	var y := minf(70.0, tail.size.y - 20.0)
	var pts := PackedVector2Array(
		[Vector2(0, y), Vector2(tail.size.x + 2, y - 14), Vector2(tail.size.x + 2, y + 14)]
	)
	tail.draw_colored_polygon(pts, UiTokens.PAPER)
	tail.draw_polyline(PackedVector2Array([pts[1], pts[0], pts[2]]), UiTokens.INK, 2.0)

extends CanvasLayer
## Faixa "Selo novo!" que desce do topo quando uma conquista sai. Vive no
## Global, entao aparece em qualquer tela.

const SHOW_TIME := 3.2

var _panel: PanelContainer
var _name: Label
var _queue: Array = []
var _busy := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)
	_panel.add_child(row)
	var star := UiIcon.make("star", UiTokens.EDITABLE_ON_PAPER, 36.0)
	star.outlined = false
	row.add_child(star)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	row.add_child(col)
	var cap := Label.new()
	cap.text = "SELO NOVO NO CADERNO!"
	cap.theme_type_variation = &"InkLabel"
	cap.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	cap.add_theme_color_override("font_color", UiTokens.EDITABLE_ON_PAPER)
	col.add_child(cap)
	_name = Label.new()
	_name.theme_type_variation = &"InkLabel"
	_name.add_theme_font_override("font", UiTheme.title_font())
	_name.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	col.add_child(_name)
	_panel.visible = false


func show_badge(title: String) -> void:
	_queue.append(title)
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	_name.text = _queue.pop_front()
	_panel.visible = true
	_panel.reset_size()
	var w := _panel.get_combined_minimum_size().x
	_panel.position = Vector2((1280.0 - w) * 0.5, -90.0)
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", 12.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "position:y", -90.0, 0.3)
	tw.tween_callback(func(): _panel.visible = false)
	tw.tween_callback(_next)

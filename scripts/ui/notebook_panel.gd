class_name NotebookPanel
extends UiModal
## Caderno da Ada: uma pagina ilustrada e animada por fase vencida. Esquerda:
## o desenho animado; direita: titulo, a Ada explicando e a formula.

const PANEL_SIZE := Vector2(1000, 0)
const PAGE_SIZE := Vector2(450, 380)

var _index := 0
var _book: HBoxContainer
var _diagram: AnimatedDiagram
var _lock: Control
var _title: Label
var _caption: Label
var _text: Label
var _formula: Label
var _formula_box: PanelContainer
var _counter: Label
var _new_tag: Label
var _ada: AdaPortrait
var _prev: Button
var _next: Button
var _turning := false


func _build_content() -> void:
	pauses_game = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "Caderno da Ada"

	_book = HBoxContainer.new()
	_book.add_theme_constant_override("separation", 6)
	body.add_child(_book)

	var left := _page()
	_book.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = PAGE_SIZE
	left.add_child(stage)
	_diagram = AnimatedDiagram.new()
	stage.add_child(_diagram)
	_diagram.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lock = UiIcon.make("lock", UiTokens.INK, 120.0)
	stage.add_child(_lock)
	_lock.position = PAGE_SIZE * 0.5 - Vector2(60, 60)

	var right := _page()
	_book.add_child(right)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = PAGE_SIZE
	right.add_child(col)
	_caption = _ink(UiTokens.FONT_XS, UiTokens.EDITABLE_ON_PAPER)
	col.add_child(_caption)
	_title = _ink(UiTokens.FONT_TITLE, UiTokens.INK)
	_title.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(_title)
	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation", 10)
	col.add_child(talk)
	_ada = AdaPortrait.new()
	_ada.custom_minimum_size = Vector2(72, 72)
	_ada.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	talk.add_child(_ada)
	_text = _ink(UiTokens.FONT_MD, UiTokens.INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PAGE_SIZE.x - 110.0, 0)
	talk.add_child(_text)
	_formula_box = PanelContainer.new()
	_formula_box.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.CARD))
	_formula_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_formula_box)
	_formula = Label.new()
	_formula.theme_type_variation = &"ResultLabel"
	_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_box.add_child(_formula)
	_new_tag = _ink(UiTokens.FONT_SM, UiTokens.DANGER_ON_PAPER)
	_new_tag.text = "NOVA!"
	col.add_child(_new_tag)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(foot)
	_prev = UiButton.create("←  Anterior", UiButton.Kind.SECONDARY, null, true)
	_prev.custom_minimum_size = Vector2(200, 48)
	_prev.pressed.connect(_turn.bind(-1))
	foot.add_child(_prev)
	_counter = Label.new()
	_counter.custom_minimum_size = Vector2(200, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(_counter)
	_next = UiButton.create("Próxima  →", UiButton.Kind.PRIMARY, null, true)
	_next.custom_minimum_size = Vector2(200, 48)
	_next.pressed.connect(_turn.bind(1))
	foot.add_child(_next)
	var close_btn := UiButton.create("Fechar", UiButton.Kind.SECONDARY, null, true)
	close_btn.custom_minimum_size = Vector2(140, 48)
	close_btn.pressed.connect(close)
	foot.add_child(close_btn)


func _page() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	return p


func _ink(size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l


## Abre na primeira pagina nova (ou na primeira, se nao houver).
func open() -> void:
	_index = 0
	for i in range(Notebook.PAGES.size()):
		var page: Dictionary = Notebook.PAGES[i]
		if Notebook.is_unlocked(page) and not Global.notebook_seen.has(Notebook.page_id(page)):
			_index = i
			break
	_show_page()
	super()
	_next.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_turn(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_turn(1)
	else:
		super(event)


## Vira a pagina: o caderno "fecha" na horizontal e abre com a pagina nova.
## Anima escala e opacidade porque a posicao seria desfeita pelo container.
func _turn(step: int) -> void:
	var target := clampi(_index + step, 0, Notebook.PAGES.size() - 1)
	if target == _index or _turning:
		return
	_turning = true
	UiButton._play(window, "res://assets/audio/menu_hover_.ogg")
	_book.pivot_offset = _book.size * 0.5
	var tw := create_tween()
	tw.tween_property(_book, "scale:x", 0.05, 0.12)
	tw.parallel().tween_property(_book, "modulate:a", 0.3, 0.12)
	tw.tween_callback(
		func():
			_index = target
			_show_page()
	)
	tw.tween_property(_book, "scale:x", 1.0, 0.16)
	tw.parallel().tween_property(_book, "modulate:a", 1.0, 0.16)
	tw.tween_callback(func(): _turning = false)


func _show_page() -> void:
	var page: Dictionary = Notebook.PAGES[_index]
	var unlocked := Notebook.is_unlocked(page)
	var base_name: String = Global.get_base_data(page.base).get("name", "")
	_counter.text = "Página %d de %d" % [_index + 1, Notebook.PAGES.size()]
	_caption.text = "%s · FASE %d" % [base_name.to_upper(), page.stage + 1]
	_prev.disabled = _index == 0
	_next.disabled = _index == Notebook.PAGES.size() - 1
	_diagram.visible = unlocked
	_lock.visible = not unlocked
	_formula_box.visible = unlocked
	var is_new := unlocked and not Global.notebook_seen.has(Notebook.page_id(page))
	_new_tag.visible = is_new
	if unlocked:
		_title.text = page.title
		_text.text = page.text
		_formula.text = page.formula
		_diagram.play(page.anim, page.p)
		_ada.expression = "proud" if is_new else "happy"
		if is_new:
			Global.notebook_seen[Notebook.page_id(page)] = true
			Global.save_game()
	else:
		_title.text = "Página trancada"
		_text.text = "Vença a fase %d da %s para abrir esta página do meu caderno." % [page.stage + 1, base_name]
		_ada.expression = "thinking"

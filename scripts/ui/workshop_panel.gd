class_name WorkshopPanel
extends UiModal
## Oficina da Ada: camuflagens, rastros e bandeirinhas pagos em latao.
##
## O tanque no topo mostra o item escolhido aplicado ao vivo: clicar num cartao
## so experimenta; "Comprar" e "Usar" sao os botoes do cartao.

signal changed

const HULL_TEX := preload("res://assets/sprites/tank_hull.png")
const BARREL_TEX := preload("res://assets/sprites/tank_barrel.png")
const TrailScript := preload("res://scenes/arena/shot_trail.gd")
const FlagScript := preload("res://scenes/arena/tank_flag.gd")

const PANEL_SIZE := Vector2(760, 0)
const CARD_W := 160.0
const PREVIEW_K := 0.375
## Canto do sprite na previa; o topo do PNG e vazio, entao sobe para caber.
const PREVIEW_ORIGIN := Vector2(10, 4)

var _slot := "camo"
var _preview_items := {}
var _brass_label: Label
var _grid: GridContainer
var _tabs: Array = []
var _hull: TextureRect
var _barrel: TextureRect
var _flag: Node2D
var _trail_demo: Control
var _t := 0.0


func _build_content() -> void:
	pauses_game = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "Oficina da Ada"

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTokens.GAP_LG)
	body.add_child(top)
	top.add_child(_build_preview())

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	top.add_child(side)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	side.add_child(row)
	row.add_child(UiIcon.make("gear", UiTokens.BRASS, 30.0))
	_brass_label = Label.new()
	_brass_label.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	_brass_label.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	_brass_label.add_theme_color_override("font_color", UiTokens.BRASS_LIGHT)
	row.add_child(_brass_label)
	var hint := Label.new()
	hint.text = "Cada fase vencida rende %d de latão." % Global.BRASS_PER_WIN
	hint.theme_type_variation = &"CaptionLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hint)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	side.add_child(tabs)
	var group := ButtonGroup.new()
	for slot in Cosmetics.SLOTS:
		var b := UiButton.create(Cosmetics.SLOT_NAMES[slot], UiButton.Kind.SECONDARY, null, true)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(140, 40)
		b.add_theme_color_override("font_pressed_color", UiTokens.EDITABLE)
		b.toggled.connect(_on_tab.bind(slot))
		tabs.add_child(b)
		_tabs.append(b)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)

	var close_btn := UiButton.create("VOLTAR AO MAPA", UiButton.Kind.SECONDARY, null, true)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	_tabs[0].button_pressed = true


func open() -> void:
	for slot in Cosmetics.SLOTS:
		_preview_items[slot] = Cosmetics.equipped(slot)
	_refresh()
	super()
	_tabs[0].grab_focus.call_deferred()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_trail_demo.queue_redraw()


## Tanque grande com o que esta sendo experimentado, e um rastro de exemplo.
func _build_preview() -> Control:
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(300, 136)
	paper.add_child(stage)
	_trail_demo = Control.new()
	_trail_demo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trail_demo.draw.connect(_draw_trail_demo)
	stage.add_child(_trail_demo)
	# Mesma montagem da arena, na escala K do sprite original (676x369).
	var origin := PREVIEW_ORIGIN
	var pivot := origin + Vector2(404, 139) * PREVIEW_K
	_barrel = _sprite(BARREL_TEX, pivot + Vector2(10, -21) * PREVIEW_K, Vector2(227, 40) * PREVIEW_K)
	_barrel.pivot_offset = -Vector2(10, -21) * PREVIEW_K
	_barrel.rotation = -0.45
	stage.add_child(_barrel)
	_hull = _sprite(HULL_TEX, origin, Vector2(676, 369) * PREVIEW_K)
	stage.add_child(_hull)
	_flag = Node2D.new()
	_flag.set_script(FlagScript)
	_flag.position = origin + Vector2(90, 136) * PREVIEW_K
	_flag.scale = Vector2(1.5, 1.5)
	stage.add_child(_flag)
	return paper


func _sprite(tex: Texture2D, pos: Vector2, size_px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = pos
	t.size = size_px
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Arco de exemplo saindo do cano, desenhado com o rastro experimentado.
func _draw_trail_demo() -> void:
	var trail: Dictionary = _preview_items.get("trail", Cosmetics.TRAILS[0])
	var col := Color(trail.color)
	var start := PREVIEW_ORIGIN + Vector2(404, 139) * PREVIEW_K + Vector2(85, -40) * PREVIEW_K
	var prev := start
	for i in range(1, 20):
		var k := fposmod(_t * 0.6 + i / 20.0, 1.0)
		var p := start + Vector2(i * 2.2, -i * 1.6 + i * i * 0.09)
		var a := float(i) / 20.0
		match trail.style:
			"rainbow":
				_trail_demo.draw_line(prev, p, Color.from_hsv(k, 0.75, 1.0, a), 3.0)
			"stars":
				if i % 4 == 0:
					UiIcon.paint(_trail_demo, "star", Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(col, a), false)
			"dots":
				if i % 2 == 0:
					_trail_demo.draw_circle(p, 2.5, Color(col, a), true, -1.0, false)
			"fire":
				_trail_demo.draw_line(prev, p, Color(UiTokens.FIRE_HOT.lerp(col, a), a), 4.0)
			_:
				_trail_demo.draw_line(prev, p, Color(col, a), 3.0)
		prev = p


func _on_tab(on: bool, slot: String) -> void:
	if on:
		_slot = slot
		_refresh()


func _refresh() -> void:
	_brass_label.text = "%d de latão" % Global.brass
	var mat := Cosmetics.camo_material(_preview_items.get("camo", Cosmetics.CAMOS[0]))
	_hull.material = mat
	_barrel.material = mat
	_flag.setup(_preview_items.get("flag", Cosmetics.FLAGS[0]))
	for c in _grid.get_children():
		c.queue_free()
	for it in Cosmetics.items(_slot):
		_grid.add_child(_card(it))


func _card(it: Dictionary) -> Control:
	var card := PanelContainer.new()
	var trying: bool = _preview_items.get(_slot, {}).get("id", "") == it.id
	var style := UiPanel.create(UiPanel.Kind.SELECTED if trying else UiPanel.Kind.CARD)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(it))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	col.add_child(_swatch(it))
	var name_label := Label.new()
	name_label.text = it.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var equipped: bool = Global.equipped.get(_slot, "") == it.id
	var btn: Button
	if equipped:
		btn = UiButton.create("Em uso", UiButton.Kind.SECONDARY)
		btn.disabled = true
	elif Global.owns(it.id):
		btn = UiButton.create("Usar", UiButton.Kind.PRIMARY, null, true)
		btn.pressed.connect(_equip.bind(it))
	else:
		btn = UiButton.create("%d latão" % it.price, UiButton.Kind.PRIMARY, null, true)
		btn.disabled = Global.brass < it.price
		btn.pressed.connect(_buy.bind(it))
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	col.add_child(btn)
	return card


## Amostra do item: tres faixas da camuflagem, a cor do rastro ou a bandeira.
func _swatch(it: Dictionary) -> Control:
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(0, 36)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := _slot
	sw.draw.connect(
		func():
			var r := Rect2(Vector2(10, 4), Vector2(sw.size.x - 20, 28))
			match slot:
				"camo":
					var colors: Array = it.colors if not it.colors.is_empty() else ["4e5a36", "6b7a3e", "a0a070"]
					for i in range(3):
						var w := r.size.x / 3.0
						sw.draw_rect(Rect2(r.position + Vector2(i * w, 0), Vector2(w, r.size.y)), Color(colors[i]))
				"trail":
					sw.draw_line(r.position + Vector2(0, 24), r.end - Vector2(0, 24), Color(it.color), 5.0)
				_:
					if it.icon == "":
						sw.draw_line(r.position, r.end, UiTokens.TEXT_DISABLED, 2.0)
					else:
						sw.draw_rect(Rect2(r.get_center() - Vector2(22, 14), Vector2(44, 28)), Color(it.color))
						var c := r.get_center()
						UiIcon.paint(sw, it.icon, Rect2(c - Vector2(10, 10), Vector2(20, 20)), UiTokens.TEXT_HOVER, false)
			sw.draw_rect(r, UiTokens.NIGHT_950, false, 2.0)
	)
	return sw


func _on_card_input(event: InputEvent, it: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_preview_items[_slot] = it
		_refresh()


func _buy(it: Dictionary) -> void:
	if Global.buy_cosmetic(it.id):
		Global.equip(_slot, it.id)
		_preview_items[_slot] = it
		UiButton._play(window, "res://assets/audio/menu_click.ogg")
		changed.emit()
	_refresh()


func _equip(it: Dictionary) -> void:
	Global.equip(_slot, it.id)
	_preview_items[_slot] = it
	changed.emit()
	_refresh()

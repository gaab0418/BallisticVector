class_name EndScreen
extends Control
## Tela de fim de jogo, compartilhada por vitoria e derrota.
##
## O conteudo vem por configure(); todo estilo vem do tema e de UiTokens.
##
## Fundo: o mesmo acampamento do menu, escurecido, com particulas desenhadas em
## codigo -- estrelas subindo na vitoria, fumaca na derrota.

const CAMP := preload("res://scenes/menu_play/camp.jpg")

enum Mood { VICTORY, DEFEAT }

var mood := Mood.VICTORY
var _parts: Array = []
var _fx: Control
var _first_button: Button


## `buttons` = lista de [texto, UiButton.Kind, Callable]. O primeiro recebe o foco.
func configure(
	screen_mood: int, title: String, subtitle: String, lines: Array, tip: String, buttons: Array
) -> void:
	mood = screen_mood
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = CAMP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = UiTokens.END_VICTORY_SHADE if mood == Mood.VICTORY else UiTokens.END_DEFEAT_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.MODAL))
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTokens.GAP)
	panel.add_child(col)

	var accent := UiTokens.EDITABLE if mood == Mood.VICTORY else UiTokens.DANGER
	var icon := UiIcon.make("star" if mood == Mood.VICTORY else "shield", accent, 72.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var head := Label.new()
	head.text = title
	head.theme_type_variation = &"DisplayLabel"
	head.add_theme_font_size_override("font_size", UiTokens.FONT_HERO)
	head.add_theme_color_override("font_color", accent)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)

	for line in lines:
		var l := Label.new()
		l.text = line
		l.theme_type_variation = &"ResultLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)

	if tip != "":
		var paper := PanelContainer.new()
		paper.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
		var t := Label.new()
		t.text = tip
		t.theme_type_variation = &"InkLabel"
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(520, 0)
		paper.add_child(t)
		col.add_child(paper)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.GAP)
	col.add_child(row)
	for b in buttons:
		var btn := UiButton.create(b[0], b[1], null, true)
		btn.custom_minimum_size = Vector2(240, 54)
		btn.pressed.connect(b[2])
		row.add_child(btn)
		if _first_button == null:
			_first_button = btn

	_seed_particles()
	_animate_in(panel, icon)
	if _first_button:
		_first_button.grab_focus.call_deferred()


func _animate_in(panel: Control, icon: Control) -> void:
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, UiTokens.ANIM)
	icon.pivot_offset = icon.custom_minimum_size * 0.5
	icon.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(icon, "scale", Vector2.ONE, 0.15)


func _seed_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(42):
		(
			_parts
			. append(
				{
					"p": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
					"v": rng.randf_range(20.0, 70.0),
					"s": rng.randf_range(8.0, 18.0),
					"ph": rng.randf_range(0.0, TAU),
				}
			)
		)


func _process(delta: float) -> void:
	for p in _parts:
		# Estrelas sobem; fumaca sobe devagar e espalha.
		p.p.y -= p.v * delta * (1.0 if mood == Mood.VICTORY else 0.5)
		p.p.x += sin(p.ph + p.p.y * 0.01) * delta * 12.0
		if p.p.y < -20.0:
			p.p.y = size.y + 20.0
	if _fx:
		_fx.queue_redraw()


func _draw_fx() -> void:
	for p in _parts:
		if mood == Mood.VICTORY:
			var col := UiTokens.MEDAL_GOLD if int(p.s) % 2 == 0 else UiTokens.CALCULATED
			UiIcon.paint(_fx, "star", Rect2(p.p, Vector2(p.s, p.s)), Color(col, 0.55), false)
		else:
			_fx.draw_circle(p.p, p.s * 1.6, Color(UiTokens.SMOKE, 0.08), true, -1.0, false)

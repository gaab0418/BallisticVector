extends Control
## Menu de boas-vindas steampunk / cartográfico.
## Toda a UI é construída programaticamente no _ready().

# ── Caminhos de assets ──────────────────────────────────────────────
const FONT_BOLD_PATH := "res://assets/fonts/Caveat/static/Caveat-Bold.ttf"
const FONT_REGULAR_PATH := "res://assets/fonts/Caveat/static/Caveat-Regular.ttf"
const BTN_TEXTURE_PATH := "res://assets/sprites/ui_pack/Grey/Default/button_rectangle_depth_flat.png"
const BGM_MENU_PATH := "res://assets/audio/musica_fundo.wav"
const SFX_HOVER_PATH := "res://assets/audio/menu_hover_.ogg"
const SFX_CLICK_PLAY_PATH := "res://assets/audio/menu_welcome_click.ogg"

# ── Paleta steampunk / pergaminho ───────────────────────────────────
const COLOR_PARCHMENT := Color(0.82, 0.75, 0.62, 1.0)
const COLOR_PARCHMENT_INNER := Color(0.78, 0.71, 0.58, 1.0)
const COLOR_BORDER := Color(0.35, 0.25, 0.15, 1.0)
const COLOR_TITLE := Color(0.25, 0.18, 0.12, 1.0)
const COLOR_SUBTITLE := Color(0.40, 0.30, 0.20, 1.0)
const COLOR_BTN_LABEL := Color(0.20, 0.14, 0.08, 1.0)
const COLOR_VERSION := Color(0.45, 0.35, 0.25, 0.6)
const COLOR_OUTLINE := Color(0.15, 0.10, 0.05, 0.5)
const COLOR_DECOR_LINE := Color(0.50, 0.38, 0.25, 0.35)

# ── Referências construídas no _ready ───────────────────────────────
var title_label: Label
var subtitle_label: Label
var play_button: TextureButton
var btn_label: Label
var version_label: Label
var decor_top: ColorRect
var decor_bot: ColorRect

var settings_btn: TextureButton
var settings_panel: PanelContainer
var master_slider: HSlider
var bgm_slider: HSlider
var sfx_slider: HSlider
var close_settings_btn: TextureButton


func _ready() -> void:
	# Carregar fontes
	var font_bold := SystemFont.new()
	font_bold.font_names = ["Georgia", "Times New Roman", "Serif"]
	var font_regular := SystemFont.new()
	font_regular.font_names = ["Georgia", "Times New Roman", "Serif"]

	# ── 1. Fundo pergaminho ─────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = COLOR_PARCHMENT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── 2. Painel interno com borda steampunk ───────────────────────
	var inner_panel := Panel.new()
	inner_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_panel.offset_left = 32.0
	inner_panel.offset_top = 32.0
	inner_panel.offset_right = -32.0
	inner_panel.offset_bottom = -32.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PARCHMENT_INNER
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.15)
	panel_style.shadow_size = 6
	inner_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(inner_panel)

	# ── 3. Linhas decorativas horizontais (filigrana simples) ───────
	decor_top = _create_decor_line(80.0)
	add_child(decor_top)

	decor_bot = _create_decor_line(640.0)
	add_child(decor_bot)

	# ── 4. Título "Ballistic Vector" ───────────────────────────────
	title_label = Label.new()
	title_label.text = "Ballistic Vector"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_top = 140.0
	title_label.offset_left = -400.0
	title_label.offset_right = 400.0
	title_label.add_theme_font_override("font", font_bold)
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	title_label.modulate.a = 0.0  # começa invisível para fade-in
	add_child(title_label)

	# ── 5. Subtítulo ────────────────────────────────────────────────
	subtitle_label = Label.new()
	subtitle_label.text = "Um jogo de estratégia balística"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle_label.offset_top = 225.0
	subtitle_label.offset_left = -400.0
	subtitle_label.offset_right = 400.0
	subtitle_label.add_theme_font_override("font", font_regular)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	subtitle_label.modulate.a = 0.0
	add_child(subtitle_label)

	# ── 6. Botão JOGAR (TextureButton + Label) ─────────────────────
	var btn_texture: Texture2D = load(BTN_TEXTURE_PATH)

	play_button = TextureButton.new()
	play_button.texture_normal = btn_texture
	play_button.ignore_texture_size = true
	play_button.stretch_mode = TextureButton.STRETCH_SCALE
	play_button.custom_minimum_size = Vector2(280, 80)
	play_button.set_anchors_preset(Control.PRESET_CENTER)
	play_button.offset_left = -140.0
	play_button.offset_top = 40.0
	play_button.offset_right = 140.0
	play_button.offset_bottom = 120.0
	play_button.modulate.a = 0.0
	play_button.mouse_entered.connect(_on_play_hover)
	play_button.pressed.connect(_on_play_pressed)
	add_child(play_button)

	btn_label = Label.new()
	btn_label.text = "JOGAR"
	btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_label.add_theme_font_override("font", font_bold)
	btn_label.add_theme_font_size_override("font_size", 36)
	btn_label.add_theme_color_override("font_color", COLOR_BTN_LABEL)
	btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_button.add_child(btn_label)

	# ── 7. Versão / crédito ─────────────────────────────────────────
	version_label = Label.new()
	version_label.text = "v0.3 — PAC #1"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.offset_left = -200.0
	version_label.offset_top = -40.0
	version_label.offset_right = -16.0
	version_label.offset_bottom = -10.0
	version_label.add_theme_font_override("font", font_regular)
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", COLOR_VERSION)
	add_child(version_label)

	# ── 8. Iniciar música de fundo ──────────────────────────────────
	AudioManager.play_bgm(BGM_MENU_PATH)

	# ── 8.5. Menu de Configurações ──────────────────────────────────
	_build_settings_ui(font_bold, font_regular)

	# ── 9. Animação de entrada (fade-in escalonado) ─────────────────
	_play_intro_animation()


# ── Animação de entrada ─────────────────────────────────────────────
func _play_intro_animation() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Título aparece primeiro
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0).from(0.0)
	# Subtítulo logo depois
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.7).from(0.0).set_delay(0.3)
	# Botão por último
	tween.tween_property(play_button, "modulate:a", 1.0, 0.8).from(0.0).set_delay(0.2)


# ── Callbacks de UI ─────────────────────────────────────────────────
func _on_play_hover() -> void:
	AudioManager.play_sfx(SFX_HOVER_PATH)
	# Micro-animação de escala no hover
	var tween := create_tween()
	tween.tween_property(play_button, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(play_button, "scale", Vector2(1.0, 1.0), 0.1)


func _on_play_pressed() -> void:
	AudioManager.play_sfx(SFX_CLICK_PLAY_PATH)
	# Desabilitar botão para evitar duplo-clique
	play_button.disabled = true
	# Pequena pausa para o SFX tocar antes de trocar de cena
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


# ── Helpers ─────────────────────────────────────────────────────────
func _create_decor_line(y_position: float) -> ColorRect:
	var line := ColorRect.new()
	line.color = COLOR_DECOR_LINE
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.offset_left = 80.0
	line.offset_right = -80.0
	line.offset_top = y_position
	line.offset_bottom = y_position + 2.0
	return line


# ── Configurações UI ───────────────────────────────────────────────
func _build_settings_ui(font_bold: Font, font_regular: Font) -> void:
	settings_btn = TextureButton.new()
	settings_btn.texture_normal = load("res://assets/sprites/icons/gear_white.png")
	settings_btn.ignore_texture_size = true
	settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	settings_btn.custom_minimum_size = Vector2(48, 48)
	settings_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_btn.offset_left = -64.0
	settings_btn.offset_top = 16.0
	settings_btn.offset_right = -16.0
	settings_btn.offset_bottom = 64.0
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)

	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -200.0
	settings_panel.offset_top = -150.0
	settings_panel.offset_right = 200.0
	settings_panel.offset_bottom = 150.0
	settings_panel.visible = false
	settings_panel.z_index = 100
	
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = COLOR_PARCHMENT_INNER
	sp_style.border_color = COLOR_BORDER
	sp_style.border_width_left = 3
	sp_style.border_width_top = 3
	sp_style.border_width_right = 3
	sp_style.border_width_bottom = 3
	sp_style.corner_radius_top_left = 8
	sp_style.corner_radius_top_right = 8
	sp_style.corner_radius_bottom_left = 8
	sp_style.corner_radius_bottom_right = 8
	sp_style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	sp_style.shadow_size = 10
	settings_panel.add_theme_stylebox_override("panel", sp_style)
	add_child(settings_panel)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	settings_panel.add_child(vbox)
	
	var settings_title := Label.new()
	settings_title.text = "Configurações"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_override("font", font_bold)
	settings_title.add_theme_font_size_override("font_size", 32)
	settings_title.add_theme_color_override("font_color", COLOR_TITLE)
	vbox.add_child(settings_title)
	
	master_slider = _create_slider_row(vbox, "Volume Geral", AudioManager.master_volume, font_regular)
	master_slider.value_changed.connect(_on_master_volume_changed)
	
	bgm_slider = _create_slider_row(vbox, "Música (BGM)", AudioManager.bgm_volume, font_regular)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	
	sfx_slider = _create_slider_row(vbox, "Efeitos (SFX)", AudioManager.sfx_volume, font_regular)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	close_settings_btn = TextureButton.new()
	close_settings_btn.texture_normal = load("res://assets/sprites/ui_pack/Grey/Default/icon_cross.png")
	close_settings_btn.ignore_texture_size = true
	close_settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_settings_btn.custom_minimum_size = Vector2(32, 32)
	close_settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_settings_btn.pressed.connect(_on_close_settings_pressed)
	vbox.add_child(close_settings_btn)


func _create_slider_row(parent: Control, lbl_text: String, start_val: float, font: Font) -> HSlider:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", COLOR_TITLE)
	lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(lbl)
	
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = start_val
	hbox.add_child(slider)
	
	parent.add_child(hbox)
	return slider


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(SFX_CLICK_PLAY_PATH)
	settings_panel.visible = true

func _on_close_settings_pressed() -> void:
	AudioManager.play_sfx(SFX_CLICK_PLAY_PATH)
	settings_panel.visible = false

func _on_master_volume_changed(value: float) -> void:
	AudioManager.master_volume = value
	AudioManager.update_volumes()
	_play_slider_sfx()

func _on_bgm_volume_changed(value: float) -> void:
	AudioManager.bgm_volume = value
	AudioManager.update_volumes()
	_play_slider_sfx()

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.sfx_volume = value
	AudioManager.update_volumes()
	_play_slider_sfx()

func _play_slider_sfx() -> void:
	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")

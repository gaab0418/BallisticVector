extends Control

# -- Icones reutilizados (const preload evita recarregar o recurso) --
const ICON_COIN := preload("res://assets/sprites/icons/coin.png")
const ICON_CART := preload("res://assets/sprites/icons/cart.svg")
const ICON_ARROW_BACK := preload("res://assets/sprites/ui_pack/Grey/Default/arrow_basic_w.png")

const UiModalScript = preload("res://scripts/ui/ui_modal.gd")
const ShopPanelScript = preload("res://scripts/ui/shop_panel.gd")

const SFX_CLICK := "res://assets/audio/menu_click.ogg"
const SFX_BACK := "res://assets/audio/menu_back.ogg"
const SFX_HOVER := "res://assets/audio/menu_hover_.ogg"
const SFX_ERROR := "res://assets/audio/erro.ogg"

const HUD_HEIGHT := 50.0
const NAV_BUTTON_SIZE := Vector2(150, 44)
const ATTACK_POPUP_SIZE := Vector2(440, 260)

# ── Texturas ─────────────────────────────────────────────────────────
var tex_castle: Texture2D
var tex_castle_wide: Texture2D
var tex_tower_tall: Texture2D
var tex_flag: Texture2D
var tex_map_bg: Texture2D

# ── Referências internas ─────────────────────────────────────────────
var money_label: Label
var attack_modal: CanvasLayer
var attack_desc_label: Label
var attack_btn: Button
var shop: CanvasLayer
var base_labels: Dictionary = {}  # base_id -> Label (progresso)
var base_sprites: Dictionary = {}  # base_id -> TextureRect (sprite)
var base_flag_icons: Dictionary = {}  # base_id -> TextureRect (bandeira)
var base_glows: Dictionary = {}  # base_id -> TextureRect (aureola de hover)
var base_tweens: Dictionary = {}  # base_id -> Tween (animação de hover em andamento)
var tex_hover_glow: GradientTexture2D

var selected_base_id: String = ""

# ── Configuração das bases ───────────────────────────────────────────
const BASE_CONFIGS: Array = [
	{"id": "Base_A", "pos": Vector2(200, 250), "sprite": "castle"},
	{"id": "Base_B", "pos": Vector2(975, 580), "sprite": "castleWide"},
	{"id": "Base_C", "pos": Vector2(910, 340), "sprite": "towerTall"},
]


func _ready() -> void:
	if Global.are_all_bases_complete():
		get_tree().change_scene_to_file("res://scenes/victory/victory.tscn")
		return

	tex_castle = load("res://assets/sprites/cartography/Default/castle.png") as Texture2D
	tex_castle_wide = load("res://assets/sprites/cartography/Default/castleWide.png") as Texture2D
	tex_tower_tall = load("res://assets/sprites/cartography/Default/towerTall.png") as Texture2D
	tex_flag = load("res://assets/sprites/cartography/Default/flag.png") as Texture2D
	tex_map_bg = load("res://assets/sprites/game_map_fase_selecao.png") as Texture2D

	_build_background()
	_build_hud_panel()
	_build_bases()
	_build_bottom_buttons()

	# Loja e popup vivem em CanvasLayer proprio. Antes eram Control irmaos, e os
	# botoes de baixo, criados por ultimo, desenhavam por cima dos overlays e
	# ainda respondiam ao clique com o popup aberto.
	_build_attack_modal()
	_build_shop()

	# Música de fundo (AudioManager não reinicia se já estiver tocando)
	AudioManager.play_bgm("res://assets/audio/musica_fundo.wav")

	_refresh_all()


# ═════════════════════════════════════════════════════════════════════
#  CONSTRUÇÃO DA UI
# ═════════════════════════════════════════════════════════════════════


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = tex_map_bg
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_hud_panel() -> void:
	var panel := Panel.new()
	panel.name = "HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Faixa translucida com fio de luz embaixo, para o titulo nao competir com o
	# mapa. Nao usa o painel do Theme porque aqui so a borda inferior existe.
	var style := StyleBoxFlat.new()
	style.bg_color = UiTokens.BG_HUD
	style.border_width_bottom = UiTokens.BORDER_W_THIN
	style.border_color = UiTokens.BORDER
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = HUD_HEIGHT

	var money_container := HBoxContainer.new()
	money_container.name = "MoneyContainer"
	money_container.add_theme_constant_override("separation", UiTokens.PAD_SM)
	panel.add_child(money_container)
	money_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	money_container.offset_left = 20.0
	money_container.offset_top = -14.0
	money_container.offset_right = 300.0
	money_container.offset_bottom = 14.0

	var coin_icon := TextureRect.new()
	coin_icon.texture = ICON_COIN
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(24, 24)
	money_container.add_child(coin_icon)

	money_label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.text = "Ouro: 0"
	money_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	money_label.add_theme_color_override("font_color", UiTokens.GOLD)
	money_container.add_child(money_label)

	var title := Label.new()
	title.name = "MapTitle"
	title.text = "MAPA DE GUERRA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	title.add_theme_color_override("font_color", UiTokens.AMBER)
	panel.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left = -200.0
	title.offset_top = -14.0
	title.offset_right = 200.0
	title.offset_bottom = 14.0


func _build_hover_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.4, 0.95))
	gradient.set_color(1, Color(1.0, 0.85, 0.4, 0.0))

	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 256
	glow.height = 256
	return glow


func _build_bases() -> void:
	var sprite_map := {
		"castle": tex_castle,
		"castleWide": tex_castle_wide,
		"towerTall": tex_tower_tall,
	}
	tex_hover_glow = _build_hover_glow_texture()

	for cfg in BASE_CONFIGS:
		var base_id: String = cfg["id"]
		var tex: Texture2D = sprite_map[cfg["sprite"]]

		var container := Control.new()
		# base_id ja e "Base_A"; concatenar o prefixo dava "Base_Base_A".
		container.name = base_id
		container.position = cfg["pos"]
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(container)

		# Aureola que aparece atras do sprite no hover -- por baixo do modulate
		# porque o sprite sozinho clareado quase nao se destaca do fundo do mapa.
		var glow_size := Vector2(tex.get_width(), tex.get_height()) * 1.7
		var glow := TextureRect.new()
		glow.name = "HoverGlow"
		glow.texture = tex_hover_glow
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.size = glow_size
		glow.position = Vector2(-glow_size.x * 0.5, -tex.get_height() * 0.5 - glow_size.y * 0.5)
		glow.modulate = Color(1, 1, 1, 0)
		container.add_child(glow)
		base_glows[base_id] = glow

		var sprite := TextureRect.new()
		sprite.texture = tex
		sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		sprite.position = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		sprite.pivot_offset = Vector2(tex.get_width() * 0.5, tex.get_height())
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(sprite)
		base_sprites[base_id] = sprite

		var flag_icon := TextureRect.new()
		flag_icon.texture = tex_flag
		flag_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		flag_icon.position = Vector2(tex.get_width() * 0.3, -tex.get_height() - 10)
		flag_icon.visible = false
		flag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(flag_icon)
		base_flag_icons[base_id] = flag_icon

		# Area de clique invisivel sobre o sprite: o mapa e uma imagem, entao o
		# alvo precisa ser um Button flat por cima dela.
		var click_btn := Button.new()
		click_btn.name = "ClickArea"
		click_btn.flat = true
		click_btn.focus_mode = Control.FOCUS_NONE
		click_btn.position = Vector2(-tex.get_width() * 0.5 - 8, -tex.get_height() - 8)
		click_btn.custom_minimum_size = Vector2(tex.get_width() + 16, tex.get_height() + 16)
		click_btn.size = click_btn.custom_minimum_size
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click_btn.pressed.connect(_on_base_clicked.bind(base_id))
		click_btn.mouse_entered.connect(_on_base_hover.bind(base_id))
		click_btn.mouse_exited.connect(_on_base_unhover.bind(base_id))
		container.add_child(click_btn)

		var label := Label.new()
		label.name = "ProgressLabel"
		label.position = Vector2(-80, 8)
		label.custom_minimum_size = Vector2(160, 30)
		label.size = label.custom_minimum_size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
		# Sombra dura: este rotulo fica sobre a arte do mapa, nao sobre painel.
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		container.add_child(label)
		base_labels[base_id] = label


func _build_attack_modal() -> void:
	attack_modal = UiModalScript.new()
	add_child(attack_modal)
	attack_modal.window.custom_minimum_size = ATTACK_POPUP_SIZE
	attack_modal.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_modal.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	attack_modal.body.add_child(HSeparator.new())

	attack_desc_label = Label.new()
	attack_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attack_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attack_modal.body.add_child(attack_desc_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", UiTokens.GAP)
	attack_modal.body.add_child(btn_row)

	# Sem icone: joystick.png e preto solido, e icon_normal_color modula por
	# multiplicacao -- preto vezes qualquer cor continua preto. Sobre o fundo
	# escuro do tema ele virava um borrao. Vale para exit.png e audioOn/Off.
	attack_btn = UiButton.create("ATACAR", UiButton.Kind.PRIMARY)
	attack_btn.custom_minimum_size = Vector2(160, 48)
	attack_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	attack_btn.pressed.connect(_on_attack_pressed)
	btn_row.add_child(attack_btn)

	var cancel_btn := UiButton.create("Cancelar")
	cancel_btn.custom_minimum_size = Vector2(160, 48)
	cancel_btn.pressed.connect(_on_cancel_popup)
	btn_row.add_child(cancel_btn)


func _build_shop() -> void:
	shop = ShopPanelScript.new()
	add_child(shop)
	# O ouro do topo tambem muda quando o jogador compra.
	shop.purchased.connect(_refresh_all)
	shop.closed.connect(_refresh_all)


func _build_bottom_buttons() -> void:
	var shop_btn := UiButton.create("Loja", UiButton.Kind.SECONDARY, ICON_CART)
	shop_btn.name = "ShopButton"
	shop_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shop_btn.custom_minimum_size = NAV_BUTTON_SIZE
	shop_btn.pressed.connect(_on_shop_open)
	add_child(shop_btn)
	shop_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	shop_btn.offset_left = 20.0
	shop_btn.offset_top = -70.0
	shop_btn.offset_right = 20.0 + NAV_BUTTON_SIZE.x
	shop_btn.offset_bottom = -20.0

	var back_btn := UiButton.create("Voltar", UiButton.Kind.SECONDARY, ICON_ARROW_BACK)
	back_btn.name = "BackButton"
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	back_btn.custom_minimum_size = NAV_BUTTON_SIZE
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back_btn.offset_left = -20.0 - NAV_BUTTON_SIZE.x
	back_btn.offset_top = -70.0
	back_btn.offset_right = -20.0
	back_btn.offset_bottom = -20.0


# ═════════════════════════════════════════════════════════════════════
#  ATUALIZAÇÃO DA UI
# ═════════════════════════════════════════════════════════════════════


func _refresh_all() -> void:
	_update_money_display()
	_update_base_visuals()


func _update_money_display() -> void:
	if money_label:
		money_label.text = "Ouro: " + str(Global.money)


func _update_base_visuals() -> void:
	for cfg in BASE_CONFIGS:
		var base_id: String = cfg["id"]
		var data: Dictionary = Global.get_base_data(base_id)
		var base_name: String = data.get("name", base_id)
		var cleared: int = data.get("stages_cleared", 0)
		var total: int = data.get("total_stages", 3)
		var complete: bool = Global.is_base_complete(base_id)

		if base_labels.has(base_id):
			var label: Label = base_labels[base_id]
			if complete:
				label.text = base_name + "\n✓ Completa"
				label.add_theme_color_override("font_color", UiTokens.SUCCESS)
			else:
				label.text = "%s\nFase %d/%d" % [base_name, cleared + 1, total]
				label.add_theme_color_override("font_color", UiTokens.TEXT)

		if base_sprites.has(base_id):
			base_sprites[base_id].modulate = _base_tint(base_id)

		if base_flag_icons.has(base_id):
			base_flag_icons[base_id].visible = complete


func _base_tint(base_id: String, hovered: bool = false) -> Color:
	var complete := Global.is_base_complete(base_id)
	if hovered:
		# Realce quente e forte, perceptivel mesmo sobre o tom acinzentado das
		# bases ja conquistadas -- multiplicar o branco normal quase nao aparecia.
		return Color(1.0, 0.82, 0.4, 0.95) if complete else Color(1.7, 1.45, 0.55, 1.0)
	return Color(0.6, 0.6, 0.6, 0.85) if complete else Color.WHITE


func _set_base_hover_visual(base_id: String, hovered: bool) -> void:
	if not base_sprites.has(base_id):
		return
	var sprite: TextureRect = base_sprites[base_id]

	if base_tweens.has(base_id) and is_instance_valid(base_tweens[base_id]):
		base_tweens[base_id].kill()

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	base_tweens[base_id] = tween
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.1, 1.1) if hovered else Vector2.ONE, 0.12)
	tween.tween_property(sprite, "modulate", _base_tint(base_id, hovered), 0.12)

	if base_glows.has(base_id):
		var glow: TextureRect = base_glows[base_id]
		tween.tween_property(glow, "modulate:a", 1.0 if hovered else 0.0, 0.12)


# ═════════════════════════════════════════════════════════════════════
#  CALLBACKS — BASES
# ═════════════════════════════════════════════════════════════════════


func _on_base_hover(base_id: String) -> void:
	AudioManager.play_sfx(SFX_HOVER)
	_set_base_hover_visual(base_id, true)


func _on_base_unhover(base_id: String) -> void:
	_set_base_hover_visual(base_id, false)


func _on_base_clicked(base_id: String) -> void:
	AudioManager.play_sfx(SFX_CLICK)
	selected_base_id = base_id
	_show_attack_popup(base_id)


func _show_attack_popup(base_id: String) -> void:
	var data: Dictionary = Global.get_base_data(base_id)
	var base_name: String = data.get("name", base_id)
	var cleared: int = data.get("stages_cleared", 0)
	var total: int = data.get("total_stages", 3)

	if Global.is_base_complete(base_id):
		attack_modal.title_label.text = base_name
		attack_desc_label.text = "Base já conquistada!"
		attack_btn.disabled = true
		attack_btn.text = "CONQUISTADA"
	else:
		attack_modal.title_label.text = "%s — Fase %d de %d" % [base_name, cleared + 1, total]
		attack_desc_label.text = "Prepare-se para o combate!\nDerrote os inimigos para avançar."
		attack_btn.disabled = false
		attack_btn.text = "ATACAR"

	attack_modal.open()


func _on_attack_pressed() -> void:
	if selected_base_id.is_empty():
		return

	var data: Dictionary = Global.get_base_data(selected_base_id)
	if Global.is_base_complete(selected_base_id):
		AudioManager.play_sfx(SFX_ERROR)
		return

	# Configurar estado global para a arena
	Global.current_base_id = selected_base_id
	Global.current_stage = data.get("stages_cleared", 0)
	Global.reset_armor()

	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")


func _on_cancel_popup() -> void:
	AudioManager.play_sfx(SFX_BACK)
	attack_modal.close()


# ═════════════════════════════════════════════════════════════════════
#  CALLBACKS — LOJA E NAVEGAÇÃO
# ═════════════════════════════════════════════════════════════════════


func _on_shop_open() -> void:
	shop.open()


func _on_back_pressed() -> void:
	AudioManager.play_sfx(SFX_BACK)
	get_tree().change_scene_to_file("res://scenes/menu_play/menu_play.tscn")

extends Control

# ── Recursos de munição ──────────────────────────────────────────────
var ammo_enf: AmmoData
var ammo_perf: AmmoData

# ── Fontes ───────────────────────────────────────────────────────────
var font_bold: Font
var font_regular: Font

# ── Texturas ─────────────────────────────────────────────────────────
var tex_castle: Texture2D
var tex_castle_wide: Texture2D
var tex_tower_tall: Texture2D
var tex_flag: Texture2D
var tex_btn_grey: Texture2D
var tex_btn_yellow: Texture2D
var tex_map_bg: Texture2D

# ── Referências internas ─────────────────────────────────────────────
var money_label: Label
var attack_popup: PanelContainer
var attack_title_label: Label
var attack_desc_label: Label
var attack_btn: Button
var cancel_btn: Button
var shop_panel: PanelContainer
var shop_money_label: Label
var shop_label_enf: Label
var shop_label_perf: Label
var base_labels: Dictionary = {}     # base_id -> Label (progresso)
var base_sprites: Dictionary = {}    # base_id -> TextureRect (sprite)
var base_flag_icons: Dictionary = {} # base_id -> TextureRect (bandeira)

var selected_base_id: String = ""

# ── Configuração das bases ───────────────────────────────────────────
const BASE_CONFIGS: Array = [
	{"id": "Base_A", "pos": Vector2(300, 250), "sprite": "castle"},
	{"id": "Base_B", "pos": Vector2(640, 400), "sprite": "castleWide"},
	{"id": "Base_C", "pos": Vector2(1000, 300), "sprite": "towerTall"},
]


func _ready() -> void:
	# Carregar recursos
	ammo_enf = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	ammo_perf = load("res://assets/resources/ammo_perfurante.tres") as AmmoData

	font_bold = load("res://assets/fonts/Caveat/static/Caveat-Bold.ttf") as Font
	font_regular = load("res://assets/fonts/Caveat/static/Caveat-Regular.ttf") as Font

	tex_castle = load("res://assets/sprites/cartography/Default/castle.png") as Texture2D
	tex_castle_wide = load("res://assets/sprites/cartography/Default/castleWide.png") as Texture2D
	tex_tower_tall = load("res://assets/sprites/cartography/Default/towerTall.png") as Texture2D
	tex_flag = load("res://assets/sprites/cartography/Default/flag.png") as Texture2D
	tex_btn_grey = load("res://assets/sprites/ui_pack/Grey/Default/button_rectangle_depth_flat.png") as Texture2D
	tex_btn_yellow = load("res://assets/sprites/ui_pack/Yellow/Default/button_rectangle_depth_flat.png") as Texture2D
	tex_map_bg = load("res://assets/sprites/game_map_fase_selecao.png") as Texture2D

	_build_background()
	_build_hud_panel()
	_build_bases()
	_build_attack_popup()
	_build_shop_panel()
	_build_bottom_buttons()

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
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_hud_panel() -> void:
	# Painel semi-transparente superior
	var panel := Panel.new()
	panel.name = "HudPanel"
	panel.anchors_preset = Control.PRESET_TOP_WIDE
	panel.anchor_right = 1.0
	panel.offset_bottom = 50.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.75)
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.40, 0.22, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Label de ouro
	money_label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.anchors_preset = Control.PRESET_CENTER_LEFT
	money_label.anchor_left = 0.0
	money_label.anchor_top = 0.5
	money_label.anchor_right = 0.0
	money_label.anchor_bottom = 0.5
	money_label.offset_left = 20.0
	money_label.offset_top = -14.0
	money_label.offset_right = 300.0
	money_label.offset_bottom = 14.0
	money_label.text = "🪙 Ouro: 0"
	money_label.add_theme_font_override("font", font_bold)
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color.WHITE)
	money_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	money_label.add_theme_constant_override("shadow_offset_x", 2)
	money_label.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(money_label)

	# Título centralizado
	var title := Label.new()
	title.name = "MapTitle"
	title.anchors_preset = Control.PRESET_CENTER
	title.anchor_left = 0.5
	title.anchor_top = 0.5
	title.anchor_right = 0.5
	title.anchor_bottom = 0.5
	title.offset_left = -200.0
	title.offset_top = -14.0
	title.offset_right = 200.0
	title.offset_bottom = 14.0
	title.text = "⚔ MAPA DE GUERRA ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(title)


func _build_bases() -> void:
	var sprite_map := {
		"castle": tex_castle,
		"castleWide": tex_castle_wide,
		"towerTall": tex_tower_tall,
	}

	for cfg in BASE_CONFIGS:
		var base_id: String = cfg["id"]
		var pos: Vector2 = cfg["pos"]
		var sprite_key: String = cfg["sprite"]
		var tex: Texture2D = sprite_map[sprite_key]

		# Container para a base (sprite + label)
		var container := Control.new()
		container.name = "Base_" + base_id
		container.position = pos
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(container)

		# Sprite da base
		var sprite := TextureRect.new()
		sprite.texture = tex
		sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		sprite.position = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(sprite)
		base_sprites[base_id] = sprite

		# Bandeira de conquista (inicialmente invisível)
		var flag_icon := TextureRect.new()
		flag_icon.texture = tex_flag
		flag_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		flag_icon.position = Vector2(tex.get_width() * 0.3, -tex.get_height() - 10)
		flag_icon.visible = false
		flag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(flag_icon)
		base_flag_icons[base_id] = flag_icon

		# Botão clicável invisível sobre o sprite
		var click_btn := Button.new()
		click_btn.name = "ClickArea"
		click_btn.flat = true
		click_btn.position = Vector2(-tex.get_width() * 0.5 - 8, -tex.get_height() - 8)
		click_btn.custom_minimum_size = Vector2(tex.get_width() + 16, tex.get_height() + 16)
		click_btn.size = click_btn.custom_minimum_size
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click_btn.pressed.connect(_on_base_clicked.bind(base_id))
		click_btn.mouse_entered.connect(_on_base_hover.bind(base_id))
		container.add_child(click_btn)

		# Label de progresso abaixo do sprite
		var label := Label.new()
		label.name = "ProgressLabel"
		label.position = Vector2(-80, 8)
		label.custom_minimum_size = Vector2(160, 30)
		label.size = label.custom_minimum_size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", font_bold)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		container.add_child(label)
		base_labels[base_id] = label


func _build_attack_popup() -> void:
	# Overlay escuro para bloquear cliques atrás do popup
	var overlay := ColorRect.new()
	overlay.name = "PopupOverlay"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Painel do popup
	attack_popup = PanelContainer.new()
	attack_popup.name = "AttackPopup"
	attack_popup.visible = false
	attack_popup.anchors_preset = Control.PRESET_CENTER
	attack_popup.anchor_left = 0.5
	attack_popup.anchor_top = 0.5
	attack_popup.anchor_right = 0.5
	attack_popup.anchor_bottom = 0.5
	attack_popup.offset_left = -210.0
	attack_popup.offset_top = -140.0
	attack_popup.offset_right = 210.0
	attack_popup.offset_bottom = 140.0

	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.82, 0.73, 0.58, 0.95)
	popup_style.border_width_left = 3
	popup_style.border_width_top = 3
	popup_style.border_width_right = 3
	popup_style.border_width_bottom = 3
	popup_style.border_color = Color(0.35, 0.25, 0.12)
	popup_style.corner_radius_top_left = 12
	popup_style.corner_radius_top_right = 12
	popup_style.corner_radius_bottom_left = 12
	popup_style.corner_radius_bottom_right = 12
	popup_style.content_margin_left = 20.0
	popup_style.content_margin_top = 20.0
	popup_style.content_margin_right = 20.0
	popup_style.content_margin_bottom = 20.0
	popup_style.shadow_color = Color(0, 0, 0, 0.35)
	popup_style.shadow_size = 8
	attack_popup.add_theme_stylebox_override("panel", popup_style)
	add_child(attack_popup)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	attack_popup.add_child(vbox)

	# Título
	attack_title_label = Label.new()
	attack_title_label.name = "Title"
	attack_title_label.text = "Base Alpha — Fase 1 de 3"
	attack_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_title_label.add_theme_font_override("font", font_bold)
	attack_title_label.add_theme_font_size_override("font_size", 24)
	attack_title_label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.05))
	vbox.add_child(attack_title_label)

	# Separador decorativo
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.45, 0.32, 0.18, 0.6)
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Descrição
	attack_desc_label = Label.new()
	attack_desc_label.name = "Description"
	attack_desc_label.text = "Prepare-se para o combate!"
	attack_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_desc_label.add_theme_font_override("font", font_regular)
	attack_desc_label.add_theme_font_size_override("font_size", 20)
	attack_desc_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.1))
	attack_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(attack_desc_label)

	# Espaçador
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Botões
	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	# Botão ATACAR
	attack_btn = _create_texture_button("ATACAR", tex_btn_yellow, Color(0.15, 0.08, 0.0))
	attack_btn.name = "AttackBtn"
	attack_btn.custom_minimum_size = Vector2(150, 48)
	attack_btn.pressed.connect(_on_attack_pressed)
	btn_row.add_child(attack_btn)

	# Botão Cancelar
	cancel_btn = _create_texture_button("Cancelar", tex_btn_grey, Color(0.2, 0.15, 0.1))
	cancel_btn.name = "CancelBtn"
	cancel_btn.custom_minimum_size = Vector2(150, 48)
	cancel_btn.pressed.connect(_on_cancel_popup)
	btn_row.add_child(cancel_btn)


func _build_shop_panel() -> void:
	# Overlay da loja
	var overlay := ColorRect.new()
	overlay.name = "ShopOverlay"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Painel da loja
	shop_panel = PanelContainer.new()
	shop_panel.name = "ShopPanel"
	shop_panel.visible = false
	shop_panel.anchors_preset = Control.PRESET_CENTER
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -260.0
	shop_panel.offset_top = -200.0
	shop_panel.offset_right = 260.0
	shop_panel.offset_bottom = 200.0

	var shop_style := StyleBoxFlat.new()
	shop_style.bg_color = Color(0.78, 0.68, 0.52, 0.95)
	shop_style.border_width_left = 3
	shop_style.border_width_top = 3
	shop_style.border_width_right = 3
	shop_style.border_width_bottom = 3
	shop_style.border_color = Color(0.35, 0.25, 0.12)
	shop_style.corner_radius_top_left = 12
	shop_style.corner_radius_top_right = 12
	shop_style.corner_radius_bottom_left = 12
	shop_style.corner_radius_bottom_right = 12
	shop_style.shadow_color = Color(0, 0, 0, 0.35)
	shop_style.shadow_size = 8
	shop_panel.add_theme_stylebox_override("panel", shop_style)
	add_child(shop_panel)

	# Painel interno para borda dupla
	var inner_panel := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.78, 0.68, 0.52, 0.0)
	inner_style.border_width_left = 1
	inner_style.border_width_top = 1
	inner_style.border_width_right = 1
	inner_style.border_width_bottom = 1
	inner_style.border_color = Color(0.25, 0.18, 0.08, 0.5)
	inner_style.corner_radius_top_left = 10
	inner_style.corner_radius_top_right = 10
	inner_style.corner_radius_bottom_left = 10
	inner_style.corner_radius_bottom_right = 10
	inner_style.content_margin_left = 20.0
	inner_style.content_margin_top = 15.0
	inner_style.content_margin_right = 20.0
	inner_style.content_margin_bottom = 15.0
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	shop_panel.add_child(inner_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	inner_panel.add_child(vbox)

	# Cabeçalho da loja
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var shop_title := Label.new()
	shop_title.text = "⚙ Loja de Munições"
	shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_title.add_theme_font_override("font", font_bold)
	shop_title.add_theme_font_size_override("font_size", 28)
	shop_title.add_theme_color_override("font_color", Color(0.2, 0.12, 0.05))
	header.add_child(shop_title)

	var close_btn := Button.new()
	close_btn.name = "CloseShopBtn"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.add_theme_font_override("font", font_bold)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_on_close_shop)
	header.add_child(close_btn)

	# Separador decorativo
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.35, 0.25, 0.12, 0.8)
	sep_style.content_margin_top = 2.0
	sep_style.content_margin_bottom = 2.0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Ouro com destaque (fundo semi-transparente)
	var money_bg := PanelContainer.new()
	var money_bg_style := StyleBoxFlat.new()
	money_bg_style.bg_color = Color(0.1, 0.08, 0.05, 0.6)
	money_bg_style.corner_radius_top_left = 8
	money_bg_style.corner_radius_top_right = 8
	money_bg_style.corner_radius_bottom_left = 8
	money_bg_style.corner_radius_bottom_right = 8
	money_bg_style.content_margin_left = 15.0
	money_bg_style.content_margin_top = 8.0
	money_bg_style.content_margin_right = 15.0
	money_bg_style.content_margin_bottom = 8.0
	money_bg.add_theme_stylebox_override("panel", money_bg_style)
	money_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(money_bg)

	shop_money_label = Label.new()
	shop_money_label.name = "ShopMoneyLabel"
	shop_money_label.text = "🪙 Ouro: 0"
	shop_money_label.add_theme_font_override("font", font_bold)
	shop_money_label.add_theme_font_size_override("font_size", 24)
	shop_money_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.15))
	money_bg.add_child(shop_money_label)

	# ── Item Enferrujada ─────────────────────────────────────────────
	var row_enf := _build_shop_item_row(
		ammo_enf, 5, "_on_buy_enferrujada"
	)
	vbox.add_child(row_enf)

	# ── Item Perfurante ──────────────────────────────────────────────
	var row_perf := _build_shop_item_row(
		ammo_perf, 3, "_on_buy_perfurante"
	)
	vbox.add_child(row_perf)


func _build_shop_item_row(ammo: AmmoData, qty: int, callback_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.72, 0.62, 0.45, 0.8)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.4, 0.3, 0.15, 0.8)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 15.0
	card_style.content_margin_top = 15.0
	card_style.content_margin_right = 15.0
	card_style.content_margin_bottom = 15.0
	card.add_theme_stylebox_override("panel", card_style)
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	card.add_child(row)

	# Ícone do Míssil (Procedural 2D)
	var icon := load("res://scripts/ammo_icon.gd").new(ammo.color)
	row.add_child(icon)

	# VBox Centro (Nome + Estoque)
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(center_vbox)

	var label := Label.new()
	label.add_theme_font_override("font", font_bold)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.05))
	center_vbox.add_child(label)

	var stock_label := Label.new()
	stock_label.add_theme_font_override("font", font_regular)
	stock_label.add_theme_font_size_override("font_size", 16)
	stock_label.add_theme_color_override("font_color", Color(0.3, 0.25, 0.2))
	center_vbox.add_child(stock_label)

	if ammo.ammo_name == "Enferrujada":
		shop_label_enf = label
	else:
		shop_label_perf = label
		
	# Adiciona stock_label como um meta para facilitar a atualização
	label.set_meta("stock_label", stock_label)

	# VBox Direita (Preço + Botão)
	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 5)
	row.add_child(right_vbox)

	var price_label := Label.new()
	price_label.text = str(ammo.price * qty) + " G (x" + str(qty) + ")"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override("font", font_bold)
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color(0.5, 0.35, 0.12))
	right_vbox.add_child(price_label)

	var buy_btn := _create_texture_button("Comprar", tex_btn_yellow if tex_btn_yellow else tex_btn_grey, Color(0.15, 0.1, 0.05))
	buy_btn.custom_minimum_size = Vector2(110, 36)
	buy_btn.pressed.connect(Callable(self, callback_name))
	right_vbox.add_child(buy_btn)

	return card


func _build_bottom_buttons() -> void:
	# ── Botão Loja (canto inferior esquerdo) ─────────────────────────
	var shop_btn := _create_texture_button("⚙ Loja", tex_btn_grey, Color(0.15, 0.08, 0.0))
	shop_btn.name = "ShopButton"
	shop_btn.anchors_preset = Control.PRESET_BOTTOM_LEFT
	shop_btn.anchor_left = 0.0
	shop_btn.anchor_top = 1.0
	shop_btn.anchor_right = 0.0
	shop_btn.anchor_bottom = 1.0
	shop_btn.offset_left = 20.0
	shop_btn.offset_top = -70.0
	shop_btn.offset_right = 170.0
	shop_btn.offset_bottom = -20.0
	shop_btn.pressed.connect(_on_shop_open)
	add_child(shop_btn)

	# ── Botão Voltar (canto inferior direito) ────────────────────────
	var back_btn := _create_texture_button("◀ Voltar", tex_btn_grey, Color(0.15, 0.08, 0.0))
	back_btn.name = "BackButton"
	back_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	back_btn.anchor_left = 1.0
	back_btn.anchor_top = 1.0
	back_btn.anchor_right = 1.0
	back_btn.anchor_bottom = 1.0
	back_btn.offset_left = -170.0
	back_btn.offset_top = -70.0
	back_btn.offset_right = -20.0
	back_btn.offset_bottom = -20.0
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)


# ═════════════════════════════════════════════════════════════════════
#  HELPERS
# ═════════════════════════════════════════════════════════════════════

func _create_texture_button(text: String, tex: Texture2D, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.clip_text = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_style := StyleBoxTexture.new()
	normal_style.texture = tex
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_right = 12.0
	normal_style.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.modulate_color = Color(1.1, 1.05, 0.95)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.modulate_color = Color(0.85, 0.8, 0.75)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_override("font", font_bold)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", Color(0.35, 0.2, 0.05))

	return btn


# ═════════════════════════════════════════════════════════════════════
#  ATUALIZAÇÃO DA UI
# ═════════════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_update_money_display()
	_update_base_visuals()
	_update_shop_ui()


func _update_money_display() -> void:
	if money_label:
		money_label.text = "🪙 Ouro: " + str(Global.money)


func _update_base_visuals() -> void:
	for cfg in BASE_CONFIGS:
		var base_id: String = cfg["id"]
		var data: Dictionary = Global.get_base_data(base_id)
		var base_name: String = data.get("name", base_id)
		var cleared: int = data.get("stages_cleared", 0)
		var total: int = data.get("total_stages", 3)
		var complete: bool = Global.is_base_complete(base_id)

		# Atualizar label de progresso
		if base_labels.has(base_id):
			if complete:
				base_labels[base_id].text = base_name + "\n✓ Completa"
				base_labels[base_id].add_theme_color_override(
					"font_color", Color(0.4, 0.75, 0.3))
			else:
				base_labels[base_id].text = base_name + "\nFase " + str(cleared + 1) + "/" + str(total)

		# Modular sprite para cinza se completa
		if base_sprites.has(base_id):
			if complete:
				base_sprites[base_id].modulate = Color(0.6, 0.6, 0.6, 0.85)
			else:
				base_sprites[base_id].modulate = Color.WHITE

		# Bandeira visível se base completa
		if base_flag_icons.has(base_id):
			base_flag_icons[base_id].visible = complete


func _update_shop_ui() -> void:
	if shop_money_label:
		shop_money_label.text = "🪙 Ouro: " + str(Global.money)

	var count_enf: int = Global.ammo_inventory.get(ammo_enf.ammo_name, 0)
	var count_perf: int = Global.ammo_inventory.get(ammo_perf.ammo_name, 0)

	if shop_label_enf:
		shop_label_enf.text = ammo_enf.ammo_name
		if shop_label_enf.has_meta("stock_label"):
			var sl: Label = shop_label_enf.get_meta("stock_label")
			sl.text = "(" + str(count_enf) + "/" + str(ammo_enf.max_ammo) + ")"
	if shop_label_perf:
		shop_label_perf.text = ammo_perf.ammo_name
		if shop_label_perf.has_meta("stock_label"):
			var sl: Label = shop_label_perf.get_meta("stock_label")
			sl.text = "(" + str(count_perf) + "/" + str(ammo_perf.max_ammo) + ")"


# ═════════════════════════════════════════════════════════════════════
#  CALLBACKS — BASES
# ═════════════════════════════════════════════════════════════════════

func _on_base_hover(_base_id: String) -> void:
	AudioManager.play_sfx("res://assets/audio/menu_hover_.ogg")


func _on_base_clicked(base_id: String) -> void:
	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")
	selected_base_id = base_id
	_show_attack_popup(base_id)


func _show_attack_popup(base_id: String) -> void:
	var data: Dictionary = Global.get_base_data(base_id)
	var base_name: String = data.get("name", base_id)
	var cleared: int = data.get("stages_cleared", 0)
	var total: int = data.get("total_stages", 3)
	var complete: bool = Global.is_base_complete(base_id)

	if complete:
		attack_title_label.text = base_name
		attack_desc_label.text = "⚑ Base já conquistada!"
		attack_btn.disabled = true
		attack_btn.text = "CONQUISTADA"
	else:
		attack_title_label.text = base_name + " — Fase " + str(cleared + 1) + " de " + str(total)
		attack_desc_label.text = "Prepare-se para o combate!\nDerrote os inimigos para avançar."
		attack_btn.disabled = false
		attack_btn.text = "⚔ ATACAR"

	# Mostrar overlay e popup
	var overlay = get_node("PopupOverlay")
	if overlay:
		overlay.visible = true
	attack_popup.visible = true


func _on_attack_pressed() -> void:
	if selected_base_id.is_empty():
		return

	var data: Dictionary = Global.get_base_data(selected_base_id)
	if Global.is_base_complete(selected_base_id):
		AudioManager.play_sfx("res://assets/audio/erro.ogg")
		return

	# Configurar estado global para a arena
	Global.current_base_id = selected_base_id
	Global.current_stage = data.get("stages_cleared", 0)
	Global.reset_armor()

	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")


func _on_cancel_popup() -> void:
	AudioManager.play_sfx("res://assets/audio/menu_back.ogg")
	attack_popup.visible = false
	var overlay = get_node("PopupOverlay")
	if overlay:
		overlay.visible = false


# ═════════════════════════════════════════════════════════════════════
#  CALLBACKS — LOJA
# ═════════════════════════════════════════════════════════════════════

func _on_shop_open() -> void:
	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")
	_update_shop_ui()
	var overlay = get_node("ShopOverlay")
	if overlay:
		overlay.visible = true
	shop_panel.visible = true


func _on_close_shop() -> void:
	AudioManager.play_sfx("res://assets/audio/menu_back.ogg")
	shop_panel.visible = false
	var overlay = get_node("ShopOverlay")
	if overlay:
		overlay.visible = false
	_update_money_display()
	_update_base_visuals()


func _on_buy_enferrujada() -> void:
	_buy_ammo_batch(ammo_enf, 5)


func _on_buy_perfurante() -> void:
	_buy_ammo_batch(ammo_perf, 3)


func _buy_ammo_batch(ammo: AmmoData, qty: int) -> void:
	var current_count: int = Global.ammo_inventory.get(ammo.ammo_name, 0)
	var total_cost: int = ammo.price * qty
	var can_add: int = ammo.max_ammo - current_count

	if can_add <= 0:
		AudioManager.play_sfx("res://assets/audio/erro.ogg")
		_flash_error_money()
		return

	# Ajustar quantidade se ultrapassar o máximo
	var actual_qty: int = mini(qty, can_add)
	var actual_cost: int = ammo.price * actual_qty

	if Global.money < actual_cost:
		AudioManager.play_sfx("res://assets/audio/erro.ogg")
		_flash_error_money()
		return

	Global.money -= actual_cost
	Global.ammo_inventory[ammo.ammo_name] = current_count + actual_qty
	AudioManager.play_sfx("res://assets/audio/menu_click.ogg")
	
	if ammo.ammo_name == "Enferrujada":
		_flash_success_label(shop_label_enf)
	else:
		_flash_success_label(shop_label_perf)
		
	_update_shop_ui()


func _flash_error_money() -> void:
	var original_color = Color(0.75, 0.6, 0.15)
	var tween = create_tween()
	shop_money_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	tween.tween_property(shop_money_label, "theme_override_colors/font_color", original_color, 0.5)


func _flash_success_label(label: Label) -> void:
	var original_color = Color(0.2, 0.12, 0.05)
	var tween = create_tween()
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	tween.tween_property(label, "theme_override_colors/font_color", original_color, 0.4)


# ═════════════════════════════════════════════════════════════════════
#  CALLBACKS — NAVEGAÇÃO
# ═════════════════════════════════════════════════════════════════════

func _on_back_pressed() -> void:
	AudioManager.play_sfx("res://assets/audio/menu_back.ogg")
	get_tree().change_scene_to_file("res://scenes/menu_play/menu_play.tscn")

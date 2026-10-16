extends Control
## Mapa de guerra: o pergaminho cartesiano (WarTable) com as quatro bases
## (capitulos) da campanha, cada uma numa ilha com coordenadas inteiras.
##
## As bases ficam ancoradas em coordenadas do plano cartesiano do mapa e sao
## reposicionadas a cada mudanca de tamanho: nada e recortado nem sai do lugar.

const ICON_COIN := preload("res://assets/sprites/icons/coin.png")
const ICON_CART := preload("res://assets/sprites/icons/cart.svg")
const ICON_ARROW_BACK := preload("res://assets/sprites/ui_pack/Grey/Default/arrow_basic_w.png")
const TEX_CASTLE := preload("res://assets/sprites/cartography/Default/castle.png")
const TEX_CASTLE_WIDE := preload("res://assets/sprites/cartography/Default/castleWide.png")
const TEX_TOWER := preload("res://assets/sprites/cartography/Default/towerTall.png")

const UiModalScript = preload("res://scripts/ui/ui_modal.gd")
const ShopPanelScript = preload("res://scripts/ui/shop_panel.gd")
const BaseMarkerScript = preload("res://scenes/war_map/base_marker.gd")
const WarTableScript = preload("res://scenes/war_map/war_table.gd")

const SFX_CLICK := "res://assets/audio/menu_click.ogg"
const SFX_BACK := "res://assets/audio/menu_back.ogg"
const SFX_ERROR := "res://assets/audio/erro.ogg"

const TOP_BAR_H := 60.0
const NAV_BUTTON_SIZE := Vector2(170, 52)
const CARD_W := 300.0
const ATTACK_POPUP_SIZE := Vector2(520, 0)

## Bases na ordem das ilhas de WarTable.ISLANDS (as coordenadas moram la).
const BASE_CONFIGS: Array = [
	{"id": "Base_A", "tex": "castle", "flip": false},
	{"id": "Base_B", "tex": "wide", "flip": false},
	{"id": "Base_C", "tex": "tower", "flip": false},
	{"id": "Base_D", "tex": "castle", "flip": true},
]

var money_label: Label
var stars_label: Label
var attack_modal: CanvasLayer
var shop: CanvasLayer
var selected_base_id: String = ""
var selected_stage: int = 0

var _table: WarTable
var _markers: Dictionary = {}
var _card: PanelContainer
var _card_title: Label
var _card_body: VBoxContainer
var _attack_title: Label
var _attack_blurb: Label
var _attack_rows: VBoxContainer
var _attack_btn: Button
var _stage_group := ButtonGroup.new()


func _ready() -> void:
	if Global.are_all_bases_complete():
		get_tree().change_scene_to_file("res://scenes/victory/victory.tscn")
		return

	_build_table()
	_build_markers()
	_build_card()
	_build_top_bar()
	_build_bottom_buttons()

	# Loja e popup vivem em CanvasLayer proprio: com o popup aberto, nada do mapa
	# atras dele desenha por cima nem responde ao clique.
	_build_attack_modal()
	_build_shop()

	AudioManager.play_bgm("res://assets/audio/musica_fundo.wav")
	_table.resized.connect(_layout_markers)
	_layout_markers.call_deferred()
	_refresh_all()
	_focus_next_base.call_deferred()


# ═════════════════════════════════════════════════════════════════════
#  CONSTRUÇÃO
# ═════════════════════════════════════════════════════════════════════


func _build_table() -> void:
	_table = WarTableScript.new()
	_table.name = "WarTable"
	_table.top_margin = TOP_BAR_H + 8.0
	add_child(_table)
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Coordenada (x, y) da base no plano cartesiano do mapa.
func _base_grid(index: int) -> Vector2:
	return WarTable.ISLANDS[index].grid


func _build_markers() -> void:
	var textures := {"castle": TEX_CASTLE, "wide": TEX_CASTLE_WIDE, "tower": TEX_TOWER}
	for cfg in BASE_CONFIGS:
		var id: String = cfg.id
		var data: Dictionary = Global.get_base_data(id)
		var marker: BaseMarker = BaseMarkerScript.new()
		marker.name = id
		add_child(marker)
		marker.setup(
			id, textures[cfg.tex], cfg.flip, data.get("name", id), Campaign.base(id).chapter
		)
		marker.pressed.connect(_on_base_clicked.bind(id))
		marker.mouse_entered.connect(_show_card.bind(id))
		marker.focus_entered.connect(_show_card.bind(id))
		marker.mouse_exited.connect(_hide_card)
		marker.focus_exited.connect(_hide_card)
		_markers[id] = marker


func _layout_markers() -> void:
	for i in range(BASE_CONFIGS.size()):
		var marker: BaseMarker = _markers[BASE_CONFIGS[i].id]
		var p := _table.grid_to_screen(_base_grid(i))
		marker.position = p - Vector2(BaseMarker.PLAQUE_W * 0.5, BaseMarker.CASTLE * 0.55)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UiPanel.frame(UiTokens.BG_HUD, UiTokens.BORDER, 1, 4))
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_BAR_H

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)
	bar.add_child(row)

	var gold := HBoxContainer.new()
	gold.add_theme_constant_override("separation", UiTokens.PAD_SM)
	gold.custom_minimum_size = Vector2(260, 0)
	row.add_child(gold)
	var coin := TextureRect.new()
	coin.texture = ICON_COIN
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(34, 34)
	gold.add_child(coin)
	money_label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	money_label.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	money_label.add_theme_color_override("font_color", UiTokens.GOLD)
	gold.add_child(money_label)

	var title := Label.new()
	title.name = "MapTitle"
	title.text = "MAPA DE GUERRA"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_END
	stars.add_theme_constant_override("separation", UiTokens.PAD_SM)
	stars.custom_minimum_size = Vector2(260, 0)
	row.add_child(stars)
	stars.add_child(UiIcon.make("star", UiTokens.MEDAL_GOLD, 30.0))
	stars_label = Label.new()
	stars_label.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	stars_label.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	stars.add_child(stars_label)


## Cartao que aparece ao passar o mouse (ou focar pelo teclado) numa base.
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	_card.custom_minimum_size = Vector2(CARD_W, 0)
	_card.visible = false
	_card.z_index = 5
	add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_card.add_child(col)
	_card_title = Label.new()
	_card_title.theme_type_variation = &"InkLabel"
	_card_title.add_theme_font_override("font", UiTheme.title_font())
	_card_title.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	col.add_child(_card_title)
	_card_body = VBoxContainer.new()
	_card_body.add_theme_constant_override("separation", 2)
	col.add_child(_card_body)


func _show_card(base_id: String) -> void:
	var info: Dictionary = Campaign.base(base_id)
	var data: Dictionary = Global.get_base_data(base_id)
	_card_title.text = "%s — %s" % [data.get("name", base_id), info.chapter]
	for child in _card_body.get_children():
		child.queue_free()

	var index := _index_of(base_id)
	var g := _base_grid(index)
	var coords := Label.new()
	coords.text = "Coordenadas no mapa: (%d, %d)" % [roundi(g.x), roundi(g.y)]
	coords.theme_type_variation = &"InkLabel"
	coords.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	coords.add_theme_color_override("font_color", UiTokens.CALCULATED_ON_PAPER)
	_card_body.add_child(coords)

	var blurb := Label.new()
	blurb.text = info.blurb
	blurb.theme_type_variation = &"InkLabel"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(CARD_W - 40.0, 0)
	_card_body.add_child(blurb)

	var stars: Array = data.get("stars", [0, 0, 0])
	var cleared: int = data.get("stages_cleared", 0)
	for i in range(info.stages.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_label := Label.new()
		name_label.text = "%d. %s" % [i + 1, info.stages[i].title]
		name_label.theme_type_variation = &"InkLabel"
		name_label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > cleared:
			name_label.add_theme_color_override("font_color", UiTokens.MAP_ROUTE)
		row.add_child(name_label)
		for k in range(3):
			var on: bool = k < int(stars[i])
			# Sem contorno no papel: a tinta ja contrasta, e o contorno escuro
			# engrossava a estrela vazia ate parecer cheia.
			var star := UiIcon.make(
				"star" if on else "star_empty", UiTokens.EDITABLE_ON_PAPER, 18.0
			)
			star.outlined = false
			row.add_child(star)
		_card_body.add_child(row)

	var hint := Label.new()
	hint.theme_type_variation = &"InkLabel"
	hint.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	if Global.is_base_unlocked(base_id):
		hint.text = "Clique (ou Enter) para escolher a fase"
	else:
		hint.text = "Conquiste a base anterior para liberar"
		hint.add_theme_color_override("font_color", UiTokens.DANGER_ON_PAPER)
	_card_body.add_child(hint)

	# Ao lado da base, do lado que tiver espaco.
	var marker: BaseMarker = _markers[base_id]
	var at := marker.position + Vector2(BaseMarker.PLAQUE_W + 8.0, 0)
	if at.x + CARD_W > size.x - 8.0:
		at.x = marker.position.x - CARD_W - 8.0
	at.y = clampf(at.y, TOP_BAR_H + 8.0, size.y - 260.0)
	_card.position = at
	_card.visible = true
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, UiTokens.ANIM_FAST)


func _hide_card() -> void:
	_card.visible = false


func _build_attack_modal() -> void:
	attack_modal = UiModalScript.new()
	add_child(attack_modal)
	attack_modal.window.custom_minimum_size = ATTACK_POPUP_SIZE

	_attack_blurb = Label.new()
	_attack_blurb.theme_type_variation = &"CaptionLabel"
	_attack_blurb.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	attack_modal.body.add_child(_attack_blurb)
	_attack_title = attack_modal.title_label

	_attack_rows = VBoxContainer.new()
	_attack_rows.add_theme_constant_override("separation", 6)
	attack_modal.body.add_child(_attack_rows)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", UiTokens.GAP)
	attack_modal.body.add_child(btn_row)

	var cancel_btn := UiButton.create("Cancelar", UiButton.Kind.SECONDARY, null, true)
	cancel_btn.custom_minimum_size = Vector2(180, 52)
	cancel_btn.pressed.connect(_on_cancel_popup)
	btn_row.add_child(cancel_btn)

	_attack_btn = UiButton.create("ATACAR!", UiButton.Kind.PRIMARY, null, true)
	_attack_btn.custom_minimum_size = Vector2(220, 52)
	_attack_btn.pressed.connect(_on_attack_pressed)
	btn_row.add_child(_attack_btn)


func _build_shop() -> void:
	shop = ShopPanelScript.new()
	add_child(shop)
	# O ouro do topo tambem muda quando o jogador compra.
	shop.purchased.connect(_refresh_all)
	shop.closed.connect(_refresh_all)


func _build_bottom_buttons() -> void:
	var shop_btn := UiButton.create("Loja", UiButton.Kind.SECONDARY, ICON_CART, true)
	shop_btn.name = "ShopButton"
	shop_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shop_btn.custom_minimum_size = NAV_BUTTON_SIZE
	shop_btn.pressed.connect(_on_shop_open)
	add_child(shop_btn)
	shop_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	shop_btn.offset_left = 20.0
	shop_btn.offset_top = -20.0 - NAV_BUTTON_SIZE.y
	shop_btn.offset_right = 20.0 + NAV_BUTTON_SIZE.x
	shop_btn.offset_bottom = -20.0

	var back_btn := UiButton.create("Voltar", UiButton.Kind.SECONDARY, ICON_ARROW_BACK, true)
	back_btn.name = "BackButton"
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	back_btn.custom_minimum_size = NAV_BUTTON_SIZE
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back_btn.offset_left = -20.0 - NAV_BUTTON_SIZE.x
	back_btn.offset_top = -20.0 - NAV_BUTTON_SIZE.y
	back_btn.offset_right = -20.0
	back_btn.offset_bottom = -20.0


# ═════════════════════════════════════════════════════════════════════
#  ATUALIZAÇÃO
# ═════════════════════════════════════════════════════════════════════


func _refresh_all() -> void:
	if money_label:
		money_label.text = str(Global.money)
	if stars_label:
		stars_label.text = "%d / %d" % [Global.total_stars(), BASE_CONFIGS.size() * 9]
	for cfg in BASE_CONFIGS:
		var id: String = cfg.id
		var data: Dictionary = Global.get_base_data(id)
		var state := BaseMarker.State.OPEN
		if Global.is_base_complete(id):
			state = BaseMarker.State.DONE
		elif not Global.is_base_unlocked(id):
			state = BaseMarker.State.LOCKED
		_markers[id].set_progress(
			state,
			data.get("stars", [0, 0, 0]),
			data.get("stages_cleared", 0),
			data.get("total_stages", 3)
		)
	if _table:
		var done := []
		for i in range(BASE_CONFIGS.size() - 1):
			done.append(Global.is_base_complete(BASE_CONFIGS[i].id))
		_table.done_routes = done
		_table.queue_redraw()


func _index_of(base_id: String) -> int:
	for i in range(BASE_CONFIGS.size()):
		if BASE_CONFIGS[i].id == base_id:
			return i
	return 0


func _focus_next_base() -> void:
	for cfg in BASE_CONFIGS:
		if Global.is_base_unlocked(cfg.id) and not Global.is_base_complete(cfg.id):
			_markers[cfg.id].grab_focus()
			return


# ═════════════════════════════════════════════════════════════════════
#  CALLBACKS — BASES
# ═════════════════════════════════════════════════════════════════════


func _on_base_clicked(base_id: String) -> void:
	if not Global.is_base_unlocked(base_id):
		AudioManager.play_sfx(SFX_ERROR)
		(
			_markers[base_id]
			. create_tween()
			. tween_property(_markers[base_id], "rotation", 0.0, 0.25)
			. from(0.06)
		)
		return
	selected_base_id = base_id
	_show_attack_popup(base_id)


## Lista as tres fases: as ja vencidas e a proxima podem ser escolhidas
## (rejogar vale mais estrelas); as seguintes aparecem trancadas.
func _show_attack_popup(base_id: String) -> void:
	var info: Dictionary = Campaign.base(base_id)
	var data: Dictionary = Global.get_base_data(base_id)
	var cleared: int = data.get("stages_cleared", 0)
	var stars: Array = data.get("stars", [0, 0, 0])
	_attack_title.text = "%s — %s" % [data.get("name", base_id), info.chapter]
	_attack_blurb.text = info.blurb

	for child in _attack_rows.get_children():
		child.queue_free()
	_stage_group = ButtonGroup.new()
	selected_stage = mini(cleared, info.stages.size() - 1)
	var first_btn: Button = null
	for i in range(info.stages.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var open := i <= cleared
		var label := "%d. %s" % [i + 1, info.stages[i].title]
		var btn := UiButton.create(label, UiButton.Kind.SECONDARY, null, true)
		btn.toggle_mode = true
		btn.button_group = _stage_group
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(330, 46)
		btn.disabled = not open
		btn.add_theme_color_override("font_pressed_color", UiTokens.EDITABLE)
		btn.button_pressed = i == selected_stage
		btn.toggled.connect(_on_stage_toggled.bind(i))
		row.add_child(btn)
		if i == selected_stage:
			first_btn = btn
		if not open:
			row.add_child(UiIcon.make("lock", UiTokens.TEXT_DISABLED, 22.0))
		for k in range(3):
			var on: bool = k < int(stars[i])
			row.add_child(UiIcon.make("star" if on else "star_empty", UiTokens.EDITABLE, 24.0))
		_attack_rows.add_child(row)

	attack_modal.open()
	if first_btn:
		first_btn.grab_focus.call_deferred()


func _on_stage_toggled(on: bool, index: int) -> void:
	if on:
		selected_stage = index


func _on_attack_pressed() -> void:
	if selected_base_id.is_empty() or not Global.is_base_unlocked(selected_base_id):
		AudioManager.play_sfx(SFX_ERROR)
		return
	# Configurar estado global para a arena
	Global.current_base_id = selected_base_id
	Global.current_stage = selected_stage
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

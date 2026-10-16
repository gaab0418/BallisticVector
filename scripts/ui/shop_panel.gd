class_name ShopPanel
extends UiModal
## Loja de municoes e reparo, aberta pelo mapa de guerra.
##
## Cada municao mostra a sua ficha -- gravidade, precisao e dano -- porque isso
## muda a parabola na arena: a crianca escolhe sabendo que a Perfurante cai mais
## devagar (gravidade menor) e erra menos (faixa de queda menor na regua).
##
## Os tres cards passam pelo mesmo _build_card(); antes o kit de reparo era uma
## copia divergente do card de municao.

signal purchased

const AmmoIconScript = preload("res://scripts/ammo_icon.gd")

const ICON_COIN := preload("res://assets/sprites/icons/coin.png")

const SFX_CLICK := "res://assets/audio/menu_click.ogg"
const SFX_ERROR := "res://assets/audio/erro.ogg"

const PANEL_SIZE := Vector2(600, 0)
const ICON_SIZE := Vector2(40, 40)
const BUY_SIZE := Vector2(150, 48)

## Lotes de compra e custo do reparo.
const BATCH_ENFERRUJADA := 5
const BATCH_PERFURANTE := 3
const REPAIR_COST := 100
const REPAIR_HEAL := 30.0

var _ammo_enf: AmmoData
var _ammo_perf: AmmoData

var _money_label: Label
var _repair_label: Label
## ammo_name -> {"card": Control, "stock": Label}
var _rows: Dictionary = {}
var _repair_card: Control
var _first_buy: Button


func _build_content() -> void:
	pauses_game = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "Loja de Munições"

	_ammo_enf = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	_ammo_perf = load("res://assets/resources/ammo_perfurante.tres") as AmmoData

	body.add_child(_build_money_badge())
	body.add_child(_build_ammo_card(_ammo_enf, BATCH_ENFERRUJADA))
	body.add_child(_build_ammo_card(_ammo_perf, BATCH_PERFURANTE))
	body.add_child(_build_repair_card())

	var back := UiButton.create("VOLTAR AO MAPA", UiButton.Kind.SECONDARY, null, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	body.add_child(back)


func open() -> void:
	refresh()
	super()
	_first_buy.grab_focus.call_deferred()


func refresh() -> void:
	if _money_label:
		_money_label.text = str(Global.money)

	for ammo in [_ammo_enf, _ammo_perf]:
		if not _rows.has(ammo.ammo_name):
			continue
		var count: int = Global.ammo_inventory.get(ammo.ammo_name, 0)
		_rows[ammo.ammo_name]["stock"].text = "no estoque: %d de %d" % [count, ammo.max_ammo]

	if _repair_label:
		var pct := int(Global.player_armor / Global.max_player_armor * 100.0)
		_repair_label.text = "blindagem atual: %d%%  ·  conserta %d" % [pct, int(REPAIR_HEAL)]


# ═════════════════════════════════════════════════════════════════════
#  CONSTRUÇÃO
# ═════════════════════════════════════════════════════════════════════


func _build_money_badge() -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.CARD))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.PAD_SM)
	badge.add_child(row)

	var coin := TextureRect.new()
	coin.texture = ICON_COIN
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(32, 32)
	row.add_child(coin)

	_money_label = Label.new()
	_money_label.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	_money_label.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	_money_label.add_theme_color_override("font_color", UiTokens.GOLD)
	row.add_child(_money_label)

	var unit := Label.new()
	unit.text = "de ouro"
	unit.theme_type_variation = &"CaptionLabel"
	row.add_child(unit)
	return badge


## Molde unico dos tres itens da loja. `details` e uma linha de fichas
## (icone + texto) abaixo do nome.
func _build_card(
	icon: Control, title: String, price: int, details: Control, on_buy: Callable
) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.CARD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)
	card.add_child(row)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(center)

	var name_label := Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"HeadingLabel"
	center.add_child(name_label)

	var subtitle := Label.new()
	subtitle.theme_type_variation = &"CaptionLabel"
	center.add_child(subtitle)
	center.add_child(details)

	var buy := UiButton.create("%d ouro" % price, UiButton.Kind.PRIMARY, ICON_COIN, true)
	buy.custom_minimum_size = BUY_SIZE
	buy.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.tooltip_text = "Comprar"
	buy.pressed.connect(on_buy)
	row.add_child(buy)
	if _first_buy == null:
		_first_buy = buy

	card.set_meta("subtitle", subtitle)
	return card


func _build_ammo_card(ammo: AmmoData, qty: int) -> Control:
	var icon: Control = AmmoIconScript.new(ammo.color)
	icon.custom_minimum_size = ICON_SIZE
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", UiTokens.GAP)
	details.add_child(_chip("planet", "g %s m/s²" % Ballistics.fmt(Ballistics.to_m(ammo.gravity))))
	details.add_child(_precision_chip(ammo.precision))
	details.add_child(_chip("target", "dano %d" % ammo.damage))
	var title := "%s  ×%d" % [ammo.ammo_name, qty]
	var card := _build_card(icon, title, ammo.price * qty, details, _buy_ammo.bind(ammo, qty))
	_rows[ammo.ammo_name] = {"card": card, "stock": card.get_meta("subtitle")}
	return card


func _build_repair_card() -> Control:
	var icon := UiIcon.make("shield", UiTokens.ARMOR_FILL, ICON_SIZE.x)
	var details := HBoxContainer.new()
	details.add_child(_chip("check", "tanque inteiro mira melhor"))
	_repair_card = _build_card(icon, "Kit de Reparo", REPAIR_COST, details, _buy_repair)
	_repair_label = _repair_card.get_meta("subtitle")
	return _repair_card


func _chip(icon_name: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(UiIcon.make(icon_name, UiTokens.CALCULATED, 18.0))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	row.add_child(label)
	return row


## Precisao em tres estrelas: a crianca compara as municoes sem ler numero.
func _precision_chip(precision: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = "mira"
	label.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	row.add_child(label)
	var stars := clampi(roundi((precision + 0.5) / 1.5 * 3.0), 0, 3)
	for i in range(3):
		row.add_child(UiIcon.make("star" if i < stars else "star_empty", UiTokens.EDITABLE, 16.0))
	return row


# ═════════════════════════════════════════════════════════════════════
#  COMPRA
# ═════════════════════════════════════════════════════════════════════


func _buy_ammo(ammo: AmmoData, qty: int) -> void:
	var owned: int = Global.ammo_inventory.get(ammo.ammo_name, 0)
	var room: int = ammo.max_ammo - owned
	if room <= 0:
		_reject()
		return

	# Compra parcial quando o lote nao cabe no estoque, cobrando so o que entrou.
	var actual_qty: int = mini(qty, room)
	var cost: int = ammo.price * actual_qty
	if Global.money < cost:
		_reject()
		return

	Global.money -= cost
	Global.ammo_inventory[ammo.ammo_name] = owned + actual_qty
	AudioManager.play_sfx(SFX_CLICK)
	_celebrate(_rows[ammo.ammo_name]["card"], "+%d" % actual_qty)
	refresh()
	Global.save_game()
	purchased.emit()


func _buy_repair() -> void:
	if Global.money < REPAIR_COST or Global.player_armor >= Global.max_player_armor:
		_reject()
		return

	Global.money -= REPAIR_COST
	Global.player_armor = min(Global.player_armor + REPAIR_HEAL, Global.max_player_armor)
	AudioManager.play_sfx(SFX_CLICK)
	_celebrate(_repair_card, "+%d" % int(REPAIR_HEAL))
	refresh()
	Global.save_game()
	purchased.emit()


func _reject() -> void:
	AudioManager.play_sfx(SFX_ERROR)
	_money_label.add_theme_color_override("font_color", UiTokens.DANGER)
	var tween := create_tween()
	tween.tween_property(_money_label, "theme_override_colors/font_color", UiTokens.GOLD, 0.45)
	# Balanca o saldo: "nao da" sem precisar de texto.
	var shake := create_tween()
	for dx in [6.0, -6.0, 4.0, -4.0, 0.0]:
		shake.tween_property(_money_label, "position:x", _money_label.position.x + dx, 0.04)


## Compra feita: o card pulsa e um numero sobe do botao.
func _celebrate(card: Control, text: String) -> void:
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.08)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"OverlayLabel"
	label.add_theme_color_override("font_color", UiTokens.SUCCESS)
	label.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	# top_level: dentro do PanelContainer o layout reposicionaria o rotulo.
	label.top_level = true
	card.add_child(label)
	label.global_position = card.global_position + Vector2(card.size.x - 110.0, -4.0)
	var up := create_tween()
	up.set_parallel(true)
	up.tween_property(label, "global_position:y", label.global_position.y - 40.0, 0.7)
	up.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	up.chain().tween_callback(label.queue_free)

class_name ShopPanel
extends UiModal
## Loja de municoes e reparo, extraida do war_map.gd.
##
## A extracao nao foi estetica: war_map.gd estava com 949 das 1000 linhas que o
## .gdlintrc permite, e a loja sozinha respondia por um terco do arquivo.
##
## Os tres cards agora passam pelo mesmo _build_card(). Antes o kit de reparo era
## uma copia divergente do card de municao, e na copia tinham ficado de fora tres
## font_color e um font_size -- o card saia com texto branco corpo 16 sobre fundo
## claro, diferente dos outros dois.

signal purchased

const AmmoIconScript = preload("res://scripts/ammo_icon.gd")

const ICON_COIN := preload("res://assets/sprites/icons/coin.png")
const ICON_REPAIR := preload("res://assets/sprites/icons/gear_white.png")

const SFX_CLICK := "res://assets/audio/menu_click.ogg"
const SFX_ERROR := "res://assets/audio/erro.ogg"

const PANEL_SIZE := Vector2(520, 420)
const ICON_SIZE := Vector2(32, 32)
const BUY_SIZE := Vector2(110, 36)

## Lotes de compra e custo do reparo. O 75 estava escrito a mao em tres pontos
## do war_map: no rotulo, na checagem e no desconto.
const BATCH_ENFERRUJADA := 5
const BATCH_PERFURANTE := 3
const REPAIR_COST := 100
const REPAIR_HEAL := 30.0

var _ammo_enf: AmmoData
var _ammo_perf: AmmoData

var _money_label: Label
var _repair_label: Label
## ammo_name -> {"name": Label, "stock": Label}
var _rows: Dictionary = {}


func _build_content() -> void:
	pauses_game = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.text = "Loja de Munições"

	_ammo_enf = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	_ammo_perf = load("res://assets/resources/ammo_perfurante.tres") as AmmoData

	body.add_child(_build_money_badge())
	body.add_child(HSeparator.new())
	body.add_child(_build_ammo_card(_ammo_enf, BATCH_ENFERRUJADA))
	body.add_child(_build_ammo_card(_ammo_perf, BATCH_PERFURANTE))
	body.add_child(_build_repair_card())

	var back := UiButton.create("VOLTAR AO MAPA")
	back.pressed.connect(close)
	body.add_child(back)


func open() -> void:
	refresh()
	super()


func refresh() -> void:
	if _money_label:
		_money_label.text = "Ouro: " + str(Global.money)

	for ammo in [_ammo_enf, _ammo_perf]:
		if not _rows.has(ammo.ammo_name):
			continue
		var count: int = Global.ammo_inventory.get(ammo.ammo_name, 0)
		_rows[ammo.ammo_name]["stock"].text = "(%d/%d)" % [count, ammo.max_ammo]

	if _repair_label:
		var pct := int(Global.player_armor / Global.max_player_armor * 100.0)
		_repair_label.text = "Blindagem: %d%%" % pct


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
	coin.custom_minimum_size = Vector2(24, 24)
	row.add_child(coin)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_money_label.add_theme_color_override("font_color", UiTokens.GOLD)
	row.add_child(_money_label)

	return badge


## Molde unico dos tres itens da loja.
func _build_card(icon: Control, title: String, price: String, on_buy: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.CARD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)
	card.add_child(row)
	row.add_child(icon)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(center)

	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	center.add_child(name_label)

	var subtitle := Label.new()
	subtitle.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	subtitle.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	center.add_child(subtitle)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 5)
	row.add_child(right)

	var price_label := Label.new()
	price_label.text = price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	price_label.add_theme_color_override("font_color", UiTokens.GOLD)
	right.add_child(price_label)

	var buy := UiButton.create("Comprar", UiButton.Kind.PRIMARY)
	buy.custom_minimum_size = BUY_SIZE
	buy.pressed.connect(on_buy)
	right.add_child(buy)

	card.set_meta("subtitle", subtitle)
	card.set_meta("name_label", name_label)
	return card


func _build_ammo_card(ammo: AmmoData, qty: int) -> Control:
	var icon: Control = AmmoIconScript.new(ammo.color)
	var price := "%d G (x%d)" % [ammo.price * qty, qty]
	var card := _build_card(icon, ammo.ammo_name, price, _buy_ammo.bind(ammo, qty))
	_rows[ammo.ammo_name] = {
		"name": card.get_meta("name_label"),
		"stock": card.get_meta("subtitle"),
	}
	return card


func _build_repair_card() -> Control:
	var icon := TextureRect.new()
	icon.texture = ICON_REPAIR
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var price := "%d G" % REPAIR_COST
	var card := _build_card(icon, "Kit de Reparo", price, _buy_repair)
	_repair_label = card.get_meta("subtitle")
	return card


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
	_flash(_rows[ammo.ammo_name]["name"], UiTokens.SUCCESS, UiTokens.TEXT)
	refresh()
	purchased.emit()


func _buy_repair() -> void:
	if Global.money < REPAIR_COST or Global.player_armor >= Global.max_player_armor:
		_reject()
		return

	Global.money -= REPAIR_COST
	Global.player_armor = min(Global.player_armor + REPAIR_HEAL, Global.max_player_armor)
	AudioManager.play_sfx(SFX_CLICK)
	_flash(_repair_label, UiTokens.SUCCESS, UiTokens.TEXT_MUTED)
	refresh()
	purchased.emit()


func _reject() -> void:
	AudioManager.play_sfx(SFX_ERROR)
	_flash(_money_label, UiTokens.DANGER, UiTokens.GOLD)


## Pisca a cor e volta ao repouso. O tween anima a propria propriedade de
## override, entao o valor final e o mesmo que o Theme daria.
func _flash(label: Label, from: Color, to: Color) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", from)
	var tween := create_tween()
	tween.tween_property(label, "theme_override_colors/font_color", to, 0.45)

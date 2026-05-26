extends Control

@onready var shop_panel = $ShopPanel
@onready var money_label = $ShopPanel/MoneyLabel
@onready var label_enf = $ShopPanel/VBoxContainer/Item1/Name
@onready var label_perf = $ShopPanel/VBoxContainer/Item2/Name
@onready var label_repair = $ShopPanel/VBoxContainer/Item3/Name

var ammo_enf: AmmoData
var ammo_perf: AmmoData

# Kit de Reparo
const REPAIR_PRICE: int = 75
const REPAIR_AMOUNT: float = 30.0

func _ready() -> void:
	ammo_enf = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	ammo_perf = load("res://assets/resources/ammo_perfurante.tres") as AmmoData
	update_shop_ui()

	# Victory check: if all bases cleared, go to victory screen
	var all_cleared := true
	for base in Global.bases:
		if base.stages_cleared < 3:
			all_cleared = false
			break
	if all_cleared:
		get_tree().change_scene_to_file("res://scenes/victory/victory.tscn")
		return

	# Update base buttons
	_update_base_buttons()

	# Connect base attack buttons via code
	$BaseA/AttackButtonA.pressed.connect(_on_attack_base.bind("A"))
	$BaseB/AttackButtonB.pressed.connect(_on_attack_base.bind("B"))
	$BaseC/AttackButtonC.pressed.connect(_on_attack_base.bind("C"))

func _update_base_buttons() -> void:
	var base_nodes = {
		"A": {
			"container": $BaseA,
			"label": $BaseA/LabelA,
			"button": $BaseA/AttackButtonA
		},
		"B": {
			"container": $BaseB,
			"label": $BaseB/LabelB,
			"button": $BaseB/AttackButtonB
		},
		"C": {
			"container": $BaseC,
			"label": $BaseC/LabelC,
			"button": $BaseC/AttackButtonC
		}
	}

	for base in Global.bases:
		var id = base.id
		if not base_nodes.has(id):
			continue
		var nodes = base_nodes[id]
		var cleared: int = base.stages_cleared
		var percent: int = int((float(cleared) / 3.0) * 100.0)

		if cleared >= 3:
			nodes.label.text = "Base " + id + " - Destruida"
			nodes.button.text = "Destruida"
			nodes.button.disabled = true
		else:
			nodes.label.text = "Base " + id + " - " + str(percent) + "%"
			nodes.button.text = "Atacar"
			nodes.button.disabled = false

func _on_attack_base(base_id: String) -> void:
	Global.current_base_id = base_id
	Global.current_stage = 0
	Global.player_armor = Global.max_player_armor
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

# --- Shop system (kept as-is) ---

func update_shop_ui() -> void:
	if money_label:
		money_label.text = "Dinheiro: " + str(Global.money)

	var count_enf = Global.ammo_inventory.get(ammo_enf.ammo_name, 0)
	var count_perf = Global.ammo_inventory.get(ammo_perf.ammo_name, 0)

	if label_enf:
		label_enf.text = ammo_enf.ammo_name + " (x" + str(count_enf) + "/" + str(ammo_enf.max_ammo) + ")"
	if label_perf:
		label_perf.text = ammo_perf.ammo_name + " (x" + str(count_perf) + "/" + str(ammo_perf.max_ammo) + ")"

	# Atualizar label do Kit de Reparo
	if label_repair:
		var armor_pct = int(Global.player_armor / Global.max_player_armor * 100.0)
		label_repair.text = "Kit de Reparo (Blindagem: " + str(armor_pct) + "%)"

func _on_shop_button_pressed() -> void:
	shop_panel.visible = not shop_panel.visible
	update_shop_ui()

func _on_close_shop_button_pressed() -> void:
	shop_panel.visible = false

func _on_buy_button_1_pressed() -> void:
	_buy_ammo(ammo_enf)

func _on_buy_button_2_pressed() -> void:
	_buy_ammo(ammo_perf)

func _buy_ammo(ammo: AmmoData) -> void:
	var current_count = Global.ammo_inventory.get(ammo.ammo_name, 0)
	if Global.money >= ammo.price and current_count < ammo.max_ammo:
		Global.money -= ammo.price
		Global.ammo_inventory[ammo.ammo_name] = current_count + 1
		update_shop_ui()

func _on_buy_repair_kit_pressed() -> void:
	if Global.money >= REPAIR_PRICE and Global.player_armor < Global.max_player_armor:
		Global.money -= REPAIR_PRICE
		Global.player_armor = min(Global.player_armor + REPAIR_AMOUNT, Global.max_player_armor)
		update_shop_ui()

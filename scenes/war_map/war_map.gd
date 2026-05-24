extends Control

@onready var shop_panel = $ShopPanel
@onready var money_label = $ShopPanel/MoneyLabel
@onready var label_enf = $ShopPanel/VBoxContainer/Item1/Name
@onready var label_perf = $ShopPanel/VBoxContainer/Item2/Name

var ammo_enf: AmmoData
var ammo_perf: AmmoData

func _ready() -> void:
	ammo_enf = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	ammo_perf = load("res://assets/resources/ammo_perfurante.tres") as AmmoData
	update_shop_ui()

func update_shop_ui() -> void:
	if money_label:
		money_label.text = "Dinheiro: " + str(Global.money)
	
	var count_enf = Global.ammo_inventory.get(ammo_enf.ammo_name, 0)
	var count_perf = Global.ammo_inventory.get(ammo_perf.ammo_name, 0)
	
	if label_enf:
		label_enf.text = ammo_enf.ammo_name + " (x" + str(count_enf) + "/" + str(ammo_enf.max_ammo) + ")"
	if label_perf:
		label_perf.text = ammo_perf.ammo_name + " (x" + str(count_perf) + "/" + str(ammo_perf.max_ammo) + ")"

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

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			$AttackPopup.visible = not $AttackPopup.visible

func _on_attack_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

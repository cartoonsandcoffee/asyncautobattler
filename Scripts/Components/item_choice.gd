extends Control
class_name ItemChoice

signal item_selected(slot: ItemChoice)
signal item_purchased(item: ItemChoice)

enum ChoiceType {
	REWARD,
	PURCHASE
}


@onready var panel_border: PanelContainer
@onready var order_container: PanelContainer
@onready var lbl_order: Label 
@onready var item_icon: TextureRect 
@onready var wep_indicator: TextureRect 
@onready var anim_hover: AnimationPlayer
@onready var anim_upgrade: AnimationPlayer

@onready var button: Button
@onready var box_cost: HBoxContainer
@onready var box_poor: HBoxContainer

@onready var lbl_price: Label
@onready var price_container: PanelContainer

@onready var pnl_rarity: Panel
@onready var pic_rarity: TextureRect

@export var choice_type: ChoiceType = ChoiceType.REWARD
@export var current_item: Item = null
@export var item_cost: int = 0

var item_instance_id: int = -1  # Track the specific instance
var slot_index: int = 10  # to track position

var default_grey: Color = Color("#9b9b9b")
var gamecolors: GameColors

var has_been_selected: bool = false
var can_afford_item: bool = false

func _ready() -> void:
	set_references()

func set_references():
	gamecolors = GameColors.new()
	panel_border = $Panel/VBoxContainer/itemContainer
	order_container = $Panel/VBoxContainer/orderContainer
	lbl_order = $Panel/VBoxContainer/orderContainer/MarginContainer/lblOrder
	item_icon = $Panel/VBoxContainer/itemContainer/MarginContainer/item_icon
	anim_hover = $animSelect
	button = $Panel/Button
	lbl_price = $Panel/priceContainer/MarginContainer/hboxCost/lblPrice
	price_container = $Panel/priceContainer
	box_poor = $Panel/priceContainer/MarginContainer/hboxPoor
	box_cost = $Panel/priceContainer/MarginContainer/hboxCost
	wep_indicator = $Panel/VBoxContainer/itemContainer/wep_indicator
	pic_rarity = $Panel/VBoxContainer/itemContainer/pnlRare/picRarity
	pnl_rarity = $Panel/VBoxContainer/itemContainer/pnlRare
	anim_upgrade = $animUpgrade

	if choice_type == ChoiceType.REWARD:
		price_container.visible = false
	elif  choice_type == ChoiceType.PURCHASE:
		price_container.visible = true

func set_item(item: Item):
	set_references()

	if item:
		current_item = item
		item_instance_id = item.instance_id  
		update_visuals()
		button.disabled = false
		pnl_rarity.visible = true
		if ItemsManager.player_has_duplicate(item, false):
			show_upgrade_anim()
		else:
			stop_upgrade_anim()
	else:
		set_empty()
	
func setup_for_store(_on_sale: bool = false):
	choice_type = ChoiceType.PURCHASE
	price_container.visible = true
	set_price(_on_sale)

func set_empty():
	current_item = null
	item_instance_id = -1 
	panel_border.self_modulate = Color.WHITE
	button.disabled = true
	pnl_rarity.visible = false

func set_price(_on_sale: bool = false):
	if current_item:
		match current_item.rarity:
			Enums.Rarity.COMMON:
				item_cost = 3
			Enums.Rarity.UNCOMMON:
				item_cost = 5
			Enums.Rarity.RARE:
				item_cost = 10
			Enums.Rarity.LEGENDARY:
				item_cost = 20
			Enums.Rarity.GOLDEN:
				item_cost = 20
			Enums.Rarity.DIAMOND:
				item_cost = 40
			Enums.Rarity.CRAFTED:
				item_cost = 50
			_:
				item_cost = (randi_range(3,15))

		# First upgrade each weapon is free
		if current_item.item_type == Item.ItemType.UPGRADE:
			if Player.current_weapon_rule_upgrade != null:
				item_cost = 10
			else:
				item_cost = 0

	if _on_sale:
		lbl_price.modulate = Color.LIME_GREEN
		item_cost -= int(item_cost/2)

	lbl_price.text = str(item_cost)


func update_visuals():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		if (current_item.item_type == Item.ItemType.WEAPON):
			set_weapon_text_color()
		else:
			set_item_type_desc()
		item_icon.texture = current_item.item_icon
		set_rarity_color()

func get_current_item() -> Item:
	return current_item

func set_item_type_desc():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		match current_item.item_type:
			Item.ItemType.BODY_ARMOR:
				lbl_order.text = "armor"
			Item.ItemType.BOOTS:
				lbl_order.text = "boots"
			Item.ItemType.GLOVES:
				lbl_order.text = "gloves"
			Item.ItemType.SHIELD:
				lbl_order.text = "shield"
			Item.ItemType.POTION:
				lbl_order.text = "potion"
			Item.ItemType.JEWELRY:
				lbl_order.text = "jewelry"
			_:
				lbl_order.text = "Tool"


func set_rarity_color():
	var rarity_common: Texture2D = load("res://Resources/Rarity/common.tres")
	var rarity_uncommon: Texture2D = load("res://Resources/Rarity/uncommon.tres")
	var rarity_rare: Texture2D = load("res://Resources/Rarity/rare.tres")
	var rarity_legendary: Texture2D = load("res://Resources/Rarity/legendary.tres")
	var rarity_mystic: Texture2D = load("res://Resources/Rarity/mystic.tres")
	var rarity_golden: Texture2D = load("res://Resources/Rarity/golden.tres")
	var rarity_diamond: Texture2D = load("res://Resources/Rarity/diamond.tres")
	var rarity_crafted: Texture2D = load("res://Resources/Rarity/crafted.tres")

	if current_item.rarity == Enums.Rarity.COMMON:
		pic_rarity.texture = rarity_common
		pic_rarity.self_modulate = gamecolors.rarity.common
		panel_border.self_modulate = gamecolors.rarity.common
		wep_indicator.modulate = gamecolors.rarity.common
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		pic_rarity.texture = rarity_uncommon
		pic_rarity.self_modulate = gamecolors.rarity.uncommon
		panel_border.self_modulate = gamecolors.rarity.uncommon
		wep_indicator.modulate = gamecolors.rarity.uncommon
	elif current_item.rarity == Enums.Rarity.RARE:
		pic_rarity.texture = rarity_rare
		pic_rarity.self_modulate = gamecolors.rarity.rare
		panel_border.self_modulate = gamecolors.rarity.rare
		wep_indicator.modulate = gamecolors.rarity.rare
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		pic_rarity.texture = rarity_legendary
		pic_rarity.self_modulate = gamecolors.rarity.legendary
		panel_border.self_modulate = gamecolors.rarity.legendary
		wep_indicator.modulate = gamecolors.rarity.legendary
	elif current_item.rarity == Enums.Rarity.MYSTERIOUS:
		pic_rarity.texture = rarity_mystic
		pic_rarity.self_modulate = gamecolors.rarity.mysterious
		panel_border.self_modulate = gamecolors.rarity.mysterious
		wep_indicator.modulate = gamecolors.rarity.mysterious
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		pic_rarity.texture = rarity_golden
		pic_rarity.self_modulate = gamecolors.rarity.golden
		panel_border.self_modulate = gamecolors.rarity.golden
		wep_indicator.modulate = gamecolors.rarity.golden
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		pic_rarity.texture = rarity_diamond
		pic_rarity.self_modulate = gamecolors.rarity.diamond
		panel_border.self_modulate = gamecolors.rarity.diamond
		wep_indicator.modulate = gamecolors.rarity.diamond
	elif current_item.rarity == Enums.Rarity.CRAFTED:
		pic_rarity.texture = rarity_crafted
		pic_rarity.self_modulate = gamecolors.rarity.crafted
		panel_border.self_modulate = gamecolors.rarity.crafted
		wep_indicator.modulate = gamecolors.rarity.crafted

func set_weapon_text_color():
	lbl_order.text = "weapon"
	lbl_order.set("theme_override_colors/font_color", Color("#D9A5A5"))
	order_container.self_modulate = Color("#8a1d1dff")
	wep_indicator.visible = true

func get_item_instance() -> Item:
	# Return the specific instance, not just any item
	if current_item and current_item.instance_id == item_instance_id:
		return current_item
	return null

func cannot_afford():
	box_cost.modulate = Color.RED
	$Panel/VBoxContainer.modulate.a = 0.5
	can_afford_item = false
	#button.disabled = true

func can_afford():
	can_afford_item = true
	button.disabled = false
	box_cost.visible = true
	box_cost.modulate = Color("#ffbb00")

	box_poor.visible = false
	$Panel/VBoxContainer.modulate.a = 1

func _on_button_mouse_exited() -> void:
	anim_hover.play("stop")
	CursorManager.reset_cursor()
	TooltipManager.hide_tooltip() 
	panel_border.modulate = Color.WHITE

func _on_button_mouse_entered() -> void:
	if current_item:  # Only if slot has item
		AudioManager.play_ui_sound("item_hover")	
		CursorManager.set_interact_cursor()
	if !button.disabled:
		anim_hover.play("hover")
		TooltipManager.show_item_tooltip(current_item, global_position, size)

func _on_button_pressed() -> void:
	if !can_afford_item && choice_type == ChoiceType.PURCHASE:
		AudioManager.play_random_voice_no()
		return

	if has_been_selected:
		return

	if current_item:  # Only if slot has item
		if choice_type == ChoiceType.REWARD:
			AudioManager.play_ui_sound("item_pickup")
		elif choice_type == ChoiceType.PURCHASE:
			AudioManager.play_event_sound("coins_02")

	has_been_selected = true
	button.disabled = true
	
	if choice_type == ChoiceType.REWARD:
		item_selected.emit(current_item)
	elif choice_type == ChoiceType.PURCHASE:
		item_purchased.emit(self)

func show_upgrade_anim():
	if current_item.rarity == Enums.Rarity.COMMON:
		anim_upgrade.play("show_gold")
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		anim_upgrade.play("show_diamond")
	else:
		anim_upgrade.play("upgrade_show")

func stop_upgrade_anim():
	anim_upgrade.play("RESET")
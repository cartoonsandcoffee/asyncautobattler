extends Control
class_name ItemChoice

signal item_selected(slot: ItemChoice)

enum ChoiceType {
	REWARD,
	PURCHASE
}


@onready var panel_border: PanelContainer
@onready var order_container: PanelContainer
@onready var lbl_order: Label 
@onready var item_icon: TextureRect 
@onready var anim_hover: AnimationPlayer
@onready var tooltip: Control
@onready var tooltip_panel: Panel
@onready var button: Button

@export var choice_type: ChoiceType = ChoiceType.REWARD
@export var current_item: Item = null

var item_instance_id: int = -1  # Track the specific instance
var slot_index: int = 10  # to track position

var gamecolors: GameColors

func _ready() -> void:
	set_references()

func set_references():
	gamecolors = GameColors.new()
	panel_border = $Panel/VBoxContainer/itemContainer
	order_container = $Panel/VBoxContainer/orderContainer
	lbl_order = $Panel/VBoxContainer/orderContainer/MarginContainer/lblOrder
	item_icon = $Panel/VBoxContainer/itemContainer/MarginContainer/item_icon
	anim_hover = $animSelect
	tooltip = $ToolTip/ItemTooltip
	tooltip_panel = $ToolTip
	button = $Panel/Button

func set_item(item: Item):
	set_references()

	if item:
		current_item = item
		item_instance_id = item.instance_id  
		update_visuals()
		tooltip.set_item(item)
		button.disabled = false
	else:
		set_empty()
	

func set_empty():
	current_item = null
	item_instance_id = -1 
	panel_border.self_modulate = Color.WHITE
	button.disabled = true


func update_visuals():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		if (current_item.item_type == Item.ItemType.WEAPON):
			set_weapon_text_color()
		else:
			set_item_type_desc()
		item_icon.texture = current_item.item_icon
		set_rarity_color()

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
	if current_item.rarity == Enums.Rarity.COMMON:
		panel_border.self_modulate = gamecolors.rarity.common
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		panel_border.self_modulate = gamecolors.rarity.uncommon
	elif current_item.rarity == Enums.Rarity.RARE:
		panel_border.self_modulate = gamecolors.rarity.rare
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		panel_border.self_modulate = gamecolors.rarity.legendary	

func set_weapon_text_color():
	lbl_order.text = "weapon"
	lbl_order.set("theme_override_colors/font_color", Color("#D9A5A5"))
	order_container.self_modulate = Color("#8a1d1dff")

func get_item_instance() -> Item:
	# Return the specific instance, not just any item
	if current_item and current_item.instance_id == item_instance_id:
		return current_item
	return null


func _on_button_mouse_exited() -> void:
	anim_hover.play("stop")
	tooltip_panel.visible = false
	panel_border.modulate = Color.WHITE

func _on_button_mouse_entered() -> void:
	if !button.disabled:
		anim_hover.play("hover")
		tooltip_panel.visible = true

func _on_button_pressed() -> void:
	item_selected.emit(current_item)

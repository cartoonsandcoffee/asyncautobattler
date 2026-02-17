@tool
class_name ItemOffering
extends Control

signal item_selected(Item)
signal item_skipped()
signal need_item_replace(Item)

enum FilterItemsBy {
	RARITY,
	TYPE,
	CATEGORY,
	NONE
}

@onready var item_choice_container: GridContainer = $Panel/panelBlack/PanelContainer/VBoxContainer/itemsContainer
@onready var name_label: Label = $Panel/panelBlack/PanelContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $Panel/panelBlack/PanelContainer/VBoxContainer/MarginContainer/txtDesc
@onready var btn_skip: Button = $Panel/panelBlack/PanelContainer/VBoxContainer/btnSkip

## Filter by what item criteria for selection
@export var filter_by: ItemOffering.FilterItemsBy = ItemOffering.FilterItemsBy.RARITY:
	set(value):
		filter_by = value
		notify_property_list_changed()

@export var item_rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var items_offered: int = 3
@export var box_name:String = ""
@export_multiline var box_desc:String = ""


## Includes an extra item of one rarity higher than selected above.
@export var include_extra_rare: bool = false
## Have choices include weapons or just items
@export var include_weapons: bool = true
## Don't show more than 1 weapon in choices (requires "Include_Weapons" be selected)
@export var max_1_weapon: bool = true
## Category string 
@export var category_string: String = ""
@export var item_type: Item.ItemType


var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var offered_items: Array[Item] = []
var selection_locked: bool = false

func _init() -> void:
	pass

func _validate_property(property: Dictionary) -> void:
	var prop_name = property.name
	
	if prop_name in ["include_extra_rare", "include_weapons", "max_1_weapon"]:
		if filter_by not in [ItemOffering.FilterItemsBy.RARITY]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if prop_name in ["item_rarity"]:
		if filter_by not in [ItemOffering.FilterItemsBy.RARITY, ItemOffering.FilterItemsBy.NONE]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if prop_name in ["category_string"]:
		if filter_by not in [ItemOffering.FilterItemsBy.CATEGORY]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if prop_name in ["item_type"]:
		if filter_by not in [ItemOffering.FilterItemsBy.TYPE, ItemOffering.FilterItemsBy.NONE]:
			property.usage = PROPERTY_USAGE_NO_EDITOR


func _ready() -> void:
	add_to_group("item_selection_events") 
	item_choice_container.columns = items_offered
	if include_extra_rare: item_choice_container.columns = items_offered + 1
	generate_item_choices()
	setup_labels()

func setup_labels():
	name_label.text = box_name
	dialogue_label.text = box_desc
	if box_desc == "" || box_desc == null:
		dialogue_label.visible = false

func generate_item_choices():
	# Get 3 random common items
	if filter_by == ItemOffering.FilterItemsBy.RARITY:
		offered_items = ItemsManager.get_random_items(items_offered, item_rarity, include_extra_rare, include_weapons, max_1_weapon)
	elif filter_by == ItemOffering.FilterItemsBy.CATEGORY:
		offered_items = ItemsManager.get_items_by_category(items_offered, category_string)
	elif filter_by == ItemOffering.FilterItemsBy.TYPE:
		offered_items = ItemsManager.get_items_by_item_type(items_offered, item_type)
	else:
		offered_items = ItemsManager.get_items_by_item_type(items_offered, item_type, true, item_rarity)

	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(110, 110)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.item_selected.connect(_on_item_selected)

func _on_item_selected(item: Item):
	if selection_locked:
		return
	
	selection_locked = true
	btn_skip.disabled = true

	if item.item_type == Item.ItemType.WEAPON:
		# Automatic weapon swap
		Player.inventory.set_weapon(item)
		Player.update_stats_from_items()
		#AudioManager.play_ui_sound("item_pickup")
		item_selected.emit(item)
	else:
		if Player.inventory.has_empty_slot():
			Player.inventory.add_item(item)
			Player.update_stats_from_items()
			#AudioManager.play_ui_sound("item_pickup")
			item_selected.emit(item)	
		else:
			need_item_replace.emit(item)

func _on_btn_skip_pressed() -> void:
	item_skipped.emit()



func _on_btn_skip_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

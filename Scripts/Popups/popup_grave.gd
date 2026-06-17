@tool
class_name PopupGrave
extends Control

signal item_selected(Item)
signal item_skipped()
signal need_item_replace(Item)

enum FilterItemsBy {
	RARITY,
	TYPE,
	CATEGORY,
	NONE,
	ITEM_LIST
}

@onready var item_choice_container: GridContainer = $CanvasLayer/Control/centerArea/PanelContainer/GridContainer
@onready var btn_skip: Button = $CanvasLayer/Control/panelButtons/HBoxContainer/btnSkip
@onready var btn_reroll: Button = $CanvasLayer/Control/panelButtons/HBoxContainer/btnReroll
@onready var anim_main: AnimationPlayer = $AnimationPlayer
@onready var canvas_layer: CanvasLayer = $CanvasLayer

## Filter by what item criteria for selection
@export var filter_by: ItemOffering.FilterItemsBy = ItemOffering.FilterItemsBy.RARITY:
	set(value):
		filter_by = value
		notify_property_list_changed()

@export var item_rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var items_offered: int = 3

## Includes an extra item of one rarity higher than selected above.
@export var include_extra_rare: bool = false
## Uses item's keywords to weight the randomness towards what player is building
@export var use_keyword_weighting: bool = true

@export_group("Weapon Stuff")
## Have choices include weapons or just items
@export var include_weapons: bool = true
## Don't show more than 1 weapon in choices (requires "Include_Weapons" be selected)
@export var max_1_weapon: bool = true

@export_group("Filter Options")
## Category string 
@export var category_string: String = ""
@export var item_type: Item.ItemType
@export var items: Array[Item] = []

@export_group("Rerolls")
## if 0 reroll button won't appear
@export var rerolls: int = 0
@export var reroll_button_text:String = ""
@export var reroll_sound_name: String = "dig_grave"

var item_choice_scene = preload("res://Scenes/item_selection.tscn")
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

	if prop_name in ["items"]:
		if filter_by not in [ItemOffering.FilterItemsBy.ITEM_LIST]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

func _ready() -> void:
	add_to_group("item_selection_events") 
	item_choice_container.columns = items_offered
	if include_extra_rare: item_choice_container.columns = items_offered + 1
	setup_rerolls()

func setup_rerolls():
	if rerolls > 0:
		btn_reroll.visible = true
		btn_reroll.text = reroll_button_text
	else:
		btn_reroll.visible = false
		

func generate_item_choices():
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.free()
	
	offered_items.clear()
	
	# Get 3 random common items
	if filter_by == ItemOffering.FilterItemsBy.RARITY:
		offered_items = ItemsManager.get_random_items(items_offered, item_rarity, include_extra_rare, include_weapons, max_1_weapon, use_keyword_weighting)
	elif filter_by == ItemOffering.FilterItemsBy.CATEGORY:
		offered_items = ItemsManager.get_items_by_category(items_offered, category_string)
	elif filter_by == ItemOffering.FilterItemsBy.TYPE:
		offered_items = ItemsManager.get_items_by_item_type(items_offered, item_type)
	elif filter_by == ItemOffering.FilterItemsBy.ITEM_LIST:
		offered_items = items
	else:
		offered_items = ItemsManager.get_items_by_item_type(items_offered, item_type, true, item_rarity)

func show_the_choices():
	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(200, 200)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.item_selected.connect(_on_item_selected)


func _on_item_selected(item: Item):
	if selection_locked:
		return
	
	selection_locked = true
	btn_skip.disabled = true

	if item.item_type == Item.ItemType.WEAPON:
		if Player.inventory.weapon_slot != null and Player.inventory.weapon_slot.item_id != "weapon_fists":
			need_item_replace.emit(item)
		else:
			Player.inventory.set_weapon(item)
			Player.update_stats_from_items()
			item_selected.emit(item)
	else:
		if Player.inventory.has_empty_slot():
			Player.inventory.add_item(item)
			Player.update_stats_from_items()
			#AudioManager.play_ui_sound("item_pickup")
			_clear_inventory_duplicate_indicators()
			item_selected.emit(item)	
		else:
			need_item_replace.emit(item)

func _on_btn_skip_pressed() -> void:
	_clear_inventory_duplicate_indicators()
	item_skipped.emit()

func _on_btn_skip_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func _on_btn_reroll_pressed() -> void:
	rerolls -= 1
	anim_main.play("reroll")
	if reroll_sound_name &&  reroll_sound_name != "":
		AudioManager.play_event_sound(reroll_sound_name)
	setup_rerolls()
	generate_item_choices()
	show_the_choices()
	

func _on_btn_reroll_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_reroll_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("woosh")

func _refresh_inventory_duplicate_indicators():
	var main_game = get_tree().get_first_node_in_group("main_game")
	if not main_game:
		return
	
	# Build set of offered common item_ids
	var offered_ids: Array = []
	for child in item_choice_container.get_children():
		if child.has_method("get_current_item"):
			var offered_item = child.get_current_item()
			if offered_item and offered_item.rarity == Enums.Rarity.COMMON:
				offered_ids.append(offered_item.item_id)
	
	for inv_slot in main_game.item_slots:
		if not inv_slot.current_item:
			continue
		if inv_slot.current_item.item_id in offered_ids:
			inv_slot.show_upgrade_anim()
		else:
			inv_slot.stop_upgrade_anim()

func _clear_inventory_duplicate_indicators():
	var main_game = get_tree().get_first_node_in_group("main_game")
	if not main_game:
		return
	for inv_slot in main_game.item_slots:
		if not inv_slot.current_item:
			continue
		if ItemsManager.player_has_duplicate(inv_slot.current_item, true):
			inv_slot.show_upgrade_anim()
		else:
			inv_slot.stop_upgrade_anim()

func show_popup():
	AudioManager.play_event_sound("fill_grave")
	generate_item_choices()
	anim_main.play("show_popup")
	await anim_main.animation_finished
	show_the_choices()
	_refresh_inventory_duplicate_indicators()

func hide_popup():
	AudioManager.play_event_sound("dig_grave")
	anim_main.play("hide_popup")
	await anim_main.animation_finished

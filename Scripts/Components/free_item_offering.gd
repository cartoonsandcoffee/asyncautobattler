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
	NONE,
	ITEM_LIST
}

@onready var item_choice_container: GridContainer = $Panel/panelBlack/PanelContainer/VBoxContainer/itemsContainer
@onready var name_label: Label = $Panel/panelBlack/PanelContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $Panel/panelBlack/PanelContainer/VBoxContainer/marginDesc/txtDesc
@onready var dialogue_margin: MarginContainer = $Panel/panelBlack/PanelContainer/VBoxContainer/marginDesc
@onready var btn_skip: Button = $Panel/panelBlack/PanelContainer/VBoxContainer/HBoxContainer/btnSkip
@onready var btn_reroll: Button = $Panel/panelBlack/PanelContainer/VBoxContainer/HBoxContainer/btnReroll
@onready var anim_reroll: AnimationPlayer = $animReroll

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
@export var reroll_sound_name: String = ""

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

	if prop_name in ["items"]:
		if filter_by not in [ItemOffering.FilterItemsBy.ITEM_LIST]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

func _ready() -> void:
	add_to_group("item_selection_events") 
	item_choice_container.columns = items_offered
	if include_extra_rare: item_choice_container.columns = items_offered + 1
	generate_item_choices()
	setup_labels()
	setup_rerolls()

func setup_rerolls():
	if rerolls > 0:
		btn_reroll.visible = true
		btn_reroll.text = reroll_button_text
	else:
		btn_reroll.visible = false
		
func setup_labels():
	name_label.text = box_name
	dialogue_label.text = box_desc
	if box_desc == "" || box_desc == null:
		dialogue_margin.visible = false
	else:
		dialogue_margin.visible = true

func generate_item_choices():
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.free()
	
	offered_items.clear()
	
	# Get 3 random common items
	if filter_by == ItemOffering.FilterItemsBy.RARITY:
		offered_items = ItemsManager.get_random_items(items_offered, item_rarity, include_extra_rare, include_weapons, max_1_weapon)
	elif filter_by == ItemOffering.FilterItemsBy.CATEGORY:
		offered_items = ItemsManager.get_items_by_category(items_offered, category_string)
	elif filter_by == ItemOffering.FilterItemsBy.TYPE:
		offered_items = ItemsManager.get_items_by_item_type(items_offered, item_type)
	elif filter_by == ItemOffering.FilterItemsBy.ITEM_LIST:
		offered_items = items
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
	anim_reroll.play("reroll")
	if reroll_sound_name &&  reroll_sound_name != "":
		AudioManager.play_event_sound(reroll_sound_name)
	setup_rerolls()
	generate_item_choices()
	

func _on_btn_reroll_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_reroll_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("woosh")

func show_popup():
	_refresh_inventory_duplicate_indicators()

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
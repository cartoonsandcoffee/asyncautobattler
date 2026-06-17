@tool
class_name DisplayItemChoicesFree
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

const ITEM_SIZE: Vector2 = Vector2(175,155)

@onready var item_choice_container: GridContainer = $fullWidgetContainer/centerPoint/pnlItems/itemContainer/itemGrid
@onready var btn_skip: Button = $fullWidgetContainer/buttonHolder/PanelContainer/VBoxContainer/buttonRow/btnSkip
@onready var btn_reroll: Button = $fullWidgetContainer/buttonHolder/PanelContainer/VBoxContainer/buttonRow/btnRoll
@onready var txt_desc: RichTextLabel = $fullWidgetContainer/buttonHolder/PanelContainer/VBoxContainer/labelRow/labelHolder/txtHeader
@onready var anim_reroll: AnimationPlayer = $animReroll
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# Detail card — add these nodes to the scene (see scene setup notes below)
@onready var detail_card_area: Control = $fullWidgetContainer/DetailCardArea
@onready var detail_card: Control = $fullWidgetContainer/DetailCardArea/pnlCard/VBoxContainer/ItemCardWide
@onready var btn_take: Button = $fullWidgetContainer/DetailCardArea/pnlCard/VBoxContainer/boxButtons/btnTake
@onready var btn_banish: Button = $fullWidgetContainer/DetailCardArea/pnlCard/VBoxContainer/boxButtons/btnBanish
@onready var anim_detail: AnimationPlayer = $animCard

## Filter by what item criteria for selection
@export var filter_by: ItemOffering.FilterItemsBy = ItemOffering.FilterItemsBy.RARITY:
	set(value):
		filter_by = value
		notify_property_list_changed()

@export var items_offered: int = 3
@export var box_name: String = ""
@export_multiline var box_desc: String = ""

## Includes an extra item of one rarity higher than selected above.
@export var include_extra_rare: bool = false
## randomizer will weight items based on categories and keywords of player
@export var use_keyword_weighting: bool = true
## Show a Banish button when an item is selected
@export var allow_banish: bool = false

@export_group("Weapon Stuff")
@export var include_weapons: bool = true
@export var max_1_weapon: bool = true

@export_group("Filter Options")
@export var item_rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var category_string: String = ""
@export var item_type: Item.ItemType
@export var items: Array[Item] = []

@export_group("Rerolls")
@export var rerolls: int = 0
@export var reroll_button_text: String = ""
@export var reroll_sound_name: String = ""

var item_selection_scene = preload("res://Scenes/item_selection.tscn")
var empty_item = preload("res://Scenes/Elements/empty_choice.tscn")
var offered_items: Array[Item] = []
var selection_locked: bool = false
var selected_item: Item = null
var selected_card: ItemSelection = null
var selection_active: bool = false


func _init() -> void:
	pass

#func _unhandled_input(event: InputEvent) -> void:
#	if not selection_active:
#		return
#	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
#		_reset_selection()
#		get_viewport().set_input_as_handled()

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
	item_choice_container.custom_minimum_size.x = items_offered * (ITEM_SIZE.x)
	if include_extra_rare:
		item_choice_container.columns = items_offered + 1
	setup_rerolls()
	detail_card_area.hide()
	btn_take.pressed.connect(_on_btn_take_pressed)
	btn_banish.pressed.connect(_on_btn_banish_pressed)
	txt_desc.text = box_desc

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
	_reset_selection()

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

	# 1. Instantiate and add ALL cards first — layout settles once
	var cards: Array = []
	for item in offered_items:
		var choice_button = item_selection_scene.instantiate()
		choice_button.use_selection_mode = true
		choice_button.custom_minimum_size = ITEM_SIZE
		choice_button.modulate.a = 0.0 
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.item_selected.connect(_on_item_card_clicked)
		cards.append(choice_button)

	# 2. Wait one frame for the grid to finish layout
	await get_tree().process_frame

	# 3. Stagger only the reveal animations — no layout changes during these
	for card in cards:
		card.display_item()    # or whatever plays the appear anim in ItemSelection
		await CombatSpeed.create_timer(0.3)
		
## Called when a card is tapped/clicked — drives selection state
func _on_item_card_clicked(item: Item) -> void:
	if selection_locked:
		return

	# Tap selected item again to deselect
	if selected_item == item:
		_reset_selection()
		return

	# Deselect only the previously selected card
	if selected_card:
		selected_card.set_selected(false)

	selected_item = item
	selected_card = null

	for child in item_choice_container.get_children():
		if child.has_method("get_current_item") and child.get_current_item() == item:
			selected_card = child
			break

	if selected_card:
		selected_card.set_selected(true)

	_show_detail_card(item)

func _show_detail_card(item: Item) -> void:
	selection_active = true
	_set_hover_enabled(false)
	TooltipManager.hide_tooltip()

	if selected_card:
		var card_center_x = selected_card.global_position.x + selected_card.size.x / 2.0
		var parent_x = detail_card_area.get_parent().global_position.x
		detail_card_area.position.x = card_center_x - parent_x - detail_card_area.size.x / 2.0

	detail_card.is_from_compendium = true
	detail_card.set_item(item, true)
	detail_card.show_card()

	btn_take.show()
	var has_banishes = allow_banish and Player.banishes_left_this_rank > 0
	btn_banish.visible = allow_banish
	btn_banish.disabled = not has_banishes
	if allow_banish:
		btn_banish.text = "Banish (%d)" % Player.banishes_left_this_rank

	detail_card_area.show()
	#anim_detail.play("show_card")

func _reset_selection() -> void:
	if selected_card:
		selected_card.set_selected(false)
	selected_item = null
	selected_card = null
	selection_active = false
	_set_hover_enabled(true)
	detail_card_area.hide()

func _set_hover_enabled(enabled: bool) -> void:
	for child in item_choice_container.get_children():
		if child is ItemSelection:
			child.hover_enabled = enabled

func _on_btn_take_pressed() -> void:
	if not selected_item:
		return
	var item_to_take := selected_item
	if selected_card:
		selected_card.confirm_selection()
	_reset_selection()
	_commit_take(item_to_take)
	AudioManager.play_ui_sound("take")

func _on_btn_banish_pressed() -> void:
	if not selected_item or Player.banishes_left_this_rank <= 0:
		return
	Player.banishes_left_this_rank -= 1
	detail_card_area.hide()

	var item_to_banish: Item = selected_item     # capture before await
	var card_to_banish = selected_card	

	if card_to_banish and card_to_banish.current_item == item_to_banish:
		await card_to_banish.banish_me()
	ItemsManager.banish_item(item_to_banish.item_id)
	_replace_with_empty(item_to_banish)
	_reset_selection()

func _replace_with_empty(item: Item) -> void:
	for child in item_choice_container.get_children():
		if child.has_method("get_current_item") and child.get_current_item() == item:
			var idx: int = child.get_index()
			item_choice_container.remove_child(child)
			child.free()
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = ITEM_SIZE
			item_choice_container.add_child(empty_slot)
			item_choice_container.move_child(
				item_choice_container.get_child(item_choice_container.get_child_count() - 1), idx
			)
			break

## Commits the take action — inventory logic, emits signals upward
func _commit_take(item: Item) -> void:
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
			_clear_inventory_duplicate_indicators()
			item_selected.emit(item)
		else:
			need_item_replace.emit(item)

func _on_btn_skip_pressed() -> void:
	_reset_selection()
	_clear_inventory_duplicate_indicators()
	item_skipped.emit()

func _on_btn_skip_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_skip_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("paper_hover")

func _on_btn_reroll_pressed() -> void:
	rerolls -= 1
	#anim_reroll.play("reroll")
	if reroll_sound_name and reroll_sound_name != "":
		AudioManager.play_event_sound(reroll_sound_name)
	setup_rerolls()
	generate_item_choices()

func _on_btn_reroll_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_reroll_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("paper_hover")

func show_popup():
	generate_item_choices()
	AudioManager.play_ui_sound("paper_drop")
	anim_player.play("show_box")
	_refresh_inventory_duplicate_indicators()
	await anim_player.animation_finished

func hide_popup():
	_reset_selection()
	anim_player.play("hide_box")
	await anim_player.animation_finished

func _refresh_inventory_duplicate_indicators():
	var main_game = get_tree().get_first_node_in_group("main_game")
	if not main_game:
		return
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

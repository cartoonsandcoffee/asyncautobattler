class_name PopupDiscountPeddler
extends Control


signal item_selected(Item)
signal store_closed()
signal need_item_replace(Item)

@onready var item_choice_container: GridContainer = $CanvasLayer/Control/centerArea/PanelContainer/MarginContainer/GridContainer
@onready var btn_cancel: Button = $CanvasLayer/Control/panelButtons/HBoxContainer/btnSkip
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var stat_gold: StatBoxDisplay = $CanvasLayer/Control/pnlGold/PanelContainer/MarginContainer/statGold

@onready var btn_take: Button = $CanvasLayer/Control/panelButtons/HBoxContainer/btnTake
@onready var btn_banish: Button = $CanvasLayer/Control/panelButtons/HBoxContainer/btnBanish

@export var item_rarity: Enums.Rarity = Enums.Rarity.UNCOMMON
@export var items_offered: int = 2
@export var include_extra_rare: bool = false
@export var on_sale: bool = false
@export var use_keyword_weighting: bool = true

var selected_item: Item = null
var selected_card: ItemSelection = null
var selection_locked: bool = false

var item_choice_scene = preload("res://Scenes/item_selection.tscn")
var empty_item = preload("res://Scenes/Elements/empty_choice.tscn")

var is_store_open: bool = false

var offered_items: Array[Item] = []	# the combined array of offerings

func _ready() -> void:
	item_choice_container.columns = items_offered
	if include_extra_rare: item_choice_container.columns = items_offered + 1
	btn_take.visible = false
	btn_banish.visible = false

	Player.stats.stats_updated.connect(_update_gold_display)
	_update_gold_display()
	add_to_group("item_selection_events") 

func _update_gold_display() -> void:
	stat_gold.update_stat(Enums.Stats.GOLD, Player.stats.gold, Player.stats.gold)
	
func generate_item_choices():
	#clear old items
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.queue_free()
		
	# Get 3 random items
	offered_items = ItemsManager.get_random_items(items_offered, item_rarity, include_extra_rare, true, false, use_keyword_weighting)

func show_the_choices():
	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.use_selection_mode = true
		choice_button.custom_minimum_size = Vector2(200, 200)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.setup_for_store(on_sale)
		choice_button.enable_button()
		choice_button.item_selected.connect(_on_item_card_clicked)
		choice_button.display_item()
	check_affordability()

func _on_item_card_clicked(item: Item) -> void:
	if selection_locked:
		return
	selected_item = item
	for child in item_choice_container.get_children():
		if child.has_method("set_selected"):
			var is_this_card = child.has_method("get_current_item") and child.get_current_item() == item
			child.set_selected(is_this_card)
			if is_this_card:
				selected_card = child
	_update_action_bar()

func _update_action_bar() -> void:
	btn_banish.visible = selected_item != null
	btn_take.visible = selected_item != null
	if selected_item:
		var can_afford = Player.stats.gold >= selected_card.item_cost if selected_card else false
		btn_take.disabled = not can_afford	
	var has_banishes = Player.banishes_left_this_rank > 0
	btn_banish.visible = has_banishes
	btn_banish.text = "Banish Item (%d)" % Player.banishes_left_this_rank if has_banishes else "No banishes remaining"

func _on_btn_take_pressed() -> void:
	if not selected_item:
		return
	var item_to_take := selected_card
	if selected_card:
		selected_card.confirm_selection()
	_reset_selection()
	_on_item_selected(item_to_take)

func _on_btn_banish_pressed() -> void:
	if not selected_item or Player.banishes_left_this_rank <= 0:
		return
	Player.banishes_left_this_rank -= 1
	ItemsManager.banish_item(selected_item.item_id)
	AudioManager.play_ui_sound("popup_close")
	_replace_with_empty(selected_item)
	AudioManager.play_ui_sound("item_pickup")
	_reset_selection()

func _on_btn_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")
	CursorManager.set_interact_cursor()


func _on_item_selected(item: ItemSelection):
	purchase_item_from_store(item)

func _on_btn_cancel_pressed() -> void:
	hide_store()

func show_store():
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.free()

	generate_item_choices()
	anim_player.play("show_popup")
	await anim_player.animation_finished
	show_the_choices() 
	is_store_open = true
	Player.popup_open = true
	_refresh_inventory_duplicate_indicators()

func hide_store():
	AudioManager.play_ui_sound("popup_close")
	anim_player.play("hide_popup")
	_clear_inventory_duplicate_indicators()
	await anim_player.animation_finished
	is_store_open = false
	Player.popup_open = false
	store_closed.emit()

func _replace_with_empty(item: Item) -> void:
	for child in item_choice_container.get_children():
		if child.has_method("get_current_item") and child.get_current_item() == item:
			var idx: int = child.get_index()
			item_choice_container.remove_child(child)
			child.free()
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = Vector2(200, 200)
			item_choice_container.add_child(empty_slot)
			item_choice_container.move_child(
				item_choice_container.get_child(item_choice_container.get_child_count() - 1), idx
			)
			break

func check_affordability():
	var children = item_choice_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		if item_slot.has_method("get_current_item"):
			if item_slot.item_cost > Player.stats.gold:
				item_slot.cannot_afford()
			else:
				item_slot.can_afford()

func purchase_item_from_store(purchased_item: ItemSelection):
	if Player.stats.gold >= purchased_item.item_cost:
		Player.subtract_gold(purchased_item.item_cost)
		var item: Item = purchased_item.current_item
		AudioManager.play_event_sound("coins_02")

		if item.item_type == Item.ItemType.WEAPON:
			AudioManager.play_ui_sound("item_pickup")
			_replace_with_empty(item)
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
				AudioManager.play_ui_sound("item_pickup")
				item_selected.emit(item)	
				_replace_with_empty(item)
			else:
				need_item_replace.emit(item)
				_replace_with_empty(item)

	check_affordability()


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

func _reset_selection() -> void:
	selected_item = null
	selected_card = null
	btn_take.visible = false
	btn_banish.visible = false
	for child in item_choice_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(false)

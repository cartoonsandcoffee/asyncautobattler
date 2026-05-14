class_name ItemStore
extends Control

signal item_selected(Item)
signal store_closed()
signal need_item_replace(Item)

@onready var item_choice_container: GridContainer = $Panel/BlackBack/PanelContainer/VBoxContainer/itemsContainer
@onready var name_label: Label = $Panel/BlackBack/PanelContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $Panel/BlackBack/PanelContainer/VBoxContainer/MarginContainer/txtDesc
@onready var btn_cancel: Button = $Panel/BlackBack/PanelContainer/VBoxContainer/btnCancel
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var refresh_panel: PanelContainer = $Panel/sidePanelBlack
@onready var refresh_cost: Label = $Panel/sidePanelBlack/panelReroll/HBoxContainer/HBoxContainer2/lblRerollCost
@onready var btn_refresh: Button = $Panel/sidePanelBlack/btnReroll
@onready var anim_reroll: AnimationPlayer = $animReroll

@export var item_rarity: Enums.Rarity = Enums.Rarity.UNCOMMON
@export var items_offered: int = 6
@export var item_columns: int = 3

@export var box_name:String = ""
@export_multiline var box_desc:String = ""
@export var include_extra_rare: bool = false
@export var allow_refresh: bool = true
@export var on_sale: bool = false
## Category string (Leave blank to not limit by category) 
@export var category_string: String = ""
## Shop will be saved and must be manually rerolled
@export var persistent: bool = false 

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var empty_item = preload("res://Scenes/Elements/empty_choice.tscn")

var offered_items: Array[Item] = []
var is_store_open: bool = false

func _ready() -> void:
	item_choice_container.columns = item_columns
	refresh_panel.visible = allow_refresh
	add_to_group("item_selection_events") 
	setup_labels()

	if not persistent:
		generate_item_choices()

func setup_labels():
	name_label.text = box_name
	refresh_cost_label()
	dialogue_label.text = box_desc
	if box_desc == "" || box_desc == null:
		dialogue_label.visible = false

func generate_item_choices():
	#clear old items
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.queue_free()
		
	# Get 3 random items
	if category_string && category_string != "":
		if category_string == "weapon" || category_string == "Weapon":
			offered_items = ItemsManager.get_random_weapons_by_rarity(items_offered, item_rarity, include_extra_rare)
		else:
			offered_items = ItemsManager.get_random_items_by_categry_and_rarity(items_offered, item_rarity, include_extra_rare, category_string)
	else:
		offered_items = ItemsManager.get_random_items(items_offered, item_rarity, include_extra_rare, true)
	
	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(110, 140)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.setup_for_store(on_sale)
		choice_button.item_purchased.connect(_on_item_selected)
	
	check_affordability()

func _on_item_selected(item: ItemChoice):
	purchase_item_from_store(item)

func _on_btn_cancel_pressed() -> void:
	hide_store()


func show_store():
	if persistent:
		for child in item_choice_container.get_children():
			item_choice_container.remove_child(child)
			child.free()
		if Player.town_shop_inventory.is_empty():
			generate_item_choices()
			_save_persistent_inventory()
		else:
			_restore_persistent_inventory()	

	check_affordability()
	anim_player.play("show_store")
	var anim_length = anim_player.get_animation("show_store").length
	await CombatSpeed.create_timer(anim_length)
	is_store_open = true
	Player.popup_open = true
	_refresh_inventory_duplicate_indicators()

func hide_store():
	AudioManager.play_ui_sound("popup_close")
	anim_player.play("hide_store")
	_clear_inventory_duplicate_indicators()
	var anim_length = anim_player.get_animation("hide_store").length
	await CombatSpeed.create_timer(anim_length)	
	is_store_open = false
	Player.popup_open = false
	store_closed.emit()

func replace_item_with_empty(target_item: Item):
	var children = item_choice_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		# Check if this slot contains the target item
		if item_slot.has_method("get_current_item") and item_slot.get_current_item() == target_item:
			# Remove the old slot
			item_choice_container.remove_child(item_slot)
			item_slot.queue_free()
			
			# Create and add empty slot
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = item_slot.custom_minimum_size  # Keep same size
			item_choice_container.add_child(empty_slot)
			
			# Move to correct position in grid
			item_choice_container.move_child(empty_slot, i)
			break

	if persistent:
		_save_persistent_inventory()

func check_affordability():
	var children = item_choice_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		if item_slot.has_method("get_current_item"):
			if item_slot.item_cost > Player.stats.gold:
				item_slot.cannot_afford()
			else:
				item_slot.can_afford()


func purchase_item_from_store(purchased_item: ItemChoice):
	if Player.stats.gold >= purchased_item.item_cost:
		Player.subtract_gold(purchased_item.item_cost)

		if purchased_item.current_item.item_type == Item.ItemType.WEAPON:
			AudioManager.play_ui_sound("item_pickup")
			replace_item_with_empty(purchased_item.current_item)
			if Player.inventory.weapon_slot != null and Player.inventory.weapon_slot.item_id != "weapon_fists":
				need_item_replace.emit(purchased_item.current_item)
			else:
				Player.inventory.set_weapon(purchased_item.current_item)
				Player.update_stats_from_items()
				item_selected.emit(purchased_item.current_item)
		else:
			if Player.inventory.has_empty_slot():
				Player.inventory.add_item(purchased_item.current_item)
				Player.update_stats_from_items()
				AudioManager.play_ui_sound("item_pickup")
				item_selected.emit(purchased_item.current_item)	
				replace_item_with_empty(purchased_item.current_item)
			else:
				need_item_replace.emit(purchased_item.current_item)
				replace_item_with_empty(purchased_item.current_item)

			check_affordability()

# Alternative approach if you want to rebuild the entire grid:
func refresh_store_display():
	# Clear all existing children
	if Player.stats.gold >= Player.stats.refresh_cost:
		Player.subtract_gold(Player.stats.refresh_cost)
		Player.stats.refresh_cost += 1
		refresh_cost_label()
		generate_item_choices()
		
		if persistent:
			_save_persistent_inventory()

		check_affordability()

func refresh_cost_label():
	refresh_cost.text = str(Player.stats.refresh_cost)

func _on_btn_reroll_pressed() -> void:
	refresh_store_display()
	AudioManager.play_event_sound("coins_01")



func _on_btn_reroll_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_reroll.play("reroll_hide")

func _on_btn_reroll_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("woosh")
	anim_reroll.play("reroll_show")

func _save_persistent_inventory():
	if not persistent:
		return

	Player.town_shop_inventory.clear()

	for child in item_choice_container.get_children():
		if not child.is_inside_tree():
			continue
		if child.has_method("get_current_item") and child.get_current_item() != null:
			Player.town_shop_inventory.append(child.get_current_item().item_id)
		else:
			Player.town_shop_inventory.append("")  # empty slot

func _restore_persistent_inventory():
	if not persistent:
		return

	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.free()
	
	offered_items.clear()
	for item_id in Player.town_shop_inventory:
		if item_id == "":
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = Vector2(110, 140)
			item_choice_container.add_child(empty_slot)
		else:
			var item = ItemsManager.get_item_by_id(item_id)
			if item:
				offered_items.append(item)
				var choice_button = item_choice_scene.instantiate()
				choice_button.custom_minimum_size = Vector2(110, 140)
				item_choice_container.add_child(choice_button)
				choice_button.set_item(item)
				choice_button.setup_for_store(on_sale)
				choice_button.item_purchased.connect(_on_item_selected)
	
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
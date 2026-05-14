class_name ItemTownStore
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

@onready var upgrade_panel: PanelContainer = $Panel/sidePanelUpgrade
@onready var upgrade_cost: Label = $Panel/sidePanelUpgrade/panelUpgrade/HBoxContainer/HBoxContainer2/lblUpgradeCost
@onready var btn_upgrade: Button = $Panel/sidePanelUpgrade/btnUpgrade
@onready var anim_upgrade: AnimationPlayer = $animUpgrade

@export var box_name:String = ""
@export_multiline var box_desc:String = ""

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var empty_item = preload("res://Scenes/Elements/empty_choice.tscn")

var is_store_open: bool = false

var base_items_offered: int = 3

var offered_items: Array[Item] = []	# the combined array of offerings

var common_items: Array[Item] = []
var uncommon_items: Array[Item] = []
var rare_items: Array[Item] = []

func _ready() -> void:
	item_choice_container.columns = 6
	refresh_panel.visible = true

	if Player.stats.shop_upgrades < 3:
		upgrade_panel.visible = true
	else:
		upgrade_panel.visible = false

	add_to_group("item_selection_events") 
	setup_labels()

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
	if Player.current_rank < 3:
		common_items = ItemsManager.get_random_items(2, Enums.Rarity.COMMON, false, true)
		uncommon_items = ItemsManager.get_random_items(3, Enums.Rarity.UNCOMMON, false, true)
	else:
		common_items = []
		uncommon_items = ItemsManager.get_random_items(5, Enums.Rarity.UNCOMMON, false, true)

	rare_items = ItemsManager.get_random_items(1, Enums.Rarity.RARE, false, true)

	offered_items = common_items + uncommon_items + rare_items

	var itm_count: int = 0

	# Create choice buttons for each item
	for item in offered_items:
		itm_count += 1

		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(110, 140)
		item_choice_container.add_child(choice_button)
		if itm_count > (base_items_offered + Player.stats.shop_upgrades):
			choice_button.visible = false
		else:
			choice_button.visible = true
		choice_button.set_item(item)
		choice_button.setup_for_store(false)
		choice_button.item_purchased.connect(_on_item_selected)
	
	check_affordability()

func _on_item_selected(item: ItemChoice):
	purchase_item_from_store(item)

func _on_btn_cancel_pressed() -> void:
	hide_store()


func show_store():
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.free()
	if Player.town_shop_inventory.is_empty():
		generate_item_choices()
		_save_persistent_inventory()
	else:
		_restore_persistent_inventory()	

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
		
		_save_persistent_inventory()

		check_affordability()

func refresh_after_upgrade():
	# Clear all existing children
	if Player.stats.gold >= Player.stats.upgrade_cost:
		Player.subtract_gold(Player.stats.upgrade_cost)
		Player.stats.upgrade_cost *= 2
		Player.stats.shop_upgrades += 1

		refresh_cost_label()
		generate_item_choices()
		_save_persistent_inventory()
	
	if Player.stats.shop_upgrades >= 3:
		upgrade_panel.visible = false


func refresh_cost_label():
	refresh_cost.text = str(Player.stats.refresh_cost)
	upgrade_cost.text = str(Player.stats.upgrade_cost)

func _on_btn_upgrade_pressed() -> void:
	refresh_after_upgrade()
	AudioManager.play_event_sound("coins_02")


func _on_btn_upgrade_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_upgrade.play("hide_upgrade")

func _on_btn_upgrade_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("woosh")
	anim_upgrade.play("show_upgrade")
	

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
	Player.town_shop_inventory.clear()

	for child in item_choice_container.get_children():
		if not child.is_inside_tree():
			continue
		if child.has_method("get_current_item") and child.get_current_item() != null:
			Player.town_shop_inventory.append(child.get_current_item().item_id)
		else:
			Player.town_shop_inventory.append("")  # empty slot

func _restore_persistent_inventory():
	for child in item_choice_container.get_children():
		item_choice_container.remove_child(child)
		child.free()
	
	offered_items.clear()

	var itm_count: int = 0

	for item_id in Player.town_shop_inventory:
		itm_count += 1

		if item_id == "":
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = Vector2(110, 140)
			if itm_count > (base_items_offered + Player.stats.shop_upgrades):
				empty_slot.visible = false
			else:
				empty_slot.visible = true
			item_choice_container.add_child(empty_slot)
		else:
			var item = ItemsManager.get_item_by_id(item_id)
			if item:
				# Silently replace with empty slot if item is now invalid for player
				var is_invalid = item == null \
					or (item.has_category("Unique") and Player.inventory.has_unique_item(item_id)) \
					or (item.has_category("Singularity") and Player.inventory.has_any_singularity_item())

				if is_invalid:
					var empty_slot = empty_item.instantiate()
					empty_slot.custom_minimum_size = Vector2(110, 140)
					if itm_count > (base_items_offered + Player.stats.shop_upgrades):
						empty_slot.visible = false
					item_choice_container.add_child(empty_slot)
				else:
					offered_items.append(item)
					var choice_button = item_choice_scene.instantiate()
					choice_button.custom_minimum_size = Vector2(110, 140)
					if itm_count > (base_items_offered + Player.stats.shop_upgrades):
						choice_button.visible = false
					else:
						choice_button.visible = true
					item_choice_container.add_child(choice_button)
					choice_button.set_item(item)
					choice_button.setup_for_store(false)
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
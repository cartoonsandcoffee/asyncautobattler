class_name ItemCombiner
extends Control

## Reusable crafting component - combine two items into one
## Can be used in any room event (Forge, Workshop, etc.)

signal item_crafted(result_item: Item)
signal item_skipped()
signal invalid_combination()
signal combiner_closed()

enum CombinerMode {
	COMBINE,                  	# Combine items using recipes
	REPLACE_SAME_RARITY,		# Replace with random item of same rarity
	REPLACE_HIGHER_TIER,     	# Replace with random item of higher tier
	CRAFT,
	BANISH,						# Banish an item from the game
	SINGLE_UPGRADE,				# Rare version of Combine
	POTION,						# Upgrade a potion to the rarer version
}

@onready var craft_display: PanelContainer = $Panel/panelBlack/panelCombiner
@onready var invalid_display: PanelContainer = $Panel/panelBlack/panelInvalid
@onready var craft_slot_1: Panel = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1
@onready var craft_slot_2: Panel = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot2
@onready var craft_button: Button = $Panel/panelBlack/panelCombiner/VBoxContainer/boxButtons/btnCraft
@onready var message_label: RichTextLabel = $Panel/panelBlack/panelCombiner/VBoxContainer/MarginContainer/txtDesc
@onready var title_label: Label = $Panel/panelBlack/panelCombiner/VBoxContainer/lblName

@onready var result_display: PanelContainer = $Panel/panelBlack/panelReward
@onready var result_icon: TextureRect = $Panel/panelBlack/panelReward/VBoxContainer/itemsContainer/RewardPanel/itemIcon
@onready var result_label: Label = $Panel/panelBlack/panelReward/VBoxContainer/itemsContainer/RewardPanel/itemLabel
@onready var result_name: Label = $Panel/panelBlack/panelReward/VBoxContainer/lblName
@onready var result_text: RichTextLabel = $Panel/panelBlack/panelReward/VBoxContainer/MarginContainer/txtDesc
@onready var continue_button: Button = $Panel/panelBlack/panelReward/VBoxContainer/btnDone

@onready var slot_1_icon: TextureRect = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1/itemIcon
@onready var slot_2_icon: TextureRect = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot2/itemIcon
@onready var slot_1_label: Label = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1/itemLabel
@onready var slot_2_label: Label = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot2/itemLabel

@onready var particle_crafting: CPUParticles2D = $particles_crafting
@onready var particle_offering: CPUParticles2D = $particles_offering

@onready var zoom_altar: ZoomEvent = $zoomAltar
@onready var zoom_forge: ZoomEvent = $zoomForge
@onready var zoom_craft: ZoomEvent = $zoomCraftBug

@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export var combiner_mode: CombinerMode = CombinerMode.COMBINE
@export var number_of_slots: int = 2:
	set(value):
		number_of_slots = clampi(value, 1, 2)
		if is_node_ready():
			update_slot_visibility()

@export var allow_multiple_crafts: bool = true
@export var auto_close_on_craft: bool = false
@export_multiline var instruction_text: String = "Feed me two identical common items..."
@export var box_name:String = ""
@export var button_text: String = ""
@export var crafting_message: String = "Crafting..."

@export_group("Item Requirement")
@export var has_category_requirement: bool = false
@export var required_category:String = ""

@export_group("Success Box")
@export var sb_name: String = ""
@export var sb_text: String = ""
@export var sb_button: String = ""

const EMPTY_SLOT = -2

var slot_1_item: Item = null
var slot_2_item: Item = null
var slot_1_instance_id: int = EMPTY_SLOT
var slot_2_instance_id: int = EMPTY_SLOT

var crafting_particles: CPUParticles2D
var is_processing_craft: bool = false
var result: Item = null

func _ready():
	zoom_altar.zoom_completed.connect(_on_altar_zoom_completed)
	zoom_forge.zoom_completed.connect(_on_forge_zoom_completed)
	zoom_craft.zoom_completed.connect(_on_craft_bug_zoom_completed)
	result = null

	setup_ui()
	setup_drop_zones()
	update_slot_visibility()

func update_slot_visibility():
	if number_of_slots == 1:
		craft_slot_2.visible = false
	elif number_of_slots == 2:
		craft_slot_2.visible = true

func setup_ui():
	"""Initialize UI elements"""
	craft_button.disabled = true
	craft_button.pressed.connect(_on_craft_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	craft_button.text = button_text
	title_label.text = box_name
	message_label.text = instruction_text
	result_display.visible = false
	
	result_text.text = sb_text
	result_name.text = sb_name
	continue_button.text = sb_button

	slot_1_label.text = "SLOT 1"
	slot_2_label.text = "SLOT 2"
	
	# Make slots visual indicators for drag-drop
	craft_slot_1.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_slot_2.mouse_filter = Control.MOUSE_FILTER_STOP

func player_popup_open():
	Player.popup_open = true

func player_popup_close():
	Player.popup_open = false

func setup_drop_zones():
	"""Set up drag-and-drop zones for inventory items"""
	# Connect to your main game's drag system
	# The main_game will call add_item_to_slot() when items are dragged here
	pass

func add_item_to_slot(item: Item, slot_number: int):
	"""Add an item to one of the crafting slots (called by drag-drop system)"""
	if is_processing_craft:
		return  # Don't allow changes during crafting
	
	if has_category_requirement:
		if !item.has_category(required_category):
			if slot_number == 1:
				_restore_inventory_slot_opacity(slot_1_instance_id)
			elif slot_number == 2:
				_restore_inventory_slot_opacity(slot_2_instance_id)
			show_error_message("I can't do anything with that.")
			return

	if item.item_type == Item.ItemType.WEAPON && combiner_mode != CombinerMode.CRAFT:
			if slot_number == 1:
				_restore_inventory_slot_opacity(slot_1_instance_id)
			elif slot_number == 2:
				_restore_inventory_slot_opacity(slot_2_instance_id)
			show_error_message("Weapons cannot be upgraded here.")
			return

	if slot_number == 1:
		if item.instance_id == slot_2_instance_id:
			show_error_message("Can't use the same item twice!")
			return
		_restore_inventory_slot_opacity(slot_1_instance_id)
		slot_1_item = item
		slot_1_instance_id  = item.instance_id
		slot_1_icon.texture = item.item_icon
		slot_1_icon.modulate = item.item_color
		slot_1_icon.visible = true
		slot_1_label.text = item.item_name
	elif slot_number == 2:
		if item.instance_id == slot_1_instance_id:
			show_error_message("Can't use the same item twice!")
			return
		_restore_inventory_slot_opacity(slot_2_instance_id)
		slot_2_item = item
		slot_2_instance_id = item.instance_id
		slot_2_icon.texture = item.item_icon
		slot_2_icon.modulate = item.item_color
		slot_2_icon.visible = true
		slot_2_label.text = item.item_name
	
	if combiner_mode == CombinerMode.COMBINE || combiner_mode == CombinerMode.CRAFT || combiner_mode == CombinerMode.SINGLE_UPGRADE || combiner_mode == CombinerMode.POTION:
		validate_combination(slot_number)
	else:
		validate_offering()

func remove_item_from_slot(slot_number: int):
	"""Clear a crafting slot"""
	if is_processing_craft:
		return
	
	if slot_number == 1:
		_restore_inventory_slot_opacity(slot_1_instance_id) 
		slot_1_item = null
		slot_1_instance_id  = EMPTY_SLOT
		slot_1_icon.texture = null
		slot_1_icon.visible = false
		slot_1_label.text = "SLOT 1"
	elif slot_number == 2:
		_restore_inventory_slot_opacity(slot_2_instance_id)
		slot_2_item = null
		slot_2_instance_id  = EMPTY_SLOT
		slot_2_icon.texture = null
		slot_2_icon.visible = false
		slot_2_label.text = "SLOT 2"
	
	if combiner_mode == CombinerMode.COMBINE || combiner_mode == CombinerMode.CRAFT:
		validate_combination(slot_number)
	else:
		validate_offering()

func validate_combination(slot_number: int):
	match combiner_mode:
		CombinerMode.COMBINE:
			if slot_1_item and slot_2_item:
				if slot_1_item.item_name != slot_2_item.item_name:
					craft_button.disabled = true
					remove_item_from_slot(slot_number)
					await show_error_message("These items aren't the same...")
				elif ItemsManager.can_combine_items(slot_1_item, slot_2_item):
					craft_button.disabled = false
					message_label.text = "Hmmm... these will go well together."
					message_label.modulate = Color.GREEN
					AudioManager.play_event_sound("mmm")
				else:
					craft_button.disabled = true
					remove_item_from_slot(slot_number)
					await show_error_message("These items don't go together...")
			else:
				craft_button.disabled = true
				message_label.text = instruction_text
				message_label.modulate = Color.WHITE
		CombinerMode.CRAFT:
			if slot_1_item and slot_2_item:
				# Check if recipe exists
				if slot_1_item.item_name == slot_2_item.item_name:
					craft_button.disabled = true
					remove_item_from_slot(slot_number)
					await show_error_message("Inbreeding bugs doesn't work, try upgrading those...")
				elif ItemsManager.can_craft_items(slot_1_item, slot_2_item):
					craft_button.disabled = false
					message_label.text = "A new creature can be formed..."
					message_label.modulate = Color.GREEN
				else:
					craft_button.disabled = true
					message_label.text = "These bugs don't have compatible genes."
					message_label.modulate = Color.ORANGE
			else:
				craft_button.disabled = true
		CombinerMode.SINGLE_UPGRADE:
			if slot_1_item:
				if slot_1_item.rarity == Enums.Rarity.COMMON || slot_1_item.rarity == Enums.Rarity.GOLDEN:
					craft_button.disabled = false
					message_label.text = "I can do something with this."
					message_label.modulate = Color.GREEN
					AudioManager.play_event_sound("mmm")
				else:
					craft_button.disabled = true
					remove_item_from_slot(slot_number)
					await show_error_message("I can't do anything with this one...")
			else:
				craft_button.disabled = true
				message_label.text = instruction_text
				message_label.modulate = Color.WHITE
		CombinerMode.POTION:
			if slot_1_item:
				# Check if recipe exists
				if ItemsManager.can_craft_potion(slot_1_item):
					craft_button.disabled = false
					message_label.text = "This Potion can be mixed in the fountain..."
					message_label.modulate = Color.GREEN
				else:
					craft_button.disabled = true
					message_label.text = "This potion cannot be enhanced here."
					message_label.modulate = Color.ORANGE
			else:
				craft_button.disabled = true
		_:
			validate_offering()

func validate_offering():
	if slot_1_item:
		craft_button.disabled = false
	else:
		craft_button.disabled = true

func _on_craft_pressed():
	# CRAFT!!!

	if is_processing_craft:
		return
	
	if combiner_mode == CombinerMode.CRAFT:
		if not ItemsManager.can_craft_items(slot_1_item, slot_2_item):
			show_error_message("Invalid recipe!")
			return
	elif combiner_mode == CombinerMode.COMBINE:
		if not ItemsManager.can_combine_items(slot_1_item, slot_2_item):
			show_error_message("Invalid combination!")
			return
	elif combiner_mode == CombinerMode.POTION:
		if not ItemsManager.can_craft_potion(slot_1_item):
			show_error_message("Nope, sorry!")
			return

	is_processing_craft = true
	craft_button.disabled = true
	
	if combiner_mode == CombinerMode.COMBINE:
		result = ItemsManager.combine_items(slot_1_item, slot_2_item)
	if combiner_mode == CombinerMode.CRAFT:
		result = ItemsManager.craft_items(slot_1_item, slot_2_item)	
	elif combiner_mode == CombinerMode.REPLACE_SAME_RARITY:
		result = ItemsManager.get_item_of_same_tier(slot_1_item.rarity, slot_1_item.item_name)
		Player.shrine_uses_left_this_rank -= 1
	elif combiner_mode == CombinerMode.REPLACE_HIGHER_TIER:
		result = ItemsManager.get_item_of_higher_tier(slot_1_item.rarity)
	elif combiner_mode == CombinerMode.SINGLE_UPGRADE:
		Player.super_upgrades_left -= 1
		result = ItemsManager.combine_items(slot_1_item, slot_1_item)
	if combiner_mode == CombinerMode.POTION:
		result = ItemsManager.craft_potion(slot_1_item)
	elif combiner_mode == CombinerMode.BANISH:
		Player.banishes_left_this_rank -= 1
		result = null

	if not result && combiner_mode != CombinerMode.BANISH:
		show_error_message("Offering failed!")
		is_processing_craft = false
		return

	if combiner_mode == CombinerMode.COMBINE:
		zoom_forge.show_popup(result, result)
	elif combiner_mode == CombinerMode.REPLACE_SAME_RARITY:
		zoom_altar.show_popup(slot_1_item, result)
	elif combiner_mode == CombinerMode.REPLACE_HIGHER_TIER:
		show_crafting_result(result)
	elif combiner_mode == CombinerMode.SINGLE_UPGRADE:
		show_crafting_result(result)
	elif combiner_mode == CombinerMode.POTION:
		show_crafting_result(result)
	elif combiner_mode == CombinerMode.CRAFT:
		zoom_craft.show_popup(slot_1_item, slot_2_item, result)
	elif combiner_mode == CombinerMode.BANISH:
		ItemsManager.banish_item(slot_1_item.item_id)

	# Remove consumed items from player inventory
	var removed_successfully = remove_consumed_items()
	if not removed_successfully:
		show_error_message("Failed to remove items from inventory!")
		is_processing_craft = false
		return
	
	if combiner_mode == CombinerMode.BANISH:
		show_banished_done()

	#if combiner_mode != CombinerMode.BANISH:
		# Add result to player inventory
	#	var added = Player.inventory.add_item(result)
	#	if not added:
			# Inventory full - restore items and show error
	#		show_error_message("Inventory full! Make space and try again.")
			# TODO: Handle inventory full case better
	#		is_processing_craft = false
	#		return
	#else:
	#	show_banished_done()
	
	#Player.update_stats_from_items()
		
	# Emit signal
	#item_crafted.emit(result)
	
	#is_processing_craft = false
	
	# Auto-close if configured
	#if auto_close_on_craft:
	#	await get_tree().create_timer(2.0).timeout
	#	combiner_closed.emit()

func remove_consumed_items() -> bool:
	"""Remove the two crafted items from player inventory"""
	if number_of_slots == 2:
		if slot_1_instance_id <= EMPTY_SLOT or slot_2_instance_id <= EMPTY_SLOT:
			return false
	else:
		if slot_1_instance_id <= EMPTY_SLOT:
			return false

	if combiner_mode == CombinerMode.COMBINE || combiner_mode == CombinerMode.CRAFT:
		var idx1 = Player.inventory.get_slot_by_instance_id(slot_1_instance_id)
		var idx2 = Player.inventory.get_slot_by_instance_id(slot_2_instance_id)
		if idx1 <= EMPTY_SLOT or idx2 <= EMPTY_SLOT:
			return false

		# Remove in descending order to avoid index shifting issues
		var indices: Array[int] = [idx1, idx2]
		Player.inventory.remove_multiple_items(indices)
		Player.inventory.item_added.emit(slot_1_item,idx1)
	else:
		if slot_1_instance_id < 0:
			return false
		var idx1 = Player.inventory.get_slot_by_instance_id(slot_1_instance_id)
		if idx1 < 0:
			return false
		Player.inventory.remove_item(idx1)
		Player.inventory.compact_items()
		Player.inventory.item_added.emit(slot_1_item,idx1)

	return true

func show_crafting_result(result_item: Item):
	"""Display the crafted result with celebration"""
	result_display.visible = true
	craft_display.visible = false

	result_icon.texture = result_item.item_icon
	result_icon.modulate = result_item.item_color
	result_label.text = result_item.item_name 
	continue_button.visible = !auto_close_on_craft
	
	#var gamecolors = GameColors.new()
	result_label.modulate = result_item.item_color
	anim_player.play("show_refresh")

func show_banished_done():
	result_display.visible = true
	craft_display.visible = false

	result_icon.texture = slot_1_item.item_icon
	result_icon.modulate = slot_1_item.item_color
	result_label.text = slot_1_item.item_name 
	continue_button.visible = !auto_close_on_craft
	
	#var gamecolors = GameColors.new()
	result_label.modulate = slot_1_item.item_color

func _on_continue_pressed():
	reset()
	if combiner_mode != CombinerMode.BANISH:
		var added = Player.inventory.add_item(result)
		if not added:
			show_error_message("Inventory full! Make space and try again.")
			return
	
	Player.update_stats_from_items()
	item_crafted.emit(result)
	is_processing_craft = false

	if allow_multiple_crafts:
		# Clear slots for next craft
		reset()
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE
	else:
		# Close the combiner
		item_skipped.emit()
		hide_popup()

func clear_crafting_slots():
	_restore_inventory_slot_opacity(slot_1_instance_id)
	_restore_inventory_slot_opacity(slot_2_instance_id)

	slot_1_item = null
	slot_2_item = null
	slot_1_instance_id  = EMPTY_SLOT
	slot_2_instance_id  = EMPTY_SLOT
	
	slot_1_icon.texture = null
	slot_1_icon.visible = false
	slot_2_icon.texture = null
	slot_2_icon.visible = false
	
	slot_1_label.text = "SLOT 1"
	slot_2_label.text = "SLOT 2"
	
	if combiner_mode == CombinerMode.COMBINE:
		validate_combination(0)
	else:
		validate_offering()

func _restore_inventory_slot_opacity(instance_id: int):
	if instance_id < 0:
		return
	var main_game = get_tree().get_first_node_in_group("main_game")
	if not main_game:
		return
	
	# Check inventory slots
	for slot in main_game.item_slots:
		if slot.current_item and slot.current_item.instance_id == instance_id:
			slot.is_in_crafting_slot = false
			slot.modulate.a = 1.0
			slot.button.disabled = false
			return
		
	# Check weapon slot
	var ws = main_game.weapon_slot
	if ws and ws.current_item and ws.current_item.instance_id == instance_id:
		ws.is_in_crafting_slot = false
		ws.modulate.a = 1.0
		ws.button.disabled = false

func show_error_message(error_text: String):
	"""Display error message with flash effect"""
	message_label.text = error_text
	message_label.modulate = Color.RED
	
	invalid_combination.emit()
	AudioManager.play_random_voice_no()

	# Flash the message
	var tween = create_tween()
	tween.tween_property(message_label, "modulate:a", 0.3, 1)
	tween.tween_property(message_label, "modulate:a", 1.0, 1)
	tween.tween_callback(func(): 
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE
	)

func reset():
	clear_crafting_slots()
	result_display.visible = false
	invalid_display.visible = false
	craft_display.visible = true	
	is_processing_craft = false
	message_label.text = instruction_text
	message_label.modulate = Color.WHITE


func _on_btn_back_pressed() -> void:
	invalid_display.visible = false
	craft_display.visible = true
	reset()


func _on_btn_skip_pressed() -> void:
	reset()
	hide_popup()
	item_skipped.emit()

func _on_altar_zoom_completed():
	show_crafting_result(result)

func _on_forge_zoom_completed():
	show_crafting_result(result)

func _on_craft_bug_zoom_completed():
	show_crafting_result(result)

func _on_btn_craft_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func show_popup():
	anim_player.play("show_popup")
	var anim_length = anim_player.get_animation("show_popup").length
	await CombatSpeed.create_timer(anim_length)
	Player.popup_open = true

func hide_popup():
	AudioManager.play_ui_sound("popup_close")
	anim_player.play("hide_popup")
	var anim_length = anim_player.get_animation("hide_popup").length
	await CombatSpeed.create_timer(anim_length)	
	Player.popup_open = false
	reset()
	combiner_closed.emit()

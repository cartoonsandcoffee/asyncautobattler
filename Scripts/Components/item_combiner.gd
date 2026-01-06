class_name ItemCombiner
extends Control

## Reusable crafting component - combine two items into one
## Can be used in any room event (Forge, Workshop, etc.)

signal item_crafted(result_item: Item)
signal item_skipped()
signal invalid_combination()
signal combiner_closed()

enum CombinerMode {
	CRAFT,                  # Combine items using recipes
	REPLACE_SAME_RARITY,    # Replace with random item of same rarity
	REPLACE_HIGHER_TIER     # Replace with random item of higher tier
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

@export var combiner_mode: CombinerMode = CombinerMode.CRAFT
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

@export_group("Success Box")
@export var sb_name: String = ""
@export var sb_text: String = ""
@export var sb_button: String = ""

var slot_1_item: Item = null
var slot_2_item: Item = null
var slot_1_inventory_index: int = -1
var slot_2_inventory_index: int = -1

var crafting_particles: CPUParticles2D
var is_processing_craft: bool = false
var result: Item = null

func _ready():
	zoom_altar.zoom_completed.connect(_on_altar_zoom_completed)
	zoom_forge.zoom_completed.connect(_on_forge_zoom_completed)
	result = null

	setup_ui()
	setup_particles()
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

func setup_particles():
	"""Create particle effect for crafting success"""
	crafting_particles = CPUParticles2D.new()
	crafting_particles.amount = 50
	crafting_particles.lifetime = 1.0
	crafting_particles.explosiveness = 0.8
	crafting_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	crafting_particles.emission_sphere_radius = 30.0
	
	# Golden spark colors
	var gradient = Gradient.new()
	gradient.colors = [Color("#FFD700"), Color("#FFA500"), Color("#FFFFFF")]
	crafting_particles.color_ramp = gradient
	
	crafting_particles.gravity = Vector2(0, 200)
	crafting_particles.initial_velocity_min = 100
	crafting_particles.initial_velocity_max = 200
	crafting_particles.scale_amount_min = 2.0
	crafting_particles.scale_amount_max = 4.0
	
	crafting_particles.one_shot = true
	crafting_particles.emitting = false
	
	add_child(crafting_particles)
	
	# Position particles at center of crafting area
	await get_tree().process_frame
	crafting_particles.position = Vector2(size.x / 2, size.y / 2)

func setup_drop_zones():
	"""Set up drag-and-drop zones for inventory items"""
	# Connect to your main game's drag system
	# The main_game will call add_item_to_slot() when items are dragged here
	pass

func add_item_to_slot(item: Item, inventory_index: int, slot_number: int):
	"""Add an item to one of the crafting slots (called by drag-drop system)"""
	if is_processing_craft:
		return  # Don't allow changes during crafting
	
	if slot_number == 1:
		if inventory_index == slot_2_inventory_index:
			show_error_message("Can't use the same item twice!")
			return

		slot_1_item = item
		slot_1_inventory_index = inventory_index
		slot_1_icon.texture = item.item_icon
		slot_1_icon.modulate = item.item_color
		slot_1_icon.visible = true
		slot_1_label.text = item.item_name
	elif slot_number == 2:
		if inventory_index == slot_1_inventory_index:
			show_error_message("Can't use the same item twice!")
			return

		slot_2_item = item
		slot_2_inventory_index = inventory_index
		slot_2_icon.texture = item.item_icon
		slot_2_icon.modulate = item.item_color
		slot_2_icon.visible = true
		slot_2_label.text = item.item_name
	
	if combiner_mode == CombinerMode.CRAFT:
		validate_combination(slot_number)
	else:
		validate_offering()

func remove_item_from_slot(slot_number: int):
	"""Clear a crafting slot"""
	if is_processing_craft:
		return
	
	if slot_number == 1:
		slot_1_item = null
		slot_1_inventory_index = -1
		slot_1_icon.texture = null
		slot_1_icon.visible = false
		slot_1_label.text = "SLOT 1"
	elif slot_number == 2:
		slot_2_item = null
		slot_2_inventory_index = -1
		slot_2_icon.texture = null
		slot_2_icon.visible = false
		slot_2_label.text = "SLOT 2"
	
	if combiner_mode == CombinerMode.CRAFT:
		validate_combination(slot_number)
	else:
		validate_offering()

func validate_combination(slot_number: int):
	"""Check if current items can be crafted and update UI accordingly"""
	if slot_1_item and slot_2_item:
		if ItemsManager.can_craft_items(slot_1_item, slot_2_item):
			craft_button.disabled = false
			message_label.text = "Hmmm... these will taste good."
			message_label.modulate = Color.GREEN
			AudioManager.play_event_sound("mmm")

			# Preview the result
			#result = ItemsManager.craft_items(slot_1_item, slot_2_item)
			#if result:
			#	message_label.text = "Ready to craft: " + result.item_name
		else:
			craft_button.disabled = true
			remove_item_from_slot(slot_number)
			await show_error_message("These items don't taste right together...")
			#message_label.text = "These items don't taste right together..."
			#message_label.modulate = Color.RED
	else:
		craft_button.disabled = true
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE

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
			show_error_message("Invalid combination!")
			return
		
	is_processing_craft = true
	craft_button.disabled = true
	
	if combiner_mode == CombinerMode.CRAFT:
		result = ItemsManager.craft_items(slot_1_item, slot_2_item)
	elif combiner_mode == CombinerMode.REPLACE_SAME_RARITY:
		result = ItemsManager.get_item_of_same_tier(slot_1_item.rarity, slot_1_item.item_name)
	elif combiner_mode == CombinerMode.REPLACE_HIGHER_TIER:
		result = ItemsManager.get_item_of_higher_tier(slot_1_item.rarity)

	if not result:
		show_error_message("Offering failed!")
		is_processing_craft = false
		return

	if combiner_mode == CombinerMode.CRAFT:
		zoom_forge.show_popup(result, result)
	elif combiner_mode == CombinerMode.REPLACE_SAME_RARITY:
		zoom_altar.show_popup(slot_1_item, result)
	elif combiner_mode == CombinerMode.REPLACE_HIGHER_TIER:
		pass

	# Remove consumed items from player inventory
	var removed_successfully = remove_consumed_items()
	if not removed_successfully:
		show_error_message("Failed to remove items from inventory!")
		is_processing_craft = false
		return
	
	# Add result to player inventory
	var added = Player.inventory.add_item(result)
	if not added:
		# Inventory full - restore items and show error
		show_error_message("Inventory full! Make space and try again.")
		# TODO: Handle inventory full case better
		is_processing_craft = false
		return
	
	Player.update_stats_from_items()
		
	# Emit signal
	item_crafted.emit(result)
	
	is_processing_craft = false
	
	# Auto-close if configured
	if auto_close_on_craft:
		await get_tree().create_timer(2.0).timeout
		combiner_closed.emit()

func remove_consumed_items() -> bool:
	"""Remove the two crafted items from player inventory"""
	if combiner_mode == CombinerMode.CRAFT:
		if slot_1_inventory_index < 0 or slot_2_inventory_index < 0:
			return false
	else:
		if slot_1_inventory_index < 0:
			return false

	if combiner_mode == CombinerMode.CRAFT:			
		# Remove in descending order to avoid index shifting issues
		var indices: Array[int] = [slot_1_inventory_index, slot_2_inventory_index]
		Player.inventory.remove_multiple_items(indices)
	else:
		Player.inventory.remove_item(slot_1_inventory_index)

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


func _on_continue_pressed():
	if allow_multiple_crafts:
		# Clear slots for next craft
		reset()
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE
	else:
		# Close the combiner
		combiner_closed.emit()
		item_skipped.emit()

func clear_crafting_slots():
	"""Reset slots for next craft"""
	slot_1_item = null
	slot_2_item = null
	slot_1_inventory_index = -1
	slot_2_inventory_index = -1
	
	slot_1_icon.texture = null
	slot_1_icon.visible = false
	slot_2_icon.texture = null
	slot_2_icon.visible = false
	
	slot_1_label.text = "SLOT 1"
	slot_2_label.text = "SLOT 2"
	
	if combiner_mode == CombinerMode.CRAFT:
		validate_combination(0)
	else:
		validate_offering()

func show_error_message(error_text: String):
	"""Display error message with flash effect"""
	message_label.text = error_text
	message_label.modulate = Color.RED
	
	invalid_combination.emit()
	AudioManager.play_event_sound("forge_bad")

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


func _on_btn_craft_pressed() -> void:
	pass # Replace with function body.


func _on_btn_skip_pressed() -> void:
	item_skipped.emit()


func _on_btn_done_pressed() -> void:
	_on_continue_pressed()

func _on_altar_zoom_completed():
	show_crafting_result(result)

func _on_forge_zoom_completed():
	show_crafting_result(result)


func _on_btn_craft_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

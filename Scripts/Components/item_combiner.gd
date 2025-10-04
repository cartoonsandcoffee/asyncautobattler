class_name ItemCombiner
extends Control

## Reusable crafting component - combine two items into one
## Can be used in any room event (Forge, Workshop, etc.)

signal item_crafted(result_item: Item)
signal item_skipped()
signal invalid_combination()
signal combiner_closed()

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
@onready var continue_button: Button = $Panel/panelBlack/panelReward/VBoxContainer/btnDone

@onready var slot_1_icon: TextureRect = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1/itemIcon
@onready var slot_2_icon: TextureRect = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot2/itemIcon
@onready var slot_1_label: Label = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1/itemLabel
@onready var slot_2_label: Label = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot2/itemLabel

@export var allow_multiple_crafts: bool = true
@export var auto_close_on_craft: bool = false
@export_multiline var instruction_text: String = "Feed me two identical common items..."
@export var box_name:String = ""

var slot_1_item: Item = null
var slot_2_item: Item = null
var slot_1_inventory_index: int = -1
var slot_2_inventory_index: int = -1

var crafting_particles: CPUParticles2D
var is_processing_craft: bool = false

func _ready():
	setup_ui()
	setup_particles()
	setup_drop_zones()

func setup_ui():
	"""Initialize UI elements"""
	craft_button.disabled = true
	craft_button.pressed.connect(_on_craft_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	message_label.text = instruction_text
	result_display.visible = false
	
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
		slot_1_item = item
		slot_1_inventory_index = inventory_index
		slot_1_icon.texture = item.item_icon
		slot_1_icon.modulate = item.item_color
		slot_1_icon.visible = true
		slot_1_label.text = item.item_name
	elif slot_number == 2:
		slot_2_item = item
		slot_2_inventory_index = inventory_index
		slot_2_icon.texture = item.item_icon
		slot_2_icon.modulate = item.item_color
		slot_2_icon.visible = true
		slot_2_label.text = item.item_name
	
	validate_combination()

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
	
	validate_combination()

func validate_combination():
	"""Check if current items can be crafted and update UI accordingly"""
	if slot_1_item and slot_2_item:
		if ItemsManager.can_craft_items(slot_1_item, slot_2_item):
			craft_button.disabled = false
			message_label.text = "Ready to craft!"
			message_label.modulate = Color.GREEN
			
			# Preview the result
			var result = ItemsManager.craft_items(slot_1_item, slot_2_item)
			if result:
				message_label.text = "Ready to craft: " + result.item_name
		else:
			craft_button.disabled = true
			message_label.text = "These items cannot be combined"
			message_label.modulate = Color.RED
	else:
		craft_button.disabled = true
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE

func _on_craft_pressed():
	"""Perform the crafting"""
	if is_processing_craft:
		return
	
	if not ItemsManager.can_craft_items(slot_1_item, slot_2_item):
		show_error_message("Invalid combination!")
		return
	
	is_processing_craft = true
	craft_button.disabled = true
	
	# Get the crafted result
	var result = ItemsManager.craft_items(slot_1_item, slot_2_item)
	if not result:
		show_error_message("Crafting failed!")
		is_processing_craft = false
		return
	
	# Play crafting animation
	await play_crafting_animation()
	
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
	
	# Show success result
	show_crafting_result(result)
	
	# Emit signal
	item_crafted.emit(result)
	
	is_processing_craft = false
	
	# Auto-close if configured
	if auto_close_on_craft:
		await get_tree().create_timer(2.0).timeout
		combiner_closed.emit()

func play_crafting_animation() -> void:
	"""Visual effect for crafting"""
	message_label.text = "Crafting..."
	message_label.modulate = Color.YELLOW
	
	# Emit particles
	crafting_particles.emitting = true
	
	# Flash effect on slots - items being consumed
	var tween = create_tween()
	tween.tween_property(craft_slot_1, "modulate", Color(1, 1, 1, 0.3), 0.2)
	tween.parallel().tween_property(craft_slot_2, "modulate", Color(1, 1, 1, 0.3), 0.2)
	tween.tween_property(craft_slot_1, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(craft_slot_2, "modulate", Color.WHITE, 0.2)
	tween.tween_property(craft_slot_1, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.parallel().tween_property(craft_slot_2, "modulate", Color(1, 1, 1, 0), 0.3)
	
	await get_tree().create_timer(1.2).timeout
	
	# Reset slot visibility
	craft_slot_1.modulate = Color.WHITE
	craft_slot_2.modulate = Color.WHITE

func remove_consumed_items() -> bool:
	"""Remove the two crafted items from player inventory"""
	if slot_1_inventory_index < 0 or slot_2_inventory_index < 0:
		return false
	
	# Remove in descending order to avoid index shifting issues
	var indices = [slot_1_inventory_index, slot_2_inventory_index]
	Player.inventory.remove_multiple_items(indices)
	
	return true

func show_crafting_result(result_item: Item):
	"""Display the crafted result with celebration"""
	result_display.visible = true
	result_icon.texture = result_item.item_icon
	result_icon.modulate = result_item.item_color
	result_label.text = "Created:\n" + result_item.item_name + "!"
	
	var gamecolors = GameColors.new()
	result_label.modulate = gamecolors.rarity.golden
	
	# Animate result panel in
	result_display.scale = Vector2(0.5, 0.5)
	result_display.modulate.a = 0.0
	
	var tween = create_tween()
	tween.parallel().tween_property(result_display, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(result_display, "modulate:a", 1.0, 0.3)

func _on_continue_pressed():
	"""Continue crafting or close"""
	result_display.visible = false
	
	if allow_multiple_crafts:
		# Clear slots for next craft
		clear_crafting_slots()
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE
	else:
		# Close the combiner
		combiner_closed.emit()

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
	
	validate_combination()

func show_error_message(error_text: String):
	"""Display error message with flash effect"""
	message_label.text = error_text
	message_label.modulate = Color.RED
	
	invalid_combination.emit()
	
	# Flash the message
	var tween = create_tween()
	tween.tween_property(message_label, "modulate:a", 0.3, 0.2)
	tween.tween_property(message_label, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): 
		message_label.text = instruction_text
		message_label.modulate = Color.WHITE
	)

func reset():
	"""Reset the combiner to initial state"""
	clear_crafting_slots()
	result_display.visible = false
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
	pass # Replace with function body.

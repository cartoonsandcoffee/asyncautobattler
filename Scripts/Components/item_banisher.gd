class_name ItemBanisher
extends Control

signal item_skipped()
signal item_banished()
signal combiner_closed()


@onready var craft_display: PanelContainer = $Panel/panelBlack/panelCombiner
@onready var invalid_display: PanelContainer = $Panel/panelBlack/panelInvalid
@onready var craft_slot_1: Panel = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1
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
@onready var slot_1_label: Label = $Panel/panelBlack/panelCombiner/VBoxContainer/itemsContainer/CraftSlot1/itemLabel

@onready var particle_crafting: CPUParticles2D = $particles_crafting
@onready var particle_offering: CPUParticles2D = $particles_offering


@onready var anim_player: AnimationPlayer = $AnimationPlayer


@export var allow_multiple_crafts: bool = true
@export var auto_close_on_craft: bool = false



var slot_1_item: Item = null
var slot_2_item: Item = null
var slot_1_inventory_index: int = -1
var slot_2_inventory_index: int = -1

var crafting_particles: CPUParticles2D
var is_processing_craft: bool = false
var result: Item = null

func _ready():
	result = null

	setup_ui()
	setup_drop_zones()

func setup_ui():
	"""Initialize UI elements"""
	craft_button.disabled = true
	craft_button.pressed.connect(_on_craft_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	result_display.visible = false
	
	# Make slots visual indicators for drag-drop
	craft_slot_1.mouse_filter = Control.MOUSE_FILTER_STOP

func player_popup_open():
	Player.popup_open = true

func player_popup_close():
	Player.popup_open = false

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
			return

		slot_1_item = item
		slot_1_inventory_index = inventory_index
		slot_1_icon.texture = item.item_icon
		slot_1_icon.modulate = item.item_color
		slot_1_icon.visible = true
		slot_1_label.text = item.item_name

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

func _on_craft_pressed():
	# CRAFT!!!

	if is_processing_craft:
		return
	

	is_processing_craft = true
	craft_button.disabled = true
	
	if not result:
		is_processing_craft = false
		return

	# Remove consumed items from player inventory
	var removed_successfully = remove_consumed_items()
	if not removed_successfully:
		is_processing_craft = false
		return
	
	# Add result to player inventory
	var added = Player.inventory.add_item(result)
	if not added:
		# Inventory full - restore items and show error
		# TODO: Handle inventory full case better
		is_processing_craft = false
		return
	
	Player.update_stats_from_items()
		
	
	is_processing_craft = false
	
	# Auto-close if configured
	if auto_close_on_craft:
		await get_tree().create_timer(2.0).timeout
		combiner_closed.emit()

func remove_consumed_items() -> bool:
	if slot_1_inventory_index < 0:
		return false

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
		message_label.modulate = Color.WHITE
	else:
		# Close the combiner
		item_skipped.emit()
		hide_popup()

func clear_crafting_slots():
	"""Reset slots for next craft"""
	slot_1_item = null
	slot_2_item = null
	slot_1_inventory_index = -1
	
	slot_1_icon.texture = null
	slot_1_icon.visible = false


func reset():
	clear_crafting_slots()
	result_display.visible = false
	invalid_display.visible = false
	craft_display.visible = true	
	is_processing_craft = false
	message_label.modulate = Color.WHITE


func _on_btn_back_pressed() -> void:
	invalid_display.visible = false
	craft_display.visible = true
	reset()


func _on_btn_craft_pressed() -> void:
	if slot_1_item:
		Player.banishes_left_this_rank -= 1
		ItemsManager.banish_item(slot_1_item.item_id)
		remove_consumed_items()


func _on_btn_skip_pressed() -> void:
	hide_popup()
	item_skipped.emit()


func _on_btn_done_pressed() -> void:
	_on_continue_pressed()

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

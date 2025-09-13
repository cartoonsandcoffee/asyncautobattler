# reward_replacement_popup.gd
class_name RewardReplacementPopup
extends Control

## Popup that allows player to replace inventory items when inventory is full
## Shows the reward item and lets player select which inventory item to replace

signal item_replacement_selected(reward_item: Item, replaced_slot_index: int)
signal replacement_cancelled()

# UI References
@onready var popup_panel: Panel = $replacementPanel
@onready var reward_item_display: ItemSlot = $replacementPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/HBoxContainer/newItem
@onready var instruction_label: Label = $replacementPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/lblDesc
@onready var inventory_grid: GridContainer = $replacementPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/inventoryGrid
@onready var cancel_button: Button = $replacementPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/boxButtons/btnCancel
@onready var confirm_button: Button = $replacementPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/boxButtons/btnConfirm

# State
var reward_item: Item
var selected_slot_index: int = -1
var inventory_slots: Array[ItemSlot] = []

# Preloaded scenes
var item_slot_scene = preload("res://Scenes/item.tscn")

func _ready():
	# Start hidden
	visible = false
	
	# Connect buttons
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true
	
	# Setup popup styling
	_setup_popup_style()

func show_replacement_popup(reward: Item):
	"""Display the popup with the reward item and current inventory"""
	reward_item = reward
	selected_slot_index = -1
	confirm_button.disabled = true
	
	# Update instruction text
	instruction_label.text = "Your inventory is full!\nSelect which item to replace with:"
	
	# Display the reward item
	_setup_reward_display()
	
	# Display current inventory for selection
	_setup_inventory_selection()
	
	# Show the popup with animation
	visible = true
	#_animate_popup_in()

func _setup_reward_display():
	"""Set up the reward item display"""
	# Clear existing reward display
	for child in reward_item_display.get_children():
		child.queue_free()
	
	# Create reward item slot
	var reward_slot = item_slot_scene.instantiate()
	reward_slot.set_item(reward_item)
	reward_slot.custom_minimum_size = Vector2(120, 120)
	reward_slot.set_selectable(false)  # Not clickable
	
	# Add glow effect to make it stand out
	reward_slot.modulate = Color(1.2, 1.2, 1.0)  # Slight golden tint
	
	reward_item_display.add_child(reward_slot)

func _setup_inventory_selection():
	"""Set up the inventory grid for item selection"""
	# Clear existing inventory display
	for child in inventory_grid.get_children():
		child.queue_free()
	inventory_slots.clear()
	
	# Set up grid columns
	inventory_grid.columns = 6
	
	# Add current inventory items
	for i in range(Player.inventory.item_slots.size()):
		var item = Player.inventory.item_slots[i]
		var slot = item_slot_scene.instantiate()
		
		if item:
			slot.set_item(item)
		else:
			slot.set_empty()
		
		slot.custom_minimum_size = Vector2(100, 100)
		slot.set_order(i + 1)  # Show slot numbers
		slot.set_selectable(true)
		
		# Connect click signal for selection
		slot.slot_clicked.connect(_on_inventory_slot_clicked.bind(i))
		
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)

func _on_inventory_slot_clicked(slot_index: int):
	"""Handle clicking on an inventory slot for replacement"""
	# Deselect previous selection
	if selected_slot_index >= 0 and selected_slot_index < inventory_slots.size():
		inventory_slots[selected_slot_index].set_selected(false)
	
	# Select new slot
	selected_slot_index = slot_index
	inventory_slots[slot_index].set_selected(true)
	
	# Enable confirm button
	confirm_button.disabled = false
	
	# Update instruction text
	var item_name = "Empty Slot"
	if Player.inventory.item_slots[slot_index]:
		item_name = Player.inventory.item_slots[slot_index].item_name
	
	instruction_label.text = "Replace [%d] %s with %s?" % [slot_index + 1, item_name, reward_item.item_name]

func _on_confirm_pressed():
	"""Confirm the replacement"""
	if selected_slot_index >= 0:
		item_replacement_selected.emit(reward_item, selected_slot_index)
		_close_popup()

func _on_cancel_pressed():
	"""Cancel the replacement"""
	replacement_cancelled.emit()
	_close_popup()

func _close_popup():
	"""Close the popup with animation"""
	await _animate_popup_out()
	visible = false

func _animate_popup_in():
	"""Animate popup appearing"""
	popup_panel.scale = Vector2(0.8, 0.8)
	popup_panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.parallel().tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(popup_panel, "modulate:a", 1.0, 0.2)

func _animate_popup_out():
	"""Animate popup disappearing"""
	var tween = create_tween()
	tween.parallel().tween_property(popup_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(popup_panel, "modulate:a", 0.0, 0.2)
	await tween.finished

func _setup_popup_style():
	"""Set up popup visual styling"""
	# Add semi-transparent background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks outside popup
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	move_child(overlay, 0)  # Put overlay behind popup panel

class_name MainGameController
extends Control

## Main game scene controller that manages the overall game interface
## Coordinates inventory UI, dungeon map, and room display area

# UI Components
@onready var dungeon_map_panel: Panel = $TopPanel
@onready var inventory_panel: Panel = $BottomPanel
@onready var stat_panel: Panel = $StatPanel
@onready var room_container_panel: Panel = $RoomPanel

@onready var stat_health: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statHealth
@onready var stat_damage: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statDamage
@onready var stat_shield: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statShield
@onready var stat_agility: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statAgility
@onready var stat_gold: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statGold

@onready var item_grid: GridContainer = $BottomPanel/MarginContainer/VBoxContainer/HBoxContainer/InventorySlots/ItemSlots
@onready var weapon_slot: ItemSlot = $BottomPanel/MarginContainer/VBoxContainer/HBoxContainer/Weapon

var current_room_scene: Node
var item_slot = preload("res://Scenes/item.tscn")

var item_slots: Array[ItemSlot] = []

var dragging_instance_id: int = -1
var dragging_from_slot: int = -1
var dragging_slot: ItemSlot = null
var drag_preview: Control = null

func _ready():
	print("Main Game Scene initialized")
	Player.stats_updated.connect(_on_stats_updated)
	create_test_player()
	set_process_input(true) # for drag preview
	
func _input(event: InputEvent):
	# Update drag preview position
	if dragging_slot and drag_preview:
		if event is InputEventMouseMotion:
			drag_preview.global_position = event.global_position - Vector2(50, 50)  # Center on mouse


func create_test_player():
	setup_inventory()
	setup_weapon()
	Player.update_stats_from_items()

	
func set_player_stats():
	stat_health.update_stuff()
	stat_damage.update_stuff()
	stat_shield.update_stuff()
	stat_agility.update_stuff()
	stat_gold.update_stuff()

func setup_inventory():
	item_slots.clear()
	item_slots.resize(Player.inventory.max_item_slots)
	item_grid.columns = Player.inventory.max_item_slots

	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()

	for i in range(Player.inventory.item_slots.size()):
		var item = Player.inventory.item_slots[i]
		var item_container = item_slot.instantiate()

		item_container.set_item(item)
		item_container.custom_minimum_size = Vector2(100, 100)
		item_container.slot_index = i
		item_container.set_order(i + 1)  # Display 1-based index

		item_container.drag_started.connect(_on_drag_started)
		item_container.drag_ended.connect(_on_drag_ended)
		item_container.slot_dropped_on.connect(_on_slot_dropped_on)

		item_slots.append(item_container)
		item_grid.add_child(item_container)

func setup_weapon():
	weapon_slot.set_item(Player.inventory.weapon_slot)

func _on_stats_updated():
	set_player_stats()

func _on_drag_started(slot: ItemSlot):
	if not slot.current_item:
		return
	
	dragging_slot = slot
	
	# Create drag preview
	create_drag_preview(slot.current_item)
	
	# Optional: Hide tooltip while dragging
	if slot.tooltip_panel:
		slot.tooltip_panel.hide()

func _on_drag_ended(slot: ItemSlot):
	# Find what slot we're over
	var target_slot = get_slot_under_mouse()
	
	if target_slot and target_slot != slot:
		# Perform the swap or move
		perform_item_move(slot, target_slot)
	
	# Clean up drag state
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_slot = null
	slot.modulate.a = 1.0

func _on_slot_dropped_on(target_slot: ItemSlot, dragged_item: Item):
	if dragging_slot and dragging_slot != target_slot:
		perform_item_move(dragging_slot, target_slot)

func perform_item_move(from_slot: ItemSlot, to_slot: ItemSlot):
	var from_index = from_slot.slot_index
	var to_index = to_slot.slot_index
	
	# If moving to empty slot, just move
	if not to_slot.current_item:
		Player.inventory.move_item_to_slot(from_index, to_index)
	else:
		# Swap items
		Player.inventory.swap_items(from_index, to_index)
	
	# Compact to remove gaps
	Player.inventory.compact_items()
	
	# Refresh display
	setup_inventory()
	Player.update_stats_from_items()

func get_slot_under_mouse() -> ItemSlot:
	var mouse_pos = get_global_mouse_position()
	for slot in item_slots:
		if slot and slot.get_global_rect().has_point(mouse_pos):
			return slot
	return null

func create_drag_preview(item: Item):
	if drag_preview:
		drag_preview.queue_free()
	
	drag_preview = Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.size = Vector2(100, 100)
	
	var icon = TextureRect.new()
	icon.texture = item.item_icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(100, 100)
	icon.modulate = item.item_color
	icon.modulate.a = 0.7
	
	drag_preview.add_child(icon)
	get_tree().root.add_child(drag_preview)

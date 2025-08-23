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

func _ready():
	print("Main Game Scene initialized")
	Player.stats_updated.connect(_on_stats_updated)
	create_test_player()
	

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
	item_slots.resize(Player.inventory.max_item_slots)
	item_grid.columns = Player.inventory.max_item_slots

	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()
		item_slots.clear()

	for item in Player.inventory.item_slots:
		var item_container = item_slot.instantiate()
		item_container.set_item(item)
		item_container.custom_minimum_size = Vector2(100, 100)
		item_slots.append(item_container)
		item_container.set_order(item_slots.size())
		item_grid.add_child(item_container)

func setup_weapon():
	weapon_slot.set_item(Player.inventory.weapon_slot)

func _on_stats_updated():
	set_player_stats()

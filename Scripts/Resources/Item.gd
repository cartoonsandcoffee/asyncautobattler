# item.gd
class_name Item
extends Resource

## Base item class with rule-based mechanics system
## All items, weapons, armor, etc. inherit from this

enum ItemType {
	WEAPON,
	BODY_ARMOR,
	SHIELD,
	GLOVES, 
	BOOTS,
	HELMET,
	FOOD,
	POTION,
	TOME,
	TOOL,
	PET,
	JEWELRY
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
	LEGENDARY,
	MYSTERIOUS
}

@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export_multiline var item_desc: String = ""
@export var item_icon: Texture2D
@export var item_color: Color

@export var rarity: Rarity = Rarity.COMMON
@export var categories: Array[String] = []  # Tags like "Sword", "Metal", "Fire"
@export var rng_weight: float = 1.0
@export var unlocked: bool = false

# Stat modifiers this item provides
@export var damage_bonus: int = 0
@export var shield_bonus: int = 0
@export var agility_bonus: int = 0
@export var hit_points_bonus: int = 0
@export var strikes_bonus: int = 0


var instance_id: int = -1 # Add unique instance ID
var slot_index: int = -1  # Track which slot this item is in

func _init():
	instance_id = Time.get_unix_time_from_system() * 1000000 + randi() % 1000000
	slot_index = -1

func create_instance() -> Item:
	var new_instance = duplicate(true)  # Deep duplicate
	new_instance.instance_id = Time.get_unix_time_from_system() * 1000000 + randi() % 1000000
	slot_index = -1
	return new_instance

func set_position(pos: int):
	slot_index = pos

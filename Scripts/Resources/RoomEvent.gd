class_name RoomEvent
extends Resource

enum EventType {
	TREASURE_CHEST,
	CAMP_FIRE,
	MERCHANT,
	ALTAR,
	BLACKSMITH,
	TINKER,
	MERGE_BOWL,
	CAULDRON,
	FAIRY,
	OLD_WOMAN,
	MAGIC_WELL,
	BARGAINING_TENT,
	VAULT,
	PITS,
	HERO_GRAVE,
	WANDERING_DEALER,
	ROYAL_CHEST,
	ROYAL_MERCHANT,
	MYSTERIOUS_OLD_MAN,
	WITCH_QUEEN  # Elite encounter
}

enum RoomType {
	HALLWAY,
	TOMB,
	CHAMBERS,
	FORGE, 
	LIBRARY,
	COVEN,
	LARDER,
	GALLERY,
	BOSS,
	STARTING_ROOM,
	SPECIAL
}

@export var event_name: String = "Unknown Event"
@export_multiline var description: String = ""
@export var event_type: EventType = EventType.TREASURE_CHEST
@export var event_room: RoomType = RoomType.HALLWAY
# Weight for random selection
@export var rng_weight: float = 1.0

# Event properties
@export_group("Combat")
@export var has_combat: bool = false
@export var enemy: Enemy
@export var is_elite: bool = false


var combat_completed: bool = false
var event_completed: bool = false


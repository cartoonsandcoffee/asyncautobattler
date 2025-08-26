class_name RoomData
extends Resource

## Base item class with rule-based mechanics system
## All items, weapons, armor, etc. inherit from this

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
	MYSTERIOUS
}

@export var room_type: DungeonManager.RoomType = DungeonManager.RoomType.STARTER
@export var event_name: String = "Unknown Event"
@export var event_type: String = ""
@export_multiline var room_desc: String = ""
@export var room_pic: Texture2D
@export var room_color: Color

@export var rarity: Rarity = Rarity.COMMON
@export var rng_weight: float = 1.0
@export var unlocked: bool = false

func _init(type: DungeonManager.RoomType = DungeonManager.RoomType.STARTER, event: String = "mysterious_old_man"):
	room_type = type
	event_name = event
	event_type = event
	room_pic = DungeonManager.get_background_for_room_type(type)

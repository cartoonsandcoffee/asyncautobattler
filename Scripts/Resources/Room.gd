class_name Room
extends Resource

## Base item class with rule-based mechanics system
## All items, weapons, armor, etc. inherit from this

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

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
	MYSTERIOUS
}

@export var room_name: String = ""
@export var room_type: RoomType = RoomType.HALLWAY
@export_multiline var room_desc: String = ""
@export var room_pic: Texture2D
@export var room_color: Color

@export var rarity: Rarity = Rarity.COMMON
@export var rng_weight: float = 1.0
@export var unlocked: bool = false


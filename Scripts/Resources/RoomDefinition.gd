class_name RoomDefinition
extends Resource

@export var room_type: Enums.RoomType
@export var rarity: Enums.Rarity  
@export var room_name: String = "Unknown Room"
@export_multiline var room_desc: String = "Unknown Room"

@export var background_texture: Texture2D
@export var door_texture: Texture2D
@export var room_icon: Texture2D  # for minimap
@export var room_color: Color

# The events that can happen in this room type
@export var possible_events: Array[PackedScene] = []

# RNG weight for door generation (higher = more likely)
@export var spawn_weight: int = 1

# Requirements (what rank this room can appear in)
@export var min_rank: int = 1
@export var max_rank: int = 5

func get_random_event() -> PackedScene:
	if possible_events.size() > 0:
		return possible_events.pick_random()
	else:
		push_warning("No events defined for room: " + room_name)
		return null

func can_appear_at_rank(rank: int) -> bool:
	return rank >= min_rank and rank <= max_rank


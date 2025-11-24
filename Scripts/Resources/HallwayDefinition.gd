class_name HallwayDefinition
extends Resource

@export var hallway_type: Enums.HallwayType
@export var hallway_name: String = "Mysterious Hallway"
@export_multiline var hallway_desc: String = ""

@export var hallway_background_texture: Texture2D  # For background
@export var hallway_icon: Texture2D  # For minimap
@export var hallway_color: Color = Color.WHITE

# Events that can happen in this hallway
@export var possible_events: Array[PackedScene] = []

# RNG weight for hallway generation
@export var spawn_weight: int = 1

# Requirements (which ranks this hallway can appear in)
@export var min_rank: int = 1
@export var max_rank: int = 5

# Position restrictions (which hallway slots 0-4 this can appear in)
@export var allowed_positions: Array[int] = [0, 1, 2, 3, 4]  # Empty = all positions allowed

func get_random_event() -> PackedScene:
	if possible_events.size() > 0:
		return possible_events.pick_random()
	else:
		push_warning("No events defined for hallway: " + hallway_name)
		return null

func can_appear_at_rank(rank: int) -> bool:
	return rank >= min_rank and rank <= max_rank

func can_appear_at_position(position: int) -> bool:
	if allowed_positions.is_empty():
		return true  # No restrictions
	return allowed_positions.has(position)
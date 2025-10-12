class_name RoomData
extends Resource


var room_definition: RoomDefinition     # Reference to the template
var chosen_event_scene: PackedScene     # Which specific event was chosen
var room_state: Dictionary = {}         # Runtime state (visited, completed, etc.)

func _init(def: RoomDefinition = null, event: PackedScene = null):
	room_definition = def
	chosen_event_scene = event

# Delegate methods to RoomDefinition
func get_room_name() -> String:
	return room_definition.room_name if room_definition else "Unknown Door"

func get_room_desc() -> String:
	return room_definition.room_desc if room_definition else "Nothing is known about what lies beyond."

func get_background_texture() -> Texture2D:
	return room_definition.background_texture if room_definition else null

func get_door_icon() -> Texture2D:
	return room_definition.door_icon if room_definition else null

func get_rarity() -> Enums.Rarity:
	return room_definition.rarity if room_definition else Enums.Rarity.COMMON

func get_room_type() -> Enums.RoomType:
	return room_definition.room_type if room_definition else Enums.RoomType.HALLWAY
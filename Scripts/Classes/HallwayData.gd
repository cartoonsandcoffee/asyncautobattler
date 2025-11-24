class_name HallwayData
extends Resource

var hallway_definition: HallwayDefinition
var chosen_event_scene: PackedScene

func _init(def: HallwayDefinition = null, event: PackedScene = null):
	hallway_definition = def
	chosen_event_scene = event

func get_hallway_name() -> String:
	return hallway_definition.hallway_name if hallway_definition else "Unknown Hallway"

func get_hallway_icon() -> Texture2D:
	return hallway_definition.hallway_icon if hallway_definition else null

func get_hallway_color() -> Color:
	return hallway_definition.hallway_color if hallway_definition else Color.WHITE
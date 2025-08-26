extends Node

var event_scenes: Dictionary = {
	"mysterious_old_man": preload("res://Scenes/Rooms/room_old_man.tscn")
	# Add more events as we build them
}

func get_event_scene(event_type: String) -> PackedScene:
	if event_scenes.has(event_type):
		return event_scenes[event_type]
	else:
		push_error("Event scene not found: " + event_type)
		return null

func has_event(event_type: String) -> bool:
	return event_scenes.has(event_type)
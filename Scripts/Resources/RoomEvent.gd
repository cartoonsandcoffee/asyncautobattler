class_name RoomEvent
extends Control

## Base class for all room events
## Handles setup and completion signals

signal event_completed()

@export var room_data: RoomData
@export_multiline var event_description: String
@export var enemy_resource: Enemy = null  # Direct enemy resource reference

func setup(data: RoomData):
	room_data = data
	initialize_event()
	start_event()
	
func start_event():
    # Override in child classes for event-specific startup
	pass

func initialize_event():
	pass

func spawn_enemy(difficulty_multiplier: float = 1.0) -> Enemy:
	"""Spawn enemy with difficulty scaling"""
	if not enemy_resource:
		return null
	
	return enemy_resource.create_scaled_version(difficulty_multiplier)
	
func complete_event():
	event_completed.emit()
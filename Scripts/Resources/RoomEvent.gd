class_name RoomEvent
extends Control

## Base class for all room events
## Handles setup and completion signals

signal event_completed()

@export var room_data: RoomData
@export_multiline var event_description: String

func setup(data: RoomData):
	room_data = data
	initialize_event()
	start_event()
	
func start_event():
    # Override in child classes for event-specific startup
	pass

func initialize_event():
	pass

func complete_event():
	event_completed.emit()
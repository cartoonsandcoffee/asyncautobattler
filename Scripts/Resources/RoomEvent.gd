class_name RoomEvent
extends Control

## Base class for all room events
## Handles setup and completion signals

signal event_completed()

@export var room_data: RoomData

func setup(data: RoomData):
	room_data = data
	initialize_event()

func initialize_event():
	pass

func complete_event():
	event_completed.emit()
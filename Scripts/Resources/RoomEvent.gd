class_name RoomEvent
extends Control

## Base class for all room events
## Handles setup and completion signals

signal event_completed()
signal combat_requested(enemy: Enemy)

@export var room_data: RoomData
@export_multiline var event_description: String
@export var enemy_resource: Enemy = null  # Direct enemy resource reference

var main_game_ref: Control
var combat_completed: bool = false
var player_won_combat: bool = false


func _ready():
	# Get reference to main game
	main_game_ref = get_tree().get_root().get_node_or_null("MainGame")
	if not main_game_ref:
		push_error("RoomEvent: Could not find MainGame node!")
	
	# Start the event sequence
	_begin_event_sequence()

func setup(data: RoomData):
	room_data = data
	
func start_event():
	# Override in child classes for event-specific startup
	pass

func initialize_event():
	pass

func _begin_event_sequence():
	"""Handle the two-phase sequence: combat (if any) then event"""
	if enemy_resource:
		# Phase 1: Combat
		await _initiate_combat()
		
		# Check if player won
		if not player_won_combat:
			# Player lost or ran - end event
			complete_event()
			return
	
	# Phase 2: Actual event
	await _run_room_event()
	
	# Complete
	complete_event()



func complete_event():
	event_completed.emit()


func _initiate_combat():
	"""Request combat from MainGame"""
	if not main_game_ref:
		push_error("No MainGame reference!")
		return
	
	# Request combat from main game
	combat_requested.emit(enemy_resource)
	
	# Wait for combat to complete
	if main_game_ref.has_method("request_combat"):
		var result = await main_game_ref.request_combat(enemy_resource)
		player_won_combat = result
		combat_completed = true
	else:
		push_error("MainGame doesn't have request_combat method!")
		combat_completed = true
		player_won_combat = false


func _run_room_event():
	"""Override this in child classes to implement the actual event"""
	# Default: just show description
	if event_description != "":
		print("Room Event: ", event_description)
	initialize_event()
	start_event()

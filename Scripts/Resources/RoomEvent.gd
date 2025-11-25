class_name RoomEvent
extends Control

## Base class for all room events
## Handles setup and completion signals

signal event_completed()
signal combat_requested(enemy: Enemy)

@export var room_data: RoomData
@export_multiline var event_description: String  # I dont think this is used/displayed anywhere yet... Maybe delete
@export var enemy_resource: Enemy = null  # Legacy - now use room_data.assigned_enemy ... maybe delete?

var main_game_ref: Control
var combat_completed: bool = false
var player_won_combat: bool = false


func _ready():
	# Get reference to main game
	print("room_event -> ready")
	reset_all_animations()
	main_game_ref = get_tree().get_root().get_node_or_null("MainGame")
	if not main_game_ref:
		push_error("RoomEvent: Could not find MainGame node!")
	
	# Start the event sequence
	_begin_event_sequence()

func setup(data: RoomData):
	room_data = data
	print("RoomEvent.setup() called with room_data: ", room_data.room_definition.room_name if room_data else "null")

func start_event():
	print("room_event -> start_event")

func initialize_event():
	print("room_event -> initialize_event")

func reset_all_animations():
	# Find and reset all AnimationPlayers in this room 
	for child in get_children():
		if child is AnimationPlayer:
			if child.has_animation("RESET"):
				child.play("RESET")
				child.stop()  # Stop after setting to RESET state

func _begin_event_sequence():
	# --- Handle the two-phase sequence: combat (if any) then event
	# JDM: If you want to add a call to a FADE_IN function on the individual roomevent scenes, here is where I think.

	# Check if this room instance has combat
	var has_combat = false
	var enemy_to_fight = null
	
	# Priority 1: Check room_data for assigned combat
	if room_data and room_data.has_combat_this_instance:
		has_combat = true
		enemy_to_fight = room_data.assigned_enemy
	# Priority 2: Legacy enemy_resource (for old room events)
	elif enemy_resource:
		print("enable legacy combat here if you want")
		#has_combat = true
		#enemy_to_fight = enemy_resource
	
	if has_combat and enemy_to_fight:
		# Phase 1: Combat
		await _initiate_combat(enemy_to_fight)
		
		# Check if player won
		if not player_won_combat:
			# Player lost or ran - end event
			complete_event()
			return
	
	# Phase 2: Actual event
	await _run_room_event()
	
func complete_event():
	event_completed.emit()


func _initiate_combat(enemy: Enemy):
	"""Request combat from MainGame"""
	if not main_game_ref:
		push_error("No MainGame reference!")
		return
	
	# Request combat from main game
	combat_requested.emit(enemy)
	
	# Wait for combat to complete
	if main_game_ref.has_method("request_combat"):
		var result = await main_game_ref.request_combat(enemy)
		player_won_combat = result
		combat_completed = true
	else:
		push_error("MainGame doesn't have request_combat method!")
		combat_completed = true
		player_won_combat = false


func _run_room_event():
	# Override this in child classes to implement the actual event
	# Default: just show description

	if event_description != "":
		print("Room Event: ", event_description)
	initialize_event()
	start_event()

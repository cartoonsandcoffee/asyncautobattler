class_name HallwayEvent
extends Control

## Base class for all hallway events (non-combat encounters between rooms)

signal hallway_completed()

@export_multiline var event_description: String = ""

var hallway_data: HallwayData
var main_game_ref: Control
var event_resolved: bool = false  # Track if player interacted or just continued


func _ready():
	print("hallway_event -> ready")
	reset_all_animations()
	main_game_ref = get_tree().get_root().get_node_or_null("MainGame")
	if not main_game_ref:
		push_error("HallwayEvent: Could not find MainGame node!")
	
	_begin_hallway_sequence()

func setup(data: HallwayData):
	hallway_data = data

func reset_all_animations():
	# Reset all AnimationPlayers in this hallway
	for child in get_children():
		if child is AnimationPlayer:
			if child.has_animation("RESET"):
				child.play("RESET")
				child.stop()

func _begin_hallway_sequence():
	"""Start the hallway event - override this in child classes"""
	await initialize_event()
	show_event()

func initialize_event():
	"""Override in child classes to set up event-specific logic"""
	print("hallway_event -> initialize_event (override this)")

func show_event():
	"""Override if you want custom continue button logic, or call directly"""
	# Child classes should implement their own continue button
	# and connect it to complete_hallway()
	pass

func event_completed():
	"""Call this when player is done with hallway (clicked continue or finished event)"""
	print("hallway_event -> complete_hallway")
	hallway_completed.emit()

func on_event_interaction():
	"""Called when player actually interacts with the event (not just continuing)"""
	event_resolved = true
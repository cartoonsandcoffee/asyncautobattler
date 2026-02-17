class_name Minimap
extends HBoxContainer

signal room_icon_clicked(room_index: int)
signal zoom_out_requested()

@onready var lbl_rank: Label = $VBoxContainer/lblRank
@onready var btn_zoom_out: LinkButton = $VBoxContainer/btnZoom

const QUESTION_MARK_ICON = preload("res://Resources/Icons/icon_question.tres") 
const CROWN_ICON = preload("res://Resources/Icons/icon_crown.tres") 

var room_icons: Array[RoomIconSlot] = []
var current_rank: int = 1
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_create_zoom_out_button()
	_initialize_room_slots()
	update_display()

func _create_zoom_out_button():
	btn_zoom_out.pressed.connect(_on_zoom_out_pressed)

func _initialize_room_slots():
	pass

func update_display():
	lbl_rank.text = "Rank: %d" % current_rank
	#	# Get predetermined rooms for current rank
	#var predetermined_rooms = 10 #DungeonManager.current_rank_rooms
	#var current_room_idx = 1 # DungeonManager.current_room_index
	
	# Special case: If we're at the very start (rank 1, room 0, no rooms cleared)
	# Show starter room as first icon
	#var showing_starter = (current_rank == 0 and DungeonManager.rooms_cleared_this_rank == 0)
	
	#for i in range(room_grid.columns):
	#	if i < predetermined_rooms.size():
	#		var room_data = predetermined_rooms[i]
	#		
	#		if i < current_room_idx:
	#			# Already visited - show actual room (full color)
	#			room_icons[i].set_visited_room(room_data)
	#			room_icons[i].set_current(false)
	#			if room_data.room_state.get("skipped", false):
	#				room_icons[i].set_skipped()				
	#		elif i == current_room_idx:
	#			# Current room - highlight
	#			room_icons[i].set_room_type(room_data)
	#			room_icons[i].set_current(true)
	#		else:
	#			# Future room - show abstract type (greyed out)
	#			room_icons[i].set_room_type(room_data)
	#			room_icons[i].set_current(false)
	#			# Grey out future rooms
	#			room_icons[i].texture_rect.modulate = Color(0.5, 0.5, 0.5)
	#			if room_data.has_combat_this_instance:
	#				room_icons[i]._set_border(Color.RED, 2)
	#			else:
	#				room_icons[i]._set_border(Color(0.5, 0.5, 0.5), 1)
	#	else:
	#		# No room data - show unknown
	#		room_icons[i].set_unknown()

	#room_icons[DungeonManager.ROOMS_PER_RANK].set_boss_room()

	# If showing starter room, override first slot
	#if showing_starter:
		# Get starter room icon
	#	var starter_def = RoomRegistry.get_room_definition("starter")
	#	if starter_def and starter_def.room_icon:
	#		room_icons[0].texture_rect.texture = starter_def.room_icon
	#		room_icons[0].texture_rect.modulate = starter_def.room_color
	#		room_icons[0].set_current(true)

func _on_room_icon_clicked(room_index: int):
	room_icon_clicked.emit(room_index)

func _on_zoom_out_pressed():
	zoom_out_requested.emit()

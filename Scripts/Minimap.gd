class_name Minimap
extends HBoxContainer

signal room_icon_clicked(room_index: int)
signal zoom_out_requested()

@onready var lbl_rank: Label = $VBoxContainer/lblRank
@onready var room_grid: GridContainer = $RoomGrid
@onready var btn_zoom_out: LinkButton = $VBoxContainer/btnZoom

const ROOMS_PER_RANK = 6
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
	# Clear existing (from scene)
	for child in room_grid.get_children():
		child.queue_free()
	
	room_icons.clear()
	room_grid.columns = 6
	
	# Create 6 room icon slots
	for i in range(ROOMS_PER_RANK):
		var room_slot = room_box.instantiate()
		room_slot.room_index = i
		room_slot.custom_minimum_size = Vector2(40, 40)
		room_slot.icon_clicked.connect(_on_room_icon_clicked)
		room_grid.add_child(room_slot)
		room_icons.append(room_slot)

func update_display():
	lbl_rank.text = "Rank: %d" % current_rank
	
	# Get current rank's rooms from DungeonManager
	var current_rooms = DungeonManager.current_rank_rooms
	
	for i in range(ROOMS_PER_RANK):
		if i < current_rooms.size():
			# Show visited room icon
			room_icons[i].set_visited_room(current_rooms[i])
			
			# Highlight current room
			if i == current_rooms.size() - 1:
				room_icons[i].set_current(true)
			else:
				room_icons[i].set_current(false)
		elif i == ROOMS_PER_RANK - 1:
			# Last slot is always boss
			room_icons[i].set_boss_room()
		else:
			# Unknown future room
			room_icons[i].set_unknown()

func _on_room_icon_clicked(room_index: int):
	room_icon_clicked.emit(room_index)

func _on_zoom_out_pressed():
	zoom_out_requested.emit()

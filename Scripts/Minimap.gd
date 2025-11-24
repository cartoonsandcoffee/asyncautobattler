class_name Minimap
extends HBoxContainer

signal room_icon_clicked(room_index: int)
signal zoom_out_requested()

@onready var lbl_rank: Label = $VBoxContainer/lblRank
@onready var room_grid: GridContainer = $RoomGrid
@onready var btn_zoom_out: LinkButton = $VBoxContainer/btnZoom

const NODES_PER_RANK = 11  # 6 rooms + 6 halls
const ROOMS_PER_RANK = 6
const HALLWAYS_PER_RANK = 5
const QUESTION_MARK_ICON = preload("res://Resources/Icons/icon_question.tres") 
const CROWN_ICON = preload("res://Resources/Icons/icon_crown.tres") 


var node_icons: Array[RoomIconSlot] = []  # Mix of rooms and hallways
var current_rank: int = 1
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_create_zoom_out_button()
	_initialize_node_slots()
	update_display()

func _create_zoom_out_button():
	btn_zoom_out.pressed.connect(_on_zoom_out_pressed)

func _initialize_node_slots():
	# Clear existing (from scene)
	for child in room_grid.get_children():
		child.queue_free()
	
	node_icons.clear()
	room_grid.columns = NODES_PER_RANK
	
	# Create 11 node slots (alternating rooms and hallways)
	# [Room0] [Hall0] [Room1] [Hall1] [Room2] [Hall2] [Room3] [Hall3] [Room4] [Hall4] [Room5/Boss]
	for i in range(NODES_PER_RANK):
		var node_slot = room_box.instantiate()
		node_slot.room_index = i

		# Hallways are smaller (every odd index except last)
		if i % 2 == 1:  # Hallway
			node_slot.custom_minimum_size = Vector2(40, 30)
		else:  # Room
			node_slot.custom_minimum_size = Vector2(40, 40)

		node_slot.icon_clicked.connect(_on_room_icon_clicked)
		room_grid.add_child(node_slot)
		node_icons.append(node_slot)

func update_display():
	lbl_rank.text = "Rank: %d" % current_rank
	
	# Get current rank's rooms from DungeonManager
	var current_rooms = DungeonManager.current_rank_rooms
	var current_hallways = DungeonManager.current_rank_hallways

	# Update each node in the grid
	for i in range(NODES_PER_RANK):
		if i % 2 == 0:
			# Even indices are rooms
			_update_room_slot(i, current_rooms)
		else:
			# Odd indices are hallways
			_update_hallway_slot(i, current_hallways)


func _update_room_slot(node_index: int, rooms: Array):
	var room_index = node_index / 2  # 0,2,4,6,8,10 → 0,1,2,3,4,5
	
	if room_index < rooms.size():
		# Visited room
		node_icons[node_index].set_visited_room(rooms[room_index])
		
		# Highlight current room (last in array, and only if we're not waiting for hallway)
		if room_index == rooms.size() - 1 and not DungeonManager.awaiting_hallway:
			node_icons[node_index].set_current(true)
		else:
			node_icons[node_index].set_current(false)
	elif room_index == 5:
		# Boss room (always visible)
		node_icons[node_index].set_boss_room()
	else:
		# Unknown future room
		node_icons[node_index].set_unknown()

func _update_hallway_slot(node_index: int, hallways: Array):
	var hallway_index = (node_index - 1) / 2  # 1,3,5,7,9 → 0,1,2,3,4
	
	if hallway_index < hallways.size():
		var hallway = hallways[hallway_index]

		# Check if this hallway has been visited
		var visited = hallway_index < DungeonManager.current_rank_visited_hallways.size()
				
		if visited:
			# Show as completed hallway (slightly dimmed)
			node_icons[node_index].set_hallway(hallway)
			node_icons[node_index].texture_rect.modulate = hallway.hallway_color * Color(0.7, 0.7, 0.7)
		else:
			# Show as upcoming hallway (full color)
			node_icons[node_index].set_hallway(hallway)
		
		# Highlight current hallway if we're waiting to enter it
		if hallway_index == DungeonManager.current_hallway_index and DungeonManager.awaiting_hallway:
			node_icons[node_index].set_current(true)
		else:
			node_icons[node_index].set_current(false)
	else:
		# This shouldn't happen - hallways are pre-generated
		node_icons[node_index].set_unknown()

func _on_room_icon_clicked(room_index: int):
	room_icon_clicked.emit(room_index)

func _on_zoom_out_pressed():
	zoom_out_requested.emit()

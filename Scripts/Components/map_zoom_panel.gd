class_name MapZoomPanel
extends Control

signal closed()
signal boss_rush_pressed()

@onready var dungeon_grid: GridContainer = $Panel/PanelContainer/VBoxContainer/mainContent/dungeonContainer/dungeonGrid
@onready var boss_inventory_grid: GridContainer = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/bossInventoryGrid

@onready var lbl_boss: Label = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/lblBoss
@onready var stat_health: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statHealth
@onready var stat_shield: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statShield
@onready var stat_damage: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statAttack
@onready var stat_agility: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statAgility

@onready var btn_close: Button = $Panel/PanelContainer/VBoxContainer/buttonContainer/btnClose
@onready var btn_rush: Button = $Panel/PanelContainer/VBoxContainer/buttonContainer/btnRush
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const NODES_PER_RANK = 11  # 6 rooms + 5 hallways
const ROOMS_PER_RANK = 6
const HALLWAYS_PER_RANK = 5
const MAX_RANKS = 5

var node_icons: Array[Array] = []  # 2D array: [rank][node_index]
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_setup_grid()
	_setup_buttons()
	visible = false

func _setup_grid():
	dungeon_grid.columns = NODES_PER_RANK

	# Add final boss row (larger crown)
	#_add_final_boss_row()

	# Create 5 ranks (rows) + 1 final boss row
	for rank in range(MAX_RANKS, 0, -1):  # Rank 5 at top, Rank 1 at bottom
		var rank_nodes: Array[RoomIconSlot] = []
		
		for node_idx in range(NODES_PER_RANK):
			var node_slot = room_box.instantiate()
			node_slot.set_references()
			node_slot.room_index = node_idx

			# Hallways are smaller (every odd index except last)
			if node_idx % 2 == 1:  # Hallway
				node_slot.custom_minimum_size = Vector2(30, 30)
			else:  # Room
				node_slot.custom_minimum_size = Vector2(40, 40)
			
			# Don't allow clicking in zoom view
			node_slot.icon_button.disabled = true
			
			dungeon_grid.add_child(node_slot)
			rank_nodes.append(node_slot)
		
		node_icons.insert(0, rank_nodes)  # Insert at front so index matches rank
	


func _add_final_boss_row():
	# Add 6 cells for spacing, with crown in middle
	for i in range(ROOMS_PER_RANK):
		if i == 2 or i == 3:  # Middle 2 cells
			if i == 2:
				var final_boss = room_box.instantiate()
				final_boss.set_references()
				final_boss.custom_minimum_size = Vector2(80, 80)  # Larger
				final_boss.set_boss_room()
				final_boss.icon_button.disabled = true
				dungeon_grid.add_child(final_boss)
		else:
			# Empty spacer
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(40, 40)
			dungeon_grid.add_child(spacer)

func _setup_buttons():
	btn_close.pressed.connect(_on_close_pressed)
	btn_rush.pressed.connect(_on_rush_pressed)

func show_panel():
	update_display()
	visible = true
	anim_player.play("slide_in")

func hide_panel():
	anim_player.play("slide_out")
	visible = false

func update_display():
	var all_rooms = DungeonManager.all_visited_rooms
	var all_hallways = DungeonManager.all_visited_hallways
	var current_rank = DungeonManager.current_rank
	
	# Clear all nodes to unknown first
	for rank in range(MAX_RANKS):
		for node_idx in range(NODES_PER_RANK):
			node_icons[rank][node_idx].set_unknown()
	
	# Fill in visited rooms
	var room_counter = 0
	for room_data in all_rooms:
		var rank_index = room_counter / ROOMS_PER_RANK  # Which rank (0-4)
		var room_index = room_counter % ROOMS_PER_RANK  # Which room in rank (0-5)
		
		if rank_index < MAX_RANKS:
			var node_index = room_index * 2  # Rooms are at even indices: 0,2,4,6,8,10
			
			if room_index == ROOMS_PER_RANK - 1:
				# Boss room
				node_icons[rank_index][node_index].set_boss_room()
			else:
				node_icons[rank_index][node_index].set_visited_room(room_data)
		
		room_counter += 1
	
	# Fill in visited hallways
	var hallway_counter = 0
	for hallway_def in all_hallways:
		var rank_index = hallway_counter / HALLWAYS_PER_RANK  # Which rank (0-4)
		var hallway_index = hallway_counter % HALLWAYS_PER_RANK  # Which hallway in rank (0-4)
		
		if rank_index < MAX_RANKS:
			var node_index = hallway_index * 2 + 1  # Hallways are at odd indices: 1,3,5,7,9
			node_icons[rank_index][node_index].set_hallway(hallway_def)
		
		hallway_counter += 1
	
	# Show current rank's boss with gold crown
	var current_rank_index = current_rank - 1
	if current_rank_index < MAX_RANKS:
		var boss_node_index = (ROOMS_PER_RANK - 1) * 2  # Boss is at node 10
		node_icons[current_rank_index][boss_node_index].set_boss_room()
		node_icons[current_rank_index][boss_node_index].texture_rect.modulate = Color.GOLD
	
	# Grey out future boss rooms
	for rank in range(current_rank, MAX_RANKS):
		var boss_node_index = (ROOMS_PER_RANK - 1) * 2
		node_icons[rank][boss_node_index].set_boss_room()
		node_icons[rank][boss_node_index].texture_rect.modulate = Color.DARK_GRAY
	
	# Update boss info (placeholder for now)
	_update_boss_info()

func _update_boss_info():
	# TODO: Populate with actual boss data from Supabase
	btn_rush.disabled = false  # Enable when ready

func _on_close_pressed():
	hide_panel()
	closed.emit()

func _on_rush_pressed():
	boss_rush_pressed.emit()
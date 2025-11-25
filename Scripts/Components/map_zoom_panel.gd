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

const ROOMS_PER_RANK = 11
const MAX_RANKS = 5

var node_icons: Array[Array] = []  # 2D array: [rank][room_index]
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_setup_grid()
	_setup_buttons()
	visible = false

func _setup_grid():
	dungeon_grid.columns = ROOMS_PER_RANK
	
	# Create 5 ranks (rows), each with 10 rooms
	for rank in range(MAX_RANKS, 0, -1):  # Rank 5 at top, Rank 1 at bottom
		var rank_nodes: Array[RoomIconSlot] = []
		
		for room_idx in range(ROOMS_PER_RANK):
			var node_slot = room_box.instantiate()
			node_slot.set_references()
			node_slot.room_index = room_idx
			node_slot.custom_minimum_size = Vector2(40, 40)
			
			# Don't allow clicking in zoom view
			node_slot.icon_button.disabled = true
			
			dungeon_grid.add_child(node_slot)
			rank_nodes.append(node_slot)
		
		node_icons.insert(0, rank_nodes)  # Insert at front so index matches rank

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
	var current_rank = DungeonManager.current_rank
	
	# Clear all nodes to unknown first
	for rank in range(MAX_RANKS):
		for room_idx in range(ROOMS_PER_RANK):
			node_icons[rank][room_idx].set_unknown()
	
	# Fill in visited rooms from history
	var room_counter = 0
	for room_data in all_rooms:
		var rank_index = room_counter / ROOMS_PER_RANK  # Which rank (0-4)
		var room_index = room_counter % ROOMS_PER_RANK  # Which room in rank (0-9)
		
		if rank_index < MAX_RANKS:
			node_icons[rank_index][room_index].set_visited_room(room_data)
		
		room_counter += 1
	
	# Show current rank's predetermined rooms (abstract icons, greyed out if not visited)
	var current_rank_index = current_rank - 1
	if current_rank_index >= 0 and current_rank_index < MAX_RANKS:
		var current_rank_rooms = DungeonManager.current_rank_rooms
		var current_room_idx = DungeonManager.current_room_index
		
		for room_idx in range(current_rank_rooms.size()):
			if room_idx < current_room_idx:
				# Already visited - full color (already set above from all_visited_rooms)
				pass
			else:
				# Not visited yet - show abstract type but greyed out
				var room_data = current_rank_rooms[room_idx]
				node_icons[current_rank_index][room_idx].set_room_type(room_data)
				# Grey it out
				node_icons[current_rank_index][room_idx].texture_rect.modulate = Color(0.5, 0.5, 0.5)
	
	# Update boss info
	_update_boss_info()

func _update_boss_info():
	# TODO: Populate with actual boss data from Supabase
	btn_rush.disabled = true  # Enable when boss system ready

func _on_close_pressed():
	hide_panel()
	closed.emit()

func _on_rush_pressed():
	boss_rush_pressed.emit()

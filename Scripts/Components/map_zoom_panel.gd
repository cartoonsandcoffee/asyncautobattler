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

const ROOMS_PER_RANK = 6
const MAX_RANKS = 5

var room_icons: Array[Array] = []  # 2D array: [rank][room_index]
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_setup_grid()
	_setup_buttons()
	visible = false

func _setup_grid():
	dungeon_grid.columns = ROOMS_PER_RANK

	# Add final boss row (larger crown)
	#_add_final_boss_row()

	# Create 5 ranks (rows) + 1 final boss row
	for rank in range(MAX_RANKS, 0, -1):  # Rank 5 at top, Rank 1 at bottom
		var rank_icons: Array[RoomIconSlot] = []
		
		for room_idx in range(ROOMS_PER_RANK):
			var room_slot = room_box.instantiate()
			room_slot.set_references()
			room_slot.room_index = room_idx
			room_slot.custom_minimum_size = Vector2(40, 40)
			
			# Don't allow clicking in zoom view
			room_slot.icon_button.disabled = true
			
			dungeon_grid.add_child(room_slot)
			rank_icons.append(room_slot)
		
		room_icons.insert(0, rank_icons)  # Insert at front so index matches rank
	


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
	var current_rank = DungeonManager.current_rank
	
	# Clear all icons to unknown first
	for rank in range(MAX_RANKS):
		for room_idx in range(ROOMS_PER_RANK):
			room_icons[rank][room_idx].set_unknown()
	
	# Fill in visited rooms
	var room_counter = 0
	for room_data in all_rooms:
		var rank_index = room_counter / ROOMS_PER_RANK  # Which rank (0-4)
		var room_index = room_counter % ROOMS_PER_RANK  # Which room in rank (0-5)
		
		if rank_index < MAX_RANKS:
			if room_index == ROOMS_PER_RANK - 1:
				# Boss room
				room_icons[rank_index][room_index].set_boss_room()
			else:
				room_icons[rank_index][room_index].set_visited_room(room_data)
		
		room_counter += 1
	
	# Show current rank's boss with gold crown
	var current_rank_index = current_rank - 1
	if current_rank_index < MAX_RANKS:
		room_icons[current_rank_index][ROOMS_PER_RANK - 1].set_boss_room()
		room_icons[current_rank_index][ROOMS_PER_RANK - 1].texture_rect.modulate = Color.GOLD
	
	# Grey out future boss rooms
	for rank in range(current_rank, MAX_RANKS):
		room_icons[rank][ROOMS_PER_RANK - 1].set_boss_room()
		room_icons[rank][ROOMS_PER_RANK - 1].texture_rect.modulate = Color.DARK_GRAY
	
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
class_name MapZoomPanel
extends Control

signal closed()
signal boss_rush_pressed()

@onready var dungeon_grid: GridContainer = $Panel/PanelContainer/VBoxContainer/mainContent/dungeonContainer/dungeonGrid
@onready var boss_inventory_grid: GridContainer = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/bossInventoryGrid

@onready var boss_pic: TextureRect = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/bossPic
@onready var lbl_boss: Label = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/lblBoss
@onready var boss_stat_grid: Container = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid
@onready var lbl_rank: Label = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/lblRank

@onready var boss_stat_health: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statHealth
@onready var boss_stat_shield: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statShield
@onready var boss_stat_attack: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statAttack
@onready var boss_stat_agility: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/VBoxContainer/bossStatGrid/statAgility

@onready var btn_close: Button = $Panel/PanelContainer/VBoxContainer/buttonContainer/btnClose
@onready var btn_rush: Button = $Panel/PanelContainer/VBoxContainer/buttonContainer/btnRush
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# TODO: Add these nodes to scene:
# @onready var boss_stat_strikes = boss_stat_grid.get_node("statStrikes")
# @onready var boss_stat_burn = boss_stat_grid.get_node("statBurnDamage")
# @onready var boss_stat_gold = boss_stat_grid.get_node("statGold")


const MAX_RANKS = 5

var node_icons: Array[Array] = []  # 2D array: [rank][room_index]
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_setup_grid()
	_setup_buttons()
	visible = false

	if DungeonManager:
		DungeonManager.boss_loaded.connect(_on_boss_loaded)

func _setup_grid():
	dungeon_grid.columns = DungeonManager.ROOMS_PER_RANK
	
	# Create 5 ranks (rows), each with 10 rooms
	for rank in range(MAX_RANKS, 0, -1):  # Rank 5 at top, Rank 1 at bottom
		var rank_nodes: Array[RoomIconSlot] = []
		
		for room_idx in range(DungeonManager.ROOMS_PER_RANK):
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

	lbl_rank.text = "Rank  " + str(current_rank) + "  Boss"

	# Clear all nodes to unknown first
	for rank in range(MAX_RANKS):
		for room_idx in range(DungeonManager.ROOMS_PER_RANK):
			node_icons[rank][room_idx].set_unknown()
	
	# Fill in visited rooms from history
	var room_counter = 0
	for room_data in all_rooms:
		var rank_index = room_counter / DungeonManager.ROOMS_PER_RANK  # Which rank (0-4)
		var room_index = room_counter % DungeonManager.ROOMS_PER_RANK  # Which room in rank (0-9)
		
		if rank_index < MAX_RANKS:
			node_icons[rank_index][room_index].set_visited_room(room_data)
		
			# CHECK IF SKIPPED 
			if room_data.room_state.get("skipped", false):
				node_icons[rank_index][room_index].set_skipped()

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
	_update_boss_preview()
	btn_rush.disabled = true  # Enable when boss system ready

func _on_close_pressed():
	hide_panel()
	closed.emit()

func _on_rush_pressed():
	boss_rush_pressed.emit()

func _on_boss_loaded(boss: Enemy):
	print("[MapZoomPanel] Boss loaded, updating preview: %s" % boss.enemy_name)
	_update_boss_preview(boss)

func _update_boss_preview(boss: Enemy = null):
	"""Populate boss preview panel with boss data."""
	# Use provided boss or get from DungeonManager
	if not boss:
		boss = DungeonManager.current_boss_enemy
	
	if not boss:
		print("[MapZoomPanel] No boss to display")
		_hide_boss_preview()
		return
	
	# Show boss container
	_show_boss_preview()
	
	# Update boss name
	lbl_boss.text = boss.enemy_name
	
	# Update boss sprite
	_update_boss_sprite(boss)
	
	# Update boss stats
	_update_boss_stats(boss)
	
	# Update boss inventory
	_update_boss_inventory(boss)

func _show_boss_preview():
	"""Make boss preview container visible."""
	# TODO: Set visibility on boss container
	# boss_container.visible = true
	pass

func _hide_boss_preview():
	"""Hide boss preview when no boss available."""
	# TODO: Set visibility on boss container
	# boss_container.visible = false
	pass

func _update_boss_sprite(boss: Enemy):
	"""Load and display boss sprite based on skin_id from Supabase."""
	# Get skin_id from boss data (stored in DungeonManager.current_boss_data)
	var skin_id: int = 0
	if not DungeonManager.current_boss_data.is_empty():
		skin_id = DungeonManager.current_boss_data.get("skin_id", 0)
	
	# Load sprite
	var sprite_path = "res://Assets/Art/Player/PVP/Player_Skin_%d.png" % skin_id
	if ResourceLoader.exists(sprite_path):
		boss_pic.texture = load(sprite_path)
	else:
		# Fallback to default or enemy sprite if boss skin doesn't exist
		if boss.sprite:
			boss_pic.texture = boss.sprite
		else:
			push_warning("[MapZoomPanel] Boss sprite not found: %s" % sprite_path)

func _update_boss_stats(boss: Enemy):
	"""Update all boss stat displays."""
	# Update existing stats
	boss_stat_health.update_stat(
		Enums.Stats.HITPOINTS, 
		boss.stats.hit_points, 
		boss.stats.hit_points
	)
	
	boss_stat_attack.update_stat(
		Enums.Stats.DAMAGE, 
		boss.stats.damage, 
		boss.stats.damage
	)
	
	boss_stat_shield.update_stat(
		Enums.Stats.SHIELD, 
		boss.stats.shield, 
		boss.stats.shield
	)
	
	boss_stat_agility.update_stat(
		Enums.Stats.AGILITY, 
		boss.stats.agility, 
		boss.stats.agility
	)
	
	# TODO: Add these to scene and uncomment:
	# boss_stat_strikes.update_stat(
	# 	Enums.Stats.STRIKES, 
	# 	boss.stats.strikes, 
	# 	boss.stats.strikes
	# )
	
	# boss_stat_burn.update_stat(
	# 	Enums.Stats.BURN_DAMAGE, 
	# 	boss.stats.burn_damage, 
	# 	boss.stats.burn_damage
	# )
	
	# boss_stat_gold.update_stat(
	# 	Enums.Stats.GOLD, 
	# 	boss.stats.gold, 
	# 	boss.stats.gold
	# )

func _update_boss_inventory(boss: Enemy):
	"""Populate boss inventory grid with weapon and items."""
	# Clear existing items
	for child in boss_inventory_grid.get_children():
		child.queue_free()
	
	if not boss.inventory:
		print("[MapZoomPanel] Boss has no inventory")
		return
	
	var item_slot_scene = preload("res://Scenes/item.tscn")
	
	# Add weapon first
	if boss.inventory.weapon_slot:
		var weapon_slot = item_slot_scene.instantiate()
		weapon_slot.set_item(boss.inventory.weapon_slot)
		weapon_slot.set_weapon_text_color()
		weapon_slot.slot_index = 100  # High number for tooltip positioning
		weapon_slot.custom_minimum_size = Vector2(100, 100)
		boss_inventory_grid.add_child(weapon_slot)
	
	# Add inventory items
	for i in range(boss.inventory.item_slots.size()):
		var item = boss.inventory.item_slots[i]
		if item:
			var item_slot = item_slot_scene.instantiate()
			item_slot.set_item(item)
			item_slot.set_order(i+1)
			item_slot.custom_minimum_size = Vector2(100, 100)
			item_slot.slot_index = 100  # High number for tooltip positioning
			boss_inventory_grid.add_child(item_slot)

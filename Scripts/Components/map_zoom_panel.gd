class_name MapZoomPanel
extends Control

signal closed()
signal boss_rush_pressed()


@onready var boss_inventory_grid: GridContainer = $Panel/PanelContainer/VBoxContainer/mainContent/bossInventory/bossInventoryGrid
@onready var weapon_container: GridContainer = $Panel/PanelContainer/VBoxContainer/mainContent/bossInventory/weapon/GridContainer

@onready var boss_pic: TextureRect = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/vBoxProfile/bossPic
@onready var lbl_boss: Label = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/vBoxProfile/lblBoss
@onready var lbl_rank: Label = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/boxProfile/vBoxProfile/lblRank
@onready var boss_stat_grid: Container = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid

@onready var boss_stat_health: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statHealth
@onready var boss_stat_shield: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statShield
@onready var boss_stat_attack: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statAttack
@onready var boss_stat_agility: StatBoxDisplay = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statAgility

@onready var btn_close: Button = $Panel/PanelContainer/VBoxContainer/buttonContainer/btnClose
@onready var btn_rush: Button = $Panel/PanelContainer/VBoxContainer/buttonContainer/btnRush
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var boss_stat_strikes = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statStrikes
@onready var boss_stat_burn = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statBurnDamage
@onready var boss_stat_gold = $Panel/PanelContainer/VBoxContainer/mainContent/bossContainer/vBoxStats/bossStatGrid/statGold

## == MATCH UP SCREEN ==
@onready var lbl_fight: Label = $panelMatchup/panelTitle/MarginContainer/VBoxContainer/lblFight
@onready var player_1: TextureRect = $panelMatchup/Player1
@onready var player_2: TextureRect = $panelMatchup/Player2
@onready var lbl_player1: Label = $panelMatchup/panelTitle/MarginContainer/VBoxContainer/HBoxContainer/lblPlayer1
@onready var lbl_player2: Label = $panelMatchup/panelTitle/MarginContainer/VBoxContainer/HBoxContainer/lblPlayer2
@onready var anim_matchup: AnimationPlayer = $animFight

func _ready():
	_setup_buttons()
	visible = false

	if DungeonManager:
		DungeonManager.boss_loaded.connect(_on_boss_loaded)


func _setup_buttons():
	btn_close.pressed.connect(_on_close_pressed)
	btn_rush.pressed.connect(_on_rush_pressed)

func show_panel():
	update_display()
	visible = true
	anim_player.play("slide_in")

func hide_panel():
	anim_matchup.play("RESET")
	anim_player.play("slide_out")
	visible = false

func update_display():
	#var all_rooms = DungeonManager.all_visited_rooms
	var current_rank = DungeonManager.current_rank

	lbl_rank.text = "- Rank  " + str(current_rank) + "  Boss -"
	lbl_fight.text = "- Rank  " + str(current_rank) + "  Title  Match -"

	if current_rank == 6:
		lbl_rank.text = "- Undefeated Champion -"
		lbl_fight.text = "- Championship Match -"
		
	lbl_player1.text = Player.player_name
	_update_player_sprite()

	# Update boss info
	_update_boss_info()

func show_matchup():
	AudioManager.play_event_sound("cheering")
	anim_matchup.play("show_players")
	var anim_length = anim_matchup.get_animation("show_players").length + 1.5
	await CombatSpeed.create_timer(anim_length)
	boss_rush_pressed.emit()

func _update_boss_info():
	_update_boss_preview()
	#btn_rush.disabled = true  # Enable when boss system ready

func _on_close_pressed():
	hide_panel()
	closed.emit()

func _on_rush_pressed():
	anim_matchup.play("show_matchup")
	
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
	lbl_player2.text = boss.enemy_name

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
		player_2.texture = load(sprite_path)
	else:
		# Fallback to default or enemy sprite if boss skin doesn't exist
		if boss.sprite:
			boss_pic.texture = boss.sprite
			player_2.texture = boss.sprite
		else:
			push_warning("[MapZoomPanel] Boss sprite not found: %s" % sprite_path)

func _update_player_sprite():
	"""Load and display boss sprite based on skin_id from Supabase."""
	# Get skin_id from boss data (stored in DungeonManager.current_boss_data)
	var skin_id: int = 0
	skin_id = Player.skin_id
	
	# Load sprite
	var sprite_path = "res://Assets/Art/Player/PVP/Player_Skin_%d.png" % skin_id
	if ResourceLoader.exists(sprite_path):
		player_1.texture = load(sprite_path)


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
	boss_stat_strikes.update_stat(
		Enums.Stats.STRIKES, 
		boss.stats.strikes, 
		boss.stats.strikes
	)
	
	boss_stat_burn.update_stat(
		Enums.Stats.BURN_DAMAGE, 
		boss.stats.burn_damage, 
		boss.stats.burn_damage
	)
	
	boss_stat_gold.update_stat(
		Enums.Stats.GOLD, 
		boss.stats.gold, 
		boss.stats.gold
	)

func _update_boss_inventory(boss: Enemy):
	"""Populate boss inventory grid with weapon and items."""
	# Clear existing items
	for child in boss_inventory_grid.get_children():
		child.queue_free()
	
	for child in weapon_container.get_children():
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
		weapon_container.add_child(weapon_slot)
	
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

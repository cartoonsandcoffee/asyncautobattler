class_name MainGameController
extends Control

## Main game scene controller that manages the overall game interface
## Coordinates inventory UI, dungeon map, and room display area

signal replacement_done()

# UI Components
@onready var combat_panel: CombatPanel = $CombatPanel

@onready var room_background: TextureRect = $RoomContainer/roomPic
@onready var event_container: Node = $EventContainer

@onready var onward_button: OnwardButton = $OnwardButton
@onready var fight_or_flee: FightOrFlee = $FightFlee
@onready var pet_interface: Control = $PetItemInterface
@onready var pet_button: Control = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/boxDinglemeyer/PetButton

@onready var stat_health: Control = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/mainStatContainer/PanelContainer/VBoxContainer/HboxStats2/statHealth
@onready var stat_damage: Control = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/mainStatContainer/PanelContainer/VBoxContainer/hboxStats1/statDamage
@onready var stat_shield: Control = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/mainStatContainer/PanelContainer/VBoxContainer/hboxStats1/statShield
@onready var stat_agility: Control = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/mainStatContainer/PanelContainer/VBoxContainer/hboxStats1/statAgility
@onready var stat_gold: Control = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/mainStatContainer/PanelContainer/VBoxContainer/HboxStats2/statGold
@onready var stat_strikes: Control = $BottomPanelHolder/stackedBarContainer/rowTertiary/miscContainer/HBoxExtraStats/statStrikes
@onready var stat_burn_damage: Control = $BottomPanelHolder/stackedBarContainer/rowTertiary/miscContainer/HBoxExtraStats/statBurnDamage
@onready var stat_turns_left: Control = $BottomPanelHolder/stackedBarContainer/rowTertiary/miscContainer/HBoxExtraStats/statTurns

@onready var lbl_rank: Label = $RankLabelHolder/HBoxContainer/RankPanel/HBoxContainer/VBoxContainer/lblRank

@onready var item_grid: GridContainer = $BottomPanelHolder/stackedBarContainer/rowInventory/PanelContainer/HBoxContainer/ItemSlots
@onready var weapon_slot: ItemSlot = $BottomPanelHolder/stackedBarContainer/rowInventory/PanelContainer/HBoxContainer/Weapon
@onready var sets_grid: GridContainer = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/StatusAndSets/gridSets
@onready var status_grid: GridContainer = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/StatusAndSets/statusBox

@onready var discard_zone: PanelContainer = $DiscardZoneHolder/panelDiscard
@onready var replacement_panel: Panel = $ReplaceItemPanel
@onready var replacement_item: ItemSlot = $ReplaceItemPanel/controlReplace/PanelContainer/MarginContainer/mainContent/HBoxContainer/picHolder/MarginContainer/itemBox/ItemReplace
@onready var drop_panel: Panel = $DropItemPanel
@onready var drop_item: ItemSlot = $DropItemPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/itemBox/ItemDrop

@onready var pic_player: TextureRect = $CombatPanel/Player/picPlayer
@onready var anim_promotion: AnimationPlayer  = $animPromotion
@onready var anim_tools: AnimationPlayer = $animToolbars
@onready var anim_fade: AnimationPlayer = $animFade
@onready var fade_overlay: ColorRect = $FadeOverlay

## -- Combat Controls
@onready var box_comatspeed: VBoxContainer = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/combatSpeedBox
@onready var lbl_turn: Label = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/combatSpeedBox/lblTurn
@onready var lbl_speed: Label = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/combatSpeedBox/speedControls/lblSpeed
@onready var box_dinglemeyer: MarginContainer = $BottomPanelHolder/stackedBarContainer/rowStatsStatusCets/boxDinglemeyer

## -- Version Popup
@onready var version_popup: Control = $versionPopup
@onready var version_label: RichTextLabel = $versionPopup/PanelContainer/panelBlack/panelBorder/VBoxContainer/txtVersionMsg

@onready var crt_shader: CanvasLayer = $CRT_Shader
@onready var fog_shader: ColorRect = $Fog_Shader

@onready var check_boss_panel: MapZoomPanel = $CheckBossPanel
@onready var pause_menu: Control = $PauseMenu
@onready var settings_menu: Control = $SettingsPanel
@onready var compendium: Control = $Compendium

var current_event

var item_slot = preload("res://Scenes/item.tscn")
var set_slot = preload("res://Scenes/Elements/set_bonus_display.tscn")

var item_slots: Array[ItemSlot] = []
var current_room_data: RoomData = null

# for reordering your inventory
var dragging_instance_id: int = -1
var dragging_from_slot: int = -1
var dragging_slot: ItemSlot = null
var drag_preview: Control = null
var is_dragging: bool = false
var is_hovering_discard_zone: bool = false
var hovered_slot_during_drag: ItemSlot = null

# for combat
var awaiting_combat_result: bool = false
var combat_result_callback: Callable

# for overwriting items when your inventory is full
var pending_reward_item: Item = null
var inventory_replacement_mode: bool = false
var pending_weapon_replace: bool = false

var pending_drop_item: Item = null
var pending_drop_slot_index: int = -1

var gamecolors: GameColors

func get_combat_panel() -> CombatPanel:
	# Get reference to the combat panel for room events to use
	return combat_panel

func _ready():
	add_to_group("main_game")
	await get_tree().process_frame

	confirm_systems_initializes()
	gamecolors = GameColors.new()

	print("----- TEST PERFORMANCE MONITOR: ")
	print(Performance.get_monitor(Performance.OBJECT_COUNT))

	Player.stats.stats_updated.connect(_on_stats_updated)
	Player.inventory.item_added.connect(_on_inventory_updated)
	Player.inventory.inventory_size_changed.connect(_on_inventory_size_changed)
	#Player.status_updated.connect(_on_status_effects_updated)
	SetBonusManager.set_bonuses_updated.connect(setup_bonuses)

	onward_button.chose_camp.connect(_go_back_to_camp)
	onward_button.chose_onward.connect(_on_continue_pressed)

	fight_or_flee.chose_fight.connect(_player_chose_fight)
	fight_or_flee.chose_run.connect(_player_chose_run)

	pet_button.button_clicked.connect(pet_interface.open_popup)

	# Connect to CombatManager signals for real-time combat stat updates
	CombatManager.stat_changed.connect(_on_combat_stat_changed)
	CombatManager.combat_started.connect(_on_combat_started_for_ui)
	CombatManager.combat_ended.connect(_on_combat_ended_for_ui)
	CombatManager.item_processor.occurrence_updated.connect(_on_occurrence_updated)
	#CombatManager.combat_log_updated.connect(_on_combat_log_updated)

	# Signals to drag and drop "Replacement" items when inventory full
	replacement_item.drag_started.connect(_on_drag_started)
	replacement_item.drag_ended.connect(_on_drag_ended)

	# Version check signal
	DungeonManager.version_outdated.connect(_on_version_outdated)
	
	# Connect minimap signals
	#DungeonManager.minimap_update_requested.connect(_on_minimap_update_requested)
	#minimap.room_icon_clicked.connect(_on_minimap_room_clicked)
	#minimap.zoom_out_requested.connect(_on_zoom_out_requested)
	pause_menu.new_run_requested.connect(reset_dungeon_for_new_run)
	pause_menu.menu_closed.connect(check_crt_filter)

	combat_panel.main_game = self
	combat_panel.player_status_container = status_grid
	combat_panel.combat_completed.connect(_on_combat_completed)
	combat_panel.player_chose_run.connect(_on_player_ran)

	if pause_menu and settings_menu:
		pause_menu.settings_panel = settings_menu

	if pause_menu and compendium:
		pause_menu.compendium_panel = compendium

	# CRT SHADER SETTING
	check_crt_filter()

	# -- Add Map Zoom Panel
	check_boss_panel.closed.connect(_on_zoom_panel_closed)
	check_boss_panel.boss_rush_pressed.connect(_on_boss_rush_pressed)

	if DungeonManager.is_loaded_from_save:
		DungeonManager.is_loaded_from_save = false  
		create_test_player()
		await _ensure_player_profile()
		show_bottom_panel(true)
		load_room(DungeonManager.get_town_room())
	else:
		DungeonManager.reset()
		create_test_player()
		await _ensure_player_profile()
		load_starting_room()
		
	load_player_skin()

	#AUDIO
	var dungeon_ambient = load("res://Assets/Audio/Ambient/Ambience 01.mp3")
	AudioManager.play_ambient(dungeon_ambient, true)

	#anim_tools.play("setup_toolbars")
	set_process_input(true) # for drag preview
	#call_deferred("_debug_find_oversized_controls")
	await get_tree().process_frame
	
func _process(delta: float) -> void:
	if is_dragging:
		# Inventory slot hover highlight
		var slot_under_mouse = get_slot_under_mouse()
		if slot_under_mouse != hovered_slot_during_drag:
			if hovered_slot_during_drag:
				hovered_slot_during_drag.hide_drag_hover()
			hovered_slot_during_drag = slot_under_mouse
			if hovered_slot_during_drag and hovered_slot_during_drag != dragging_slot:
				hovered_slot_during_drag.show_drag_hover()
		
		# Discard zone hover
		if discard_zone.visible:
			var over_zone = is_over_discard_zone()
			if over_zone and not is_hovering_discard_zone:
				is_hovering_discard_zone = true
				anim_tools.play("discard_hover")
			elif not over_zone and is_hovering_discard_zone:
				is_hovering_discard_zone = false
				anim_tools.play("discard_idle")

func check_crt_filter():
	# CRT SHADER SETTING
	if GameSettings.crt_effect_enabled:
		crt_shader.visible = true
	else:
		crt_shader.visible = false

	if GameSettings.fog_enabled:
		fog_shader.visible = true
	else:
		fog_shader.visible = false

func _debug_find_oversized_controls():
	print("\n=== CHECKING FOR OVERSIZED CONTROLS ===")
	_check_control_recursive(self, 0)
	print("=== END CHECK ===\n")

func _check_control_recursive(node: Node, depth: int):
	if node is Control:
		var control = node as Control
		var pos = control.global_position
		var size = control.size
		var end_pos = pos + size
		
		# Flag anything with extreme positions or sizes
		var is_problematic = false
		var issues = []
		
		if abs(pos.x) > 5000 or abs(pos.y) > 5000:
			is_problematic = true
			issues.append("EXTREME POSITION")
		
		if size.x > 3000 or size.y > 3000:
			is_problematic = true
			issues.append("HUGE SIZE")
		
		if end_pos.x > 3000 or end_pos.y > 3000:
			is_problematic = true
			issues.append("EXTENDS FAR OFF SCREEN")
		
		if is_problematic:
			var indent = "  ".repeat(depth)
			print("%s X %s (%s)" % [indent, node.name, node.get_class()])
			print("%s   Position: %v" % [indent, pos])
			print("%s   Size: %v" % [indent, size])
			print("%s   End Position: %v" % [indent, end_pos])
			print("%s   Issues: %s" % [indent, ", ".join(issues)])
	
	# Recurse through children
	for child in node.get_children():
		_check_control_recursive(child, depth + 1)

func confirm_systems_initializes():
	if not ItemsManager._initialized:
		ItemsManager.initialize()
	if not RoomRegistry._initialized:
		RoomRegistry.initialize()
	if not DungeonManager._initialized:
		DungeonManager.initialize()
	if not SetBonusManager._initialized:
		SetBonusManager.initialize()
	if not CombatManager._initialized:
		CombatManager.initialize()

func _input(event: InputEvent):
	# Update drag preview position
	if dragging_slot and drag_preview:
		if event is InputEventMouseMotion:
			drag_preview.global_position = event.global_position - Vector2(50, 50)  # Center on mouse
			update_combiner_slot_highlights()

func create_test_player():
	ItemsManager.clear_banished_items()
	setup_inventory()
	Player.update_stats_from_items()


func load_starting_room():
	# Initialize rank 1
	await DungeonManager.initialize_rank()

	# Load starter room
	var starter_room = DungeonManager.get_starter_room()
	load_room(starter_room)

func load_room(room_data: RoomData):
	# Update background
	room_background.texture = room_data.room_definition.background_texture

	if room_data.get_rarity() == Enums.Rarity.COMMON || room_data.get_rarity() == Enums.Rarity.UNCOMMON:
		room_background.modulate = gamecolors.get_rank_color(Player.current_rank)
	else:
		room_background.modulate = room_data.room_definition.room_color

	# Clear previous event
	clear_current_event()
	
	# Load new event
	load_room_event(room_data)
	current_room_data = room_data

	# Player uses room currency
	Player.use_room()

	if !Player.is_in_town and Player.pet_carrying_item == null:
		pet_button.is_enabled(true)
	else:
		pet_button.is_enabled(false)

	# Fade transition
	anim_fade.play("fade_in")
	await anim_fade.animation_finished

	if get_tree().has_group("item_selection_events"):
		for room_event in get_tree().get_nodes_in_group("item_selection_events"):
			if room_event.has_signal("need_item_replace"):
				room_event.need_item_replace.connect(show_inventory_replacement_mode)

func show_bottom_panel(_fast:bool):
	if _fast:
		anim_tools.play("show_bottom_panel_fast")
	else:
		anim_tools.play("show_bottom_panel")
		await anim_tools.animation_finished

func load_player_skin():
	var skin_id: int = 0
	var color_hex:String = "#FFFFFF"
	
	skin_id = Player.skin_id
	color_hex = Player.skin_color.to_html()
	
	# Load sprite
	var sprite_path = "res://Assets/Art/Player/Player_Skin_%d.png" % skin_id
	if ResourceLoader.exists(sprite_path):
		pic_player.modulate = Color(color_hex)
		pic_player.texture = load(sprite_path)
	else:
		push_warning("[MainGame] Player skin sprite not found: %s" % sprite_path)	

func show_inventory_replacement_mode(new_item: Item):
	pending_reward_item = new_item
	replacement_item.set_item(new_item)
	if ItemsManager.player_has_duplicate(new_item, false):
		replacement_item.show_upgrade_anim()
	pending_weapon_replace = (new_item.item_type == Item.ItemType.WEAPON)
	show_item_replacement_overlay()

func clear_current_event():
	if current_event:
		current_event.queue_free()
		current_event = null
	
	# Clear any remaining children6
	for child in event_container.get_children():
		child.queue_free()

func load_room_event(room_data: RoomData):
	var event_scene = room_data.chosen_event_scene

	if event_scene:
		current_event = event_scene.instantiate()

		if current_event.has_method("setup"):
			current_event.setup(room_data)
		else:
			# Fallback: set directly if setup method doesn't exist
			current_event.room_data = room_data

		event_container.add_child(current_event)
		current_event.event_completed.connect(_on_event_completed)

		# Connect to combat request if the event needs it
		if current_event.has_signal("combat_requested"):
			current_event.combat_requested.connect(request_combat)
	else:
		push_error("Could not load event.")

func _on_event_completed():
	await get_tree().process_frame
	
	clear_current_event()
	show_continue_button()

	var completed_room = current_room_data  # Store this when loading room
	DungeonManager.complete_room(completed_room)

## ==========================================================
## BOSS ROOM STUFF
## ==========================================================

func _handle_boss_victory():
	# Handle rank advancement after boss victory.
	print("[MainGame] Boss defeated! Starting rank advancement sequence")
	
	# 1. Play staircase animation (comic-book panel of player ascending)
	await _play_staircase_animation()
	
	# 2. Advance rank (increases inventory, fetches new boss, generates rooms)
	DungeonManager.advance_rank()
	Player.complete_rank_boss()

	# 3. Load town for new rank
	var town_room = DungeonManager.get_town_room()
	if town_room:
		load_room(town_room)

func _handle_quit_while_ahead():
	"""Player chose to quit after rank 5 - show victory screen."""
	print("[MainGame] Player quit while ahead - showing victory screen")
	
	# Play victory animation
	await _play_staircase_animation()
	
	# Show victory stats screen (TODO: Create this UI)
	await _show_victory_screen()
	SaveManager.delete_saved_run()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _handle_challenge_champion():
	"""Player chose to challenge a champion - advance to rank 6."""
	print("[MainGame] Player challenging a champion - advancing to rank 6")
	
	# Play staircase animation
	await _play_staircase_animation()
	
	# Advance to rank 6 (champion rank)
	DungeonManager.advance_rank()
	Player.complete_rank_boss()
	
	# Load town for rank 6
	var town_room = DungeonManager.get_town_room()
	if town_room:
		load_room(town_room)

func _handle_champion_victory():
	"""Handle defeating a champion - player becomes a champion!"""
	print("[MainGame] Champion defeated! Player becomes champion")
	
	# Get the defeated champion's build ID from DungeonManager
	var defeated_champion_id = DungeonManager.current_boss_data.get("id", "")
	
	if not defeated_champion_id.is_empty():
		# Record the defeat
		await SupabaseManager.record_champion_defeat(defeated_champion_id)
		
		# Increment player's champion kill count
		var player_id = Player.load_or_generate_uuid()
		await SupabaseManager.increment_champions_killed(player_id)
	
	# Save player's build as a NEW champion
	# (This happens in boss_room_event already, but we need to ensure it's marked as champion)
	
	# Show victory animation
	await _play_staircase_animation()
	
	# Show champion victory screen
	await _show_champion_victory_screen()
	SaveManager.delete_saved_run()

	# Return to main menu
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _show_champion_victory_screen():
	"""Show special victory screen for becoming a champion."""
	# TODO: Create a special champion victory UI
	print("[MainGame] CHAMPION VICTORY!")
	print("  - You are now a champion!")
	print("  - Your build will defend your honor")
	print("  - Earn ears when your champion wins")
	
	await get_tree().create_timer(3.0).timeout

func _show_victory_screen():
	"""Show victory stats screen after quitting at rank 5."""
	# TODO: Create a proper victory screen UI
	# For now, just a brief message
	print("[MainGame] VICTORY!")
	print("  - Run complete!")
	print("  - Ears earned: Check profile")
	print("  - Returning to menu...")
	
	await get_tree().create_timer(2.0).timeout

func _play_staircase_animation():
	if anim_promotion:
		print("[MainGame] Playing staircase animation")
		anim_promotion.play("ascend_stairs")
		await anim_promotion.animation_finished
	else:
		# No animation - brief delay for testing
		print("[MainGame] No staircase animation - using brief delay")
		await get_tree().create_timer(1.5).timeout

func boss_room_completed(_choice: String):
	if _choice == "continue":
		await _handle_boss_victory()
	elif _choice == "end":
		await _handle_quit_while_ahead()
	elif _choice == "challenge":
		await _handle_challenge_champion()
	elif _choice == "final":
		await _handle_champion_victory()

func _on_continue_pressed():
	# Get random dungeon room
	onward_button.reset_anims()

	var next_room = DungeonManager.get_random_dungeon_room()

	if not Player.has_rooms_remaining():
		next_room = DungeonManager.get_town_room()

	if next_room:
#		# Fade transition
		anim_fade.play("fade_out_retry")
		await anim_fade.animation_finished

		var cp = get_tree().get_first_node_in_group("combat_panel")
		if cp:
			cp.slide_animation.play("RESET")
			cp.enemy_anim.play("RESET")

		load_room(next_room)
		#fade_overlay.visible = false
	else:
		push_error("No next room found!")


func show_continue_button():
	if inventory_replacement_mode:
		await replacement_done
	
	var clr: Color = Color.WHITE

	if current_room_data:
		if current_room_data.get_rarity() == Enums.Rarity.COMMON || current_room_data.get_rarity() == Enums.Rarity.UNCOMMON:
			clr = gamecolors.get_rank_color(Player.current_rank)
		else:
			clr = current_room_data.room_definition.room_color

	onward_button.show_popup(clr)


func play_combat_alert_arrow():
	anim_tools.play("combat_arrow")

func arrow_sfx():
	AudioManager.play_ui_sound("combat_player_hit_heavy")

func set_player_stats():
	if CombatManager.combat_active:
		# During combat: show current/max for HP, current only for others
		stat_health.update_stat(Enums.Stats.HITPOINTS, Player.stats.hit_points_current, Player.stats.hit_points)

		# Check for blind on damage display
		var displayed_damage = Player.stats.damage_current
		stat_damage.update_stat(Enums.Stats.DAMAGE, displayed_damage, Player.stats.damage)
				
		stat_shield.update_stat(Enums.Stats.SHIELD, Player.stats.shield_current, Player.stats.shield)
		stat_agility.update_stat(Enums.Stats.AGILITY, Player.stats.agility_current, Player.stats.agility)
		stat_burn_damage.update_stat(Enums.Stats.BURN_DAMAGE, Player.stats.burn_damage_current, Player.stats.burn_damage, Player.inventory.has_keyword("Burn"))
		stat_strikes.update_stat(Enums.Stats.STRIKES, Player.stats.strikes_left, Player.stats.strikes_next_turn, Player.inventory.has_keyword("Strikes"))
	else:
		# During exploration: show current/max for HP, base values for others
		# (since stats reset to base between combats)
		stat_health.update_stat(Enums.Stats.HITPOINTS, Player.stats.hit_points_current, Player.stats.hit_points)
		stat_damage.update_stat(Enums.Stats.DAMAGE, Player.stats.damage, Player.stats.damage)  # Show base as both current and max
		stat_shield.update_stat(Enums.Stats.SHIELD, Player.stats.shield, Player.stats.shield)
		stat_agility.update_stat(Enums.Stats.AGILITY, Player.stats.agility, Player.stats.agility)
		stat_strikes.update_stat(Enums.Stats.STRIKES, Player.stats.strikes, Player.stats.strikes, Player.inventory.has_keyword("Strikes"))
		stat_burn_damage.update_stat(Enums.Stats.BURN_DAMAGE, Player.stats.burn_damage, Player.stats.burn_damage, Player.inventory.has_keyword("Burn"))
	
	# Gold always shows current amount (no max)
	stat_gold.update_stat(Enums.Stats.GOLD, Player.stats.gold, Player.stats.gold)
	stat_turns_left.update_stat(Enums.Stats.TURNS_LEFT, Player.rooms_left_this_rank, Player.rooms_left_this_rank)

	lbl_rank.text = "Rank " + str(Player.current_rank) 

func _on_inventory_size_changed(_new_size: int):
	setup_inventory()

func setup_inventory():
	item_slots.clear()
	item_slots.resize(Player.inventory.TOTAL_SLOTS)
	item_grid.columns = Player.inventory.TOTAL_SLOTS
	setup_weapon()

	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()

	for i in range(Player.inventory.TOTAL_SLOTS):
		var item = Player.inventory.item_slots[i]
		var item_container = item_slot.instantiate()

		item_container.owner_entity = Player
		item_container.set_item(item)
		item_container.custom_minimum_size = Vector2(110, 115)
		item_container.slot_index = i
		item_container.set_order(i + 1)  # Display 1-based index
		
		var is_locked = i >= Player.inventory.unlocked_slots
		item_container.set_locked(is_locked)

		item_container.drag_started.connect(_on_drag_started)
		item_container.drag_ended.connect(_on_drag_ended)
		item_container.slot_dropped_on.connect(_on_slot_dropped_on)

		item_slots[i] = (item_container)
		item_grid.add_child(item_container)
	
	SetBonusManager.check_set_bonuses(Player)
	_reapply_crafting_slot_dims()

func setup_bonuses(entity):
	if not (entity == Player):
		return

	sets_grid.columns = 6

	for child in sets_grid.get_children():
		sets_grid.remove_child(child)
		child.queue_free()

	for bonus_item in SetBonusManager.get_active_set_bonuses(Player):
		var set_container = set_slot.instantiate()

		set_container.set_bonus(bonus_item)
		set_container.custom_minimum_size = Vector2(100, 100)

		sets_grid.add_child(set_container)


func show_item_replacement_overlay():
	anim_tools.play("show_replace_item")
	inventory_replacement_mode = true
	replacement_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func hide_item_replacement_overlay():
	pending_weapon_replace = false
	pending_reward_item = null
	anim_tools.play("hide_replace_item")
	inventory_replacement_mode = false
	replacement_done.emit()
	replacement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_item_drop_overlay():
	anim_tools.play("show_drop_item")
	drop_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func hide_item_drop_overlay():
	pending_drop_item = null
	pending_drop_slot_index = -1
	anim_tools.play("hide_drop_item")
	drop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func loop_through_player_items_for_position(item: Item) -> Vector2:
	var offset: Vector2 = Vector2(45,-50)

	if !item:
		return Vector2(0,0)

	if item == Player.inventory.weapon_slot:
		return weapon_slot.global_position + offset

	for i in range(Player.inventory.item_slots.size()):
		if item == Player.inventory.item_slots[i]:
			return item_grid.get_child(i).global_position + offset
	
	return Vector2(422,262)


func setup_weapon():
	weapon_slot.owner_entity = Player
	weapon_slot.set_item(Player.inventory.weapon_slot)

	if not weapon_slot.drag_started.is_connected(_on_drag_started):
		weapon_slot.drag_started.connect(_on_drag_started)
	if not weapon_slot.drag_ended.is_connected(_on_weapon_drag_ended):
		weapon_slot.drag_ended.connect(_on_weapon_drag_ended)	
		

func _on_stats_updated():
	set_player_stats()

func _on_inventory_updated(item: Item, slot: int):
	setup_inventory()


func _on_drag_started(slot: ItemSlot):
	if not slot.current_item:
		return
	
	dragging_slot = slot
	is_dragging = true
	
	# Create drag preview
	create_drag_preview(slot.current_item)
	
	# Optional: Hide tooltip while dragging
	TooltipManager.hide_tooltip()

	# show discard zone if item is discardable
	if not inventory_replacement_mode and get_current_item_combiner() == null and not pet_interface.visible and slot.current_item.item_type != Item.ItemType.WEAPON and not slot.current_item.has_category("Non-discardable"):
		anim_tools.play("show_discard")

func _on_drag_ended(slot: ItemSlot):
	## ---- JDM: All the functionality for the different places items can be dropped

	## -- DROPPING ON THE DISCARD ZONE
	if not inventory_replacement_mode and is_over_discard_zone() and slot.current_item and not pet_interface.visible and slot.current_item.item_type != Item.ItemType.WEAPON and not slot.current_item.has_category("Non-discardable"):
		Player.inventory.remove_item(slot.slot_index)
		#Player.inventory.compact_items()
		setup_inventory()
		Player.update_stats_from_items()
		clear_dragging_vars()
		slot.modulate.a = 1.0
		return

	## -- DROPPING INTO AN ITEM COMBINER
	var combiner = get_current_item_combiner()
	if combiner:
		var target_slot = get_combiner_slot_under_mouse(combiner)
		if target_slot > 0:
			slot.is_in_crafting_slot = true
			# Add item to combiner slot
			await combiner.add_item_to_slot(slot.current_item, target_slot)
			if slot.is_in_crafting_slot:
				var was_accepted = slot.current_item.instance_id == combiner.slot_1_instance_id or \
								slot.current_item.instance_id == combiner.slot_2_instance_id
				if was_accepted:
					slot.modulate.a = 0.4
					slot.button.disabled = true
				else:
					slot.is_in_crafting_slot = false  # early return path, restore
					slot.modulate.a = 1.0
					slot.button.disabled = false
			clear_dragging_vars()
			return  # Don't process normal inventory drop

	## -- DRAG AND DROP FROM REPLACEMENT MODAL
	if inventory_replacement_mode and dragging_slot == replacement_item:
		if pending_weapon_replace:
			if weapon_slot.get_global_rect().has_point(get_global_mouse_position()):
				Player.inventory.set_weapon(pending_reward_item)
				Player.update_stats_from_items()
				AudioManager.play_ui_sound("item_pickup")
				setup_weapon()
				hide_item_replacement_overlay()
		else:
			var target_slot = get_slot_under_mouse()
			if target_slot and not target_slot.is_locked:
				Player.inventory.replace_item_at_slot(pending_reward_item, target_slot.slot_index)
				setup_inventory()
				Player.update_stats_from_items()
				hide_item_replacement_overlay()
		clear_dragging_vars()
		return  # Don't process normal inventory drop

	## -- DROPPING INVENTORY ITEM ONTO PET SLOT
	if is_over_pet_slot() and slot.current_item:
		var inv_item = slot.current_item
		var pet_item = Player.pet_carrying_item

		if pet_item != null:
			# Swap: pet item goes to the vacated inventory slot
			Player.inventory.item_slots[slot.slot_index] = pet_item
		else:
			Player.inventory.remove_item(slot.slot_index)

		Player.pet_carrying_item = inv_item
		setup_inventory()
		Player.update_stats_from_items()
		pet_interface.refresh()
		AudioManager.play_ui_sound("item_pickup")
		clear_dragging_vars()
		slot.modulate.a = 1.0
		return

	## -- NORAML INVENTORY REORDERING
	# Find what slot we're over
	var _target_slot = get_slot_under_mouse()
	
	if _target_slot and _target_slot != slot:
		# Perform the swap or move
		perform_item_move(slot, _target_slot)

	clear_dragging_vars()
	slot.modulate.a = 1.0
	
## -- DRAGGING FROM PET SLOT TO INVENTORY
func _on_pet_slot_drag_ended(slot: ItemSlot):
	var target_slot = get_slot_under_mouse()
	if target_slot == null or target_slot.is_locked:
		# No valid target — item stays with pet, nothing changes
		clear_dragging_vars()
		slot.modulate.a = 1.0
		return

	var pet_item = Player.pet_carrying_item
	var inv_item = Player.inventory.item_slots[target_slot.slot_index]

	if inv_item != null:
		# Swap: inventory item goes to pet, pet item goes to inventory slot
		Player.inventory.item_slots[target_slot.slot_index] = pet_item
		Player.pet_carrying_item = inv_item
	else:
		# Empty slot: just move pet item into inventory
		Player.inventory.item_slots[target_slot.slot_index] = pet_item
		Player.pet_carrying_item = null

	setup_inventory()
	Player.update_stats_from_items()
	pet_interface.refresh()
	AudioManager.play_ui_sound("item_pickup")
	clear_dragging_vars()
	slot.modulate.a = 1.0

func _on_weapon_drag_ended(slot: ItemSlot):
	# Only allow weapon dragging to crafting combiner, NOT to inventory slots
	var combiner = get_current_item_combiner()
	if combiner:
		var target_slot = get_combiner_slot_under_mouse(combiner)
		if target_slot > 0:
			slot.is_in_crafting_slot = true
			# Add weapon to combiner slot
			combiner.add_item_to_slot(slot.current_item, target_slot)
			if slot.is_in_crafting_slot:
				var was_accepted = slot.current_item.instance_id == combiner.slot_1_instance_id or \
								slot.current_item.instance_id == combiner.slot_2_instance_id
				if was_accepted:
					slot.modulate.a = 0.4
					slot.button.disabled = true
				else:
					slot.is_in_crafting_slot = false  # early return path, restore
					slot.modulate.a = 1.0
					slot.button.disabled = false
				clear_dragging_vars()
			return
	
	# If not over combiner, do nothing (weapon stays in weapon slot)
	clear_dragging_vars()
	slot.modulate.a = 1.0

func clear_dragging_vars():
	if discard_zone.visible:
		anim_tools.play("hide_discard")

	# Clean up drag state
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_slot = null
	is_dragging = false
	
	if hovered_slot_during_drag:
		hovered_slot_during_drag.hide_drag_hover()
		hovered_slot_during_drag = null
	is_hovering_discard_zone = false

func discard_idle_anim():
	anim_tools.play("discard_idle")

func _on_slot_dropped_on(target_slot: ItemSlot, dragged_item: Item):
	if target_slot.is_locked:
		return
	if dragging_slot and dragging_slot != target_slot:
		perform_item_move(dragging_slot, target_slot)

func perform_item_move(from_slot: ItemSlot, to_slot: ItemSlot):
	var from_index = from_slot.slot_index
	var to_index = to_slot.slot_index
	
	if to_slot.is_locked:
		return

	## --------- JDM: This is the code for swapping item positions,
	## If moving to empty slot, just move
	#if not to_slot.current_item:
	#	Player.inventory.move_item_to_slot(from_index, to_index)
	#else:
	#	# Swap items
	#	Player.inventory.swap_items(from_index, to_index)
	
	## Compact to remove gaps
	#Player.inventory.compact_items()
	
	# JDM: New code to just insert item and move all items left.
	if not to_slot.current_item:
		Player.inventory.move_item_to_slot(from_index, to_index)
	else:
		# Swap items
		Player.inventory.insert_item_at(from_index, to_index)

	# Refresh display
	setup_inventory()
	Player.update_stats_from_items()

func get_slot_under_mouse() -> ItemSlot:
	var mouse_pos = get_global_mouse_position()
	for slot in item_slots:
		if slot and slot.get_global_rect().has_point(mouse_pos):
			return slot
	return null

func is_over_pet_slot() -> bool:
	if pet_interface == null or not pet_interface.visible:
		return false
	return pet_interface.item_slot.get_global_rect().has_point(get_global_mouse_position())

func get_current_item_combiner() -> ItemCombiner:
	# Get the ItemCombiner from current event if it exists
	#if current_event and current_event.has_node("ItemCombiner"):
	#	return current_event.get_node("ItemCombiner")
	#return null
	if current_event:
		var combiners = current_event.get_tree().get_nodes_in_group("item_combiner")
		for node in combiners:
			if node.visible == false:
				continue
			# Check if this combiner is a child of current_event
			if node.is_ancestor_of(current_event) or current_event.is_ancestor_of(node):
				return node
	return null	

func _reapply_crafting_slot_dims():
	var combiner = get_current_item_combiner()
	if not combiner:
		return
	for slot in item_slots:
		if slot == null:
			continue
		if slot.current_item and (slot.current_item.instance_id == combiner.slot_1_instance_id or slot.current_item.instance_id == combiner.slot_2_instance_id):
			slot.is_in_crafting_slot = true
			slot.modulate.a = 0.4
			slot.button.disabled = true

	# Check weapon slot
	if weapon_slot and weapon_slot.current_item and (weapon_slot.current_item.instance_id == combiner.slot_1_instance_id or weapon_slot.current_item.instance_id == combiner.slot_2_instance_id):
		weapon_slot.is_in_crafting_slot = true
		weapon_slot.modulate.a = 0.4
		weapon_slot.button.disabled = true

func get_combiner_slot_under_mouse(combiner: ItemCombiner) -> int:
	# Check which combiner slot (1 or 2) the mouse is over, or 0 if neither
	var mouse_pos = get_global_mouse_position()
	
	if combiner.craft_slot_1.get_global_rect().has_point(mouse_pos):
		return 1
	elif combiner.craft_slot_2.get_global_rect().has_point(mouse_pos):
		return 2
	
	return 0

func update_combiner_slot_highlights():
	# Highlight combiner slots when dragging items over them 
	var combiner = get_current_item_combiner()
	if not combiner:
		return
	
	var slot_num = get_combiner_slot_under_mouse(combiner)
	
	# Reset both slots
	combiner.craft_slot_1.modulate = Color.WHITE
	combiner.craft_slot_2.modulate = Color.WHITE
	
	# Highlight the hovered slot
	if slot_num == 1:
		combiner.craft_slot_1.modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint
	elif slot_num == 2:
		combiner.craft_slot_2.modulate = Color(1.2, 1.2, 1.0)

func create_drag_preview(item: Item):
	if drag_preview:
		drag_preview.queue_free()
	
	drag_preview = Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.size = Vector2(100, 100)
	drag_preview.z_index = 100
	drag_preview.z_as_relative = false

	var icon = TextureRect.new()
	icon.texture = item.item_icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(100, 100)
	icon.modulate = item.item_color
	icon.modulate.a = 0.8
	
	drag_preview.add_child(icon)
	get_tree().root.add_child(drag_preview)

func _show_panels():
	pass
	#anim_tools.play("setup_toolbars")


func request_combat(enemy: Enemy) -> bool:
	# Called by room events to initiate combat. Returns true if player won, false if lost or ran

	print("main_game -> request combat")
	
	if not combat_panel:
		push_error("No combat panel found!")
		return false
	
	if not enemy:
		push_error("No enemy provided for combat!")
		return false
	
	# Show combat encounter
	combat_panel.setup_for_combat(enemy, item_slots, weapon_slot)
	
	# Wait for combat to complete
	awaiting_combat_result = true
	var result = await combat_panel.combat_completed
	awaiting_combat_result = false
	
	return result  # Returns true if player won, false otherwise

func _on_combat_completed(player_won: bool):
	# Update player stats display
	Player.stats.reset_stats_after_combat()
	set_player_stats()
	
	# The combat panel has already slid out at this point
	print("Combat completed. Player won: ", player_won)

func _on_player_ran():
	print("Player ran from combat")
	# The combat panel will emit combat_completed(false) after sliding out


func _on_btn_cancel_replace_pressed() -> void:
	hide_item_replacement_overlay()


func is_in_replacement_mode() -> bool:
	return inventory_replacement_mode

# Track when combat starts/ends for proper stat display
func _on_combat_started_for_ui(player, enemy):
	set_player_stats()  # Refresh to show current values
	pet_button.is_enabled(false)
	AudioManager.on_combat_started(enemy.enemy_type == Enemy.EnemyType.BOSS_PLAYER, enemy)	

func _on_combat_ended_for_ui(winner, loser):
	# Stats will reset to base values, so refresh display
	await get_tree().process_frame  # Wait for stats to reset
	set_player_stats()
	AudioManager.on_combat_ended()
	
	if !Player.is_in_town and Player.pet_carrying_item == null:
		pet_button.is_enabled(true)

	# Reset all countdown displays
	for slot in item_slots:
		if slot.current_item and slot.current_item.trigger_on_occurrence_number > 0:
			slot.update_countdown_display(slot.current_item.trigger_on_occurrence_number)
	
	if weapon_slot.current_item and weapon_slot.current_item.trigger_on_occurrence_number > 0:
		weapon_slot.update_countdown_display(weapon_slot.current_item.trigger_on_occurrence_number)

func _on_combat_stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int):
	# Only update if the change affects the player
	if entity == Player:
		# Update the specific stat that changed
		match stat:
			Enums.Stats.HITPOINTS:
				stat_health.update_stat(Enums.Stats.HITPOINTS, 
					Player.stats.hit_points_current, 
					Player.stats.hit_points)
			Enums.Stats.DAMAGE:
				stat_damage.update_stat(Enums.Stats.DAMAGE, 
					Player.stats.damage_current, 
					Player.stats.damage)
			Enums.Stats.SHIELD:
				stat_shield.update_stat(Enums.Stats.SHIELD, 
					Player.stats.shield_current, 
					Player.stats.shield)
			Enums.Stats.AGILITY:
				stat_agility.update_stat(Enums.Stats.AGILITY, 
					Player.stats.agility_current, 
					Player.stats.agility)
			Enums.Stats.GOLD:
				stat_gold.update_stat(Enums.Stats.GOLD, 
					Player.stats.gold, 
					Player.stats.gold)
			Enums.Stats.STRIKES:
				stat_strikes.update_stat(Enums.Stats.STRIKES, 
					Player.stats.strikes_left,
					Player.stats.strikes_next_turn)
			Enums.Stats.BURN_DAMAGE:
				stat_burn_damage.update_stat(Enums.Stats.BURN_DAMAGE, 
					Player.stats.burn_damage_current, 
					Player.stats.burn_damage)

func _on_occurrence_updated(entity, item: Item, trigger_type: Enums.TriggerType, current_count: int, remaining: int):
	# Only update if it's the player's item
	if entity != Player:
		return
	
	# Find the item slot that has this item
	for slot in item_slots:
		if slot.current_item and slot.current_item.instance_id == item.instance_id:
			slot.update_countdown_display(remaining)
			return
	
	# Check weapon slot
	if weapon_slot.current_item and weapon_slot.current_item.instance_id == item.instance_id:
		weapon_slot.update_countdown_display(remaining)

func _on_minimap_update_requested():
	# Update minimap display when rooms change
	#minimap.current_rank = DungeonManager.current_rank
	#minimap.update_display()
	pass

func _on_minimap_room_clicked(room_index: int):
	# Boss room clicked (room index 5)
	if room_index == 5:
		show_boss_panel()

func _on_zoom_panel_closed():
	check_boss_panel.visible = false
	Player.popup_open = false

func _on_boss_rush_pressed():
	anim_fade.play("fade_out_retry")
	await anim_fade.animation_finished
	
	if combat_panel:
		combat_panel.slide_animation.play("RESET")
		combat_panel.player_anim.play("RESET")
		combat_panel.enemy_anim.play("RESET")

	onward_button.reset_anims()
	check_boss_panel.hide_panel()
	_on_zoom_panel_closed()

	var boss_room = DungeonManager.get_boss_room()
	load_room(boss_room)

func show_boss_panel():
	# Placeholder for boss room panel
	print("Boss room clicked - panel coming soon")
	# TODO: Create and show boss info panel with "Rush" button

func _ensure_player_profile():
	#Create player profile if it doesn't exist.
	# JDM: Move this to the main menu scene to avoid that weird delay at game start

	var player_id = Player.load_or_generate_uuid()
	var username = Player.player_name 
	
	print("[Game] Ensuring player profile exists...")
	var profile = await SupabaseManager.get_or_create_player(player_id, username)
	
	if profile.is_empty():
		push_warning("[Game] Failed to create player profile!")
	else:
		print("[Game] - Player profile ready: %s" % profile.get("username"))

## === AUDIO FUNCTIONS
func play_popup_open_sfx():
	AudioManager.play_synced_sound("popup_open")

func play_popup_close_sfx():
	AudioManager.play_synced_sound("popup_close")

## =============================================================================
## RESET FUNCTIONS
## =============================================================================

func reset_player_for_new_run():
	"""Reset player to starting state for new run."""
	print("[MainGame] Resetting player state...")
	
	Player.new_run(Player.player_name)

	# Reset inventory size to starting value (4 slots)
	#Player.inventory.set_inventory_size(4)
	
	# Clear all items from inventory
	#Player.inventory.clear_all_items()
	
	# Reset stats to base values
	#Player.stats.reset_base_stats()
	#Player.stats.reset_to_base_values()

	# Clear status effects
	#if Player.status_effects:
	#	Player.status_effects.clear_all_statuses()
	
	# Reset gold (if you have it)
	#if Player.stats.has("gold"):
	#	Player.stats.gold = 0
	#	Player.stats.gold_current = 0
	
	# Keep player UUID and username (same account)
	# Don't reset: Player.player_uuid, Player.username
	
	print("[MainGame] Player reset complete")

func reset_dungeon_for_new_run():
	"""Reset dungeon manager to rank 1."""
	print("[MainGame] Resetting dungeon state...")
	
	await reset_player_for_new_run()
	anim_fade.play("RESET")
	anim_tools.play("RESET")

	var new_run_scene = preload("res://Scenes/main_game.tscn")

	get_tree().change_scene_to_packed(new_run_scene)
	
func fade_out():
	anim_fade.play("fade_out_retry")
	await anim_fade.animation_finished

func screen_shake(intensity: float = 10.0, duration: float = 0.5):
	"""Shake the entire UI root instead of camera."""
	var ui_root = get_node(".")  # Your main UI container
	
	if not ui_root:
		return
	
	var original_position = ui_root.position
	var shake_tween = create_tween()
	
	# Shake effect
	var shake_count = int(duration * 60)  # 60 fps
	for i in shake_count:
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(ui_root, "position", original_position + offset, 0.016)
	
	# Return to original position
	shake_tween.tween_property(ui_root, "position", original_position, 0.1)


func _on_btn_cancel_replace_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")


func _on_btn_town_pressed() -> void:
	fade_out()
	_go_back_to_camp()

func _go_back_to_camp() -> void:
	onward_button.reset_anims()
	var town_room = DungeonManager.get_town_room()
	if town_room:
		load_room(town_room)

func _on_version_outdated(latest_version: String):
	# Show popup when client is outdated.
	print("[MainGame] Version outdated! Latest: %s, Current: %s" % [latest_version, Player.GAME_VERSION])
	
	# Show popup (use your existing popup system)
	var popup_text = "A newer version (v%s) is available!\nYou are running version %s.\n\nPlease update to ensure the best experience." % [latest_version, Player.GAME_VERSION]
	
	version_popup.visible = true
	version_label.text = popup_text

func _on_btn_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_btn_menu_pressed() -> void:
	pause_menu.show_pause_menu()

func is_over_discard_zone() -> bool:
	return discard_zone.visible and discard_zone.get_global_rect().has_point(get_global_mouse_position())

func _on_btn_zoom_pressed() -> void:
	if current_event is BossRoomEvent:
		return
	if !Player.popup_open || Player.is_in_town:
		check_boss_panel.visible = true
		check_boss_panel.show_panel()

func _player_chose_run():
	# Emit signal for room event
	combat_panel.player_chose_run.emit()
	
	# Slide out
	combat_panel.hide_panel()
	
	# Complete without combat
	combat_panel.combat_completed.emit(false)

func _player_chose_fight():
	combat_panel.setup_fight()
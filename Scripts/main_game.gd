class_name MainGameController
extends Control

## Main game scene controller that manages the overall game interface
## Coordinates inventory UI, dungeon map, and room display area

# UI Components
#@onready var dungeon_map_panel: Panel = $TopPanel
@onready var inventory_panel: Panel = $BottomPanel
@onready var combat_panel: CombatPanel = $CombatPanel

@onready var room_background: TextureRect = $RoomContainer/roomPic
@onready var event_container: Node = $EventContainer
@onready var door_container: HBoxContainer = $DoorContainer/HBoxContainer
@onready var btn_continue: Button = $DoorContainer/btnContinue

@onready var stat_health: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statHealth
@onready var stat_damage: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statDamage
@onready var stat_shield: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statShield
@onready var stat_agility: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statAgility
@onready var stat_gold: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statGold

@onready var item_grid: GridContainer = $BottomPanel/MarginContainer/VBoxContainer/HBoxContainer/InventorySlots/ItemSlots
@onready var weapon_slot: ItemSlot = $BottomPanel/MarginContainer/VBoxContainer/HBoxContainer/Weapon
@onready var sets_grid: GridContainer = $BottomPanel/panelSets/gridSets

@onready var replacement_panel: Panel = $ReplaceItemPanel
@onready var replacement_item: ItemSlot = $ReplaceItemPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/itemBox/ItemReplace
@onready var drop_panel: Panel = $DropItemPanel
@onready var drop_item: ItemSlot = $DropItemPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/itemBox/ItemDrop

@onready var anim_promotion: AnimationPlayer  = $animPromotion
@onready var anim_tools: AnimationPlayer = $animToolbars
@onready var anim_fade: AnimationPlayer = $animFade
@onready var fade_overlay: ColorRect = $FadeOverlay

@onready var crt_shader: CanvasLayer = $CRT_Shader

# Mini-map stuff
@onready var minimap: Minimap = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/boxMiniMap

@onready var pause_menu: Control = $PauseMenu
@onready var settings_menu: Control = $SettingsPanel

var current_event

var item_slot = preload("res://Scenes/item.tscn")
var item_proc = preload("res://Scenes/Elements/combat_item_proc.tscn")
var door_choice_scene = preload("res://Scenes/door_choice.tscn")

var item_slots: Array[ItemSlot] = []

# for reordering your inventory
var dragging_instance_id: int = -1
var dragging_from_slot: int = -1
var dragging_slot: ItemSlot = null
var drag_preview: Control = null
var is_dragging: bool = false

# for combat
var awaiting_combat_result: bool = false
var combat_result_callback: Callable

# for overwriting items when your inventory is full
var pending_reward_item: Item = null
var inventory_replacement_mode: bool = false

var pending_drop_item: Item = null
var pending_drop_slot_index: int = -1

var is_in_combat: bool = false

# -- Full map screen
var zoom_panel_scene = preload("res://Scenes/Elements/map_zoom_panel.tscn")
var zoom_panel: MapZoomPanel 

func get_combat_panel() -> CombatPanel:
	# Get reference to the combat panel for room events to use
	return combat_panel

func _ready():
	add_to_group("main_game")
	Player.stats.stats_updated.connect(_on_stats_updated)
	Player.inventory.item_added.connect(_on_inventory_updated)
	#Player.status_updated.connect(_on_status_effects_updated)
	SetBonusManager.set_bonuses_updated.connect(setup_bonuses)

	DungeonManager.show_minimap.connect(_show_panels)

	# Connect to CombatManager signals for real-time combat stat updates
	CombatManager.stat_changed.connect(_on_combat_stat_changed)
	CombatManager.combat_started.connect(_on_combat_started_for_ui)
	CombatManager.combat_ended.connect(_on_combat_ended_for_ui)

	# Connect minimap signals
	DungeonManager.minimap_update_requested.connect(_on_minimap_update_requested)
	minimap.room_icon_clicked.connect(_on_minimap_room_clicked)
	minimap.zoom_out_requested.connect(_on_zoom_out_requested)

	combat_panel.main_game = self
	combat_panel.combat_completed.connect(_on_combat_completed)
	combat_panel.player_chose_run.connect(_on_player_ran)

	if pause_menu and settings_menu:
		pause_menu.settings_panel = settings_menu

	if btn_continue:
		btn_continue.pressed.connect(_on_continue_pressed)
		btn_continue.disabled = true
		btn_continue.visible = false 

	# CRT SHADER SETTING
	if GameSettings.crt_effect_enabled:
		crt_shader.visible = true
	else:
		crt_shader.visible = false

	# -- Add Map Zoom Panel
	zoom_panel = MapZoomPanel.new()
	zoom_panel = zoom_panel_scene.instantiate()
	add_child(zoom_panel)
	zoom_panel.closed.connect(_on_zoom_panel_closed)
	zoom_panel.boss_rush_pressed.connect(_on_boss_rush_pressed)

	create_test_player()
	await _ensure_player_profile()

	load_starting_room()

	#AUDIO
	var dungeon_ambient = load("res://Assets/Audio/Music/Ambience 01.mp3")
	AudioManager.play_ambient(dungeon_ambient, true)

	set_process_input(true) # for drag preview
	
func _input(event: InputEvent):
	# Update drag preview position
	if dragging_slot and drag_preview:
		if event is InputEventMouseMotion:
			drag_preview.global_position = event.global_position - Vector2(50, 50)  # Center on mouse
			update_combiner_slot_highlights()

func create_test_player():
	setup_inventory()
	Player.update_stats_from_items()


func load_starting_room():
	var starter_room_data = DungeonManager.generate_starter_room()
	if starter_room_data:
		#DungeonManager.all_visited_rooms.append(starter_room_data)
		DungeonManager.minimap_update_requested.emit()
		
		await load_room(starter_room_data)
	else:
		push_error("Failed to generate starter room!")

func load_room(room_data: RoomData):
	# Update background
	room_background.texture = room_data.room_definition.background_texture
	room_background.modulate = room_data.room_definition.room_color

	# Clear previous event
	clear_current_event()
	
	# Load new event
	load_room_event(room_data)

	# Fade transition
	anim_fade.play("fade_in")
	var anim_length = anim_fade.get_animation("fade_in").length
	await CombatSpeed.create_timer(anim_length)

	if get_tree().has_group("item_selection_events"):
		for room_event in get_tree().get_nodes_in_group("item_selection_events"):
			if room_event.has_signal("need_item_replace"):
				room_event.need_item_replace.connect(show_inventory_replacement_mode)


func show_inventory_replacement_mode(new_item: Item):
	pending_reward_item = new_item
	replacement_item.set_item(new_item)
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

	# Check for shortcuts
	var completed_room = DungeonManager.current_rank_rooms[DungeonManager.current_room_index]
	var shortcuts = DungeonManager.check_for_shortcuts(completed_room)
	
	if shortcuts.size() > 0:
		# Show doors (normal + shortcuts)
		show_doors_with_shortcuts(shortcuts)

func _handle_boss_victory():
	# Handle rank advancement after boss victory.
	print("[MainGame] Boss defeated! Starting rank advancement sequence")
	
	# 1. Play staircase animation (comic-book panel of player ascending)
	await _play_staircase_animation()
	
	# 2. Advance rank (increases inventory, fetches new boss, generates rooms)
	DungeonManager.advance_rank()
	
	# 3. Load first room of new rank
	var first_room = DungeonManager.get_current_room()
	if first_room:
		print("[MainGame] Loading first room of rank %d" % DungeonManager.current_rank)
		
		# Fade transition
		anim_fade.play("fade_out")
		var anim_length = anim_fade.get_animation("fade_out").length
		await CombatSpeed.create_timer(anim_length)
		
		load_room(first_room)
		fade_overlay.visible = false
	else:
		push_error("[MainGame] Failed to load first room of new rank!")

func _play_staircase_animation():
	if anim_promotion:
		print("[MainGame] Playing staircase animation")
		anim_promotion.play("ascend_stairs")
		await anim_promotion.animation_finished
	else:
		# No animation - brief delay for testing
		print("[MainGame] No staircase animation - using brief delay")
		await get_tree().create_timer(1.5).timeout

func _on_continue_pressed():
	hide_continue_button()

	# Check if we just completed a boss room
	var current_room = DungeonManager.current_rank_rooms[DungeonManager.current_room_index]
	var is_boss_room = false
	
	if current_room and current_room.room_definition:
		is_boss_room = current_room.room_definition.room_type == Enums.RoomType.BOSS
	
	if is_boss_room:
		# Boss victory - play staircase animation and advance rank
		await _handle_boss_victory()
		return

	# Advance to next room in sequence
	DungeonManager.all_visited_rooms.append(current_room)
	DungeonManager.advance_room()
	
	# Check if rank is complete
	if DungeonManager.rooms_cleared_this_rank >= DungeonManager.ROOMS_PER_RANK:
		# TODO: Trigger boss fight
		print("Rank complete! Boss fight would trigger here.")
		# For now, just advance rank
		DungeonManager.advance_rank()
		return
	
	# Get next room and load it
	var next_room = DungeonManager.get_current_room()
	if next_room:
		# Fade transition
		anim_fade.play("fade_out")
		var anim_length = anim_fade.get_animation("fade_out").length
		await CombatSpeed.create_timer(anim_length)

		# Clear any old doors
		for child in door_container.get_children():
			child.queue_free()

		load_room(next_room)
		fade_overlay.visible = false
	else:
		push_error("No next room found!")

func show_continue_button():
	if btn_continue:
		btn_continue.visible = true
		btn_continue.disabled = false
		btn_continue.grab_focus()  # Optional: auto-focus for keyboard users

func hide_continue_button():
	if btn_continue:
		btn_continue.visible = false
		btn_continue.disabled = true

func show_doors_with_shortcuts(shortcuts: Array[ShortcutOption]):
	"""Show 3 doors: Continue + 2 shortcuts (reusing existing door system)"""
	
	# Clear any old doors
	for child in door_container.get_children():
		child.queue_free()

	# DOOR 2 & 3: Shortcuts
	for option in shortcuts:
		# Convert ShortcutOption to RoomData so door can display it
		var shortcut_room = create_room_data_for_door(option)
		
		var shortcut_door = door_choice_scene.instantiate()
		door_container.add_child(shortcut_door)
		shortcut_door.setup_door(shortcut_room)  # ← YOUR EXISTING METHOD
		shortcut_door.door_selected.connect(func(rd): _on_shortcut_door_selected(option))
		shortcut_door.on_room_completed()  # ← YOUR EXISTING ANIMATION
	
	# Show the door container
	door_container.visible = true
	
func _on_shortcut_door_selected(option: ShortcutOption):
	# Player chose shortcut door
	var current_room = DungeonManager.current_rank_rooms[DungeonManager.current_room_index]
	DungeonManager.all_visited_rooms.append(current_room)

	door_container.visible = false
	
	# Apply the shortcut (marks rooms skipped, replaces destination)
	DungeonManager.apply_shortcut(option)
	
	# Advance to destination
	DungeonManager.advance_room()  # Advance once past current room
	
	# Skip ahead
	for i in range(option.skip_count):
		var room_data = RoomData.new()
		room_data.room_definition = RoomRegistry.get_room_by_id("SKIPPED")
		room_data.room_state["skipped"] = true
		DungeonManager.all_visited_rooms.append(room_data)
		DungeonManager.advance_room()
	
	# Load destination room
	var dest_room = DungeonManager.get_current_room()
	if dest_room:
		anim_fade.play("fade_out")
		var anim_length = anim_fade.get_animation("fade_out").length
		await CombatSpeed.create_timer(anim_length)
		await load_room(dest_room)

func create_room_data_for_door(option: ShortcutOption) -> RoomData:
	"""Convert shortcut option into RoomData so door system can display it"""
	
	# Create room data from destination
	var room_data = RoomData.new(
		option.destination_room,
		option.destination_room.get_random_event()
	)
	
	# Add shortcut info to description
	var base_desc = option.destination_room.room_desc
	var shortcut_info = "\n\n Shortcut: Skip %d rooms\n%s" % [
		option.skip_count,
		" Combat ahead" if option.has_combat else " Safe passage"
	]
	
	# Store modified description (door tooltip will show this)
	room_data.room_state["custom_desc"] = base_desc + shortcut_info
	
	return room_data

func set_player_stats():
	if CombatManager.combat_active:
		# During combat: show current/max for HP, current only for others
		stat_health.update_stat(Enums.Stats.HITPOINTS, Player.stats.hit_points_current, Player.stats.hit_points)

		# Check for blind on damage display
		var displayed_damage = Player.stats.damage_current
		if Player.status_effects and Player.status_effects.blind > 0:
			displayed_damage = ceili(displayed_damage / 2.0)
		stat_damage.update_stat(Enums.Stats.DAMAGE, displayed_damage, Player.stats.damage)
				
		stat_shield.update_stat(Enums.Stats.SHIELD, Player.stats.shield_current, Player.stats.shield)
		stat_agility.update_stat(Enums.Stats.AGILITY, Player.stats.agility_current, Player.stats.agility)
	else:
		# During exploration: show current/max for HP, base values for others
		# (since stats reset to base between combats)
		stat_health.update_stat(Enums.Stats.HITPOINTS, Player.stats.hit_points_current, Player.stats.hit_points)
		stat_damage.update_stat(Enums.Stats.DAMAGE, Player.stats.damage, Player.stats.damage)  # Show base as both current and max
		stat_shield.update_stat(Enums.Stats.SHIELD, Player.stats.shield, Player.stats.shield)
		stat_agility.update_stat(Enums.Stats.AGILITY, Player.stats.agility, Player.stats.agility)
	
	# Gold always shows current amount (no max)
	stat_gold.update_stat(Enums.Stats.GOLD, Player.stats.gold, Player.stats.gold)

func setup_inventory():
	item_slots.clear()
	item_slots.resize(Player.inventory.max_item_slots)
	item_grid.columns = Player.inventory.max_item_slots
	setup_weapon()

	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()

	for i in range(Player.inventory.item_slots.size()):
		var item = Player.inventory.item_slots[i]
		var item_container = item_slot.instantiate()

		item_container.set_item(item)
		item_container.custom_minimum_size = Vector2(100, 100)
		item_container.slot_index = i
		item_container.set_order(i + 1)  # Display 1-based index

		item_container.drag_started.connect(_on_drag_started)
		item_container.drag_ended.connect(_on_drag_ended)
		item_container.slot_dropped_on.connect(_on_slot_dropped_on)
		item_container.slot_clicked.connect(_on_slot_clicked)
		item_container.slot_double_clicked.connect(_on_slot_double_clicked.bind(i))

		item_slots[i] = (item_container)
		item_grid.add_child(item_container)


func setup_bonuses(entity):
	if not (entity == Player):
		return

	sets_grid.columns = 6

	for child in sets_grid.get_children():
		sets_grid.remove_child(child)
		child.queue_free()

	for bonus_item in SetBonusManager.get_active_set_bonuses(Player):
		var item_container = item_slot.instantiate()

		item_container.set_item(bonus_item)
		item_container.slot_index = -3
		item_container.custom_minimum_size = Vector2(100, 100)
		item_container.set_bonus() 
		sets_grid.add_child(item_container)


func show_item_replacement_overlay():
	anim_tools.play("show_replace_item")
	inventory_replacement_mode = true
	replacement_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func hide_item_replacement_overlay():
	pending_reward_item = null
	anim_tools.play("hide_replace_item")
	inventory_replacement_mode = false
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
	weapon_slot.set_item(Player.inventory.weapon_slot)

func _on_stats_updated():
	set_player_stats()

func _on_inventory_updated(item: Item, slot: int):
	setup_inventory()

func _on_drag_started(slot: ItemSlot):
	if not slot.current_item:
		return
	
	dragging_slot = slot
	
	# Create drag preview
	create_drag_preview(slot.current_item)
	
	# Optional: Hide tooltip while dragging
	TooltipManager.hide_tooltip()

func _on_drag_ended(slot: ItemSlot):
	# Check if dragging over ItemCombiner
	var combiner = get_current_item_combiner()
	if combiner:
		var target_slot = get_combiner_slot_under_mouse(combiner)
		if target_slot > 0:
			# Add item to combiner slot
			combiner.add_item_to_slot(
				slot.current_item,
				slot.slot_index,
				target_slot
			)
			clear_dragging_vars()
			return  # Don't process normal inventory drop

	# Find what slot we're over
	var target_slot = get_slot_under_mouse()
	
	if target_slot and target_slot != slot:
		# Perform the swap or move
		perform_item_move(slot, target_slot)

	clear_dragging_vars()
	slot.modulate.a = 1.0
	
func clear_dragging_vars():
	# Clean up drag state
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_slot = null
	is_dragging = false


func _on_slot_dropped_on(target_slot: ItemSlot, dragged_item: Item):
	if dragging_slot and dragging_slot != target_slot:
		perform_item_move(dragging_slot, target_slot)

func _on_slot_clicked(_item: ItemSlot):
	if not inventory_replacement_mode or not pending_reward_item:
		return

	# Get the item being replaced
	#var old_item = Player.inventory.item_slots[_item.slot_index]
	
	# Replace the item
	var success = Player.inventory.replace_item_at_slot(pending_reward_item, _item.slot_index)

	setup_inventory()
	Player.update_stats_from_items()
	hide_item_replacement_overlay()

func _on_slot_double_clicked(slot_index: int):
	if inventory_replacement_mode:
		return

	# Check if slot has an item
	var item = Player.inventory.item_slots[slot_index]
	if item == null:
		return  # Can't drop empty slots

	pending_drop_item = item
	pending_drop_slot_index = slot_index
	drop_item.set_item(pending_drop_item)
	drop_item.set_item_type_desc()

	show_item_drop_overlay()
	
func perform_item_move(from_slot: ItemSlot, to_slot: ItemSlot):
	var from_index = from_slot.slot_index
	var to_index = to_slot.slot_index
	
	# If moving to empty slot, just move
	if not to_slot.current_item:
		Player.inventory.move_item_to_slot(from_index, to_index)
	else:
		# Swap items
		Player.inventory.swap_items(from_index, to_index)
	
	# Compact to remove gaps
	Player.inventory.compact_items()
	
	# Refresh display
	setup_inventory()
	Player.update_stats_from_items()

func get_slot_under_mouse() -> ItemSlot:
	var mouse_pos = get_global_mouse_position()
	for slot in item_slots:
		if slot and slot.get_global_rect().has_point(mouse_pos):
			return slot
	return null

func get_current_item_combiner() -> ItemCombiner:
	# Get the ItemCombiner from current event if it exists
	if current_event and current_event.has_node("ItemCombiner"):
		return current_event.get_node("ItemCombiner")
	return null

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
	
	var icon = TextureRect.new()
	icon.texture = item.item_icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(100, 100)
	icon.modulate = item.item_color
	icon.modulate.a = 0.7
	
	drag_preview.add_child(icon)
	get_tree().root.add_child(drag_preview)

func _show_panels():
	anim_tools.play("setup_toolbars")


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


func _on_btn_drop_pressed() -> void:
	if pending_drop_item and pending_drop_slot_index >= 0:
		# Remove item from inventory
		Player.inventory.remove_item(pending_drop_slot_index)
		
		# Shift inventory to remove gaps
		Player.inventory.compact_items()
		
		# Refresh inventory display
		setup_inventory()
		
		# Update player stats
		Player.update_stats_from_items()
		
		hide_item_drop_overlay()

func _on_btn_cancel_drop_pressed() -> void:
	hide_item_drop_overlay()

func is_in_replacement_mode() -> bool:
	return inventory_replacement_mode

# Track when combat starts/ends for proper stat display
func _on_combat_started_for_ui(player, enemy):
	is_in_combat = true
	set_player_stats()  # Refresh to show current values
	AudioManager.on_combat_started(enemy.enemy_type == Enemy.EnemyType.BOSS_PLAYER)	

func _on_combat_ended_for_ui(winner, loser):
	is_in_combat = false
	# Stats will reset to base values, so refresh display
	await get_tree().process_frame  # Wait for stats to reset
	set_player_stats()
	AudioManager.on_combat_ended()

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

func _on_minimap_update_requested():
	# Update minimap display when rooms change
	minimap.current_rank = DungeonManager.current_rank
	minimap.update_display()

func _on_minimap_room_clicked(room_index: int):
	# Boss room clicked (room index 5)
	if room_index == 5:
		show_boss_panel()

func _on_zoom_out_requested():
	zoom_panel.show_panel()

func _on_zoom_panel_closed():
	# Panel closed, nothing else needed
	pass

func _on_boss_rush_pressed():
	# TODO: Trigger boss battle early
	print("Boss Rush pressed!")
	zoom_panel.hide_panel()

func show_boss_panel():
	# Placeholder for boss room panel
	print("Boss room clicked - panel coming soon")
	# TODO: Create and show boss info panel with "Rush" button

func _ensure_player_profile():
	#Create player profile if it doesn't exist.
	# JDM: Move this to the main menu scene to avoid that weird delay at game start

	var player_id = Player.generate_or_load_uuid()
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
	
	# Reset to rank 1
	DungeonManager.current_rank = 1
	DungeonManager.current_room_index = 0
	DungeonManager.rooms_cleared_this_rank = 0
	
	# Clear current rooms
	DungeonManager.current_rank_rooms.clear()
	DungeonManager.all_visited_rooms.clear()

	# Clear boss data
	DungeonManager.current_boss_data = {}
	DungeonManager.current_boss_enemy = null
	
	# Generate fresh rank 1 rooms
	DungeonManager.generate_rank_rooms()
	
	# Update minimap
	DungeonManager.minimap_update_requested.emit()
	
	print("[MainGame] Dungeon reset to Rank 1")

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


func _on_btn_continue_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_continue_mouse_entered() -> void:
	CursorManager.set_navigation_cursor()


func _on_btn_cancel_replace_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

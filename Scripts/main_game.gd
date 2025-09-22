class_name MainGameController
extends Control

## Main game scene controller that manages the overall game interface
## Coordinates inventory UI, dungeon map, and room display area

# UI Components
@onready var dungeon_map_panel: Panel = $TopPanel
@onready var inventory_panel: Panel = $BottomPanel
@onready var combat_panel: CombatPanel = $CombatPanel

@onready var room_background: TextureRect = $RoomContainer/roomPic
@onready var event_container: Node = $EventContainer
@onready var door_container: HBoxContainer = $DoorContainer/HBoxContainer

@onready var stat_health: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statHealth
@onready var stat_damage: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statDamage
@onready var stat_shield: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statShield
@onready var stat_agility: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statAgility
@onready var stat_gold: Control = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/statGold

@onready var item_grid: GridContainer = $BottomPanel/MarginContainer/VBoxContainer/HBoxContainer/InventorySlots/ItemSlots
@onready var weapon_slot: ItemSlot = $BottomPanel/MarginContainer/VBoxContainer/HBoxContainer/Weapon

@onready var status_box_container: HBoxContainer = $BottomPanel/panelStatus/statusBox
@onready var enemy_status_box_container: HBoxContainer = $CombatPanel/CombatPanelTop/panelStatus/statusBox

@onready var replacement_panel: Panel = $ReplaceItemPanel
@onready var replacement_item: ItemSlot = $ReplaceItemPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/itemBox/ItemReplace
@onready var drop_panel: Panel = $DropItemPanel
@onready var drop_item: ItemSlot = $DropItemPanel/panelBlack/MarginContainer/panelBorder/VBoxContainer/itemBox/ItemDrop

@onready var anim_tools: AnimationPlayer = $animToolbars
@onready var anim_fade: AnimationPlayer = $animFade
@onready var fade_overlay: ColorRect = $FadeOverlay

@onready var box_minimap: VBoxContainer = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/boxMiniMap
@onready var box_combatcontrols: VBoxContainer = $BottomPanel/MarginContainer/VBoxContainer/hboxStats/boxCombatControls


var current_event: RoomEvent

var item_slot = preload("res://Scenes/item.tscn")
var status_box = preload("res://Scenes/Elements/status_box.tscn")
var item_proc = preload("res://Scenes/Elements/combat_item_proc.tscn")

var item_slots: Array[ItemSlot] = []
var status_effects: Array[StatusBox] = []

# for reordering your inventory
var dragging_instance_id: int = -1
var dragging_from_slot: int = -1
var dragging_slot: ItemSlot = null
var drag_preview: Control = null

# for combat
var awaiting_combat_result: bool = false
var combat_result_callback: Callable

# for overwriting items when your inventory is full
var pending_reward_item: Item = null
var inventory_replacement_mode: bool = false

var pending_drop_item: Item = null
var pending_drop_slot_index: int = -1

func get_combat_panel() -> CombatPanel:
	# Get reference to the combat panel for room events to use
	return combat_panel

func _ready():
	add_to_group("main_game")
	Player.stats.stats_updated.connect(_on_stats_updated)
	Player.inventory.item_added.connect(_on_inventory_updated)
	Player.status_updated.connect(_on_status_effects_updated)
	DungeonManager.show_minimap.connect(_show_panels)

	combat_panel.main_game = self
	combat_panel.combat_completed.connect(_on_combat_completed)
	combat_panel.player_chose_run.connect(_on_player_ran)

	create_test_player()
	load_starting_room()

	set_process_input(true) # for drag preview
	
func _input(event: InputEvent):
	# Update drag preview position
	if dragging_slot and drag_preview:
		if event is InputEventMouseMotion:
			drag_preview.global_position = event.global_position - Vector2(50, 50)  # Center on mouse


func create_test_player():
	setup_inventory()
	Player.update_stats_from_items()


func load_starting_room():
	var starter_room_data = DungeonManager.generate_starter_room()
	if starter_room_data:
		await load_room(starter_room_data)
	else:
		push_error("Failed to generate starter room!")

func flip_minimap_combat_controls():
	box_minimap.visible = !box_minimap.visible
	box_combatcontrols.visible = !box_combatcontrols.visible

func load_room(room_data: RoomData):
	# Update background
	room_background.texture = room_data.room_definition.background_texture
	set_background_tint(room_data.room_definition.room_type)

	# Clear previous event
	clear_doors()
	clear_current_event()
	
	# Load new event
	load_room_event(room_data)

	if get_tree().has_group("item_selection_events"):
		for room_event in get_tree().get_nodes_in_group("item_selection_events"):
			if room_event.has_signal("need_item_replace"):
				room_event.need_item_replace.connect(show_inventory_replacement_mode)

	show_door_choices()

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
		event_container.add_child(current_event)
		current_event.setup(room_data)
		current_event.event_completed.connect(_on_event_completed)

		# Connect to combat request if the event needs it
		if current_event.has_signal("combat_requested"):
			current_event.combat_requested.connect(request_combat)
	else:
		push_error("Could not load event.")

func _on_event_completed():
	await get_tree().process_frame
	
	clear_current_event()
	for child in door_container.get_children():
		if child.has_method("on_room_completed"):
			child.on_room_completed()


func show_door_choices():
	# Clear any existing doors
	clear_doors()
	
	# Generate 3 door choices from DungeonManager
	var door_options = DungeonManager.generate_door_choices()
	
	# Create door choice buttons
	var door_choice_scene = preload("res://Scenes/door_choice.tscn")
	
	for room_data in door_options:
		var door_choice = door_choice_scene.instantiate()
		door_choice.custom_minimum_size.x = 180

		door_container.add_child(door_choice)
		door_choice.setup_door(room_data)
		door_choice.door_selected.connect(_on_door_selected)

func clear_doors():
	for child in door_container.get_children():
		child.queue_free()

func _on_door_selected(room_data: RoomData):
	print("Player selected: ", DungeonManager.get_room_type_display_name(room_data))
	#print("Event will be: ", room_data.chosen_event_scene.event_description)
	
	# Advance room counter
	DungeonManager.advance_room()
	
	anim_fade.play("fade_out")
	await anim_fade.animation_finished

	# Load the selected room
	load_room(room_data)
	fade_overlay.visible = false

func set_background_tint(room_type: Enums.RoomType):
	var gamecolors = GameColors.new()
	
	match room_type:
		Enums.RoomType.STARTER:
			room_background.modulate = gamecolors.room.starter
		Enums.RoomType.HALLWAY:
			room_background.modulate = gamecolors.room.hallway
		Enums.RoomType.TOMB:
			room_background.modulate = gamecolors.room.tomb
		Enums.RoomType.CHAMBERS:
			room_background.modulate = gamecolors.room.royal
		Enums.RoomType.FORGE:
			room_background.modulate = gamecolors.room.forge
		Enums.RoomType.COVEN:
			room_background.modulate = gamecolors.room.coven
		Enums.RoomType.BOSS:
			room_background.modulate = gamecolors.room.boss
		_:
			room_background.modulate = Color.WHITE  # Default no tint

func set_player_stats():
	stat_health.update_stat(Enums.Stats.HITPOINTS, Player.stats.hit_points_current, Player.stats.hit_points)
	stat_damage.update_stat(Enums.Stats.DAMAGE, Player.stats.damage_current, Player.stats.damage)
	stat_shield.update_stat(Enums.Stats.SHIELD, Player.stats.shield_current, Player.stats.shield)
	stat_agility.update_stat(Enums.Stats.AGILITY, Player.stats.agility_current, Player.stats.agility)
	stat_gold.update_stat(Enums.Stats.GOLD, Player.stats.gold, -1)

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

		item_slots.append(item_container)
		item_grid.add_child(item_container)

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
	
	return Vector2(0,0)

func loop_through_player_statuses_for_position(_status: Enums.StatusEffects) -> Vector2:
	var offset: Vector2 = Vector2(45,-50)

	if !_status:
		return Vector2(0,0)

	for child in status_box_container.get_children():
		if child:
			if child.status == _status:
				return child.global_position + offset

	return Vector2(0,-0)

func setup_weapon():
	weapon_slot.set_item(Player.inventory.weapon_slot)

func _on_stats_updated():
	set_player_stats()

func _on_inventory_updated(item: Item, slot: int):
	setup_inventory()

func _on_status_effects_updated(_status: Enums.StatusEffects, amount: int):
	status_effects.clear()

	for child in status_box_container.get_children():
		status_box_container.remove_child(child)
		child.queue_free()

	if Player.status_effects.poison > 0:
		create_new_status_box(Enums.StatusEffects.POISON, Player.status_effects.poison)
	if Player.status_effects.acid > 0:
		create_new_status_box(Enums.StatusEffects.ACID, Player.status_effects.acid)
	if Player.status_effects.thorns > 0:
		create_new_status_box(Enums.StatusEffects.THORNS, Player.status_effects.thorns)
	if Player.status_effects.burn > 0:
		create_new_status_box(Enums.StatusEffects.BURN, Player.status_effects.burn)
	if Player.status_effects.regeneration > 0:
		create_new_status_box(Enums.StatusEffects.REGENERATION, Player.status_effects.regeneration)
	if Player.status_effects.blind > 0:
		create_new_status_box(Enums.StatusEffects.BLIND, Player.status_effects.blind)
	if Player.status_effects.blessing > 0:
		create_new_status_box(Enums.StatusEffects.BLESSING, Player.status_effects.blessing)
	if Player.status_effects.stun > 0:
		create_new_status_box(Enums.StatusEffects.STUN, Player.status_effects.stun)						

func create_new_status_box(_status: Enums.StatusEffects, amount: int):
		var item_container = status_box.instantiate()

		item_container.set_status(_status, amount)
		item_container.custom_minimum_size = Vector2(120, 78)

		status_effects.append(item_container)
		status_box_container.add_child(item_container)

func _on_drag_started(slot: ItemSlot):
	if not slot.current_item:
		return
	
	dragging_slot = slot
	
	# Create drag preview
	create_drag_preview(slot.current_item)
	
	# Optional: Hide tooltip while dragging
	if slot.tooltip_panel:
		slot.tooltip_panel.hide()

func _on_drag_ended(slot: ItemSlot):
	# Find what slot we're over
	var target_slot = get_slot_under_mouse()
	
	if target_slot and target_slot != slot:
		# Perform the swap or move
		perform_item_move(slot, target_slot)
	
	# Clean up drag state
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_slot = null
	slot.modulate.a = 1.0

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

class_name CombatPanel
extends Control

## Combat overlay panel that slides in from the right side of the screen
## Manages combat UI, displays enemy/player stats, and highlights inventory items

signal combat_ui_ready()
signal player_chose_fight()
signal player_chose_run()
signal combat_completed(player_won: bool)
signal attack_sequence_complete()

enum PanelState {
	HIDDEN,
	PRE_COMBAT,   # Shows enemy with fight/run buttons
	IN_COMBAT,    # Active combat with log and controls
	POST_COMBAT   # Victory/defeat screen
}

# UI References
@onready var enemy_name_label: Label = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/EnemyNameBox/HBoxContainer/boxEnemyName/lblEnemy
@onready var enemy_desc_label: RichTextLabel = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/EnemyNameBox/lblEnemyDesc
@onready var enemy_sprite: TextureRect = $Enemy/picEnemy
@onready var btn_enemy:Button = $Enemy/picEnemy/btnEnemy

# Enemy stat displays
@onready var enemy_health_stat: StatBoxDisplay = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/statsContainer/statHealth
@onready var enemy_shield_stat: StatBoxDisplay = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/statsContainer/statShield
@onready var enemy_damage_stat: StatBoxDisplay = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/statsContainer/statDamage
@onready var enemy_agility_stat: StatBoxDisplay = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/statsContainer/statAgility
@onready var enemy_strikes_stat: StatBoxDisplay = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/statsContainer/statBurn
@onready var enemy_burn_stat: StatBoxDisplay = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyStats/statsContainer/statStrikes

@onready var enemy_weapon_slot: ItemSlot = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyInventory/Weapon
@onready var enemy_item_grid: GridContainer = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyInventory/InventorySlots/ItemSlots
@onready var enemy_inventory: HBoxContainer = $TopPanelHolder/VBoxContainer/enemyStatsInventory/MarginContainer/VBoxContainer/enemyInventory

# Status Effect Boxes
@onready var player_status_container: GridContainer # set in code
@onready var enemy_status_container: GridContainer = $TopPanelHolder/VBoxContainer/enemyStatusSets/HBoxContainer/statusBox
@onready var enemy_set_container: HBoxContainer = $TopPanelHolder/VBoxContainer/enemyStatusSets/HBoxContainer/setBox

# Victory Panel
@onready var victory_panel: Panel = $VictoryPanel
@onready var death_panel: Panel = $DeathPanel
@onready var reward_label: Label = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxReward/panelReward/MarginContainer/HBoxContainer/lblRewardAmt
@onready var reward_box: HBoxContainer = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxReward/panelReward/MarginContainer/HBoxContainer

@onready var btn_copy: LinkButton = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/HBoxContainer/btnCopy
@onready var btn_copy_dead: LinkButton = $DeathPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/HBoxContainer/btnCopy
@onready var txt_history: RichTextLabel = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/txtHistory
@onready var txt_history_dead: RichTextLabel =$DeathPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/txtHistoryDead

# Animation
@onready var anim_enemy_stat_bar:AnimationPlayer = $animEnemyStats
@onready var slide_animation: AnimationPlayer = $combatPanelAnim
@onready var player_anim: AnimationPlayer = $animPlayer
@onready var enemy_anim: AnimationPlayer = $animEnemy
@onready var anim_instant: AnimationPlayer = $animInstant

# Main Game Controller
var main_game: MainGameController 

# State management
var current_state: PanelState = PanelState.HIDDEN

var item_proc = preload("res://Scenes/Elements/combat_item_proc.tscn")
var turn_sign = preload("res://Scenes/Elements/combat_turn_sign.tscn")
var status_box = preload("res://Scenes/Elements/status_box.tscn")

# Combat state
var is_visible: bool = false
var current_player_entity
var current_enemy_entity: Enemy
var highlighted_item_slot: ItemSlot = null

# References to inventory slots for highlighting
var inventory_item_slots: Array[ItemSlot] = []
var weapon_slot_ref: ItemSlot = null

var gamecolors: GameColors

func _ready():
	# Start off-screen
	visible = false
	add_to_group("combat_panel")
	_set_state(PanelState.HIDDEN)
	connect_combat_signals()

func connect_combat_signals():
	# --- Connect to CombatManager signals
	CombatManager.combat_started.connect(_on_combat_started)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.turn_ended.connect(_on_turn_ended)
	
	# --- Combat event signals
	CombatManager.healing_applied.connect(_on_healing_applied)
	CombatManager.stat_changed.connect(_on_stat_changed)

	# --- Item/ability triggers
	CombatManager.item_rule_triggered.connect(_on_item_rule_triggered)

func setup_for_combat(enemy_entity, inventory_slots: Array[ItemSlot], weapon_slot: ItemSlot):
	current_player_entity = Player
	inventory_item_slots = inventory_slots
	weapon_slot_ref = weapon_slot

	current_enemy_entity = enemy_entity #.duplicate()  # Work with a copy  #: JDM: removed the ".duplicate()" since it was causing the upgrades to not load, and no need to worry about persistent changes for boss battles
	current_enemy_entity.reset_to_base_values()

	btn_enemy.disabled = false
	btn_enemy.mouse_filter = Control.MOUSE_FILTER_STOP

	# Setup enemy display
	if current_enemy_entity is Enemy:
		enemy_name_label.text = current_enemy_entity.enemy_name
		enemy_desc_label.text = current_enemy_entity.description
		if current_enemy_entity.sprite:
			enemy_sprite.texture = current_enemy_entity.sprite
			enemy_name_label.modulate = current_enemy_entity.sprite_color
	
	# Initialize enemy stats display
	_update_enemy_stats()
	clear_statuses()
	
	_populate_enemy_inventory(current_enemy_entity)

	# Check and display set bonuses for enemy
	SetBonusManager.check_set_bonuses(current_enemy_entity)  # Calculate bonuses
	_populate_enemy_set_bonuses(current_enemy_entity)        # Display them

	_set_state(PanelState.PRE_COMBAT)

	# Reset turn counter
	set_turn_label("Battle Start")
	_update_speed_label(CombatSpeed.current_mode)

	var is_boss_fight = current_enemy_entity.enemy_type == Enemy.EnemyType.BOSS_PLAYER

	var can_run: bool = true

	# Update the RUN button stuff
	if is_boss_fight:
		# Boss fight - cannot run
		can_run = false
		enemy_inventory.visible = true
	else:
		# Normal fight - can run if fast enough
		enemy_inventory.visible = false
		can_run = current_player_entity.stats.agility > current_enemy_entity.stats.agility

	show_panel(can_run, is_boss_fight)

func _populate_enemy_set_bonuses(enemy: Enemy):
	"""Display active set bonuses for the enemy."""
	# Clear existing
	for child in enemy_set_container.get_children():
		child.queue_free()
	
	# Get active set bonuses for this enemy
	var bonus_items = SetBonusManager.get_active_set_bonuses(enemy)
	
	if bonus_items.is_empty():
		enemy_set_container.visible = false
		return
	
	enemy_set_container.visible = true
	
	var item_slot_scene = preload("res://Scenes/item.tscn")
	
	for bonus_item in bonus_items:
		var item_container = item_slot_scene.instantiate()
		item_container.owner_entity = enemy  # Set entity reference for tooltips
		item_container.set_item(bonus_item)
		item_container.slot_index = -3  # Special index for set bonuses
		item_container.custom_minimum_size = Vector2(50, 50)
		item_container.set_bonus()  # Apply set bonus styling
		enemy_set_container.add_child(item_container)
	
	print("[CombatPanel] Enemy has %d active set bonuses" % bonus_items.size())

func clear_statuses():
	# Clear status boxes at combat start
	for child in player_status_container.get_children():
		child.queue_free()
	for child in enemy_status_container.get_children():
		child.queue_free()

func show_panel(can_run: bool = true, is_boss: bool = false):
	"""Slide the combat panel in from the right"""
	if is_visible:
		return
		
	visible = true
	is_visible = true
	
	anim_enemy_stat_bar.play("show_stat_bar")
	slide_animation.play("open_Combat")
	await slide_animation.animation_finished

	## -- Buttons on the main game
	main_game.box_dinglemeyer.visible = false
	main_game.box_comatspeed.visible = false
	main_game.fight_or_flee.show_popup(can_run, is_boss)

	combat_ui_ready.emit()

func hide_panel():
	"""Slide the combat panel out to the right"""
	if not is_visible:
		return
	
	is_visible = false
	visible = false
	
	## -- Buttons on the main game
	main_game.box_dinglemeyer.visible = true
	main_game.box_comatspeed.visible = false

	# Clear highlighted items
	_clear_all_highlights()

func _update_enemy_stats():
	if not current_enemy_entity:
		return
	
	# HP
	enemy_health_stat.update_stat(Enums.Stats.HITPOINTS, current_enemy_entity.stats.hit_points_current, current_enemy_entity.stats.hit_points)

	# Shield stat
	enemy_shield_stat.update_stat(Enums.Stats.SHIELD, current_enemy_entity.stats.shield_current, current_enemy_entity.stats.shield_current)
	
	# Damage stat
	var displayed_damage = current_enemy_entity.stats.damage_current
	enemy_damage_stat.update_stat(Enums.Stats.DAMAGE, displayed_damage, displayed_damage)

	# Agility stat
	enemy_agility_stat.update_stat(Enums.Stats.AGILITY, current_enemy_entity.stats.agility_current, current_enemy_entity.stats.agility_current)

	enemy_strikes_stat.update_stat(Enums.Stats.STRIKES, current_enemy_entity.stats.strikes_left, current_enemy_entity.stats.strikes_next_turn)

	var show_burn: bool = false
	if current_enemy_entity.inventory:
		show_burn = current_enemy_entity.inventory.has_keyword("Burn")
	enemy_burn_stat.update_stat(Enums.Stats.BURN_DAMAGE, current_enemy_entity.stats.burn_damage_current, current_enemy_entity.stats.burn_damage_current, show_burn)


func highlight_item_slot(slot_index: int, is_weapon: bool = false):
	_clear_all_highlights()
	
	if is_weapon and weapon_slot_ref:
		highlighted_item_slot = weapon_slot_ref
		weapon_slot_ref.start_combat_highlight()
	elif slot_index >= 0 and slot_index < inventory_item_slots.size():
		# Inventory slot - VALIDATE the index
		var slot = inventory_item_slots[slot_index]
		if slot and slot.current_item:  # Make sure slot exists and has an item
			highlighted_item_slot = slot
			slot.start_combat_highlight()
		else:
			push_warning("Trying to highlight empty slot %d" % slot_index)

func _clear_all_highlights():
	"""Clear all inventory highlights"""
	if highlighted_item_slot:
		highlighted_item_slot.stop_combat_highlight()
		highlighted_item_slot = null
	
	# Ensure all slots are unhighlighted
	for slot in inventory_item_slots:
		if slot:
			slot.stop_combat_highlight()
	
	if weapon_slot_ref:
		weapon_slot_ref.stop_combat_highlight()

# Signal handlers
func _on_combat_started(player_entity, enemy_entity):
	btn_enemy.disabled = true
	btn_enemy.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## -- Buttons on the main game
	main_game.box_dinglemeyer.visible = false
	main_game.box_comatspeed.visible = true

func _on_combat_ended(winner, loser):
	var winner_name = CombatManager.get_entity_name(winner)
	var loser_name = CombatManager.get_entity_name(loser)

	if winner == current_player_entity:
		if loser.enemy_type != Enemy.EnemyType.BOSS_PLAYER:
			reward_label.text = str(0)
			var gold_earned = CombatManager.calculate_gold_reward(loser) if loser is Enemy else 0
			if gold_earned > 0:
				reward_label.text = str(gold_earned)
				Player.add_gold(gold_earned)
		else:
			reward_label.text = str(0)
	
	# Wait a moment before hiding
	for child in player_status_container.get_children():
		child.queue_free()
	for child in enemy_status_container.get_children():
		child.queue_free()

	# Wait before showing victory/death panel
	await CombatSpeed.create_timer(CombatSpeed.get_duration("phase_transition"))

	_set_state(PanelState.POST_COMBAT)
	_clear_all_highlights()
	clear_all_proc_indicators()

	## -- Buttons on the main game
	main_game.box_dinglemeyer.visible = true
	main_game.box_comatspeed.visible = false

	update_history_text()
	AudioManager.play_combat_sound("gong")
	Player.popup_open = true

	if winner == current_player_entity:
		slide_animation.play("show_victory")
		#AudioManager.play_ui_sound("pappas")
		await slide_animation.animation_finished
	else:
		AudioManager.clear_room_override()
		AudioManager.play_defeat_music()
		death_panel.visible = true

	print("----- TEST PERFORMANCE MONITOR: ")
	print(Performance.get_monitor(Performance.OBJECT_COUNT))

func clear_all_proc_indicators():
	for child in get_children():
		if child is CombatItemProc:
			child.queue_free()
		if child is StatusBox:
			child.queue_free()

func create_timed_message(msg: String) -> CombatTurnSign:

	var box_label = turn_sign.instantiate()
	
	box_label.set_label(msg)		
	add_child(box_label)

	return box_label

func _on_turn_started(entity, turn_number):
	var entity_name = CombatManager.get_entity_name(entity).left(20)
	set_turn_label("Turn: " + str(turn_number) + "/" + str(CombatManager.MAX_COMBAT_TURNS) + " (" + entity_name + "'s turn)")

func _on_turn_ended(entity):
	_clear_all_highlights()

func _get_status_enum(status_name: String) -> Enums.StatusEffects:
	match status_name:
		"poison": return Enums.StatusEffects.POISON
		"burn": return Enums.StatusEffects.BURN
		"acid": return Enums.StatusEffects.ACID
		"thorns": return Enums.StatusEffects.THORNS
		"bleed": return Enums.StatusEffects.BLEED
		"regeneration": return Enums.StatusEffects.REGENERATION
		"blessing": return Enums.StatusEffects.BLESSING
		"stun": return Enums.StatusEffects.STUN
		"random": return Enums.StatusEffects.RANDOM
		_: return Enums.StatusEffects.NONE

func test_camera_shake():
	if GameSettings.screen_shake_enabled:
		main_game.screen_shake(20,0.33)
	AudioManager.play_synced_sound("combat_player_hit_light")

func play_sfx_footstep():
	AudioManager.play_synced_sound("combat_footstep")


func _on_healing_applied(target, amount):
	"""Handle healing"""
	var target_name = CombatManager.get_entity_name(target)

	# Update enemy stats if they were healed
	if target == current_enemy_entity:
		_update_enemy_stats()

func _on_stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int):
	"""Handle stat changes"""
	if entity == current_enemy_entity:
		_update_enemy_stats()
	#else:
	#	Player.stats.stats_updated.emit()  # NOTE: Player stat updates should happen in combatmanager.stat_changed

func _on_item_rule_triggered(item: Item, rule: ItemRule, entity):
	pass

func player_joins_combat_anim():
	player_anim.play("player_ready")

func anim_player_walk_to_door():
	player_anim.play("player_walk_to_door")

func anim_close_panels():
	anim_enemy_stat_bar.play("hide_stat_bar")
	slide_animation.play("close_combat")

func anim_close_panels_instant():
	anim_enemy_stat_bar.play("hide_stat_bar")
	slide_animation.play("close_combat_instant")

func anim_player_hit():
	player_anim.play(CombatSpeed.get_animation_variant("player_hit"))

func anim_enemy_appear():
	AudioManager.play_enemy_approach(current_enemy_entity)
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_appear"))

func anim_enemy_hit():
	#enemy_sprite.texture = current_enemy_entity.sprite_hit
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_hit"))

func anim_enemy_die():
	#enemy_sprite.texture = current_enemy_entity.sprite_hit
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_die"))

func anim_player_idle():
	if CombatSpeed.is_instant_mode():
		return
	player_anim.play(CombatSpeed.get_animation_variant("player_idle"))
	attack_sequence_complete.emit()

func anim_enemy_idle():
	if CombatSpeed.is_instant_mode():
		return
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_idle"))
	attack_sequence_complete.emit()

func anim_player_attack():
	player_anim.play(CombatSpeed.get_animation_variant("player_attack"))

func anim_player_done():
	player_anim.play("player_done")

func anim_enemy_attack():
	enemy_sprite.texture = current_enemy_entity.sprite_attack
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_attack"))

func _update_speed_label(speed: CombatSpeed.CombatSpeedMode):
	match speed:
		CombatSpeed.CombatSpeedMode.PAUSE:
			set_speed_label(" PAUSED")
		CombatSpeed.CombatSpeedMode.NORMAL:
			set_speed_label(" 1x")
		CombatSpeed.CombatSpeedMode.FAST:
			set_speed_label(" 2x")
		CombatSpeed.CombatSpeedMode.VERY_FAST:
			set_speed_label(" 3.5x")
		CombatSpeed.CombatSpeedMode.INSTANT:
			set_speed_label(" INSTANT")

func pause_all_combat_animations(_pause: bool):
	if _pause:
		player_anim.pause()
		enemy_anim.pause()
	else:
		player_anim.play()
		enemy_anim.play()


func _on_btn_run_pressed() -> void:
	# Emit signal for room event
	player_chose_run.emit()
	
	# Slide out
	await hide_panel()
	
	# Complete without combat
	combat_completed.emit(false)

func setup_fight():
	if !CombatManager.combat_active:
		## -- Buttons on the main game
		main_game.box_dinglemeyer.visible = false
		main_game.box_comatspeed.visible = true

	_set_state(PanelState.IN_COMBAT)
	player_chose_fight.emit()
	CombatSpeed.enter_combat()

	if CombatSpeed.is_instant_mode():
		# Hide speed controls — combat will be over before they matter
		main_game.box_comatspeed.visible = false
		player_anim.stop()
		enemy_anim.stop()
		AudioManager.play_event_sound("instant_combat")
		anim_instant.play("instant_combat")
		var anim_length = anim_instant.get_animation("instant_combat").length
		await CombatSpeed.create_timer(anim_length)
		player_anim.play("RESET")

		CombatManager.start_combat(current_player_entity, current_enemy_entity)
	else:
		main_game.box_comatspeed.visible = true
		CombatManager.start_combat(current_player_entity, current_enemy_entity)

func _on_btn_fight_pressed() -> void:
	setup_fight()

func _set_state(new_state: PanelState):
	current_state = new_state
	
func _on_btn_pause_pressed() -> void:
	pause_all_combat_animations(true)
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.PAUSE)
	_update_speed_label(CombatSpeed.CombatSpeedMode.PAUSE)

func _on_btn_play_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL)
	pause_all_combat_animations(false)
	_update_speed_label(CombatSpeed.CombatSpeedMode.NORMAL)

func _on_btn_fast_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.FAST)
	pause_all_combat_animations(false)
	_update_speed_label(CombatSpeed.CombatSpeedMode.FAST)

func _on_btn_very_fast_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.VERY_FAST)
	pause_all_combat_animations(false)
	_update_speed_label(CombatSpeed.CombatSpeedMode.VERY_FAST)

func set_turn_label(_string: String):
	main_game.lbl_turn.text = _string

func set_speed_label(_string: String):
	main_game.lbl_speed.text = _string

func _on_btn_continue_pressed() -> void:
	slide_animation.play("hide_victory")
	Player.popup_open = false
	#await slide_animation.animation_finished

	await hide_panel()
	combat_completed.emit(true)


func _on_btn_history_pressed() -> void:
	txt_history.visible = !txt_history.visible
	btn_copy.visible = txt_history.visible
	txt_history.text = CombatManager.combat_log
	txt_history.get_v_scroll_bar().custom_minimum_size.x = 20

	if death_panel.visible:
		txt_history_dead.visible = !txt_history_dead.visible
		txt_history_dead.get_v_scroll_bar().custom_minimum_size.x = 20
		btn_copy_dead.visible = txt_history_dead.visible
		txt_history_dead.text = CombatManager.combat_log

func update_history_text():
	txt_history.text = CombatManager.combat_log
	txt_history_dead.text = CombatManager.combat_log
	txt_history_dead.get_v_scroll_bar().custom_minimum_size.x = 20
	txt_history.get_v_scroll_bar().custom_minimum_size.x = 20

func _print_node_tree(node: Node, depth: int):
	var indent = "  ".repeat(depth)
	print("%s%s (%s)" % [indent, node.name, node.get_class()])
	
	for child in node.get_children():
		_print_node_tree(child, depth + 1)


func _create_status_box(container: GridContainer, status: Enums.StatusEffects, stacks: int):
	var box = status_box.instantiate()
	box.custom_minimum_size = Vector2(100, 55)
	container.add_child(box)
	box.set_status(status, stacks)
	
	# Spawn animation
	box.show_box()


func _update_status_box_value(box: StatusBox, new_stacks: int):
	if not box or not is_instance_valid(box):
		push_warning("[CombatPanel] Cannot animate status change - box is null")
		return

	if not box.lbl_amount:
		push_warning("[CombatPanel] Status box lbl_amount is null - box may not be ready")
		return

	var old_value = int(box.lbl_amount.text)

	if old_value == new_stacks:
		return  # No change

	box.update_label(new_stacks)

func _remove_status_box(box: StatusBox):
	if not is_instance_valid(box):
		return

	await box.hide_box()

	if is_instance_valid(box) and not box.is_queued_for_deletion():
		box.queue_free()	


func _on_btn_instant_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.INSTANT)
	_update_speed_label(CombatSpeed.CombatSpeedMode.INSTANT)


func _populate_enemy_inventory(enemy: Enemy):
	enemy_item_grid.columns = enemy.inventory.item_slots.size()

	for child in enemy_item_grid.get_children():
		enemy_item_grid.remove_child(child)
		child.queue_free()

	if not enemy.inventory:
		print("[CombatPanel] Enemy has no inventory")
		return
	
	var item_slot_scene = preload("res://Scenes/item.tscn")
	
	# Add weapon first
	if enemy.inventory.weapon_slot:
		enemy_weapon_slot.owner_entity = enemy
		enemy_weapon_slot.set_item(enemy.inventory.weapon_slot)
		print("[CombatPanel] Added enemy weapon: %s" % enemy.inventory.weapon_slot.item_name)
	
	# Add inventory items
	for i in range(enemy.inventory.item_slots.size()):
		var item = enemy.inventory.item_slots[i]
		if item:
			var item_slot = item_slot_scene.instantiate()
			item_slot.owner_entity = enemy
			item_slot.set_item(item)
			item_slot.custom_minimum_size = Vector2(110, 115)
			item_slot.slot_index = i + 1
			item_slot.set_order(i + 1)
			enemy_item_grid.add_child(item_slot)
			print("[CombatPanel] Added enemy item %d: %s" % [i, item.item_name])


func _on_btn_quit_pressed() -> void:
	hide_death_panel()
	main_game.fade_out()

	SaveManager.delete_saved_run()
	
	# Update defeat stats BEFORE resetting
	await _update_defeat_stats()

	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_btn_new_run_pressed() -> void:
	hide_death_panel()
	main_game.fade_out()
	AudioManager.play_ui_sound("new_run_click")

	# Update defeat stats BEFORE resetting
	await _update_defeat_stats()

	# Reset dungeon manager
	main_game.reset_dungeon_for_new_run()
	
func _on_btn_new_run_mouse_entered() -> void:
	AudioManager.play_ui_sound("new_run_hover")

func _update_defeat_stats():
	"""Update player stats after defeat and record champion victory if applicable."""
	var player_id = Player.load_or_generate_uuid()
	var current_rank = DungeonManager.current_rank
	
	print("[CombatPanel] Player defeated at rank %d - updating stats..." % current_rank)
	
	# 1. Update player's death stats
	await SupabaseManager.update_player_after_death(player_id, current_rank)
	
	# 2. Check if boss was a champion (rank 6 only)
	if current_rank == 6:
		var boss_data = DungeonManager.current_boss_data
		var boss_id = boss_data.get("id", "")
		var is_shadow = boss_data.get("is_shadow", false)
		
		if not boss_id.is_empty() and not is_shadow:
			# Real champion defeated player - record their victory
			print("[CombatPanel] Champion %s defeated player - recording victory..." % boss_data.get("username"))
			await SupabaseManager.record_champion_victory(boss_id)
			print("[CombatPanel] Champion victory recorded (owner earns +1 ear)")
		elif is_shadow:
			print("[CombatPanel] Shadow champion defeated player - no stats updated")
	
	# 3. Reload profile to sync updated stats
	var profile = await SupabaseManager.get_player_profile(player_id)
	if not profile.is_empty():
		Player.load_profile_from_supabase(profile)
	
	print("[CombatPanel] Defeat stats updated")

func hide_death_panel():
	if death_panel:
		death_panel.visible = false
		visible = false



func _on_btn_enemy_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_enemy_mouse_entered() -> void:
	if !CombatManager.combat_active:
		#if current_enemy_entity.enemy_type == Enemy.EnemyType.REGULAR:
			#AudioManager.play_event_sound("monster_roar_1")
		CursorManager.set_combat_cursor()


func _on_btn_copy_pressed() -> void:
	var plain_text = CombatManager.combat_log

	# Strip img tags including their content (the resource path between tags)
	var img_regex = RegEx.new()
	img_regex.compile("\\[img[^\\]]*\\].*?\\[/img\\]")
	plain_text = img_regex.sub(plain_text, "", true)

	# Strip all remaining BBCode tags
	var tag_regex = RegEx.new()
	tag_regex.compile("\\[.*?\\]")
	plain_text = tag_regex.sub(plain_text, "", true)

	DisplayServer.clipboard_set(plain_text)

	# Brief visual feedback
	btn_copy.text = "COPIED!"
	await get_tree().create_timer(1.0).timeout
	btn_copy.text = "[Copy Log]"

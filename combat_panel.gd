class_name CombatPanel
extends Control

## Combat overlay panel that slides in from the right side of the screen
## Manages combat UI, displays enemy/player stats, and highlights inventory items

signal combat_ui_ready()
signal player_chose_fight()
signal player_chose_run()
signal combat_completed(player_won: bool)

enum PanelState {
	HIDDEN,
	PRE_COMBAT,   # Shows enemy with fight/run buttons
	IN_COMBAT,    # Active combat with log and controls
	POST_COMBAT   # Victory/defeat screen
}

# UI References
@onready var enemy_name_label: Label = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/VBoxContainer/HBoxContainer/boxEnemyName/lblEnemy
@onready var enemy_desc_label: RichTextLabel = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/VBoxContainer/lblEnemyDesc
@onready var enemy_sprite: TextureRect = $picEnemy

# CONTROL BOX
@onready var box_fight_run: VBoxContainer = $panelCONTROLS/PanelContainer/FightRunBox
@onready var box_combat_log: VBoxContainer = $panelCONTROLS/PanelContainer/CombatLogBox
@onready var btn_run: Button = $panelCONTROLS/PanelContainer/FightRunBox/HBoxContainer/btnRun
@onready var lbl_turn: Label = $panelCONTROLS/PanelContainer/CombatLogBox/lblTurn
@onready var lbl_speed: Label = $panelCONTROLS/PanelContainer/CombatLogBox/speedControls/lblSpeed


# Enemy stat displays
@onready var enemy_health_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statHealth
@onready var enemy_shield_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statShield
@onready var enemy_damage_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statDamage
@onready var enemy_agility_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statAgility
@onready var stat_container: PanelContainer = $CombatPanelTop/PanelContainer

# Status Effect Boxes
@onready var player_status_container: HBoxContainer = $CombatPanelTop/panelStatusPlayer/HBoxContainer/statusBox
@onready var enemy_status_container: HBoxContainer = $CombatPanelTop/panelStatusEnemy/statusBox

# Victory Panel
@onready var victory_panel: Panel = $VictoryPanel
@onready var death_panel: Panel = $DeathPanel
@onready var reward_label: Label = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxReward/panelReward/MarginContainer/HBoxContainer/lblRewardAmt
@onready var txt_history: RichTextLabel = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/txtHistory
@onready var txt_history_dead: RichTextLabel =$DeathPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/txtHistoryDead

# Animation
@onready var slide_animation: AnimationPlayer = $combatPanelAnim
@onready var player_anim: AnimationPlayer = $animPlayer
@onready var enemy_anim: AnimationPlayer = $animEnemy

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

var player_pos: Vector2 = Vector2(422, 262)
var enemy_pos: Vector2 = Vector2(695,180)

# Track pending status updates for batching
var pending_status_updates: Dictionary = {}  # {entity: [rules]}

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
	#CombatManager.status_applied.connect(_on_status_applied)   # JDM: - Remove this? 
	#CombatManager.status_removed.connect(_on_status_removed)   # JDM: - Remove this?
	CombatManager.status_proc.connect(spawn_status_proc_indicator)

	# --- Item/ability triggers
	CombatManager.item_rule_triggered.connect(_on_item_rule_triggered)
	CombatManager.enemy_ability_triggered.connect(_on_enemy_ability_triggered)
	
	# Special events
	CombatManager.entity_exposed.connect(_on_entity_exposed)
	CombatManager.entity_wounded.connect(_on_entity_wounded)

	# Connect to animation completion for item-based status effects
	#CombatManager.animation_manager.item_proc_complete.connect(_on_item_proc_complete)
	
	# Connect to status changes for turn-based procs (poison, burn, etc.)
	#CombatManager.status_handler.status_applied.connect(_on_status_data_changed)
	#CombatManager.status_handler.status_removed.connect(_on_status_data_changed)

func setup_for_combat(enemy_entity, inventory_slots: Array[ItemSlot], weapon_slot: ItemSlot):
	current_player_entity = Player
	inventory_item_slots = inventory_slots
	weapon_slot_ref = weapon_slot

	current_enemy_entity = enemy_entity.duplicate()  # Work with a copy
	current_enemy_entity.reset_to_base_values()

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
	
	_set_state(PanelState.PRE_COMBAT)

	# Reset turn counter
	set_turn_label("Battle Start")
	_update_speed_label(CombatSpeed.current_mode)

	# Update the RUN button stuff
	var can_run = current_player_entity.stats.agility > current_enemy_entity.stats.agility
	btn_run.disabled = !can_run
	if not can_run:
		btn_run.tooltip_text = "Enemy is too fast to escape!"
	
	# lets see.. i don't know
	show_panel()

func clear_statuses():
	# Clear status boxes at combat start
	for child in player_status_container.get_children():
		child.queue_free()
	for child in enemy_status_container.get_children():
		child.queue_free()

func show_panel():
	"""Slide the combat panel in from the right"""
	if is_visible:
		return
		
	visible = true
	is_visible = true
	
	slide_animation.play("open_Combat")
	#await slide_animation.animation_finished


	combat_ui_ready.emit()

func hide_panel():
	"""Slide the combat panel out to the right"""
	if not is_visible:
		return
	
	is_visible = false
	visible = false
	
	box_fight_run.visible = true
	box_combat_log.visible = false

	# Clear highlighted items
	_clear_all_highlights()

func _update_enemy_stats():
	if not current_enemy_entity:
		print("THERE IS NO ENEMY!!!!!!!!!!")
		return
	
	# HP
	enemy_health_stat.update_stat(Enums.Stats.HITPOINTS, current_enemy_entity.stats.hit_points_current, current_enemy_entity.stats.hit_points)

	# Shield stat
	enemy_shield_stat.update_stat(Enums.Stats.SHIELD, current_enemy_entity.stats.shield_current, current_enemy_entity.stats.shield_current)
	
	# Damage stat
	enemy_damage_stat.update_stat(Enums.Stats.DAMAGE, current_enemy_entity.stats.damage_current, current_enemy_entity.stats.damage_current)
	
	# Agility stat
	enemy_agility_stat.update_stat(Enums.Stats.AGILITY, current_enemy_entity.stats.agility_current, current_enemy_entity.stats.agility_current)



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
	print("IS THIS FUNCTION CALL UNNECESSARY????")
	box_fight_run.visible = false 
	box_combat_log.visible = true

func _on_combat_ended(winner, loser):
	var winner_name = CombatManager.get_entity_name(winner)
	var loser_name = CombatManager.get_entity_name(loser)
	
	if winner == current_player_entity:
		var gold_earned = CombatManager.calculate_gold_reward(loser) if loser is Enemy else 0
		if gold_earned > 0:
			reward_label.text = str(gold_earned)
			Player.add_gold(gold_earned)
	
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

	if winner == current_player_entity:
		slide_animation.play("show_victory")
		#await slide_animation.animation_finished
	else:
		death_panel.visible = true


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
	var entity_name = CombatManager.get_entity_name(entity)
	set_turn_label("Turn: " + str(turn_number) + " (" + entity_name + "'s turn)")

func _on_turn_ended(entity):
	_clear_all_highlights()


func _on_attack_executed(attacker, target, damage):
	var attacker_name = CombatManager.get_entity_name(attacker)
	var target_name = CombatManager.get_entity_name(target)

	if damage < 10:
		CameraShake.shake_medium()
	else:
		CameraShake.shake_heavy()

func _get_status_enum(status_name: String) -> Enums.StatusEffects:
	match status_name:
		"poison": return Enums.StatusEffects.POISON
		"burn": return Enums.StatusEffects.BURN
		"acid": return Enums.StatusEffects.ACID
		"thorns": return Enums.StatusEffects.THORNS
		_: return Enums.StatusEffects.NONE

func create_damage_indicator(target, amount: int, damage_stat: Enums.Stats, visual_info: Dictionary) -> void:
	"""Create a damage indicator at the appropriate position - called by AnimationManager"""
	var combat_item_proc = item_proc.instantiate()
	
	combat_item_proc.set_references()
	combat_item_proc.set_label(amount * -1)  # Negative for damage
	combat_item_proc.set_info(visual_info.get("info", "Damage!"))
	
	# Set visuals based on damage type
	if visual_info.has("status"):
		# Status effect damage - use status icon
		combat_item_proc.set_status_as_item_visuals(_get_status_enum(visual_info.status))
	elif visual_info.has("icon") and visual_info.icon:
		# Attack damage - use weapon icon
		combat_item_proc.set_item_visuals(visual_info.icon, visual_info.get("color", Color.WHITE))
	else:
		# Generic damage
		combat_item_proc.set_item_visuals(null, visual_info.get("color", Color.RED))
	
	# Set stat visual (shield or HP)
	combat_item_proc.set_stat_visuals(damage_stat)
	
	# Position based on target and stat
	add_child(combat_item_proc)
	var position_offset = Vector2(45, 50) if target == current_enemy_entity else Vector2(45, -50)
	
	if target == current_enemy_entity:
		# Enemy takes damage
		#if damage_stat == Enums.Stats.SHIELD or damage_stat == Enums.Stats.EXPOSED:
		#	combat_item_proc.global_position = enemy_shield_stat.global_position + position_offset
		#else:
		#	combat_item_proc.global_position = enemy_health_stat.global_position + position_offset
		combat_item_proc.global_position = enemy_pos
		
		combat_item_proc.run_animation(Enums.Party.PLAYER) # - change back to ENEMY to make it go downward
		_update_enemy_stats()
	else:
		# Player takes damage
		#if damage_stat == Enums.Stats.SHIELD or damage_stat == Enums.Stats.EXPOSED:
		#	combat_item_proc.position = main_game.stat_shield.global_position + position_offset
		#else:
		#	combat_item_proc.position = main_game.stat_health.global_position + position_offset
		combat_item_proc.global_position = player_pos
		
		combat_item_proc.run_animation(Enums.Party.PLAYER)
		Player.stats.stats_updated.emit()


func test_camera_shake():
	CameraShake.shake_medium()

func _on_damage_dealt(target, amount, taken_by):
	# JDM: ----- UNUSED?!?!?!
	var target_name = CombatManager.get_entity_name(target)

	if amount < 10:
		CameraShake.shake_medium()

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


func _on_status_applied(entity, status_name: Enums.StatusEffects, stacks: int):
	# JDM:  REMOVED: Status boxes now update after animation in CombatStatusHandler
	#if entity == Player:
	#	Player.status_updated.emit()
	#else:
	#	_update_enemy_status_effects()
	pass

func _on_status_removed(entity, status: Enums.StatusEffects, stacks: int):
	# JDM:  REMOVED: Status boxes now update after animation in CombatStatusHandler
	#if entity == Player:
	#	Player.status_updated.emit()	
	pass

func _on_item_rule_triggered(item: Item, rule: ItemRule, entity):
	pass

func spawn_item_proc_indicator(item: Item, rule: ItemRule, entity):
	var combat_item_proc = item_proc.instantiate()
	var _pos = Vector2(0,0)
	var offset = Vector2(45, -50)
	
	combat_item_proc.set_references()
	combat_item_proc.set_label(rule.effect_amount)		
	combat_item_proc.set_info(Enums.get_trigger_type_string(rule.trigger_type))
	combat_item_proc.set_item_visuals(item.item_icon, item.item_color)

	if rule.effect_type == Enums.EffectType.MODIFY_STAT:
		combat_item_proc.set_stat_visuals(rule.target_stat)
		if rule.target_stat == Enums.Stats.HITPOINTS:
			_pos = main_game.stat_health.global_position + offset
		if rule.target_stat == Enums.Stats.DAMAGE:
			_pos = main_game.stat_damage.global_position + offset
		if rule.target_stat == Enums.Stats.SHIELD:
			_pos = main_game.stat_shield.global_position + offset
		if rule.target_stat == Enums.Stats.AGILITY:
			_pos = main_game.stat_agility.global_position + offset	
		if rule.target_stat == Enums.Stats.GOLD:
			_pos = main_game.stat_gold.global_position + offset
	elif  rule.effect_type == Enums.EffectType.HEAL:
		combat_item_proc.set_stat_visuals(Enums.Stats.HITPOINTS)
	elif  rule.effect_type == Enums.EffectType.DEAL_DAMAGE:
		combat_item_proc.set_status_visuals(Enums.StatusEffects.BLEED) # JDM --- NEED TO TEST THIS, NOT FULLY WORKING
	elif rule.effect_type == Enums.EffectType.APPLY_STATUS:
		combat_item_proc.set_status_visuals(rule.target_status)
		_pos = main_game.loop_through_player_items_for_position(item)

	add_child(combat_item_proc)
	combat_item_proc.position = _pos

	var entity_name: String = CombatManager.get_entity_name(entity)

	if (entity_name == "Player" && rule.target_type == Enums.TargetType.SELF):
		combat_item_proc.position = player_pos
		combat_item_proc.run_animation(Enums.Party.PLAYER)

	if (entity_name == "Player" && rule.target_type == Enums.TargetType.ENEMY):
		combat_item_proc.position = enemy_pos
		combat_item_proc.run_animation(Enums.Party.PLAYER)

	if (entity_name != "Player" && rule.target_type == Enums.TargetType.SELF):
		combat_item_proc.position = enemy_pos
		combat_item_proc.run_animation(Enums.Party.PLAYER)

	if (entity_name != "Player" && rule.target_type == Enums.TargetType.ENEMY):
		combat_item_proc.position = player_pos
		combat_item_proc.run_animation(Enums.Party.PLAYER)


	# Update enemy stats if they were damaged
	#if entity == Player:
	#	combat_item_proc.run_animation(Enums.Party.PLAYER)
	#else:
	#	combat_item_proc.run_animation(Enums.Party.ENEMY)


func spawn_status_proc_indicator(entity, _status: Enums.StatusEffects, _stat: Enums.Stats, value: int):
	var combat_item_proc = item_proc.instantiate()
	
	combat_item_proc.set_references()
	combat_item_proc.set_label(value)	
	combat_item_proc.set_info("Status Effect")	
	combat_item_proc.set_status_as_item_visuals(_status)
	combat_item_proc.set_stat_visuals(_stat)

	add_child(combat_item_proc)

	if entity == current_player_entity:
		combat_item_proc.position = player_pos
	else:
		combat_item_proc.position = enemy_pos
	combat_item_proc.run_animation(Enums.Party.PLAYER)

	#if entity == current_player_entity:
	#	combat_item_proc.run_animation(Enums.Party.PLAYER)
	#	if _stat == Enums.Stats.SHIELD || _stat == Enums.Stats.EXPOSED:
	#		combat_item_proc.global_position = main_game.stat_shield.global_position + Vector2(45,-50)
	#	else:
	#		combat_item_proc.global_position = main_game.stat_health.global_position + Vector2(45,-50)
	#else:
	#	combat_item_proc.run_animation(Enums.Party.ENEMY)
	#	if _stat == Enums.Stats.SHIELD || _stat == Enums.Stats.EXPOSED:
	#		combat_item_proc.global_position = enemy_shield_stat.global_position + Vector2(45,50)
	#	else:
	#		combat_item_proc.global_position = enemy_health_stat.global_position + Vector2(45,50)


func _on_enemy_ability_triggered(ability: EnemyAbility, entity):
	pass

func _on_entity_exposed(entity):
	pass

func _on_entity_wounded(entity):
	pass

func player_joins_combat_anim():
	player_anim.play("player_ready")

func anim_close_panels():
	slide_animation.play("close_combat")

func anim_player_hit():
	player_anim.play(CombatSpeed.get_animation_variant("player_hit"))

func anim_enemy_hit():
	enemy_sprite.texture = current_enemy_entity.sprite_hit
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_hit"))

func anim_enemy_die():
	enemy_sprite.texture = current_enemy_entity.sprite_hit
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_die"))

func anim_player_idle():
	player_anim.play(CombatSpeed.get_animation_variant("player_idle"))

func anim_enemy_idle():
	enemy_sprite.texture = current_enemy_entity.sprite
	enemy_anim.play(CombatSpeed.get_animation_variant("enemy_idle"))

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
			set_speed_label("⏸ PAUSED")
		CombatSpeed.CombatSpeedMode.NORMAL:
			set_speed_label("▶ 1x")
		CombatSpeed.CombatSpeedMode.FAST:
			set_speed_label("▶▶ 2x")
		CombatSpeed.CombatSpeedMode.VERY_FAST:
			set_speed_label("▶▶▶ 3.5x")
		CombatSpeed.CombatSpeedMode.INSTANT:
			set_speed_label("⚡ INSTANT")



func _on_btn_run_pressed() -> void:
	# Emit signal for room event
	player_chose_run.emit()
	
	# Slide out
	await hide_panel()
	
	# Complete without combat
	combat_completed.emit(false)

func _on_btn_fight_pressed() -> void:
	box_fight_run.visible = false
	box_combat_log.visible = true

	# Transition to combat state
	_set_state(PanelState.IN_COMBAT)
	
	# Emit signal for room event
	player_chose_fight.emit()
	
	# Start the actual combat
	CombatManager.start_combat(current_player_entity, current_enemy_entity)

func _set_state(new_state: PanelState):
	current_state = new_state
	

func _on_btn_pause_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.PAUSE)
	_update_speed_label(CombatSpeed.CombatSpeedMode.PAUSE)

func _on_btn_play_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL)
	_update_speed_label(CombatSpeed.CombatSpeedMode.NORMAL)

func _on_btn_fast_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.FAST)
	_update_speed_label(CombatSpeed.CombatSpeedMode.FAST)

func _on_btn_very_fast_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.VERY_FAST)
	_update_speed_label(CombatSpeed.CombatSpeedMode.VERY_FAST)

func set_turn_label(_string: String):
	lbl_turn.text = _string

func set_speed_label(_string: String):
	lbl_speed.text = _string

func _on_btn_continue_pressed() -> void:
	slide_animation.play("hide_victory")
	#await slide_animation.animation_finished

	await hide_panel()
	combat_completed.emit(true)


func _on_btn_history_pressed() -> void:
	txt_history.visible = !txt_history.visible
	txt_history.text = CombatManager.combat_log


func rebuild_status_boxes(entity):
	var container = player_status_container if entity == current_player_entity else enemy_status_container
	
	# Get current boxes to check for changes
	var existing_boxes: Dictionary = {}
	for child in container.get_children():
		if child is StatusBox:
			existing_boxes[child.status] = child
	
	# Track which statuses are currently active
	var active_statuses: Dictionary = {}
	
	# Check all status types
	for status_value in Enums.StatusEffects.values():
		var status: Enums.StatusEffects = status_value
		var stacks = entity.status_effects.get_status_value(status)
		
		if stacks > 0:
			active_statuses[status] = stacks
			
			if existing_boxes.has(status):
				# Update existing box with animation
				var box = existing_boxes[status]
				_update_status_box_value(box, stacks)
				existing_boxes.erase(status)  # Mark as handled
			else:
				# Create new box with spawn animation
				_create_status_box(container, status, stacks)
	
	# Remove boxes for statuses that are now 0
	for status in existing_boxes.keys():
		var box = existing_boxes[status]
		_remove_status_box(box)

func _create_status_box(container: HBoxContainer, status: Enums.StatusEffects, stacks: int):
	var box = status_box.instantiate()
	container.add_child(box)
	box.set_status(status, stacks)
	
	# Spawn animation
	box.scale = Vector2.ZERO
	box.modulate.a = 0.0
	box.custom_minimum_size = Vector2(110, 60)
	box.pivot_offset = Vector2(55, 30)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(box, "modulate:a", 1.0, 0.15)


func _update_status_box_value(box: StatusBox, new_stacks: int):
	var old_value = int(box.lbl_amount.text)
	
	if old_value == new_stacks:
		return  # No change
	
	# Pulse animation
	var tween = create_tween()
	tween.tween_property(box, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
	
	# Lerp the number
	var lerp_tween = create_tween()
	var duration = 0.25
	var steps = 10
	var step_duration = duration / steps
	
	for step in range(steps + 1):
		var progress = float(step) / float(steps)
		var value = lerp(old_value, new_stacks, progress)
		lerp_tween.tween_callback(func(): box.lbl_amount.text = str(int(value))).set_delay(step_duration)

func _remove_status_box(box: StatusBox):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(box, "modulate:a", 0.0, 0.15)
	await tween.finished
	box.queue_free()


func _on_btn_instant_pressed() -> void:
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.INSTANT)
	_update_speed_label(CombatSpeed.CombatSpeedMode.INSTANT)

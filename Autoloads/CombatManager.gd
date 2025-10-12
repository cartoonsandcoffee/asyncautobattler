extends Node

## Central combat coordinator - delegates to specialized sub-systems
## This is the main autoload that orchestrates combat flow

# --- Combat flow signals
signal combat_started(player_entity, enemy_entity)
signal turn_started(entity)
signal turn_ended(entity)
signal combat_ended(winner, loser)

# --- State change signals (forwarded from sub-systems)
signal stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int)
signal status_applied(entity, status: Enums.StatusEffects, stacks: int)
signal status_removed(entity, status: Enums.StatusEffects, stacks: int)
signal status_proc(entity, status: Enums.StatusEffects, stat: Enums.Stats, value: int)
signal healing_applied(target, amount)

# --- Special event signals
signal entity_exposed(entity)
signal entity_wounded(entity)
signal item_rule_triggered(item: Item, rule: ItemRule, entity)
signal enemy_ability_triggered(ability: EnemyAbility, entity)

# Combat entities
var player_entity
var enemy_entity
var current_turn_entity

# Combat state
var combat_active: bool = false
var turn_number: int = 0
var combat_log: String = ""

# Special trigger tracking (used by stat_handler)
var player_exposed_triggered: bool = false
var enemy_exposed_triggered: bool = false
var player_wounded_triggered: bool = false
var enemy_wounded_triggered: bool = false

# === SUB-SYSTEMS ===
var animation_manager: AnimationManager
var stat_handler: CombatStatHandler
var status_handler: CombatStatusHandler
var item_processor: CombatItemProcessor
var condition_evaluator: CombatConditionEvaluator
var damage_system: CombatDamageSystem
var effect_executor: CombatEffectExecutor

func _ready():
	_initialize_systems()
	_connect_subsystem_signals()

func _initialize_systems():
	"""Initialize all combat sub-systems in the correct order."""
	# Animation system
	animation_manager = AnimationManager.new()
	add_child(animation_manager)
	
	# Core handlers (no dependencies)
	stat_handler = CombatStatHandler.new(self)
	add_child(stat_handler)
	
	status_handler = CombatStatusHandler.new(self, stat_handler)
	add_child(status_handler)
	
	item_processor = CombatItemProcessor.new(self)
	add_child(item_processor)
	
	# Systems that depend on handlers
	condition_evaluator = CombatConditionEvaluator.new(self, stat_handler, status_handler)
	add_child(condition_evaluator)
	
	damage_system = CombatDamageSystem.new(self, stat_handler, status_handler)
	add_child(damage_system)
	
	effect_executor = CombatEffectExecutor.new(self, stat_handler, status_handler, condition_evaluator, damage_system)
	add_child(effect_executor)

func _connect_subsystem_signals():
	"""Connect sub-system signals to forward them to CombatManager."""
	# Stat handler signals
	stat_handler.stat_changed.connect(_on_stat_changed)
	stat_handler.stat_gain_triggered.connect(_on_stat_gain_triggered)
	stat_handler.stat_loss_triggered.connect(_on_stat_loss_triggered)
	stat_handler.wounded_triggered.connect(_on_wounded_triggered)
	stat_handler.exposed_triggered.connect(_on_exposed_triggered)
	stat_handler.one_hitpoint_left_triggered.connect(_on_one_hitpoint_left_triggered)
	stat_handler.death_triggered.connect(_on_death_triggered)
	
	# Status handler signals
	status_handler.status_applied.connect(_on_status_applied)
	status_handler.status_removed.connect(_on_status_removed)
	status_handler.status_gained_triggered.connect(_on_status_gained_triggered)
	status_handler.status_removed_triggered.connect(_on_status_removed_triggered)
	
	# Damage system signals
	damage_system.healing_applied.connect(_on_healing_applied)

# ===== COMBAT FLOW =====

func start_combat(player, enemy):
	# ---- Initialize and begin combat between player and enemy.
	combat_log = ""
	add_to_combat_log_string("=== COMBAT STARTED ===\n", Color.WHITE, true)
	
	# Store combat entities
	player_entity = player
	enemy_entity = enemy
	
	# Reset combat state
	combat_active = true
	turn_number = 0
	stat_handler.reset_combat_state()
	effect_executor.reset_recursion_depth()
	item_processor.reset_all_items(player_entity)
	item_processor.reset_all_items(enemy_entity)
	
	# Reset entities to base values
	player_entity.stats.reset_to_base_values()
	enemy_entity.stats.reset_to_base_values()
	
	# Initialize animation manager with combat panel
	var combat_panel = get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		animation_manager.initialize(combat_panel)
	
	# Emit combat started signal
	combat_started.emit(player_entity, enemy_entity)
	
	# MILESTONE: Battle Start
	animation_manager.play_milestone("Battle Start")
	await animation_manager.milestone_complete
	
	# Determine turn order
	var first_entity = player_entity if player_entity.stats.agility >= enemy_entity.stats.agility else enemy_entity
	var second_entity = enemy_entity if first_entity == player_entity else player_entity
	
	add_to_combat_log_string("Turn order: " + get_entity_name(first_entity) + " goes first.")
	
	# Process battle start events
	await process_battle_start_events(first_entity, second_entity)
	
	# Start main combat loop
	await combat_loop(first_entity, second_entity)

func process_battle_start_events(first_entity, second_entity):
	# -- Process BATTLE_START trigger for both entities in turn order.
	add_to_combat_log_string("\n--- Battle Start Events ---", Color.CYAN)
	
	# First entity's battle start items
	await process_entity_items_sequentially(first_entity, Enums.TriggerType.BATTLE_START)
	
	# Second entity's battle start items
	await process_entity_items_sequentially(second_entity, Enums.TriggerType.BATTLE_START)

func combat_loop(first_entity, second_entity):
	# --- Main combat loop - alternates turns until combat ends.
	while combat_active:
		turn_number += 1

		# - JDM: Each execute_turn used to have a check to make sure the entity wasn't dead, is that still necessary?

		# First entity's turn
		await execute_turn(first_entity)
		if not combat_active:
			break
		
		# Second entity's turn
		await execute_turn(second_entity)
		if not combat_active:
			break
	
	# Combat ended - cleanup
	await end_combat_gracefully()

func execute_turn(entity):
	# Execute a single entity's turn.
	current_turn_entity = entity
	
	# MILESTONE: Turn Start
	animation_manager.play_milestone("Turn Start", {"entity": entity, "turn_number": turn_number})
	await animation_manager.milestone_complete
	
	turn_started.emit(entity)
	add_to_combat_log_string("\n--- %s's Turn %d ---" % [get_entity_name(entity), turn_number], Color.YELLOW)
	
	# Reset per-turn item states
	item_processor.reset_per_turn_items(entity)
	
	# Process turn-start status effects
	await status_handler.process_turn_start_status_effects(entity)
	
	# Process countdown/charge rules for items
	#await process_countdown_rules()

	# Process TURN_START items
	await process_entity_items_sequentially(entity, Enums.TriggerType.TURN_START)
	
	if entity.status_effects.stun > 0:
		# If they're stunned, skip attack
		add_to_combat_log_string(get_entity_name(entity) + " is stunned! Turn skipped.")
		status_handler.remove_status(entity, Enums.StatusEffects.STUN, 1)
	else:
		# Execute attacks
		await execute_attack_sequence(entity)
	
	# Process turn-end status effects
	await status_handler.process_turn_end_status_effects(entity)
	
	# Turn end
	turn_ended.emit(entity)
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func execute_attack_sequence(attacker):
	"""Execute all of an entity's attack strikes."""
	var target = enemy_entity if attacker == player_entity else player_entity
	var strikes = attacker.stats.strikes
	
	add_to_combat_log_string("%s attacks with %d strike(s)!" % [get_entity_name(attacker), strikes])
	
	for strike in range(strikes):
		if not combat_active:
			break
		
		# Play attack animation
		animation_manager.play_attack_animation(attacker, target)
		await animation_manager.wait_for_current_sequence()
		
		# Deal damage
		var damage = attacker.stats.damage_current
		await damage_system.apply_damage(target, damage, attacker, "attack")
		
		# Process ON_HIT items
		await process_entity_items_sequentially(attacker, Enums.TriggerType.ON_HIT)
		
		# Small gap between strikes
		if strike < strikes - 1:
			await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap") * 0.5)

# ===== ITEM PROCESSING =====

func process_entity_items_sequentially(entity, trigger_type: Enums.TriggerType, trigger_stat = Enums.Stats.NONE):
	# Process all items that match the trigger type for an entity.
	# Items are processed sequentially with animations.
	
	# CONDITION CHAIN BEHAVIOR:
	# - If a rule has a condition and it FAILS, all subsequent rules on that item are SKIPPED
	# - This allows complex conditional chains like:
	#   Rule 1: If HP > 50, lose 10 HP
	#   Rule 2: Gain 5 damage
	#   Rule 3: Apply 2 poison
	#   If Rule 1's condition fails, Rules 2 and 3 won't execute

	# Collect triggered items through item processor
	var triggered_items = item_processor.process_items(entity, trigger_type, trigger_stat)
	
	if triggered_items.is_empty():
		return
	
	add_to_combat_log_string("  %s items triggered:" % Enums.get_trigger_type_string(trigger_type), Color.LIGHT_BLUE)
	
	# Start item sequence animation
	var item_list = triggered_items.map(func(data): return data.item)
	animation_manager.play_item_sequence(item_list, entity, Enums.get_trigger_type_string(trigger_type))
	
	# Process each item - but group by item to handle condition chains
	var current_item = null
	var continue_processing_item = true
	
	for item_data in triggered_items:
		var item = item_data.item
		var rule = item_data.rule
		var slot_index = item_data.slot_index
		
		# Check if this is a new item (reset continuation flag)
		if item != current_item:
			current_item = item
			continue_processing_item = true
		
		# Skip if previous rule on this item failed its condition
		if not continue_processing_item:
			add_to_combat_log_string("    ⏭ Skipping rule due to failed condition in chain", Color.GRAY)
			continue
		
		# Emit trigger signal
		item_rule_triggered.emit(item, rule, entity)
		
		# Execute the rule through effect executor - This is where the condition gets evaluated
		var target = _get_rule_target(entity, rule.target_type)
		var success = await effect_executor.execute_item_rule(item, rule, entity, target)
		
		# If rule failed (condition not met), stop processing this item's remaining rules
		if not success:
			continue_processing_item = false
			add_to_combat_log_string("    🚫 Condition failed - remaining rules on this item will be skipped", Color.ORANGE)
		
		# Wait for animation
		await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc") * 0.7)
	
	# Wait for all animations to complete
	await animation_manager.wait_for_current_sequence()

func process_entity_items_with_status(entity, trigger_type: Enums.TriggerType, trigger_status: Enums.StatusEffects):
	"""Process items that trigger based on status effects."""
	var triggered_items = item_processor.process_items_with_status(entity, trigger_type, trigger_status)
	
	if triggered_items.is_empty():
		return
	
	add_to_combat_log_string("  %s (%s) items triggered:" % [Enums.get_trigger_type_string(trigger_type), Enums.get_status_string(trigger_status)], Color.LIGHT_BLUE)
	
	var item_list = triggered_items.map(func(data): return data.item)
	animation_manager.play_item_sequence(item_list, entity, Enums.get_trigger_type_string(trigger_type))
	
	for item_data in triggered_items:
		var item = item_data.item
		var rule = item_data.rule
		
		item_rule_triggered.emit(item, rule, entity)
		
		var target = _get_rule_target(entity, rule.target_type)
		await effect_executor.execute_item_rule(item, rule, entity, target)
		
		await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc") * 0.7)
	
	await animation_manager.wait_for_current_sequence()

# ===== COMBAT END =====

func end_combat_gracefully():
	"""Clean up and end combat properly."""
	await animation_manager.wait_for_current_sequence()
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	
	# Determine winner/loser
	var winner = player_entity if player_entity.stats.hit_points_current > 0 else enemy_entity
	var loser = enemy_entity if winner == player_entity else player_entity
	
	# MILESTONE: Battle End
	animation_manager.play_milestone("Battle End", {"winner": winner, "loser": loser})
	await animation_manager.milestone_complete
	
	# Award gold if player won
	if winner == player_entity:
		var gold_reward = calculate_gold_reward(loser)
		player_entity.stats.gold += gold_reward
		add_to_combat_log_string("You earned %d gold!" % gold_reward, Color.GOLD)
	
	# Reset entities
	player_entity.stats.reset_stats_after_combat()
	enemy_entity.stats.reset_stats_after_combat()
	status_handler.reset_all_statuses(player_entity)
	status_handler.reset_all_statuses(enemy_entity)
	
	# Emit combat ended
	combat_ended.emit(winner, loser)
	add_to_combat_log_string("=== COMBAT ENDED ===", Color.WHITE)

func calculate_gold_reward(loser) -> int:
	"""Calculate gold reward for defeating an enemy."""
	if loser is Enemy:
		return loser.stats.gold
	return 0

func process_countdown_rules(entity):
	# JDM: NEEDS TO BE FIXED, DOES NOT WORK
	# --- The current_countdown needs to be on the item level I think?
	# --- Or this is unnecessary with the occurrence every X handling

	#for item in item_processor.process_items(entity, Enums.TriggerType.COUNTDOWN):
	#	for rule in item.rules:
	#		if rule.trigger_type == Enums.TriggerType.COUNTDOWN:
	#			rule.current_countdown -= 1
	#			if rule.current_countdown <= 0:
	#                # Trigger the rule
	#				await effect_executor.execute_item_rule(item, rule, entity, entity)
	#                # Reset if recurs
	#				if rule.countdown_recurs:
	#					rule.current_countdown = rule.countdown_value
	pass


# ===== SIGNAL HANDLERS (Forward from sub-systems) =====

func _on_stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int):
	"""Forward stat_changed signal."""
	stat_changed.emit(entity, stat, old_value, new_value)

func _on_stat_gain_triggered(entity, stat: Enums.Stats, amount: int):
	"""Handle ON_STAT_GAIN trigger."""
	await process_entity_items_sequentially(entity, Enums.TriggerType.ON_STAT_GAIN, stat)

func _on_stat_loss_triggered(entity, stat: Enums.Stats, amount: int):
	"""Handle ON_STAT_LOSS trigger."""
	await process_entity_items_sequentially(entity, Enums.TriggerType.ON_STAT_LOSS, stat)

func _on_wounded_triggered(entity):
	"""Handle WOUNDED trigger."""
	add_to_combat_log_string(get_entity_name(entity) + " is WOUNDED!", Color.RED)
	entity_wounded.emit(entity)
	await process_entity_items_sequentially(entity, Enums.TriggerType.WOUNDED)

func _on_exposed_triggered(entity):
	"""Handle EXPOSED trigger."""
	add_to_combat_log_string(get_entity_name(entity) + " is EXPOSED!", Color.DODGER_BLUE)
	entity_exposed.emit(entity)
	await process_entity_items_sequentially(entity, Enums.TriggerType.EXPOSED)

func _on_one_hitpoint_left_triggered(entity):
	"""Handle ONE_HITPOINT_LEFT trigger."""
	add_to_combat_log_string(get_entity_name(entity) + " is at ONE HITPOINT!", Color.ORANGE)
	await process_entity_items_sequentially(entity, Enums.TriggerType.ONE_HITPOINT_LEFT)

func _on_death_triggered(entity):
	"""Handle entity death."""
	add_to_combat_log_string(get_entity_name(entity) + " has died!", Color.RED)
	combat_active = false  # End combat
	
	# Check for ON_KILL trigger (for the killer)
	var killer = enemy_entity if entity == player_entity else player_entity
	await process_entity_items_sequentially(killer, Enums.TriggerType.ON_KILL)

func _on_status_applied(entity, status: Enums.StatusEffects, stacks: int):
	"""Forward status_applied signal."""
	status_applied.emit(entity, status, stacks)

func _on_status_removed(entity, status: Enums.StatusEffects, stacks: int):
	"""Forward status_removed signal."""
	status_removed.emit(entity, status, stacks)

func _on_status_gained_triggered(entity, status: Enums.StatusEffects):
	"""Handle ON_STATUS_GAINED trigger."""
	await process_entity_items_with_status(entity, Enums.TriggerType.ON_STATUS_GAINED, status)

func _on_status_removed_triggered(entity, status: Enums.StatusEffects):
	"""Handle ON_STATUS_REMOVED trigger."""
	await process_entity_items_with_status(entity, Enums.TriggerType.ON_STATUS_REMOVED, status)

func _on_healing_applied(target, amount):
	"""Forward healing_applied signal."""
	healing_applied.emit(target, amount)

# ===== UTILITY FUNCTIONS =====

func _get_rule_target(source_entity, target_type: Enums.TargetType):
	"""Get the target entity for a rule based on target type."""
	match target_type:
		Enums.TargetType.SELF:
			return source_entity
		Enums.TargetType.ENEMY:
			return enemy_entity if source_entity == player_entity else player_entity
		Enums.TargetType.BOTH:
			return source_entity  # TODO: Handle both
		Enums.TargetType.RANDOM:
			return player_entity if randf() > 0.5 else enemy_entity
	return source_entity

func get_entity_name(entity) -> String:
	"""Get the display name of an entity."""
	if entity == player_entity:
		return "Player"
	elif entity == enemy_entity:
		if entity is Enemy:
			return entity.enemy_name
		return "Enemy"
	return "Unknown"

func add_to_combat_log_string(_string: String, _color: Color = Color.GRAY, is_bold: bool = false):
	"""Add text to combat log"""
	var color_str: String = _color.to_html()
	var final_string: String = "[color=#" + color_str + "]" + _string + "[/color]"

	if is_bold:
		final_string = "[b]" + final_string + "[/b]"

	combat_log += final_string + "\n"

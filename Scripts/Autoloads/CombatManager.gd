extends Node

## Central combat coordinator - delegates to specialized sub-systems
## This is the main autoload that orchestrates combat flow

# --- Combat flow signals
signal combat_started(player_entity, enemy_entity)
signal turn_started(entity, turn_number)
signal turn_ended(entity)
signal combat_ended(winner, loser)
signal strike_ui_update_requested(entity, strikes_remaining: int, strikes_next_turn: int)

# --- State change signals (forwarded from sub-systems)
signal stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int)
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

# Extra special handling used for item to allow exposed to trigger twice
var player_can_exposed_twice: bool = false
var enemy_can_exposed_twice: bool = false
var player_has_exposed_twice: bool = false
var enemy_has_exposed_twice: bool = false

# RULE RECURSION PROTECTION
const MAX_STAT_TRIGGER_DEPTH = 3
var current_stat_trigger_depth = 0
const MAX_STATUS_TRIGGER_DEPTH = 3
var current_status_trigger_depth = 0

var death_processing: bool = false
var trigger_type_stack: Array[Enums.TriggerType] = []

const MAX_COMBAT_TURNS: int = 25  # Failsafe to prevent infinite combat

# === SUB-SYSTEMS ===
var animation_manager: AnimationManager
var stat_handler: CombatStatHandler
var status_handler: CombatStatusHandler
var item_processor: CombatItemProcessor
var condition_evaluator: CombatConditionEvaluator
var damage_system: CombatDamageSystem
var effect_executor: CombatEffectExecutor
var game_colors: GameColors

var _initialized: bool = false

func _ready():
	pass

func initialize():
	if _initialized:
		return
	_initialized = true

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

	game_colors = GameColors.new()

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
	status_handler.status_gained_triggered.connect(_on_status_gained_triggered)
	status_handler.status_removed_triggered.connect(_on_status_removed_triggered)
	status_handler.enemy_status_gained_triggered.connect(_on_enemy_status_gained_triggered)
	status_handler.enemy_status_removed_triggered.connect(_on_enemy_status_removed_triggered)
	status_handler.acid_proc_triggered.connect(_on_acid_proc_triggered)
	status_handler.overheal_triggered.connect(_on_overheal_triggered)
	
	effect_executor.non_weapon_damage_triggered.connect(_on_non_weapon_damage_triggered)

	# Damage system signals
	damage_system.healing_applied.connect(_on_healing_applied)

# ===== COMBAT FLOW =====

func start_combat(player, enemy):
	# ---- Initialize and begin combat between player and enemy.

	combat_log = ""
	add_to_combat_log_string(CombatLog.fmt_combat_alert("=== BATTLE STARTED ==="))
	
	# Store combat entities
	player_entity = player
	enemy_entity = enemy
	
	# Reset combat state
	combat_active = true
	turn_number = 0
	current_stat_trigger_depth = 0
	current_status_trigger_depth = 0
	stat_handler.reset_combat_state()
	effect_executor.reset_recursion_depth()
	item_processor.reset_all_items(player_entity)
	item_processor.reset_all_items(enemy_entity)
	
	# Check set bonuses for both entities
	SetBonusManager.check_set_bonuses(player_entity)
	SetBonusManager.check_set_bonuses(enemy_entity)
	
	# Reset entities to base values
	player_entity.stats.reset_to_base_values()
	enemy_entity.stats.reset_to_base_values()
	
	# Reset temp modifiers
	player_entity.stats.reset_combat_temp_modifiers()
	enemy_entity.stats.reset_combat_temp_modifiers()
	
	# Initial damage recalculation (applies persistent conditionals)
	stat_handler.recalculate_damage(player_entity)
	stat_handler.recalculate_damage(enemy_entity)

	# Initialize animation manager with combat panel
	var combat_panel = get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		animation_manager.initialize(combat_panel)
	
	# Emit combat started signal
	combat_started.emit(player_entity, enemy_entity)
	
	# MILESTONE: Battle Start
	if not CombatSpeed.is_instant_mode():
		animation_manager.play_milestone("Battle Start")
		await animation_manager.milestone_complete
	
	# Determine turn order
	var first_entity = player_entity if player_entity.stats.agility >= enemy_entity.stats.agility else enemy_entity
	var second_entity = enemy_entity if first_entity == player_entity else player_entity
	
	add_to_combat_log_string(CombatLog.center("(Turn order: " + CombatLog.color_entity(get_entity_name(first_entity)) + " goes first.)"))
	
	# Process battle start events
	await process_battle_start_events(first_entity, second_entity)
	
	# Start main combat loop
	await combat_loop(first_entity, second_entity)

func process_battle_start_events(first_entity, second_entity):
	# -- Process BATTLE_START trigger for both entities in turn order.

	# First entity's battle start items
	await process_entity_items_sequentially(first_entity, Enums.TriggerType.BATTLE_START)
	
	# - Wait for first wave of BATTLE START items to proc
	if animation_manager and animation_manager.combat_panel:
		await animation_manager.combat_panel.wait_for_indicator_queue_to_finish()

	# Second entity's battle start items
	await process_entity_items_sequentially(second_entity, Enums.TriggerType.BATTLE_START)

	# - Wait for second wave of BATTLE START items to proc
	if animation_manager and animation_manager.combat_panel:
		await animation_manager.combat_panel.wait_for_indicator_queue_to_finish()


func combat_loop(first_entity, second_entity):
	# --- Main combat loop - alternates turns until combat ends.
	while combat_active:
		turn_number += 1

		# NEW: Check turn limit failsafe
		if turn_number > MAX_COMBAT_TURNS:
			add_to_combat_log_string("\n[center][b]--- TURN LIMIT REACHED ---[/b][/center]", Color.YELLOW)
			add_to_combat_log_string("[center]Combat has gone on too long![/center]", Color.ORANGE)
			add_to_combat_log_string("[center]%s wins by default![/center]" % color_entity("Player"), Color.GOLD)
			
			# Player wins by default
			combat_active = false 
			break

		# Recalculate damage with fresh turn-temp values
		stat_handler.recalculate_damage(player_entity)
		stat_handler.recalculate_damage(enemy_entity)

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

	var target = enemy_entity if entity == player_entity else player_entity

	# -- MILESTONE: Turn Start
	#animation_manager.play_milestone("Turn Start", {"entity": entity, "turn_number": turn_number})
	#await animation_manager.milestone_complete
	
	turn_started.emit(entity, turn_number)
	add_to_combat_log_string(CombatLog.fmt_turn_start(get_entity_name(entity),turn_number))

	# Reset per-turn item states
	item_processor.reset_per_turn_items(entity)
	
	# Process turn-start status effects
	await status_handler.process_turn_start_status_effects(entity)
	
	# CHECK 1: Did entity die from status effects?
	if not combat_active:
		return
		
	# Process countdown/charge rules for items
	await process_countdown_rules(entity)

	# Process TURN_START items
	await process_entity_items_sequentially(entity, Enums.TriggerType.TURN_START)
	
	# CHECK 2: Still alive?
	if not combat_active:
		return

	# JDM - timing wait for all turn start procs to finish
	if animation_manager and animation_manager.combat_panel:
		await animation_manager.combat_panel.wait_for_indicator_queue_to_finish()

	# Execute attacks
	await execute_attack_sequence(entity)
	
	# CHECK 5: Did attacks kill someone?
	if not combat_active:
		return
			
	# Process turn-end status effects
	await status_handler.process_turn_end_status_effects(entity)
	# Remove opponent's thorns if they were triggered
	await status_handler.process_thorns_removal(target)

	# Turn end
	turn_ended.emit(entity)
	await process_entity_items_sequentially(entity, Enums.TriggerType.TURN_END)

	# JDM: wait for items to finish procing at turn end
	if animation_manager and animation_manager.combat_panel:
		await animation_manager.combat_panel.wait_for_indicator_queue_to_finish()

	#await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func execute_attack_sequence(attacker):
	# === Execute all of an entity's attack strikes. ===

	var target = enemy_entity if attacker == player_entity else player_entity

	# Capture strikes for THIS attack sequence
	var strikes_this_turn = attacker.stats.strikes_current
	
	add_to_combat_log_string(CombatLog.bold("%s ATTACKS with %s (for %s per)" % [
		color_entity(get_entity_name(attacker)),
		color_text(str(strikes_this_turn), Color.WHITE) + " " + CombatLog.color_stat(Enums.Stats.STRIKES),
		color_text(str(attacker.stats.damage_current), Color.WHITE) + " " + CombatLog.color_stat(Enums.Stats.DAMAGE)
	]))

	# Reset strikes to base (ready to accumulate next turn bonuses from ON_HIT)
	attacker.stats.strikes_current = attacker.stats.strikes
	# Local countdown for UI display
	var strikes_remaining = strikes_this_turn

	for strike in range(strikes_this_turn):
		if attacker.inventory.weapon_slot && attacker.inventory.weapon_slot.cant_attack:
			break

		if not combat_active:
			break
		
		# Emit UI update with current countdown and next turn preview
		strike_ui_update_requested.emit(attacker, strikes_remaining, attacker.stats.strikes_current)

		if attacker.status_effects.stun > 0:
			# If they're stunned, skip attack
			add_to_combat_log_string(color_entity(get_entity_name(attacker)) + " is STUNNED! Attack skipped.")
			status_handler.remove_status(attacker, Enums.StatusEffects.STUN, 1)
			status_proc.emit(attacker, Enums.StatusEffects.STUN, Enums.Stats.STRIKES, -1)
			await CombatSpeed.create_timer(CombatSpeed.get_duration("attack_gap"))  # -- just to make sure the anim shows turn_start procs
			strikes_remaining -= 1
			continue

		# Play attack animation
		animation_manager.play_attack_animation(attacker, target)
		await animation_manager.wait_for_current_sequence()

		strikes_remaining -= 1

		# Deal damage
		var damage: int = attacker.stats.damage_current

		# -- APPLY BLIND IF PRESENT
		if attacker.status_effects.blind > 0:
			damage = int(ceil(float(damage) / 2))

		await damage_system.apply_damage(target, damage, attacker, "attack")
		
		# Process ON_HIT items
		await process_entity_items_sequentially(attacker, Enums.TriggerType.ON_HIT)
		
		if not combat_active:
			break

		# JDM: wait for items to finish procing at strike end?
		if animation_manager and animation_manager.combat_panel:
			await animation_manager.combat_panel.wait_for_indicator_queue_to_finish()
		else:
			# Small gap between strikes
			await CombatSpeed.create_timer(CombatSpeed.get_duration("attack_gap"))

	if not combat_active:
		return

	# Final UI update: 0 remaining, show next turn total
	strike_ui_update_requested.emit(attacker, 0, attacker.stats.strikes_current)


# ===== ITEM PROCESSING =====

func process_entity_items_sequentially(entity, trigger_type: Enums.TriggerType, trigger_stat = Enums.Stats.NONE, source_item: Item = null, stat_amount: int = 0):
	# Process all items that match the trigger type for an entity.
	# Items are processed sequentially with animations.
	
	# CONDITION CHAIN BEHAVIOR:
	# - If a rule has a condition and it FAILS, all subsequent rules on that item are SKIPPED
	# - This allows complex conditional chains like:
	#   Rule 1: If HP > 50, lose 10 HP
	#   Rule 2: Gain 5 damage
	#   Rule 3: Apply 2 poison
	#   If Rule 1's condition fails, Rules 2 and 3 won't execute

	# Make sure nothing triggers afte combat ends except one final ON KILL
	if not combat_active and trigger_type != Enums.TriggerType.ON_KILL:
		return
	trigger_type_stack.push_back(trigger_type)

	# Collect triggered items through item processor
	var triggered_items = item_processor.process_items(entity, trigger_type, trigger_stat, stat_amount)
	
	# MAKE SURE ITEMS CANNOT TRIGGER THEMSELVES
	if source_item:
		triggered_items = triggered_items.filter(func(item_data): return item_data.item != source_item)

	if triggered_items.is_empty():
		#add_to_combat_log_string("\n(%s has no %s items!)" % [color_entity(get_entity_name(entity)), Enums.get_trigger_type_string(trigger_type)])
		return
	
	add_to_combat_log_string("\n%s's %s items:" % [
		color_entity(get_entity_name(entity)),
		Enums.get_trigger_type_string(trigger_type)
	])

	# -- Get combat panel reference
	var combat_panel = animation_manager.combat_panel
	
	# Process each item - but group by item to handle condition chains
	var current_item = null
	var continue_processing_item = true
	
	for item_data in triggered_items:
		var item = item_data.item
		var rule = item_data.rule
		var slot_index = item_data.slot_index
	
		# GUARD: Abort remaining items if combat ended mid-chain
		if not combat_active and not is_processing_on_kill():
			break

		# Check if this is a new item (reset continuation flag)
		if item != current_item:
			current_item = item
			continue_processing_item = true
		
		# Skip if previous rule on this item failed its condition
		if not continue_processing_item:
			#add_to_combat_log_string("     Skipping rule due to failed condition in chain", Color.GRAY)
			continue
		
		# ======= NORMAL MODE:
		# === STEP 1: Highlight the item slot ===   JDM: Removed combat item highlighting
		#if entity == player_entity and combat_panel:
		#	combat_panel.highlight_item_slot(slot_index, slot_index == -1)
				
		# === STEP 2: Execute effect (DATA CHANGES) (This checks permissions and procs animation)===
		var target = _get_rule_target(entity, rule.target_type)
		var success = await effect_executor.execute_item_rule(item, rule, entity, target, stat_amount)

		if success:
			# Emit trigger signal
			item_rule_triggered.emit(item, rule, entity)
		else:
			continue_processing_item = false

		# === STEP 3: Update status boxes if needed ===
		#if success and rule.effect_type in [Enums.EffectType.APPLY_STATUS, Enums.EffectType.REMOVE_STATUS, Enums.EffectType.CONVERT]:
		#	if combat_panel:
		#		if rule.effect_type == Enums.EffectType.CONVERT:
		#			var from_entity = effect_executor._get_target_entity(rule.convert_from_party, entity)
		#			var to_entity = effect_executor._get_target_entity(rule.convert_to_party, entity)
		#			combat_panel.rebuild_status_boxes(from_entity)
		#			if to_entity != from_entity:
		#				combat_panel.rebuild_status_boxes(to_entity)
		#		else:
		#			combat_panel.rebuild_status_boxes(target)
		
		# === STEP 4: Clear highlight ===
		if entity == player_entity and combat_panel:
			combat_panel._clear_all_highlights()
		
	# Wait for all animations to complete
	await animation_manager.wait_for_current_sequence()

	trigger_type_stack.pop_back()


func proc_item(item, rule, entity, amount: int):
	# -- Get combat panel reference
	var combat_panel = animation_manager.combat_panel
	if combat_panel:
		if amount != 0: # Don't proc if a value doesn't change
			combat_panel.spawn_item_proc_indicator(item, rule, entity, amount)
			#await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc")) # JDM - timer pause now handled in spawn function

func process_entity_items_with_status(entity, trigger_type: Enums.TriggerType, trigger_status: Enums.StatusEffects, _stacks: int, source_item: Item = null):
	"""Process items that trigger based on status effects."""
	var triggered_items = item_processor.process_items_with_status(entity, trigger_type, trigger_status, _stacks)
	
	if triggered_items.is_empty():
		return
	
	add_to_combat_log_string("    %s (%s) items triggered:" % [Enums.get_trigger_type_string(trigger_type), Enums.get_status_string(trigger_status)], Color.LIGHT_BLUE)
	
	var item_list = triggered_items.map(func(data): return data.item)

	if not CombatSpeed.is_instant_mode():
		animation_manager.play_item_sequence(item_list, entity, Enums.get_trigger_type_string(trigger_type))
	
	for item_data in triggered_items:
		if not combat_active and not is_processing_on_kill():
					break

		var item = item_data.item
		var rule = item_data.rule

		# Don't let an item trigger from status it just applied
		if source_item != null and item == source_item:
			continue
			
		item_rule_triggered.emit(item, rule, entity)

		var target = _get_rule_target(entity, rule.target_type)
		await effect_executor.execute_item_rule(item, rule, entity, target, _stacks)

	if not CombatSpeed.is_instant_mode():
		await animation_manager.wait_for_current_sequence()

# ===== COMBAT END =====

func end_combat_gracefully():
	"""Clean up and end combat properly."""
	if not CombatSpeed.is_instant_mode():
		await animation_manager.wait_for_current_sequence()
		await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	
	# Determine winner/loser
	var winner = player_entity if player_entity.stats.hit_points_current > 0 else enemy_entity
	var loser = enemy_entity if winner == player_entity else player_entity
	
	# MILESTONE: Battle End
	if not CombatSpeed.is_instant_mode():
		animation_manager.play_milestone("Battle End", {"winner": winner, "loser": loser})
		await animation_manager.milestone_complete
	
	add_to_combat_log_string(CombatLog.fmt_combat_alert("=== BATTLE ENDED ==="))
	add_to_combat_log_string("[center]%s WINS![/center]" % color_entity(get_entity_name(winner).to_upper()))
	add_to_combat_log_string("[center]%s has been defeated.[/center]" % color_entity(get_entity_name(loser)))

	# Reset entities
	player_entity.stats.reset_stats_after_combat()
	enemy_entity.stats.reset_stats_after_combat()
	status_handler.reset_all_statuses(player_entity)
	status_handler.reset_all_statuses(enemy_entity)
	
	# Recalculate their max HP from items
	Player.update_stats_from_items()

	# Emit combat ended
	combat_ended.emit(winner, loser)
	CombatSpeed.exit_combat()

func calculate_gold_reward(loser) -> int:
	# Calculate gold reward for defeating an enemy.
	var gold_reward: int = 0

	if loser is Enemy:
		if loser.enemy_type != Enemy.EnemyType.BOSS_PLAYER:
			gold_reward = loser.gold + Player.current_rank

	if gold_reward > 0:
		add_to_combat_log_string("\nYou earned %s gold!" % color_text(str(gold_reward), Color.GOLD))

	return gold_reward

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

func _on_acid_proc_triggered(entity, amount: int):
	await process_entity_items_sequentially(entity, Enums.TriggerType.ACID_PROCS_ON_ENEMY, Enums.Stats.NONE, null, amount)

func _on_stat_gain_triggered(entity, stat: Enums.Stats, amount: int, source_item: Item):
	# == Handle ON_STAT_GAIN trigger.
	if current_stat_trigger_depth >= MAX_STAT_TRIGGER_DEPTH:
		add_to_combat_log_string("     Stat (" + Enums.get_stat_string(stat) + ") gain trigger recursion limit reached", Color.ORANGE)
		return	
	
	current_stat_trigger_depth += 1
	await process_entity_items_sequentially(entity, Enums.TriggerType.ON_STAT_GAIN, stat, source_item, amount)
	current_stat_trigger_depth -= 1

func _on_stat_loss_triggered(entity, stat: Enums.Stats, amount: int, source_item: Item):
	# == Handle ON_STAT_LOSS trigger.
	if current_stat_trigger_depth >= MAX_STAT_TRIGGER_DEPTH:
		add_to_combat_log_string("      Stat (" + Enums.get_stat_string(stat) + ") loss trigger recursion limit reached", Color.ORANGE)
		return

	current_stat_trigger_depth += 1
	await process_entity_items_sequentially(entity, Enums.TriggerType.ON_STAT_LOSS, stat, source_item, amount)
	current_stat_trigger_depth -= 1	

func _on_non_weapon_damage_triggered(entity, amount: int, source_item: Item):
	# == Handle ON_STAT_LOSS trigger.
	if current_stat_trigger_depth >= MAX_STAT_TRIGGER_DEPTH:
		add_to_combat_log_string("      Non-Weapon Damage trigger recursion limit reached", Color.ORANGE)
		return

	current_stat_trigger_depth += 1
	await process_entity_items_sequentially(entity, Enums.TriggerType.ON_DEALING_DAMAGE, Enums.Stats.NONE, source_item, amount)
	current_stat_trigger_depth -= 1	

func _on_wounded_triggered(entity):
	"""Handle WOUNDED trigger."""
	add_to_combat_log_string(CombatLog.fmt_wounded(get_entity_name(entity)))

	entity_wounded.emit(entity)
	await process_entity_items_sequentially(entity, Enums.TriggerType.WOUNDED)

	if entity == player_entity:
		await process_entity_items_sequentially(enemy_entity, Enums.TriggerType.ENEMY_WOUNDED)
	else:
		await process_entity_items_sequentially(player_entity, Enums.TriggerType.ENEMY_WOUNDED)	

func _on_exposed_triggered(entity):
	"""Handle EXPOSED trigger."""
	add_to_combat_log_string(CombatLog.fmt_exposed(get_entity_name(entity)))

	entity_exposed.emit(entity)
	await process_entity_items_sequentially(entity, Enums.TriggerType.EXPOSED)

	if entity == player_entity:
		await process_entity_items_sequentially(enemy_entity, Enums.TriggerType.ENEMY_EXPOSED)
	else:
		await process_entity_items_sequentially(player_entity, Enums.TriggerType.ENEMY_EXPOSED)

func _on_one_hitpoint_left_triggered(entity):
	"""Handle ONE_HITPOINT_LEFT trigger."""
	add_to_combat_log_string(CombatLog.fmt_one_hp(get_entity_name(entity)))

	await process_entity_items_sequentially(entity, Enums.TriggerType.ONE_HITPOINT_LEFT)

func _on_death_triggered(entity):
	## Handle entity death.
	if death_processing:
		return
	death_processing = true

	add_to_combat_log_string(CombatLog.fmt_death(get_entity_name(entity)))
	
	combat_active = false  # End combat
	
	# Clear the statuses as soon as someone dies.
	var combat_panel = animation_manager.combat_panel
	if combat_panel:
		combat_panel.clear_statuses()

	# Check for ON_KILL trigger (for the killer)
	var killer = enemy_entity if entity == player_entity else player_entity
	await process_entity_items_sequentially(killer, Enums.TriggerType.ON_KILL)

func pass_enemy_status(status: Enums.StatusEffects) -> int:
	return enemy_entity.status_effects.get_status_value(status)

func pass_enemy_stats(stat: Enums.Stats, stat_type: Enums.StatType) -> int:
	match stat:
		Enums.Stats.HITPOINTS:
			if stat_type == Enums.StatTye.CURRENT:
				return enemy_entity.stats.hit_points_current
			elif stat_type == Enums.StatType.MISSING:
				return enemy_entity.stats.hit_points - enemy_entity.stats.hit_points_current
			else:
				return enemy_entity.stats.hit_points
		Enums.Stats.DAMAGE:
			if stat_type == Enums.StatTye.CURRENT:
				return enemy_entity.stats.damage_current
			elif stat_type == Enums.StatType.MISSING:
				return enemy_entity.stats.damage - enemy_entity.stats.damage_current
			else:
				return enemy_entity.stats.damage
		Enums.Stats.SHIELD:
			if stat_type == Enums.StatTye.CURRENT:
				return enemy_entity.stats.shield_current
			elif stat_type == Enums.StatType.MISSING:
				return enemy_entity.stats.shield - enemy_entity.stats.shield_current
			else:
				return enemy_entity.stats.shield
		Enums.Stats.AGILITY:
			if stat_type == Enums.StatTye.CURRENT:
				return enemy_entity.stats.agility_current
			elif stat_type == Enums.StatType.MISSING:
				return enemy_entity.stats.agility - enemy_entity.stats.agility_current
			else:
				return enemy_entity.stats.agility
		Enums.Stats.STRIKES:
			if stat_type == Enums.StatTye.CURRENT:
				return enemy_entity.stats.strikes_current
			elif stat_type == Enums.StatType.MISSING:
				return enemy_entity.stats.strikes - enemy_entity.stats.strikes_current
			else:
				return enemy_entity.stats.strikes
		Enums.Stats.BURN_DAMAGE:
			if stat_type == Enums.StatTye.CURRENT:
				return enemy_entity.stats.burn_damage_current
			elif stat_type == Enums.StatType.MISSING:
				return enemy_entity.stats.burn_damage - enemy_entity.stats.burn_damage_current
			else:
				return enemy_entity.stats.burn_damage
		_:
			return 0

func _on_enemy_status_gained_triggered(entity, status: Enums.StatusEffects, stacks: int):
	await get_tree().process_frame

	if current_status_trigger_depth >= MAX_STATUS_TRIGGER_DEPTH:
		add_to_combat_log_string("      Enemy Status (" + Enums.get_status_string(status) + ") applied trigger recursion limit reached", Color.ORANGE)
		return

	current_status_trigger_depth += 1
	await process_entity_items_with_status(entity, Enums.TriggerType.ON_ENEMY_STATUS_GAIN, status, stacks)
	current_status_trigger_depth -= 1

func _on_enemy_status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int):
	await get_tree().process_frame

	if current_status_trigger_depth >= MAX_STATUS_TRIGGER_DEPTH:
		add_to_combat_log_string("      Enemy Status (" + Enums.get_status_string(status) + ") removed trigger recursion limit reached", Color.ORANGE)
		return

	current_status_trigger_depth += 1
	await process_entity_items_with_status(entity, Enums.TriggerType.ON_ENEMY_STATUS_PROC, status, stacks)
	current_status_trigger_depth -= 1

func _on_status_gained_triggered(entity, status: Enums.StatusEffects, stacks: int, source_item: Item = null):
	await get_tree().process_frame

	#var combat_panel = animation_manager.combat_panel
	#if combat_panel:
		#combat_panel.rebuild_status_boxes(entity)
	#	combat_panel.spawn_status_box_update(entity, status, stacks) # JDM: New queue system

	if current_status_trigger_depth >= MAX_STATUS_TRIGGER_DEPTH:
		add_to_combat_log_string("      Status (" + Enums.get_status_string(status) + ") applied trigger recursion limit reached", Color.ORANGE)
		return

	current_status_trigger_depth += 1
	await process_entity_items_with_status(entity, Enums.TriggerType.ON_STATUS_GAINED, status, stacks, source_item)
	current_status_trigger_depth -= 1

func _on_overheal_triggered(entity, stacks: int):
	await get_tree().process_frame

	await process_entity_items_sequentially(entity, Enums.TriggerType.OVERHEAL, Enums.Stats.NONE, null, stacks)

func _on_status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int):
	await get_tree().process_frame

	if current_status_trigger_depth >= MAX_STATUS_TRIGGER_DEPTH:
		add_to_combat_log_string("      Status (" + Enums.get_status_string(status) + ") removed trigger recursion limit reached", Color.ORANGE)
		return

	current_status_trigger_depth += 1
	await process_entity_items_with_status(entity, Enums.TriggerType.ON_STATUS_REMOVED, status, stacks)
	current_status_trigger_depth -= 1

func _on_healing_applied(target, amount):
	"""Forward healing_applied signal."""
	healing_applied.emit(target, amount)

func is_processing_on_kill() -> bool:
	return Enums.TriggerType.ON_KILL in trigger_type_stack

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
	# _color param retained for call-site compatibility but is no longer used —
	# all coloring is handled by CombatLog helpers before this is called.
	var final_string: String = _string
	if is_bold:
		final_string = CombatLog.bold(final_string)
	combat_log += final_string + "\n"

func color_text(text: String, c: Color) -> String:
	return CombatLog.color(text, c)

func color_stat(stat_name: String) -> String:
	return CombatLog.color_stat_str(stat_name)

func color_status(status_name: String) -> String:
	return CombatLog.color_status_str(status_name)

func color_entity(entity_name: String) -> String:
	return CombatLog.color_entity(entity_name)

func color_item(item_name: String, item_obj = null) -> String:
	return CombatLog.color_item(item_name, item_obj)


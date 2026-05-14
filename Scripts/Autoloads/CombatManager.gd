extends Node

## Central combat coordinator - delegates to specialized sub-systems
## This is the main autoload that orchestrates combat flow

# --- Combat flow signals
signal combat_started(player_entity, enemy_entity)
signal turn_started(entity, turn_number)
signal turn_ended(entity)
signal combat_ended(winner, loser)
signal combat_log_updated(text: String)

# --- State change signals (forwarded from sub-systems)
signal stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int)
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
var combat_ending: bool = false
var _combat_end_called: bool = false
var attack_sequence_active: bool = false

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

const MAX_COMBAT_TURNS: int = 25  # Failsafe to prevent infinite combat

# === SUB-SYSTEMS ===
var event_queue: CombatEventQueue
var indicator_layer: CombatIndicatorLayer
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

	event_queue = CombatEventQueue.new(self)
	event_queue.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(event_queue)
	
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
	combat_ending = false
	_combat_end_called = false
	turn_number = 0

	stat_handler.reset_combat_state()
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
		indicator_layer = CombatIndicatorLayer.new()
		combat_panel.add_child(indicator_layer)
		indicator_layer.initialize(combat_panel)

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
	process_battle_start_events(first_entity, second_entity)
	if event_queue.is_queue_processing():
		await event_queue.queue_emptied
	
	# Start main combat loop
	await combat_loop(first_entity, second_entity)

func process_battle_start_events(first_entity, second_entity):
	# -- Process BATTLE_START trigger for both entities in turn order.

	# First entity's battle start items
	enqueue_items_for_trigger(first_entity, Enums.TriggerType.BATTLE_START)
	
	# Second entity's battle start items
	enqueue_items_for_trigger(second_entity, Enums.TriggerType.BATTLE_START)

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

		# First entity's turn
		execute_turn(first_entity)
		if event_queue.is_queue_processing():
			await event_queue.queue_emptied
		if not combat_active:
			break
		
		# Second entity's turn
		execute_turn(second_entity)
		if event_queue.is_queue_processing():
			await event_queue.queue_emptied
		if not combat_active:
			break
	
	# Combat ended - cleanup
	if not _combat_end_called:
		await end_combat_gracefully()

func execute_turn(entity):
	# Execute a single entity's turn.

	var target = enemy_entity if entity == player_entity else player_entity
	
	event_queue.enqueue(CombatEvent.turn_start_signal(entity, turn_number))
	event_queue.enqueue(CombatEvent.log(CombatLog.fmt_turn_start(get_entity_name(entity), turn_number)))

	# Reset per-turn item states
	item_processor.reset_per_turn_items(entity)
	
	# Process turn-start status effects
	status_handler.process_turn_start_status_effects(entity)
	
	# Process TURN_START items
	enqueue_items_for_trigger(entity, Enums.TriggerType.TURN_START)

	# Execute attacks
	event_queue.enqueue(CombatEvent.attack_phase(entity))

func execute_attack_sequence(attacker):
	# === Execute all of an entity's attack strikes. ===

	var target = enemy_entity if attacker == player_entity else player_entity

	# Capture strikes for THIS attack sequence
	attacker.stats.strikes_left = attacker.stats.strikes_next_turn
	attacker.stats.strikes_next_turn = attacker.stats.strikes
	attack_sequence_active = true

	# Notify display of upcoming strike count
	stat_changed.emit(attacker, Enums.Stats.STRIKES, attacker.stats.strikes_left, attacker.stats.strikes_left)
	
	event_queue.enqueue(CombatEvent.log(CombatLog.bold("%s ATTACKS with %s (for %s per)" % [
			color_entity(get_entity_name(attacker)),
			color_text(str(attacker.stats.strikes_left), Color.WHITE) + " " + CombatLog.color_stat(Enums.Stats.STRIKES),
			color_text(str(attacker.stats.damage_current), Color.WHITE) + " " + CombatLog.color_stat(Enums.Stats.DAMAGE)
		])))

	if attacker.stats.strikes_left <= 0:
		event_queue.enqueue(CombatEvent.turn_end_phase(attacker))
		return

	# Handle stun for first strike
	if attacker.status_effects.stun > 0:
		event_queue.enqueue(CombatEvent.log(color_entity(get_entity_name(attacker)) + " is STUNNED! Attack skipped."))
		event_queue.enqueue(CombatEvent.remove_status(attacker, Enums.StatusEffects.STUN, 1))

		attacker.stats.strikes_left = maxi(attacker.stats.strikes_left - 1, 0)
		stat_changed.emit(attacker, Enums.Stats.STRIKES, attacker.stats.strikes_left + 1, attacker.stats.strikes_left)

		event_queue.enqueue(CombatEvent.delay(CombatSpeed.get_duration("attack_gap")))
		# Re-enqueue with one fewer strike
		if attacker.stats.strikes_left - 1 > 0:
			var damage = attacker.stats.damage_current
			event_queue.enqueue(CombatEvent.attack_animation(attacker, target, damage, 2))
		else:
			event_queue.enqueue(CombatEvent.turn_end_phase(attacker))
		return

	if attacker.inventory and attacker.inventory.weapon_slot and attacker.inventory.weapon_slot.cant_attack:
		event_queue.enqueue(CombatEvent.turn_end_phase(attacker))
		return

	var damage = attacker.stats.damage_current
	# strikes_remaining = strikes after this one
	event_queue.enqueue(CombatEvent.attack_animation(attacker, target, damage, 1))

# ===== COMBAT END =====

func end_combat_gracefully():
	"""Clean up and end combat properly."""

	if _combat_end_called:
		return
	_combat_end_called = true

	if not CombatSpeed.is_instant_mode():
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


# ===== SIGNAL HANDLERS (Forward from sub-systems) =====

func _on_stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int):
	"""Forward stat_changed signal."""
	stat_changed.emit(entity, stat, old_value, new_value)

func _on_acid_proc_triggered(entity, amount: int):
	enqueue_items_for_trigger(entity, Enums.TriggerType.ACID_PROCS_ON_ENEMY, Enums.Stats.NONE, null, amount, true)

func _on_stat_gain_triggered(entity, stat: Enums.Stats, amount: int, source_item: Item):
	enqueue_items_for_trigger(entity, Enums.TriggerType.ON_STAT_GAIN, stat, source_item, amount, true)

func _on_stat_loss_triggered(entity, stat: Enums.Stats, amount: int, source_item: Item):
	enqueue_items_for_trigger(entity, Enums.TriggerType.ON_STAT_LOSS, stat, source_item, amount, true)

func _on_non_weapon_damage_triggered(entity, amount: int, source_item: Item):
	enqueue_items_for_trigger(entity, Enums.TriggerType.ON_DEALING_DAMAGE, Enums.Stats.NONE, source_item, amount, true)

func _on_wounded_triggered(entity):
	# Handle WOUNDED trigger.
	if not combat_active:  # Don't trigger wounded if they're dead!
		return
	if entity.stats.hit_points_current <= 0:
		return

	entity_wounded.emit(entity)
	enqueue_items_for_trigger(entity, Enums.TriggerType.WOUNDED, Enums.Stats.NONE, null, 0, true)

	if entity == player_entity:
		enqueue_items_for_trigger(enemy_entity, Enums.TriggerType.ENEMY_WOUNDED, Enums.Stats.NONE, null, 0, true)
	else:
		enqueue_items_for_trigger(player_entity, Enums.TriggerType.ENEMY_WOUNDED, Enums.Stats.NONE, null, 0, true)
	event_queue.enqueue_next(CombatEvent.log(CombatLog.fmt_wounded(get_entity_name(entity))))

func _on_exposed_triggered(entity):
	#Handle EXPOSED trigger.
	if not combat_active:  # Don't trigger exposed if they're dead!
		return
	if entity.stats.hit_points_current <= 0:
		return

	entity_exposed.emit(entity)
	enqueue_items_for_trigger(entity, Enums.TriggerType.EXPOSED, Enums.Stats.NONE, null, 0, true)
	if entity == player_entity:
		enqueue_items_for_trigger(enemy_entity, Enums.TriggerType.ENEMY_EXPOSED, Enums.Stats.NONE, null, 0, true)
	else:
		enqueue_items_for_trigger(player_entity, Enums.TriggerType.ENEMY_EXPOSED, Enums.Stats.NONE, null, 0, true)
	event_queue.enqueue_next(CombatEvent.log(CombatLog.fmt_exposed(get_entity_name(entity))))

func _on_one_hitpoint_left_triggered(entity):
	# Handle ONE_HITPOINT_LEFT trigger.
	if not combat_active:  # Don't trigger if they're dead!
		return

	enqueue_items_for_trigger(entity, Enums.TriggerType.ONE_HITPOINT_LEFT, Enums.Stats.NONE, null, 0, true)
	event_queue.enqueue_next(CombatEvent.log(CombatLog.fmt_one_hp(get_entity_name(entity))))

func _on_death_triggered(entity):
	# Gate all further enqueues — only DEATH_SEQUENCE gets through
	combat_ending = true
	
	# Clear the statuses as soon as someone dies.
	var combat_panel = animation_manager.combat_panel
	if combat_panel:
		combat_panel.clear_statuses()

	# DEATH_SEQUENCE event purges the queue and drives end_combat_gracefully
	# ON_KILL removed — if re-introducing: collect ON_KILL events, purge, re-enqueue them, then enqueue death_sequence
	event_queue.enqueue_next(CombatEvent.death_sequence(entity))
	event_queue.enqueue_next(CombatEvent.log(CombatLog.fmt_death(get_entity_name(entity))))

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
				return enemy_entity.stats.strikes_left
			elif stat_type == Enums.StatType.MISSING:
				return 0
			else:
				return enemy_entity.stats.strikes_next_turn
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
	enqueue_items_for_trigger_with_status(entity, Enums.TriggerType.ON_ENEMY_STATUS_GAIN, status, stacks, null, true)

func _on_enemy_status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int):
	enqueue_items_for_trigger_with_status(entity, Enums.TriggerType.ON_ENEMY_STATUS_PROC, status, stacks, null, true)

func _on_status_gained_triggered(entity, status: Enums.StatusEffects, stacks: int, source_item: Item = null):
	enqueue_items_for_trigger_with_status(entity, Enums.TriggerType.ON_STATUS_GAINED, status, stacks, source_item, true)

func _on_overheal_triggered(entity, stacks: int):
	enqueue_items_for_trigger(entity, Enums.TriggerType.OVERHEAL, Enums.Stats.NONE, null, stacks, true)

func _on_status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int):
	enqueue_items_for_trigger_with_status(entity, Enums.TriggerType.ON_STATUS_REMOVED, status, stacks, null, true)

func _on_healing_applied(target, amount):
	"""Forward healing_applied signal."""
	healing_applied.emit(target, amount)

## =============== COMBAT EVENT QUEUE FUNX =========================
func enqueue_items_for_trigger(entity, trigger_type: Enums.TriggerType, trigger_stat = Enums.Stats.NONE, source_item: Item = null, stat_amount: int = 0, immediate: bool = false):
	if not combat_active and not combat_ending:
		return
	if combat_ending:
		return

	var triggered_items = item_processor.process_items(entity, trigger_type, trigger_stat, stat_amount)

	if source_item:
		triggered_items = triggered_items.filter(func(d): return d.item != source_item)

	if triggered_items.is_empty():
		return

	var events: Array[CombatEvent] = []
	events.append(CombatEvent.log("\n%s's %s items (%d):" % [color_entity(get_entity_name(entity)), Enums.get_trigger_type_string(trigger_type), triggered_items.size()]))
	for item_data in triggered_items:
		events.append(CombatEvent.execute_rule(
			item_data.item,
			item_data.rule,
			entity,
			trigger_type,
			stat_amount
		))

	if immediate:
		event_queue.enqueue_batch_next(events)
	else:
		event_queue.enqueue_batch(events)

func enqueue_items_for_trigger_with_status(entity, trigger_type: Enums.TriggerType, trigger_status: Enums.StatusEffects, stacks: int, source_item: Item = null, immediate: bool = false):
	if combat_ending:
		return
	if not combat_active:
		return

	var triggered_items = item_processor.process_items_with_status(entity, trigger_type, trigger_status, stacks)

	if source_item:
		triggered_items = triggered_items.filter(func(d): return d.item != source_item)

	if triggered_items.is_empty():
		return

	var events: Array[CombatEvent] = []
	events.append(CombatEvent.log("    %s (%s) items triggered (%d):" % [Enums.get_trigger_type_string(trigger_type), Enums.get_status_string(trigger_status), triggered_items.size()]))
	for item_data in triggered_items:
		events.append(CombatEvent.execute_rule(
			item_data.item,
			item_data.rule,
			entity,
			trigger_type,
			stacks
		))

	if immediate:
		event_queue.enqueue_batch_next(events)
	else:
		event_queue.enqueue_batch(events)


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
	combat_log_updated.emit(combat_log) 

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

func get_all_entity_items(entity) -> Array[Item]:
	var items: Array[Item] = []
	var inventory = Player.inventory if entity == player_entity else entity.inventory
	if not inventory:
		return items
	
	# - Weapon and upgrade
	if inventory.weapon_slot:
		items.append(inventory.weapon_slot)
		if entity.current_weapon_rule_upgrade:
			items.append(entity.current_weapon_rule_upgrade)

	# - Inventory Items
	for item in inventory.item_slots:
		if item:
			items.append(item)

	# - Set bonuses
	for set_item in SetBonusManager.get_active_set_bonuses(entity):
		items.append(set_item)

	return items
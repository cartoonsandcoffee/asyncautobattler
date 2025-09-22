extends Node

## Central combat system that manages turn-based autobattler mechanics
## Handles rule resolution, status effects, and combat flow with configurable speed

# Combat flow signals
signal combat_started(player_entity, enemy_entity)
signal turn_started(entity)
signal turn_ended(entity)
signal combat_ended(winner, loser)

# Action signals  
signal attack_executed(attacker, target, damage_dealt)
signal damage_dealt(target, amount, taken_by)
signal healing_applied(target, amount)

# State change signals
signal stat_changed(entity, stat_name: String, old_value: int, new_value: int)
signal status_applied(entity, status_name: String, stacks: int)
signal status_proc(entity, _status: Enums.StatusEffects, _stat: Enums.Stats, value: int) 
signal status_removed(entity, status_name: String)
signal entity_exposed(entity)
signal entity_wounded(entity)

# Item/rule signals
signal item_rule_triggered(item: Item, rule: ItemRule, entity)
signal enemy_ability_triggered(ability: EnemyAbility, entity)

# Combat entities
var player_entity
var enemy_entity
var current_turn_entity

# Combat state
var combat_active: bool = false
var turn_number: int = 0
var combat_speed: float = 1.0  # Multiplier for animation/wait times

# Combat state tracking per combat
var player_exposed_triggered: bool = false
var enemy_exposed_triggered: bool = false
var player_wounded_triggered: bool = false
var enemy_wounded_triggered: bool = false

# Combat timing
var base_highlight_duration: float = 0.5
var base_message_duration: float = 1

var combat_log: String = ""

# Add animation manager
var animation_manager: AnimationManager

enum CombatSpeed {
	PAUSE = 0,
	NORMAL = 1,
	FAST = 2,
	VERY_FAST = 3
}

func _ready():
	animation_manager = AnimationManager.new()
	add_child(animation_manager)


func start_combat(player, enemy):
	"""Initialize and begin combat between player and enemy"""
	combat_log = ""
	add_to_combat_log_string("=== COMBAT STARTED ===\n")
	
	# Store combat entities
	player_entity = player
	enemy_entity = enemy
	
	# Reset combat state
	combat_active = true
	turn_number = 0
	player_exposed_triggered = false
	enemy_exposed_triggered = false
	player_wounded_triggered = false
	enemy_wounded_triggered = false
	
	# Reset current values to base values for both entities
	player_entity.stats.reset_to_base_values()
	enemy_entity.stats.reset_to_base_values()
	
	# Initialize animation manager with combat panel reference
	var combat_panel = get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		animation_manager.initialize(combat_panel)
	
	# Emit combat started signal
	combat_started.emit(player_entity, enemy_entity)

	# MILESTONE: Battle Start
	animation_manager.play_milestone("Battle Start")
	await animation_manager.milestone_complete
		
	# Determine turn order based on agility
	var first_entity = player_entity if player_entity.stats.agility >= enemy_entity.stats.agility else enemy_entity
	var second_entity = enemy_entity if first_entity == player_entity else player_entity
	
	add_to_combat_log_string("Turn order: " + get_entity_name(first_entity) + " goes first.")
	
	# Trigger battle start events
	await process_battle_start_events(first_entity, second_entity)
	
	# Begin turn loop
	await combat_loop(first_entity, second_entity)

func add_to_combat_log_string(_string: String):
	combat_log += _string + "\n"
	# print(_string) # JDM: don't need to print text now that we can review it later.

func combat_loop(first_entity, second_entity):
	"""Main combat loop - alternates turns until one entity dies"""
	
	while combat_active:
		turn_number += 1
		add_to_combat_log_string("\n--- Turn " + str(turn_number) + " ---")
		
		# First entity's turn
		if combat_active and not is_entity_dead(first_entity):
			await execute_turn(first_entity)
			
		# Check for combat end
		if not combat_active:
			break
			
		# Second entity's turn  
		if combat_active and not is_entity_dead(second_entity):
			await execute_turn(second_entity)
		
		# Check for combat end after second entity
		if not combat_active:
			break

func execute_turn(entity):
	"""Execute a complete turn for the given entity"""
	current_turn_entity = entity
	add_to_combat_log_string(get_entity_name(entity) + "'s turn")
	
	# MILESTONE: Turn Start
	animation_manager.play_milestone("Turn Start", {
		"entity": entity,
		"turn_number": turn_number
	})
	await animation_manager.milestone_complete

	# Emit turn started signal
	turn_started.emit(entity)
	
	# Process status effects at turn start
	await process_turn_start_status_effects(entity)
	
	# Process turn start item rules
	await process_turn_start_rules(entity)
	
	# Check if entity is stunned (skip attacks if stunned)
	if entity.status_effects.stun > 0:
		add_to_combat_log_string(get_entity_name(entity) + " is stunned! Turn skipped.")
		entity.status_effects.stun = max(0, entity.status_effects.stun - 1)
		if entity.status_effects.stun == 0:
			status_removed.emit(entity, "stun")
		await wait_for_speed()
		turn_ended.emit(entity)
		return
	
	# Execute attacks based on strikes stat
	var strikes = entity.stats.strikes
	for strike_num in range(strikes):
		if combat_active and not is_entity_dead(get_opponent(entity)):
			await execute_attack(entity, get_opponent(entity))
	
	# Turn end
	turn_ended.emit(entity)

func execute_attack(attacker, target):
	"""Execute a single attack from attacker to target"""
	var damage = attacker.stats.damage_current
	
	add_to_combat_log_string(get_entity_name(attacker) + " attacks for " + str(damage) + " damage")
	
	# Emit attack signal
	attack_executed.emit(attacker, target, damage)

	# Process on-hit item rules for attacker
	await process_on_hit_rules(attacker)
	
	# Apply damage to target
	await apply_damage(target, damage)

	# Apply thorns as needed
	await proc_thorns(attacker, target)

	await wait_for_speed()

func proc_thorns(attacker, target):
	# thorns - all stacks removed
	if target.status_effects.thorns > 0:
		await apply_damage_from_status(attacker, target.status_effects.thorns, Enums.StatusEffects.THORNS)
		target.status_effects.remove_status(Enums.StatusEffects.THORNS)
		if target.status_effects.thorns == 0:
			status_removed.emit(target, "thorns")
		await wait_for_speed()


func apply_damage(target, damage_amount: int):
	# Apply damage to target, handling shield/armor first
	var remaining_damage = damage_amount
	
	# Apply to shield first
	if target.stats.shield_current > 0:
		var shield_damage = min(remaining_damage, target.stats.shield_current)
		target.stats.shield_current -= shield_damage
		remaining_damage -= shield_damage
		
		add_to_combat_log_string(get_entity_name(target) + " shield reduced by " + str(shield_damage) + " (" + str(target.stats.shield_current) + " remaining)")
		stat_changed.emit(target, "shield", target.stats.shield_current + shield_damage, target.stats.shield_current)

		if target.stats.shield_current == 0:
			damage_dealt.emit(target, shield_damage, Enums.Stats.EXPOSED)

			# Check for first time exposed
			if !is_entity_exposed_triggered(target):
				await trigger_exposed(target)
		else:
			damage_dealt.emit(target, shield_damage, Enums.Stats.SHIELD)

	# Apply remaining damage to hit points
	if remaining_damage > 0:
		target.stats.hit_points_current -= remaining_damage
		add_to_combat_log_string(get_entity_name(target) + " takes " + str(remaining_damage) + " damage (" + str(target.stats.hit_points_current) + " HP remaining)")
		stat_changed.emit(target, "hit_points", target.stats.hit_points_current + remaining_damage, target.stats.hit_points_current)
		
		# Check for first time wounded (50% HP)
		var wounded_threshold = target.stats.hit_points / 2
		if target.stats.hit_points_current <= wounded_threshold:
			damage_dealt.emit(target, remaining_damage, Enums.Stats.WOUNDED)

			if !is_entity_wounded_triggered(target):
				await trigger_wounded(target)
		else:
			damage_dealt.emit(target, remaining_damage, Enums.Stats.HITPOINTS)
	
	# Check for death
	if target.stats.hit_points_current <= 0:
		await handle_entity_death(target)


func apply_damage_from_status(target, damage_amount: int, _status: Enums.StatusEffects):
	# Apply damage to target, handling shield/armor first
	var remaining_damage = damage_amount

	# Apply to shield first
	if target.stats.shield_current > 0:
		var shield_damage = min(remaining_damage, target.stats.shield_current)
		target.stats.shield_current -= shield_damage
		remaining_damage -= shield_damage

		add_to_combat_log_string(get_entity_name(target) + " shield reduced by " + str(shield_damage) + " from " + Enums.get_status_string(_status) + " (" + str(target.stats.shield_current) + " remaining)")
		stat_changed.emit(target, "shield", target.stats.shield_current + shield_damage, target.stats.shield_current)
		
		if target.stats.shield_current == 0:
			status_proc.emit(target, _status, Enums.Stats.EXPOSED, shield_damage *-1)

			# Check for first time exposed
			if !is_entity_exposed_triggered(target):
				await trigger_exposed(target)
		else:
			status_proc.emit(target, _status, Enums.Stats.SHIELD, shield_damage *-1)
				
	
	# Apply remaining damage to hit points
	if remaining_damage > 0 && _status != Enums.StatusEffects.ACID:
		target.stats.hit_points_current -= remaining_damage
		add_to_combat_log_string(get_entity_name(target) + " takes " + str(remaining_damage) + " damage from " + Enums.get_status_string(_status) + " (" + str(target.stats.hit_points_current) + " HP remaining)")
		stat_changed.emit(target, "hit_points", target.stats.hit_points_current + remaining_damage, target.stats.hit_points_current)

		# Check for first time wounded (50% HP)
		var wounded_threshold = target.stats.hit_points / 2
		if target.stats.hit_points_current <= wounded_threshold and not is_entity_wounded_triggered(target):
			status_proc.emit(target, _status, Enums.Stats.WOUNDED, remaining_damage *-1)
			await trigger_wounded(target)
		else:
			status_proc.emit(target, _status, Enums.Stats.HITPOINTS, remaining_damage *-1)

	# Check for death
	if target.stats.hit_points_current <= 0:
		await handle_entity_death(target)



func process_battle_start_events(first_entity, second_entity):
	add_to_combat_log_string("\n-- BATTLE START EVENTS --")
	
	# MILESTONE: Item Effects (if any battle start items exist)
	if _entities_have_battle_start_items(first_entity, second_entity):
		animation_manager.play_milestone("Item Effects")
		await animation_manager.milestone_complete

	# First entity's battle start rules
	await process_entity_battle_start_rules(first_entity)
	
	# Second entity's battle start rules  
	await process_entity_battle_start_rules(second_entity)

func _entities_have_battle_start_items(entity1, entity2) -> bool:
	# Check if either entity has battle start items
	return _entity_has_battle_start_items(entity1) or _entity_has_battle_start_items(entity2)

func _entity_has_battle_start_items(entity) -> bool:
	if entity == player_entity:
		# Check weapon
		if entity.inventory.weapon_slot:
			for rule in entity.inventory.weapon_slot.rules:
				if rule.trigger_type == Enums.TriggerType.BATTLE_START:
					return true
		
		# Check inventory items
		for item in entity.inventory.item_slots:
			if item:
				for rule in item.rules:
					if rule.trigger_type == Enums.TriggerType.BATTLE_START:
						return true
	else:
		# Check enemy abilities
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.BATTLE_START:
				return true
	
	return false

func process_entity_battle_start_rules(entity):
	add_to_combat_log_string(get_entity_name(entity) + " battle start rules:")
	
	# Process weapon rules first if it exists
	if entity == player_entity and entity.inventory.weapon_slot:
		await process_item_rules(entity.inventory.weapon_slot, entity, Enums.TriggerType.BATTLE_START, -1)
	
	# Process inventory items in order
	if entity == player_entity:
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				await process_item_rules(item, entity, Enums.TriggerType.BATTLE_START, i)


func process_turn_start_rules(entity):
	"""Process turn start item rules for entity"""
	add_to_combat_log_string(get_entity_name(entity) + " turn start rules:")
	
	# Process weapon rules first if it exists
	if entity == player_entity and entity.inventory.weapon_slot:
		await process_item_rules(entity.inventory.weapon_slot, entity, Enums.TriggerType.TURN_START, -1)
	
	# Process inventory items in order
	if entity == player_entity:
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				await process_item_rules(item, entity, Enums.TriggerType.TURN_START, i)
	else:
		# Enemy turn start abilities
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.TURN_START:
				await process_enemy_ability(ability, entity)

func process_on_hit_rules(attacker):
	"""Process on-hit rules for attacking entity"""
	add_to_combat_log_string(get_entity_name(attacker) + " on-hit rules:")
	
	# Process weapon rules first if it exists
	if attacker == player_entity and attacker.inventory.weapon_slot:
		await process_item_rules(attacker.inventory.weapon_slot, attacker, Enums.TriggerType.ON_HIT, -1)
	
	# Process inventory items in order
	if attacker == player_entity:
		for i in range(attacker.inventory.item_slots.size()):
			var item = attacker.inventory.item_slots[i]
			if item:
				await process_item_rules(item, attacker, Enums.TriggerType.ON_HIT, i)
	else:
		# Enemy on-hit abilities
		for ability in attacker.abilities:
			if ability.trigger == Enums.TriggerType.ON_HIT:
				await process_enemy_ability(ability, attacker)

func process_item_rules(item: Item, entity, trigger_type: Enums.TriggerType, slot_index: int):
	"""Process all rules for an item that match the trigger type"""
	if not item or not item.rules:
		return

	for rule in item.rules:
		if rule.trigger_type == trigger_type:
			#await execute_item_rule(item, rule, entity)
		
			# - JDM: this should set the entity to ENEMY if they are the target of the rule
			if rule.target_type == Enums.TargetType.ENEMY:
				entity = get_opponent(entity)
			elif rule.target_type == Enums.TargetType.RANDOM:
				entity = entity if randf() < 0.5 else get_opponent(entity)

			# Emit signal BEFORE executing so UI can highlight
			item_rule_triggered.emit(item, rule, entity)

			# Wait for highlight duration
			#await wait_for_highlight()
			
			# Now execute the rule
			await execute_item_rule(item, rule, entity)
			
			# Small pause between rules
			await wait_for_speed()




func process_enemy_ability(ability: EnemyAbility, entity):
	"""Process a single enemy ability"""
	add_to_combat_log_string("  -> " + ability.ability_name + ": " + Enums.get_trigger_type_string(ability.trigger) + " effect")
	
	# Emit ability triggered signal
	enemy_ability_triggered.emit(ability, entity)
	
	# Execute the ability effect
	match ability.effect_type:
		EnemyAbility.EffectType.DAMAGE_BOOST:
			await modify_entity_stat(entity, Enums.Stats.DAMAGE, ability.value)
		EnemyAbility.EffectType.SHIELD_GAIN:
			await modify_entity_stat(entity, Enums.Stats.SHIELD, ability.value)
		EnemyAbility.EffectType.HEAL:
			await heal_entity(entity, ability.value)
		EnemyAbility.EffectType.APPLY_POISON:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), Enums.StatusEffects.POISON, ability.value)
		EnemyAbility.EffectType.APPLY_BURN:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), Enums.StatusEffects.BURN, ability.value)
		EnemyAbility.EffectType.APPLY_THORNS:
			await apply_status_effect(entity, Enums.StatusEffects.THORNS, ability.value)
		EnemyAbility.EffectType.APPLY_ACID:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), Enums.StatusEffects.ACID, ability.value)
		EnemyAbility.EffectType.APPLY_STUN:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), Enums.StatusEffects.STUN, ability.value)
		EnemyAbility.EffectType.DIRECT_DAMAGE:
			# Deal direct damage to opponent
			await apply_damage(get_opponent(entity), ability.value)
		EnemyAbility.EffectType.REDUCE_PLAYER_DAMAGE:
			# Reduce opponent's damage
			await modify_entity_stat(get_opponent(entity), Enums.Stats.DAMAGE, -ability.value)
		EnemyAbility.EffectType.DOUBLE_STRIKE:
			# Give entity extra strike this turn
			await modify_entity_stat(entity, Enums.Stats.STRIKES, ability.value)
		EnemyAbility.EffectType.STEAL_GOLD:
			# Only works if opponent is player
			if get_opponent(entity) == player_entity:
				var stolen = min(ability.value, get_opponent(entity).stats.gold)
				get_opponent(entity).stats.gold -= stolen
				add_to_combat_log_string("    Enemy steals " + str(stolen) + " gold from player.")
	
	# Update ability's runtime state
	ability.times_triggered += 1
	
	# Wait for visual feedback
	await wait_for_speed()

func execute_item_rule(item: Item, rule: ItemRule, entity):
	add_to_combat_log_string("  -> " + item.item_name + ": " + Enums.get_trigger_type_string(rule.trigger_type) + " effect.")

	# Execute the rule effect based on type
	match rule.effect_type:
		Enums.EffectType.MODIFY_STAT:
			await modify_entity_stat(entity, rule.target_stat, rule.effect_amount)
		Enums.EffectType.APPLY_STATUS:
			await apply_status_effect(entity, rule.target_status, rule.effect_amount)
		Enums.EffectType.DEAL_DAMAGE:
			await apply_damage(get_opponent(entity), rule.effect_amount)
		Enums.EffectType.HEAL:
			await heal_entity(entity, rule.effect_amount)
	
	# Wait for visual feedback
	await wait_for_speed()


func _matches_trigger(rule: ItemRule, trigger_type: String) -> bool:
	# JDM: I think I can delete this now?
	match trigger_type:
		"battle_start":
			return rule.trigger == Enums.TriggerType.BATTLE_START
		"turn_start":
			return rule.trigger == Enums.TriggerType.TURN_START
		"on_hit":
			return rule.trigger == Enums.TriggerType.ON_HIT
		"exposed":
			return rule.trigger == Enums.TriggerType.EXPOSED
		"wounded":
			return rule.trigger == Enums.TriggerType.WOUNDED
		"countdown":
			return rule.trigger == Enums.TriggerType.COUNTDOWN
		_:
			return false


func modify_entity_stat(entity, stat_name: Enums.Stats, amount: int):
	"""Modify an entity's stat and emit appropriate signals"""
	var old_value: int
	var new_value: int
	
	match stat_name:
		Enums.Stats.DAMAGE:
			old_value = entity.stats.damage_current
			entity.stats.increase_stat(Enums.Stats.DAMAGE, amount)
			new_value = entity.stats.damage_current
		Enums.Stats.SHIELD:
			old_value = entity.stats.shield_current  
			entity.stats.increase_stat(Enums.Stats.SHIELD, amount)
			new_value = entity.stats.shield_current
		Enums.Stats.AGILITY:
			old_value = entity.stats.agility_current
			entity.stats.increase_stat(Enums.Stats.AGILITY, amount)
			new_value = entity.stats.agility_current
		Enums.Stats.HITPOINTS:
			old_value = entity.stats.hit_points_current
			entity.stats.increase_stat(Enums.Stats.HITPOINTS, amount)
			new_value = entity.stats.hit_points_current
			
			# Check for overheal
			if new_value > entity.stats.hit_points:
				var overheal_amount = new_value - entity.stats.hit_points
				entity.stats.hit_points_current = entity.stats.hit_points
				new_value = entity.stats.hit_points_current
				if entity.status_effects:
					entity.status_effects.overheal_triggered.emit(overheal_amount)
		Enums.Stats.STRIKES:
			old_value = entity.stats.strikes
			entity.stats.increase_stat(Enums.Stats.STRIKES, amount)
			new_value = entity.stats.strikes
	
	add_to_combat_log_string("    " + get_entity_name(entity) + " " + Enums.get_stat_string(stat_name) + ": " + str(old_value) + " -> " + str(new_value))
	stat_changed.emit(entity, stat_name, old_value, new_value)

func apply_status_effect(entity, status_name: Enums.StatusEffects, stacks: int):
	"""Apply status effect stacks to entity"""
	if not entity.status_effects:
		return
		
	var old_value: int
	var new_value: int
	
	match status_name:
		Enums.StatusEffects.POISON:
			old_value = entity.status_effects.poison
			entity.status_effects.increment_status(Enums.StatusEffects.POISON, stacks)
			new_value = entity.status_effects.poison
		Enums.StatusEffects.THORNS:
			old_value = entity.status_effects.thorns
			entity.status_effects.increment_status(Enums.StatusEffects.THORNS, stacks)
			new_value = entity.status_effects.thorns
		Enums.StatusEffects.ACID:
			old_value = entity.status_effects.acid
			entity.status_effects.increment_status(Enums.StatusEffects.ACID, stacks)
			new_value = entity.status_effects.acid
		Enums.StatusEffects.REGENERATION:
			old_value = entity.status_effects.regeneration
			entity.status_effects.increment_status(Enums.StatusEffects.REGENERATION, stacks)
			new_value = entity.status_effects.regeneration
		Enums.StatusEffects.STUN:
			old_value = entity.status_effects.stun
			entity.status_effects.increment_status(Enums.StatusEffects.STUN, stacks)
			new_value = entity.status_effects.stun
		Enums.StatusEffects.BURN:
			old_value = entity.status_effects.burn
			entity.status_effects.increment_status(Enums.StatusEffects.BURN, stacks)
			new_value = entity.status_effects.burn
	
	add_to_combat_log_string("    " + get_entity_name(entity) + " gains " + str(stacks) + " " + Enums.get_status_string(status_name) + " (" + str(new_value) + " total)")
	status_applied.emit(entity, status_name, stacks)

func heal_entity(entity, amount: int):
	var old_hp = entity.stats.hit_points_current
	entity.stats.hit_points_current += amount
	
	# Handle overheal
	if entity.stats.hit_points_current > entity.stats.hit_points:
		var overheal = entity.stats.hit_points_current - entity.stats.hit_points
		entity.stats.hit_points_current = entity.stats.hit_points
		if entity.status_effects:
			entity.status_effects.overheal_triggered.emit(overheal)
		add_to_combat_log_string("    " + get_entity_name(entity) + " healed " + str(amount - overheal) + " HP (" + str(overheal) + " overheal)")
	else:
		add_to_combat_log_string("    " + get_entity_name(entity) + " healed " + str(amount) + " HP")
	
	healing_applied.emit(entity, amount)
	stat_changed.emit(entity, "hit_points", old_hp, entity.stats.hit_points_current)

func process_turn_start_status_effects(entity):
	if not entity.status_effects:
		return
		
	add_to_combat_log_string(get_entity_name(entity) + " status effects at turn start:")
	
	# Poison damage
	if entity.status_effects.poison > 0:
		if entity.stats.shield_current > 0:
			add_to_combat_log_string("    Poison blocked by shield")
		else:
			await apply_damage_from_status(entity, entity.status_effects.poison, Enums.StatusEffects.POISON)
		entity.status_effects.decrement_status(Enums.StatusEffects.POISON)
		if entity.status_effects.poison == 0:
			status_removed.emit(entity, "poison")
		await wait_for_speed()
	
	# Burn damage  
	if entity.status_effects.burn > 0:
		var burn_damage = entity.status_effects.burn * get_base_burn_damage(entity)
		await apply_damage_from_status(entity, burn_damage, Enums.StatusEffects.BURN)
		entity.status_effects.decrement_status(Enums.StatusEffects.BURN)
		if entity.status_effects.burn == 0:
			status_removed.emit(entity, "burn")
		await wait_for_speed()
	
	# Acid armor reduction
	if entity.status_effects.acid > 0:
		if entity.stats.shield_current > 0:
			var acid_damage = min(entity.status_effects.acid, entity.stats.shield_current)
			await apply_damage_from_status(entity, acid_damage, Enums.StatusEffects.ACID)
			add_to_combat_log_string("    Acid reduces shield by " + str(acid_damage))
			stat_changed.emit(entity, "shield", entity.stats.shield_current + acid_damage, entity.stats.shield_current)
		# - JDM: Acid doesn't naturally deteriorate
		#entity.status_effects.acid = max(0, entity.status_effects.acid - 1)
		#if entity.status_effects.acid == 0:
		#	status_removed.emit(entity, "acid")
		await wait_for_speed()
	
	# Regeneration healing
	if entity.status_effects.regeneration > 0:
		await heal_entity(entity, entity.status_effects.regeneration)
		entity.status_effects.decrement_status(Enums.StatusEffects.REGENERATION)
		if entity.status_effects.regeneration == 0:
			status_removed.emit(entity, "regeneration")
		await wait_for_speed()

	# blind healing
	if entity.status_effects.blind > 0:
		# this is where I add the functionality for blind
		entity.status_effects.decrement_status(Enums.StatusEffects.BLIND)
		if entity.status_effects.blind == 0:
			status_removed.emit(entity, "blind")
		await wait_for_speed()

func trigger_exposed(entity):
	add_to_combat_log_string(get_entity_name(entity) + " is EXPOSED!")
	
	# Mark as triggered for this combat
	if entity == player_entity:
		player_exposed_triggered = true
	else:
		enemy_exposed_triggered = true
	
	# Emit exposed signal
	entity_exposed.emit(entity)
	
	# Process exposed item rules
	await process_exposed_rules(entity)

func trigger_wounded(entity):
	add_to_combat_log_string(get_entity_name(entity) + " is WOUNDED!")
	
	# Mark as triggered for this combat
	if entity == player_entity:
		player_wounded_triggered = true
	else:
		enemy_wounded_triggered = true
	
	# Emit wounded signal
	entity_wounded.emit(entity)
	
	# Process wounded item rules
	await process_wounded_rules(entity)

func process_exposed_rules(entity):
	add_to_combat_log_string(get_entity_name(entity) + " exposed rules:")
	
	if entity == player_entity:
		# Process weapon
		if entity.inventory.weapon_slot:
			await process_item_rules(entity.inventory.weapon_slot, entity, Enums.TriggerType.EXPOSED, -1)
		
		# Process inventory items
		for item in entity.inventory.item_slots:
			if item:
				await process_item_rules(item, entity, Enums.TriggerType.EXPOSED, item.slot_index)
	else:
		# Enemy exposed abilities  
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.EXPOSED:
				await process_enemy_ability(ability, entity)

func process_wounded_rules(entity):
	add_to_combat_log_string(get_entity_name(entity) + " wounded rules:")
	
	if entity == player_entity:
		# Process weapon
		if entity.inventory.weapon_slot:
			await process_item_rules(entity.inventory.weapon_slot, entity, Enums.TriggerType.WOUNDED, -1)
		
		# Process inventory items
		for item in entity.inventory.item_slots:
			if item:
				await process_item_rules(item, entity, Enums.TriggerType.WOUNDED, item.slot_index)
	else:
		# Enemy wounded abilities
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.WOUNDED:
				await process_enemy_ability(ability, entity)

func handle_entity_death(dead_entity):
	add_to_combat_log_string(get_entity_name(dead_entity) + " has died!")
	
	combat_active = false
	var winner = get_opponent(dead_entity)
	
	# Award gold to winner if it's the player
	if winner == player_entity:
		var gold_reward = calculate_gold_reward(dead_entity)
		#player_entity.stats.gold += gold_reward
		add_to_combat_log_string("Player gains " + str(gold_reward) + " gold!")
	
	winner.stats.reset_stats_after_combat()
	winner.status_effects.reset_statuses()
	
	combat_ended.emit(winner, dead_entity)

func calculate_gold_reward(defeated_enemy) -> int:
	# TODO: Implement based on enemy types (Goblins, Ghouls, etc.)
	return defeated_enemy.stats.gold + Player.current_rank  # Default reward

func get_base_burn_damage(entity) -> int:
	# Get base burn damage for entity (default 3, can be modified by items)
	# TODO: Check for items that modify base burn damage
	return 3

func set_combat_speed(speed: CombatSpeed):
	match speed:
		CombatSpeed.PAUSE:
			combat_speed = 0.0
		CombatSpeed.NORMAL:
			combat_speed = 1.0
		CombatSpeed.FAST:
			combat_speed = 2.0
		CombatSpeed.VERY_FAST:
			combat_speed = 3.0

	# Update animation manager
	animation_manager.set_combat_speed(combat_speed)			

func wait_for_speed():
	"""Wait based on current combat speed setting"""
	if combat_speed > 0:
		var wait_time = base_message_duration / combat_speed
		await get_tree().create_timer(wait_time).timeout

func wait_for_highlight():
	"""Wait for item highlight duration"""
	if combat_speed > 0:
		var wait_time = base_highlight_duration / combat_speed
		await get_tree().create_timer(wait_time).timeout

# Helper functions
func get_opponent(entity):
	"""Get the opponent of the given entity"""
	return enemy_entity if entity == player_entity else player_entity

func get_entity_name(entity) -> String:
	"""Get display name for entity"""
	if entity == player_entity:
		return Player.player_name if Player.player_name != "" else "Player"
	else:
		return entity.get_display_name() if entity.has_method("get_display_name") else "Enemy"

func is_entity_dead(entity) -> bool:
	"""Check if entity is dead"""
	return entity.stats.hit_points_current <= 0

func is_entity_exposed_triggered(entity) -> bool:
	"""Check if entity has already triggered exposed this combat"""
	return player_exposed_triggered if entity == player_entity else enemy_exposed_triggered

func is_entity_wounded_triggered(entity) -> bool:
	"""Check if entity has already triggered wounded this combat"""
	return player_wounded_triggered if entity == player_entity else enemy_wounded_triggered

func cleanup_combat():
	"""Clean up combat state"""
	combat_active = false
	player_entity = null
	enemy_entity = null
	current_turn_entity = null
	turn_number = 0

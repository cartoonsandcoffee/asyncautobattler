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
signal damage_dealt(target, amount)
signal healing_applied(target, amount)

# State change signals
signal stat_changed(entity, stat_name: String, old_value: int, new_value: int)
signal status_applied(entity, status_name: String, stacks: int)
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
var base_highlight_duration: float = 2.0
var base_message_duration: float = 1.5

enum CombatSpeed {
	PAUSE = 0,
	NORMAL = 1,
	FAST = 2,
	VERY_FAST = 3
}

func _ready():
	# Connect to player signals if needed
	pass

func start_combat(player, enemy):
	"""Initialize and begin combat between player and enemy"""
	print("=== COMBAT STARTED ===")
	
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
	
	# Emit combat started signal
	combat_started.emit(player_entity, enemy_entity)
	
	# Determine turn order based on agility
	var first_entity = player_entity if player_entity.stats.agility >= enemy_entity.stats.agility else enemy_entity
	var second_entity = enemy_entity if first_entity == player_entity else player_entity
	
	print("Turn order: ", get_entity_name(first_entity), " goes first")
	
	# Trigger battle start events
	await process_battle_start_events(first_entity, second_entity)
	
	# Begin turn loop
	await combat_loop(first_entity, second_entity)

func combat_loop(first_entity, second_entity):
	"""Main combat loop - alternates turns until one entity dies"""
	
	while combat_active:
		turn_number += 1
		print("\n--- Turn ", turn_number, " ---")
		
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
	print(get_entity_name(entity), "'s turn")
	
	# Emit turn started signal
	turn_started.emit(entity)
	
	# Process status effects at turn start
	await process_turn_start_status_effects(entity)
	
	# Process turn start item rules
	await process_turn_start_rules(entity)
	
	# Check if entity is stunned (skip attacks if stunned)
	if entity.status_effects.stun > 0:
		print(get_entity_name(entity), " is stunned! Turn skipped.")
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
	
	print(get_entity_name(attacker), " attacks for ", damage, " damage")
	
	# Process on-hit item rules for attacker
	await process_on_hit_rules(attacker)
	
	# Apply damage to target
	await apply_damage(target, damage)
	
	# Emit attack signal
	attack_executed.emit(attacker, target, damage)
	
	await wait_for_speed()

func apply_damage(target, damage_amount: int):
	"""Apply damage to target, handling shield/armor first"""
	var remaining_damage = damage_amount
	
	# Apply to shield first
	if target.stats.shield_current > 0:
		var shield_damage = min(remaining_damage, target.stats.shield_current)
		target.stats.shield_current -= shield_damage
		remaining_damage -= shield_damage
		
		print(get_entity_name(target), " shield reduced by ", shield_damage, " (", target.stats.shield_current, " remaining)")
		stat_changed.emit(target, "shield", target.stats.shield_current + shield_damage, target.stats.shield_current)
		
		# Check for first time exposed
		if target.stats.shield_current == 0 and not is_entity_exposed_triggered(target):
			await trigger_exposed(target)
	
	# Apply remaining damage to hit points
	if remaining_damage > 0:
		target.stats.hit_points_current -= remaining_damage
		print(get_entity_name(target), " takes ", remaining_damage, " damage (", target.stats.hit_points_current, " HP remaining)")
		stat_changed.emit(target, "hit_points", target.stats.hit_points_current + remaining_damage, target.stats.hit_points_current)
		
		# Check for first time wounded (50% HP)
		var wounded_threshold = target.stats.hit_points / 2
		if target.stats.hit_points_current <= wounded_threshold and not is_entity_wounded_triggered(target):
			await trigger_wounded(target)
	
	# Emit damage dealt signal
	damage_dealt.emit(target, damage_amount)
	
	# Check for death
	if target.stats.hit_points_current <= 0:
		await handle_entity_death(target)

func process_battle_start_events(first_entity, second_entity):
	"""Process all battle start item rules in turn order"""
	print("\n-- BATTLE START EVENTS --")
	
	# First entity's battle start rules
	await process_entity_battle_start_rules(first_entity)
	
	# Second entity's battle start rules  
	await process_entity_battle_start_rules(second_entity)

func process_entity_battle_start_rules(entity):
	"""Process battle start rules for a specific entity"""
	print(get_entity_name(entity), " battle start rules:")
	
	# Process weapon rules first if it exists
	if entity == player_entity and entity.inventory.weapon_slot:
		await process_item_rules(entity.inventory.weapon_slot, entity, "battle_start")
	
	# Process inventory items in order
	if entity == player_entity:
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				await process_item_rules(item, entity, "battle_start")


func process_turn_start_rules(entity):
	"""Process turn start item rules for entity"""
	print(get_entity_name(entity), " turn start rules:")
	
	# Process weapon rules first if it exists
	if entity == player_entity and entity.inventory.weapon_slot:
		await process_item_rules(entity.inventory.weapon_slot, entity, "turn_start")
	
	# Process inventory items in order
	if entity == player_entity:
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				await process_item_rules(item, entity, "turn_start")
	else:
		# Enemy turn start abilities
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.TURN_START:
				await process_enemy_ability(ability, entity)

func process_on_hit_rules(attacker):
	"""Process on-hit rules for attacking entity"""
	print(get_entity_name(attacker), " on-hit rules:")
	
	# Process weapon rules first if it exists
	if attacker == player_entity and attacker.inventory.weapon_slot:
		await process_item_rules(attacker.inventory.weapon_slot, attacker, "on_hit")
	
	# Process inventory items in order
	if attacker == player_entity:
		for i in range(attacker.inventory.item_slots.size()):
			var item = attacker.inventory.item_slots[i]
			if item:
				await process_item_rules(item, attacker, "on_hit")
	else:
		# Enemy on-hit abilities
		for ability in attacker.abilities:
			if ability.trigger == Enums.TriggerType.ON_HIT:
				await process_enemy_ability(ability, attacker)

func process_item_rules(item: Item, entity, trigger_type: String):
	"""Process all rules for an item that match the trigger type"""
	if not item or not item.rules:
		return

	for rule in item.rules:
		if rule.trigger_type == trigger_type:
			await execute_item_rule(item, rule, entity)
		
		# Emit signal BEFORE executing so UI can highlight
		item_rule_triggered.emit(item, rule, entity)

		# Wait for highlight duration
		await wait_for_highlight()
		
		# Now execute the rule
		await execute_item_rule(item, rule, entity)
		
		# Small pause between rules
		await wait_for_speed()




func process_enemy_ability(ability: EnemyAbility, entity):
	"""Process a single enemy ability"""
	print("  -> ", ability.ability_name, ": ", ability.trigger, " effect")
	
	# Emit ability triggered signal
	enemy_ability_triggered.emit(ability, entity)
	
	# Execute the ability effect
	match ability.effect_type:
		EnemyAbility.EffectType.DAMAGE_BOOST:
			await modify_entity_stat(entity, "damage", ability.value)
		EnemyAbility.EffectType.SHIELD_GAIN:
			await modify_entity_stat(entity, "shield", ability.value)
		EnemyAbility.EffectType.HEAL:
			await heal_entity(entity, ability.value)
		EnemyAbility.EffectType.APPLY_POISON:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), "poison", ability.value)
		EnemyAbility.EffectType.APPLY_BURN:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), "burn", ability.value)
		EnemyAbility.EffectType.APPLY_THORNS:
			await apply_status_effect(entity, "thorns", ability.value)
		EnemyAbility.EffectType.APPLY_ACID:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), "acid", ability.value)
		EnemyAbility.EffectType.APPLY_STUN:
			# Apply to opponent
			await apply_status_effect(get_opponent(entity), "stun", ability.value)
		EnemyAbility.EffectType.DIRECT_DAMAGE:
			# Deal direct damage to opponent
			await apply_damage(get_opponent(entity), ability.value)
		EnemyAbility.EffectType.REDUCE_PLAYER_DAMAGE:
			# Reduce opponent's damage
			await modify_entity_stat(get_opponent(entity), "damage", -ability.value)
		EnemyAbility.EffectType.DOUBLE_STRIKE:
			# Give entity extra strike this turn
			await modify_entity_stat(entity, "strikes", ability.value)
		EnemyAbility.EffectType.STEAL_GOLD:
			# Only works if opponent is player
			if get_opponent(entity) == player_entity:
				var stolen = min(ability.value, get_opponent(entity).stats.gold)
				get_opponent(entity).stats.gold -= stolen
				print("    Enemy steals ", stolen, " gold from player")
	
	# Update ability's runtime state
	ability.times_triggered += 1
	
	# Wait for visual feedback
	await wait_for_speed()

func execute_item_rule(item: Item, rule: ItemRule, entity):
	"""Execute a specific item rule and show visual feedback"""
	print("  -> ", item.item_name, ": ", rule.trigger_type, " effect")

	# Emit rule triggered signal
	item_rule_triggered.emit(item, rule, entity)
	
	# Show visual highlight (implement in UI)
	# TODO: Highlight item in inventory for highlight duration
	
	# Execute the rule effect based on type
	match rule.effect_type:
		ItemRule.EFFECT_MODIFY_STAT:
			await modify_entity_stat(entity, rule.target_stat, rule.effect_amount)
		ItemRule.EFFECT_APPLY_STATUS:
			await apply_status_effect(entity, rule.target_status, rule.effect_amount)
		ItemRule.EFFECT_DEAL_DAMAGE:
			await apply_damage(get_opponent(entity), rule.effect_amount)
		ItemRule.EFFECT_HEAL:
			await heal_entity(entity, rule.effect_amount)
	
	# Wait for visual feedback
	await wait_for_speed()


func _matches_trigger(rule: ItemRule, trigger_type: String) -> bool:
	"""Check if a rule matches the current trigger type"""
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


func modify_entity_stat(entity, stat_name: String, amount: int):
	"""Modify an entity's stat and emit appropriate signals"""
	var old_value: int
	var new_value: int
	
	match stat_name:
		"damage":
			old_value = entity.stats.damage_current
			entity.stats.damage_current += amount
			new_value = entity.stats.damage_current
		"shield", "armor":
			old_value = entity.stats.shield_current  
			entity.stats.shield_current += amount
			new_value = entity.stats.shield_current
		"agility":
			old_value = entity.stats.agility_current
			entity.stats.agility_current += amount  
			new_value = entity.stats.agility_current
		"hit_points", "hitpoints", "health":
			old_value = entity.stats.hit_points_current
			entity.stats.hit_points_current += amount
			new_value = entity.stats.hit_points_current
			
			# Check for overheal
			if new_value > entity.stats.hit_points:
				var overheal_amount = new_value - entity.stats.hit_points
				entity.stats.hit_points_current = entity.stats.hit_points
				new_value = entity.stats.hit_points_current
				if entity.status_effects:
					entity.status_effects.overheal_triggered.emit(overheal_amount)
		"strikes":
			old_value = entity.stats.strikes
			entity.stats.strikes += amount
			new_value = entity.stats.strikes
	
	print("    ", get_entity_name(entity), " ", stat_name, ": ", old_value, " -> ", new_value)
	stat_changed.emit(entity, stat_name, old_value, new_value)

func apply_status_effect(entity, status_name: String, stacks: int):
	"""Apply status effect stacks to entity"""
	if not entity.status_effects:
		return
		
	var old_value: int
	var new_value: int
	
	match status_name:
		"poison":
			old_value = entity.status_effects.poison
			entity.status_effects.poison += stacks
			new_value = entity.status_effects.poison
		"thorns":
			old_value = entity.status_effects.thorns
			entity.status_effects.thorns += stacks
			new_value = entity.status_effects.thorns
		"acid":
			old_value = entity.status_effects.acid
			entity.status_effects.acid += stacks
			new_value = entity.status_effects.acid
		"regeneration":
			old_value = entity.status_effects.regeneration
			entity.status_effects.regeneration += stacks
			new_value = entity.status_effects.regeneration
		"stun":
			old_value = entity.status_effects.stun
			entity.status_effects.stun += stacks
			new_value = entity.status_effects.stun
		"burn":
			old_value = entity.status_effects.burn
			entity.status_effects.burn += stacks
			new_value = entity.status_effects.burn
	
	print("    ", get_entity_name(entity), " gains ", stacks, " ", status_name, " (", new_value, " total)")
	status_applied.emit(entity, status_name, stacks)

func heal_entity(entity, amount: int):
	"""Heal entity and handle overheal"""
	var old_hp = entity.stats.hit_points_current
	entity.stats.hit_points_current += amount
	
	# Handle overheal
	if entity.stats.hit_points_current > entity.stats.hit_points:
		var overheal = entity.stats.hit_points_current - entity.stats.hit_points
		entity.stats.hit_points_current = entity.stats.hit_points
		if entity.status_effects:
			entity.status_effects.overheal_triggered.emit(overheal)
		print("    ", get_entity_name(entity), " healed ", amount - overheal, " HP (", overheal, " overheal)")
	else:
		print("    ", get_entity_name(entity), " healed ", amount, " HP")
	
	healing_applied.emit(entity, amount)
	stat_changed.emit(entity, "hit_points", old_hp, entity.stats.hit_points_current)

func process_turn_start_status_effects(entity):
	"""Process all status effects that trigger at turn start"""
	if not entity.status_effects:
		return
		
	print(get_entity_name(entity), " status effects at turn start:")
	
	# Poison damage
	if entity.status_effects.poison > 0:
		if entity.stats.shield_current > 0:
			print("    Poison blocked by shield")
		else:
			await apply_damage(entity, entity.status_effects.poison)
		entity.status_effects.poison = max(0, entity.status_effects.poison - 1)
		if entity.status_effects.poison == 0:
			status_removed.emit(entity, "poison")
		await wait_for_speed()
	
	# Burn damage  
	if entity.status_effects.burn > 0:
		var burn_damage = entity.status_effects.burn * get_base_burn_damage(entity)
		await apply_damage(entity, burn_damage)
		entity.status_effects.burn = max(0, entity.status_effects.burn - 1)
		if entity.status_effects.burn == 0:
			status_removed.emit(entity, "burn")
		await wait_for_speed()
	
	# Acid armor reduction
	if entity.status_effects.acid > 0:
		if entity.stats.shield_current > 0:
			var acid_damage = min(entity.status_effects.acid, entity.stats.shield_current)
			entity.stats.shield_current -= acid_damage
			print("    Acid reduces shield by ", acid_damage)
			stat_changed.emit(entity, "shield", entity.stats.shield_current + acid_damage, entity.stats.shield_current)
		entity.status_effects.acid = max(0, entity.status_effects.acid - 1)
		if entity.status_effects.acid == 0:
			status_removed.emit(entity, "acid")
		await wait_for_speed()
	
	# Regeneration healing
	if entity.status_effects.regeneration > 0:
		await heal_entity(entity, entity.status_effects.regeneration)
		entity.status_effects.regeneration = max(0, entity.status_effects.regeneration - 1)
		if entity.status_effects.regeneration == 0:
			status_removed.emit(entity, "regeneration")
		await wait_for_speed()

func trigger_exposed(entity):
	"""Trigger exposed event for entity (first time shield reaches 0)"""
	print(get_entity_name(entity), " is EXPOSED!")
	
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
	"""Trigger wounded event for entity (first time at 50% HP)"""
	print(get_entity_name(entity), " is WOUNDED!")
	
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
	"""Process all exposed-trigger item rules for entity"""
	print(get_entity_name(entity), " exposed rules:")
	
	if entity == player_entity:
		# Process weapon
		if entity.inventory.weapon_slot:
			await process_item_rules(entity.inventory.weapon_slot, entity, "exposed")
		
		# Process inventory items
		for item in entity.inventory.item_slots:
			if item:
				await process_item_rules(item, entity, "exposed")
	else:
		# Enemy exposed abilities  
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.EXPOSED:
				await process_enemy_ability(ability, entity)

func process_wounded_rules(entity):
	"""Process all wounded-trigger item rules for entity"""
	print(get_entity_name(entity), " wounded rules:")
	
	if entity == player_entity:
		# Process weapon
		if entity.inventory.weapon_slot:
			await process_item_rules(entity.inventory.weapon_slot, entity, "wounded")
		
		# Process inventory items
		for item in entity.inventory.item_slots:
			if item:
				await process_item_rules(item, entity, "wounded")
	else:
		# Enemy wounded abilities
		for ability in entity.abilities:
			if ability.trigger == Enums.TriggerType.WOUNDED:
				await process_enemy_ability(ability, entity)

func handle_entity_death(dead_entity):
	"""Handle when an entity dies and end combat"""
	print(get_entity_name(dead_entity), " has died!")
	
	combat_active = false
	var winner = get_opponent(dead_entity)
	
	# Award gold to winner if it's the player
	if winner == player_entity:
		var gold_reward = calculate_gold_reward(dead_entity)
		player_entity.stats.gold += gold_reward
		print("Player gains ", gold_reward, " gold!")
	
	combat_ended.emit(winner, dead_entity)

func calculate_gold_reward(defeated_enemy) -> int:
	"""Calculate gold reward based on enemy type/difficulty"""
	# TODO: Implement based on enemy types (Goblins, Ghouls, etc.)
	return 5  # Default reward

func get_base_burn_damage(entity) -> int:
	"""Get base burn damage for entity (default 3, can be modified by items)"""
	# TODO: Check for items that modify base burn damage
	return 3

func set_combat_speed(speed: CombatSpeed):
	"""Set combat speed for animations and waits"""
	match speed:
		CombatSpeed.PAUSE:
			combat_speed = 0.0
		CombatSpeed.NORMAL:
			combat_speed = 1.0
		CombatSpeed.FAST:
			combat_speed = 2.0
		CombatSpeed.VERY_FAST:
			combat_speed = 3.0

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

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
var combat_log: String = ""

# Combat state tracking per combat
var player_exposed_triggered: bool = false
var enemy_exposed_triggered: bool = false
var player_wounded_triggered: bool = false
var enemy_wounded_triggered: bool = false

# Add animation manager
var animation_manager: AnimationManager

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
	# Main combat loop - alternates turns until one entity dies
	
	while combat_active:
		turn_number += 1
		add_to_combat_log_string("\n--- Turn " + str(turn_number) + " ---")
		
		# First entity's turn
		if combat_active and not is_entity_dead(first_entity):
			await execute_turn(first_entity)
			
		# Check for combat end AFTER turn completes
		if not combat_active or is_entity_dead(first_entity) or is_entity_dead(second_entity):
			break
			
		# Second entity's turn  
		if combat_active and not is_entity_dead(second_entity):
			await execute_turn(second_entity)
		
		# Check for combat end after second entity
		if not combat_active or is_entity_dead(first_entity) or is_entity_dead(second_entity):
			break

	# Combat has ended - ensure all animations complete
	await end_combat_gracefully(first_entity, second_entity)

func execute_turn(entity):
	# -- Execute a complete turn for the given entity
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

	# Process countdown/charge rules for items
	await process_countdown_rules()

	# Process turn start item rules
	await process_turn_start_rules(entity)
	
	# Check if entity is stunned (skip attacks if stunned)
	if entity.status_effects.stun > 0:
		add_to_combat_log_string(get_entity_name(entity) + " is stunned! Turn skipped.")
		entity.status_effects.stun = max(0, entity.status_effects.stun - 1)
		if entity.status_effects.stun == 0:
			status_removed.emit(entity, "stun")
		# JDM: Maybe add a little STUN animation for when the player's turn is skipped
		await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))
	else:
		# MILESTONE: Attacks
		animation_manager.play_milestone("Attacks")
		await animation_manager.milestone_complete

		# Execute attacks with proper animation
		await execute_attack_sequence(entity)

	await remove_thorn_stacks(entity)

	# Turn end
	turn_ended.emit(entity)

func execute_attack_sequence(attacker):
	var target = get_opponent(attacker)
	var strikes = attacker.stats.strikes_current

	add_to_combat_log_string(get_entity_name(attacker) + " attacks!")

	# Process each strike
	for strike_num in range(strikes):
		if is_entity_dead(target):
			break
		
		var damage = attacker.stats.damage_current
		
		# Play attack animation through AnimationManager
		animation_manager.play_attack_animation(attacker, target)
		
		# Wait for the attack to reach the hit point (usually mid-animation)
		await CombatSpeed.create_timer(CombatSpeed.get_duration("attack_slide") * 0.5)
		
		# Deal the damage 
		await apply_damage_unified(target, damage, attacker, "attack")
		
		# Apply thorns as needed
		await process_thorns_reflection(attacker, target)

		# Process on-hit rules DURING the attack animation
		if not is_entity_dead(target):
			await process_on_hit_rules(attacker)
		
		# Wait for attack animation to fully complete
		await animation_manager.wait_for_current_sequence()
		
		# Small gap between multiple strikes
		if strike_num < strikes - 1:
			await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))



func remove_thorn_stacks(entity):
	if entity.status_effects.thorns > 0:
		add_to_combat_log_string(str(entity.status_effects.thorns) + "stacks of thorns removed from " + get_entity_name(entity) + ".")
		entity.status_effects.remove_status(Enums.StatusEffects.THORNS)

func process_thorns_reflection(attacker, target):
	"""Process thorns damage reflection using unified system"""
	if target.status_effects.thorns > 0:
		var reflected_damage = target.status_effects.thorns
		add_to_combat_log_string(get_entity_name(attacker) + " takes thorns damage!")
		
		# Use unified damage function
		await apply_damage_unified(attacker, reflected_damage, target, "thorns")

		# All stacks of thorns remove on TURN END.


func apply_damage_unified(target, amount: int, source, damage_type: String = "attack") -> int:
	# SINGLE SOURCE OF TRUTH for all damage
	if amount <= 0:
		return 0
	
	var shield_damage = 0
	var hp_damage = 0
	var total_damage = amount
	var dmg_destination_enum: Enums.Stats = Enums.Stats.SHIELD 
	
	# Step 1: Apply to shield first
	if target.stats.shield_current > 0:
		shield_damage = min(target.stats.shield_current, total_damage)
		target.stats.shield_current -= shield_damage
		total_damage -= shield_damage
		
		if target.stats.shield_current <= 0:
			dmg_destination_enum = Enums.Stats.EXPOSED 
		else:
			dmg_destination_enum = Enums.Stats.SHIELD
			
		# Create shield damage visual
		if shield_damage > 0:
			await _create_damage_visual(target, shield_damage, dmg_destination_enum, source, damage_type)
			add_to_combat_log_string(get_entity_name(target) + " shield reduced by " + str(shield_damage) + " (" + str(target.stats.shield_current) + " remaining)")
			stat_changed.emit(target, "shield", target.stats.shield_current + shield_damage, target.stats.shield_current)
		
		# Check for exposed trigger
		if target.stats.shield_current == 0 and not is_entity_exposed_triggered(target):
			await trigger_exposed(target)
	
	# Step 2: Apply remaining to HP
	if total_damage > 0:
		hp_damage = total_damage
		var old_hp = target.stats.hit_points_current
		target.stats.hit_points_current -= hp_damage
		var wounded_threshold = target.stats.hit_points / 2
		
		if target.stats.hit_points_current <= wounded_threshold:
			dmg_destination_enum = Enums.Stats.WOUNDED 
		else:
			dmg_destination_enum = Enums.Stats.HITPOINTS
			
		# Create HP damage visual
		await _create_damage_visual(target, hp_damage, dmg_destination_enum, source, damage_type)
		add_to_combat_log_string(get_entity_name(target) + " takes " + str(hp_damage) + " damage (" + str(target.stats.hit_points_current) + " HP remaining)")
		stat_changed.emit(target, "hit_points", old_hp, target.stats.hit_points_current)
		
		# Check for wounded trigger (50% HP)
		if target.stats.hit_points_current <= wounded_threshold and not is_entity_wounded_triggered(target):
			await trigger_wounded(target)
	
	# Check for death
	if target.stats.hit_points_current <= 0:
		target.stats.hit_points_current = 0
		await handle_entity_death(target)
	
	return (shield_damage + hp_damage)



func process_countdown_rules():
	# JDM: This function will have to loop through inventory items and decrement countdown/charge items
	pass

func process_battle_start_events(first_entity, second_entity):
	add_to_combat_log_string("\n-- BATTLE START EVENTS --")
	
	# MILESTONE: Item Effects (if any battle start items exist)
	await process_entity_items_sequentially(first_entity, Enums.TriggerType.BATTLE_START)
	await process_entity_items_sequentially(second_entity, Enums.TriggerType.BATTLE_START)


func process_turn_start_rules(entity):
	add_to_combat_log_string(get_entity_name(entity) + " turn start rules:")
	await process_entity_items_sequentially(entity, Enums.TriggerType.TURN_START)


func process_on_hit_rules(attacker):
	add_to_combat_log_string(get_entity_name(attacker) + " on-hit rules:")
	await process_entity_items_sequentially(attacker, Enums.TriggerType.ON_HIT)



func process_entity_items_sequentially(entity, trigger_type: Enums.TriggerType):
	# Step 1: Collect all items that should trigger
	var items_to_process = collect_triggered_items(entity, trigger_type)
	
	if items_to_process.is_empty():
		return
	

	print("Processing %d items for %s - %s" % [
		items_to_process.size(), 
		get_entity_name(entity),
		Enums.get_trigger_type_string(trigger_type)
	])


	# Step 2: Send them to AnimationManager for visual sequencing
	animation_manager.play_item_sequence(items_to_process, entity, Enums.get_trigger_type_string(trigger_type))
	
	# Step 3: While animations play, apply the actual game logic
	for item_data in items_to_process:
		var item = item_data["item"]
		var rule = item_data["rule"]
		
		var target = entity

		# Wait for animation to start
		await CombatSpeed.create_timer(CombatSpeed.get_duration("item_highlight") * 0.5)

		# - JDM: this should set the entity to ENEMY if they are the target of the rule
		match rule.target_type:
			Enums.TargetType.SELF:
				target = entity
			Enums.TargetType.ENEMY:
				target = get_opponent(entity)
			Enums.TargetType.RANDOM:
				target = entity if randf() < 0.5 else get_opponent(entity)

		# Emit the signal for combat_panel to show the visual
		item_rule_triggered.emit(item, rule, target)
		
		# Apply the actual rule effect
		await execute_item_rule(item, rule, target)

		# Wait for this item's animation to complete
		await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc") * 0.7)

	# Step 4: Wait for all animations to complete
	await animation_manager.wait_for_current_sequence()

func collect_triggered_items(entity, trigger_type: Enums.TriggerType) -> Array:
	var items_to_proc = []
	
	if entity == player_entity:
		# Check weapon first
		if entity.inventory.weapon_slot:
			for rule in entity.inventory.weapon_slot.rules:
				if rule.trigger_type == trigger_type:
					items_to_proc.append({
						"item": entity.inventory.weapon_slot,
						"rule": rule,
						"slot_index": -1  # -1 indicates weapon
					})
		
		# Then check inventory items in order
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				for rule in item.rules:
					if rule.trigger_type == trigger_type:
						items_to_proc.append({
							"item": item,
							"rule": rule,
							"slot_index": i
						})
	
	else:  # Enemy entity
		# Check enemy abilities
		for ability in entity.abilities:
			if ability:
				for rule in ability.rules:
					if rule.trigger_type == trigger_type:
						items_to_proc.append({
							"item": ability,
							"rule": rule,
							"slot_index": -2
						})			
	
	return items_to_proc


func execute_item_rule(item: Item, rule: ItemRule, entity):
	add_to_combat_log_string("  -> " + item.item_name + ": " + Enums.get_trigger_type_string(rule.trigger_type) + " effect.")

	# Execute the rule effect based on type
	match rule.effect_type:
		Enums.EffectType.MODIFY_STAT:
			await modify_entity_stat(entity, rule.target_stat, rule.effect_amount)
		Enums.EffectType.APPLY_STATUS:
			await apply_status_effect(entity, rule.target_status, rule.effect_amount)
		Enums.EffectType.DEAL_DAMAGE:
			await apply_damage_unified(get_opponent(entity), rule.effect_amount, entity, "item")
		Enums.EffectType.HEAL:
			await heal_entity(entity, rule.effect_amount)
	

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


func process_poison_damage(entity):
	if entity.status_effects.poison > 0:
		if entity.stats.shield_current > 0:
			add_to_combat_log_string("    Poison blocked by shield!")
		else:
			var damage = entity.status_effects.poison
			add_to_combat_log_string(get_entity_name(entity) + " takes poison damage!")
			
			# Use unified damage function
			await apply_damage_unified(entity, damage, null, "poison")
		entity.status_effects.decrement_status(Enums.StatusEffects.POISON)
		if entity.status_effects.poison == 0:
			status_removed.emit(entity, Enums.StatusEffects.POISON)


func process_burn_damage(entity):
	if entity.status_effects.burn > 0:
		var damage = entity.stats.burn_damage_current
		add_to_combat_log_string(get_entity_name(entity) + " is burning!")
		
		# Use unified damage function
		await apply_damage_unified(entity, damage, null, "burn")
		
		# Reduce burn stacks
		entity.status_effects.decrement_status(Enums.StatusEffects.BURN)
		if entity.status_effects.burn == 0:
			status_removed.emit(entity, Enums.StatusEffects.BURN)


func process_acid_damage(entity):
	# Acid only applies to shield, and doesn't decrement during combat
	if entity.status_effects.acid > 0 and entity.stats.shield_current > 0:
		var damage = min(entity.status_effects.acid, entity.stats.shield_current)
		var dmg_destination_enum: Enums.Stats = Enums.Stats.SHIELD 
		add_to_combat_log_string(get_entity_name(entity) + "'s shield corrode for " + str(damage) + "!")
		
		# Acid only damages shield - we'll handle this specially
		entity.stats.shield_current -= damage

		if entity.stats.shield_current <= 0:
			dmg_destination_enum = Enums.Stats.EXPOSED 
		else:
			dmg_destination_enum = Enums.Stats.SHIELD	

		# Create acid visual
		await _create_damage_visual(entity, damage, dmg_destination_enum, null, "acid")
		stat_changed.emit(entity, "shield", entity.stats.shield_current + damage, entity.stats.shield_current)

		# Check exposed
		if entity.stats.shield_current == 0 and not is_entity_exposed_triggered(entity):
			await trigger_exposed(entity)
		
		# Acid does not reduce naturally.


func process_turn_start_status_effects(entity):
	if not entity.status_effects:
		return
		
	add_to_combat_log_string(get_entity_name(entity) + " status effects at turn start:")
	
	# Poison damage
	process_poison_damage(entity)
	
	# Burn damage  
	process_burn_damage(entity)
	
	# Acid armor reduction
	process_acid_damage(entity)
	
	# Regeneration healing
	if entity.status_effects.regeneration > 0:
		await heal_entity(entity, entity.status_effects.regeneration)
		entity.status_effects.decrement_status(Enums.StatusEffects.REGENERATION)
		if entity.status_effects.regeneration == 0:
			status_removed.emit(entity, Enums.StatusEffects.REGENERATION)


	# blind healing
	if entity.status_effects.blind > 0:
		# this is where I add the functionality for blind
		entity.status_effects.decrement_status(Enums.StatusEffects.BLIND)
		if entity.status_effects.blind == 0:
			status_removed.emit(entity, "blind")
		await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))

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
	await process_entity_items_sequentially(entity, Enums.TriggerType.EXPOSED)

func process_wounded_rules(entity):
	add_to_combat_log_string(get_entity_name(entity) + " wounded rules:")
	await process_entity_items_sequentially(entity, Enums.TriggerType.WOUNDED)


func handle_entity_death(dead_entity):
	add_to_combat_log_string(get_entity_name(dead_entity) + " has died!")
	
	# Setting combat_active to false allows it to end gracefully after turn
	combat_active = false



func end_combat_gracefully(entity1, entity2):
	# End combat after ensuring all animations complete
	
	# Wait for any ongoing animations to complete
	await animation_manager.wait_for_current_sequence()
	
	# Wait for any attack animations to finish
	if animation_manager.has_method("wait_for_attack_animation"):
		await animation_manager.wait_for_attack_animation()
	
	# Small pause before ending
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	
	# Determine winner and loser
	var winner = entity1 if is_entity_dead(entity2) else entity2
	var loser = entity2 if is_entity_dead(entity2) else entity1
	
	# MILESTONE: Battle End
	animation_manager.play_milestone("Battle End", {
		"winner": winner,
		"loser": loser
	})
	await animation_manager.milestone_complete
	
	animation_manager._play_turn_end()

	# Award gold to winner if it's the player
	if winner == player_entity:
		var gold_reward = calculate_gold_reward(loser)
		add_to_combat_log_string("Player gains " + str(gold_reward) + " gold!")

	# Reset entity states
	if entity1 == player_entity:
		player_entity.stats.reset_stats_after_combat()
		player_entity.status_effects.reset_statuses()
	
	if entity2 == player_entity:
		player_entity.stats.reset_stats_after_combat()
		player_entity.status_effects.reset_statuses()
	
	# Now emit the combat ended signal
	combat_ended.emit(winner, loser)
	
	add_to_combat_log_string("\n=== COMBAT ENDED ===")




func calculate_gold_reward(defeated_enemy) -> int:
	# TODO: Implement based on enemy types (Goblins, Ghouls, etc.)
	return defeated_enemy.stats.gold + Player.current_rank  # Default reward

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

func _get_status_color(status_name: String) -> Color:
	"""Get the color for a status effect"""
	match status_name:
		"poison": return GameColors.Stats.poison
		"burn": return GameColors.Stats.burn  
		"acid": return GameColors.Stats.acid
		"thorns": return GameColors.Stats.thorns
		_: return Color.WHITE

# Helper to create damage visuals through AnimationManager
func _create_damage_visual(target, amount: int, damage_stat: Enums.Stats, source, damage_type: String):
	# Determine visual info based on damage type
	var visual_info = {}
	
	match damage_type:
		"attack":
			# Regular attack damage
			if source == player_entity:
				visual_info = {
					"icon": player_entity.inventory.weapon_slot.item_icon if player_entity.inventory.weapon_slot else null,
					"color": player_entity.inventory.weapon_slot.item_color if player_entity.inventory.weapon_slot else Color.WHITE,
					"info": "You hit the Enemy!"
				}
			else:
				visual_info = {
					"icon": enemy_entity.weapon_sprite,
					"color": enemy_entity.sprite_color,
					"info": "The Enemy hits You!"
				}
		
		"poison", "burn", "acid":
			# Status effect damage
			visual_info = {
				"icon": null,  # Will use status icon
				"color": _get_status_color(damage_type),
				"info": damage_type.capitalize(),
				"status": damage_type
			}
		
		"thorns":
			# Reflected damage
			visual_info = {
				"icon": null,
				"color": Color.DARK_GREEN,
				"info": "Thorns!",
				"status": "thorns"
			}
		
		_:
			# Generic damage
			visual_info = {
				"icon": null,
				"color": Color.RED,
				"info": "UNKNOWN DAMAGE!"
			}
	
	# Send to AnimationManager for visual creation
	animation_manager.play_damage_indicator(target, amount, damage_stat, visual_info)
	
	# Small wait for visual to appear
	await CombatSpeed.create_timer(CombatSpeed.get_duration("damage_number") * 0.3)
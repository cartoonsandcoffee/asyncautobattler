class_name CombatEventQueue
extends Node

var _queue: Array[CombatEvent] = []
var _processing: bool = false

const MAX_QUEUE_DEPTH: int = 500
var _events_processed_this_batch: int = 0
var _chain_broken_item: Item = null

var combat_manager

signal queue_emptied

func _init(manager) -> void:
	combat_manager = manager

func enqueue(event: CombatEvent) -> void:
	_queue.append(event)
	_try_process()

func enqueue_next(event: CombatEvent) -> void:
	_queue.insert(0, event)

func enqueue_batch(events: Array[CombatEvent]) -> void:
	for e in events:
		_queue.append(e)
	_try_process()

func enqueue_batch_next(events: Array[CombatEvent]) -> void:
	for i in range(events.size() - 1, -1, -1):
		_queue.insert(0, events[i])

func is_queue_processing() -> bool:
	return _processing

func queue_size() -> int:
	return _queue.size()

func purge_except_death() -> void:
	# Called by DEATH_SEQUENCE handler — wipes everything mid-combat.
	# Any other pending triggers, items, status procs are irrelevant once someone dies.
	# ON_KILL note: if ON_KILL is ever re-introduced, collect those events first,
	# call purge_except_death(), then re-enqueue them before DEATH_SEQUENCE fires.
	_queue.clear()

func _try_process() -> void:
	if _processing:
		return
	_processing = true
	_events_processed_this_batch = 0
	print(">>> QUEUE START")

	while not _queue.is_empty():
		_events_processed_this_batch += 1
		if _events_processed_this_batch > MAX_QUEUE_DEPTH:
			push_warning("CombatEventQueue: MAX_QUEUE_DEPTH exceeded — clearing queue.")
			_queue.clear()
			break

		var event: CombatEvent = _queue.pop_front()
		print(">>> PROCESSING: ", event.event_type)
		await _process_event(event)

	_processing = false
	print(">>> QUEUE DONE")
	queue_emptied.emit()

func clear() -> void:
	_queue.clear()
	_processing = false
	_events_processed_this_batch = 0
	_chain_broken_item = null

func _process_event(event: CombatEvent) -> void:
	if event == null:
		return
	if event.event_type != CombatEvent.EventType.EXECUTE_RULE:
		_chain_broken_item = null
		
	var dbg := str(event.event_type)
	if event.event_type == CombatEvent.EventType.MODIFY_STAT:
		var ename = "player" if event.entity == combat_manager.player_entity else "enemy"
		dbg += " [%s %s %+d]" % [ename, event.stat, event.amount]
	if event.event_type == CombatEvent.EventType.ATTACK_ANIMATION:
		var ename = "player" if event.entity == combat_manager.player_entity else "enemy"
		dbg += " [attacker=%s dmg=%d]" % [ename, event.amount]
	print(dbg)

	var indicator_layer = combat_manager.indicator_layer
	
	match event.event_type:
		CombatEvent.EventType.MODIFY_STAT:
			if not combat_manager.combat_active and not combat_manager.combat_ending:
				return
			var read_type = Enums.StatType.BASE if event.stat == Enums.Stats.STRIKES else event.stat_type   ## -- For when STRIKES are changing
			var old_value = combat_manager.stat_handler.get_stat_value(event.entity, event.stat, read_type)
			combat_manager.stat_handler.change_stat(event.entity, event.stat, event.amount, event.stat_type, event.source_item)
			var new_value = combat_manager.stat_handler.get_stat_value(event.entity, event.stat, read_type)
			var entity_name = combat_manager.get_entity_name(event.entity)
			if old_value != new_value:
				# Make sure to evaluate thresholds
				if event.stat == Enums.Stats.SHIELD:
					enqueue_next(CombatEvent.check_thresholds(event.entity, Enums.Stats.SHIELD, old_value, new_value))
				if event.stat == Enums.Stats.HITPOINTS:
					enqueue_next(CombatEvent.check_thresholds(event.entity, Enums.Stats.HITPOINTS, old_value, new_value))

				var log_line: String
				if event.amount < 0 and event.stat == Enums.Stats.SHIELD:
					log_line = CombatLog.fmt_damage_shield(entity_name, abs(event.amount), old_value, new_value)
				elif event.amount < 0 and event.stat == Enums.Stats.HITPOINTS:
					log_line = CombatLog.fmt_damage_hp(entity_name, abs(event.amount), old_value, new_value)
				else:
					log_line = CombatLog.fmt_stat_change(entity_name, event.stat, old_value, new_value)
				if event.damage_type != "":
					var source_label: String
					if event.damage_type == "item" and event.source_item:
						source_label = CombatLog.color_item(event.source_item.item_name, event.source_item)
					else:
						source_label = CombatLog.color_status_str(event.damage_type)
					log_line = log_line.rstrip("\n") + " (%s)" % source_label
				if event.source_item:
					log_line = "   %s - %s" % [CombatLog.color_item(event.source_item.item_name, event.source_item), log_line.strip_edges()]
				combat_manager.add_to_combat_log_string(log_line)

		CombatEvent.EventType.DEAL_DAMAGE:
			if not combat_manager.combat_active and not combat_manager.combat_ending:
				return
			var source_item = event.source_item
			if source_item == null and event.entity is Item:
				source_item = event.entity
			combat_manager.damage_system.apply_damage(
				event.target,
				event.amount,
				event.entity,
				event.damage_type,
				source_item
			)

		CombatEvent.EventType.LOG:
			combat_manager.add_to_combat_log_string(event.log_text)

		CombatEvent.EventType.APPLY_STATUS:
			if not combat_manager.combat_active and not combat_manager.combat_ending:
				return
			combat_manager.status_handler.apply_status(
				event.entity, event.status, event.amount, event.source_item)
			var new_val = combat_manager.status_handler.get_status_value(event.entity, event.status)
			if not CombatSpeed.is_instant_mode():
				indicator_layer._handle_status_box_update_immediate(event.entity, event.status, new_val)
				#await CombatSpeed.create_timer(CombatSpeed.get_duration("status_change"))
			var gain_line = CombatLog.fmt_status_gain(combat_manager.status_handler._get_entity_name(event.entity),	event.status, event.amount, new_val)
			if event.source_item:
				gain_line = "   %s - %s" % [CombatLog.color_item(event.source_item.item_name, event.source_item), gain_line.strip_edges()]
			combat_manager.add_to_combat_log_string(gain_line)

		CombatEvent.EventType.REMOVE_STATUS:
			if not combat_manager.combat_active and not combat_manager.combat_ending:
				return
			var old_val = combat_manager.status_handler.get_status_value(event.entity, event.status)
			if old_val <= 0:
				return
			combat_manager.status_handler.remove_status(
				event.entity, event.status, event.amount)
			var new_val = combat_manager.status_handler.get_status_value(event.entity, event.status)
			if not CombatSpeed.is_instant_mode():
				indicator_layer._handle_status_box_update_immediate(event.entity, event.status, new_val)
				#await CombatSpeed.create_timer(CombatSpeed.get_duration("status_change"))
			var lose_line = CombatLog.fmt_status_lose(combat_manager.status_handler._get_entity_name(event.entity),	event.status, event.amount, new_val)
			if event.source_item:
				lose_line = "   %s - %s" % [CombatLog.color_item(event.source_item.item_name, event.source_item), lose_line.strip_edges()]
			combat_manager.add_to_combat_log_string(lose_line)

		CombatEvent.EventType.DAMAGE_VISUAL:
			# Plays damage number indicator. Enqueued via enqueue_next in apply_damage
			# BEFORE the MODIFY_STAT event for the same hit, so visual precedes stat change.
			if not CombatSpeed.is_instant_mode():
				indicator_layer._spawn_damage_indicator_immediate(
					event.entity, event.amount, event.stat, event.visual_info)
				await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc"))


		CombatEvent.EventType.EXECUTE_RULE:
			# Condition chain — skip if a prior rule on this item failed
			if _chain_broken_item != null and event.item == _chain_broken_item:
				return

			# Reset chain break if this is a different item
			if event.item != _chain_broken_item:
				_chain_broken_item = null

			if not combat_manager.combat_active:
				return

			# Resolve target
			var target = combat_manager._get_rule_target(event.entity, event.rule.target_type)

			# Evaluate condition before any visual
			if event.rule.has_condition:
				var condition_passes = combat_manager.condition_evaluator.evaluate_condition(event.rule, event.entity, target)
				if not condition_passes:
					var item_name = event.item.item_name if event.item else "Unknown Item"
					combat_manager.add_to_combat_log_string("   %s - %s" % [
						CombatLog.color_item(item_name, event.item),
						CombatLog.color("Condition not met (skipped): " + combat_manager.condition_evaluator.condition_to_string(event.rule), Color.GRAY)
					])
					_chain_broken_item = event.item
					return

			var execution_count = combat_manager.effect_executor._calculate_execution_count(event.item, event.rule, event.entity)

			if not CombatSpeed.is_instant_mode():
				var is_status_effect = event.rule.effect_type in [Enums.EffectType.APPLY_STATUS, Enums.EffectType.REMOVE_STATUS]
				var display_amount: int
				if event.rule.effect_type == Enums.EffectType.CONVERT:
					var from_amount = combat_manager.effect_executor._calculate_conversion_amount(event.rule, event.entity)
					display_amount = int(from_amount * event.rule.conversion_ratio)
				else:
					display_amount = combat_manager.effect_executor._calculate_effect_amount(event.rule, event.entity, target, event.amount)
					if event.rule.effect_type == Enums.EffectType.REMOVE_STATUS:
						display_amount = -display_amount
				var is_full_hp_heal = (event.rule.effect_type == Enums.EffectType.HEAL and event.rule.target_type == Enums.TargetType.SELF and event.entity.stats.hit_points_current >= event.entity.stats.hit_points)

				if display_amount != 0 and not is_full_hp_heal:
					# Resolve RANDOM status here so indicator and executor use the same value
					var resolved_status = combat_manager.effect_executor.resolve_random_status(event.rule, target)
					if event.rule.effect_type == Enums.EffectType.CONVERT and event.rule.convert_to_type == ItemRule.StatOrStatus.STATUS:
						resolved_status = combat_manager.effect_executor.resolve_random_status(event.rule, target, event.rule.convert_to_status)
					if is_status_effect and resolved_status == Enums.StatusEffects.NONE:
						combat_manager.add_to_combat_log_string("   %s - %s" % [
							CombatLog.color_item(event.item.item_name, event.item),
							CombatLog.color("No statuses to remove", Color.GRAY)
						])
						_chain_broken_item = event.item
						return
					event.resolved_status = resolved_status
					if display_amount != 0 and not is_full_hp_heal and event.rule.effect_type != Enums.EffectType.DEAL_DAMAGE:
						for i in range(execution_count):
							indicator_layer._spawn_item_proc_indicator_immediate(event.item, event.rule, event.entity, display_amount, resolved_status)
							await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc"))

			# Execute — returns false if condition failed
			var success = await combat_manager.effect_executor.execute_item_rule(event.item, event.rule, event.entity, target, event.amount, event.resolved_status, execution_count)

			if success:
				combat_manager.item_rule_triggered.emit(event.item, event.rule, event.entity)
			else:
				_chain_broken_item = event.item

		CombatEvent.EventType.STATUS_PROC_VISUAL:
			if not CombatSpeed.is_instant_mode():
				indicator_layer._spawn_status_proc_indicator_immediate(
					event.entity, event.status, event.stat, event.amount)
				await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc"))

		CombatEvent.EventType.CHECK_THRESHOLDS:
			if not combat_manager.combat_active and not combat_manager.combat_ending:
				return
			combat_manager.stat_handler.fire_threshold_signals(event.entity, event.stat, event.amount, event.amount2, event.stat_type)

		CombatEvent.EventType.TURN_END_PHASE:
			var target = combat_manager.enemy_entity if event.entity == combat_manager.player_entity else combat_manager.player_entity
			combat_manager.status_handler.process_turn_end_status_effects(event.entity)
			combat_manager.status_handler.process_thorns_removal(target)
			enqueue_next(CombatEvent.turn_end_signal(event.entity))
			combat_manager.enqueue_items_for_trigger(event.entity, Enums.TriggerType.TURN_END)

		CombatEvent.EventType.ATTACK_PHASE:
			if not combat_manager.combat_active:
				return
			combat_manager.execute_attack_sequence(event.entity)

		CombatEvent.EventType.DEATH_SEQUENCE:
			# Purge everything else — nothing matters after death.
			purge_except_death()
			combat_manager.combat_active = false
			combat_manager.combat_ending = false
			# Log handled by _on_death_triggered before enqueue — see CombatManager
			# Phase 8: enqueue ATTACK_ANIMATION event here for death anim, await it
			if not CombatSpeed.is_instant_mode():
				await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
			await combat_manager.end_combat_gracefully()

		CombatEvent.EventType.DELAY:
			if not CombatSpeed.is_instant_mode():
				await CombatSpeed.create_timer(event.amount / 1000.0)

		CombatEvent.EventType.ATTACK_ANIMATION:
			if not combat_manager.combat_active:
				return
			
			var attacker = event.entity
			var target = event.target
			var damage = event.amount
			var strike_number: int = event.log_text.to_int() if event.log_text != "" else 1
			var attack_label := "Strike %d" % strike_number
			
			if not CombatSpeed.is_instant_mode():
				combat_manager.animation_manager.play_attack_animation(attacker, target)
				await combat_manager.animation_manager.combat_panel.attack_sequence_complete
			
			# Decrement strikes_left through change_stat so stat_changed fires
			attacker.stats.strikes_left = maxi(attacker.stats.strikes_left - 1, 0)
			combat_manager.stat_changed.emit(attacker, Enums.Stats.STRIKES, attacker.stats.strikes_left + 1, attacker.stats.strikes_left)

			# Apply damage through the queue (enqueues DAMAGE_VISUAL + MODIFY_STAT via enqueue_next)
			combat_manager.damage_system.apply_damage(target, damage, attacker, attack_label)

			# Thorns: enqueues DEAL_DAMAGE for reflection if target has thorns
			combat_manager.status_handler.enqueue_thorns_if_present(attacker, target)

			# ON_HIT items
			combat_manager.enqueue_items_for_trigger(attacker, Enums.TriggerType.ON_HIT, Enums.Stats.NONE, null, 0, false)

			# Chain next strike — enqueued last so all consequences of this strike resolve first
			if attacker.stats.strikes_left > 0:
				if not CombatSpeed.is_instant_mode():
					combat_manager.event_queue.enqueue(CombatEvent.delay(CombatSpeed.get_duration("attack_gap")))
				var attacker_ref = attacker  # already captured above
				# Check stun for next strike
				if attacker_ref.status_effects.stun > 0:
					combat_manager.event_queue.enqueue(CombatEvent.log(combat_manager.color_entity(combat_manager.get_entity_name(attacker_ref)) + " is STUNNED! Attack skipped."))
					combat_manager.event_queue.enqueue(CombatEvent.remove_status(attacker_ref, Enums.StatusEffects.STUN, 1))

					attacker.stats.strikes_left = maxi(attacker.stats.strikes_left - 1, 0)
					combat_manager.stat_changed.emit(attacker, Enums.Stats.STRIKES, attacker.stats.strikes_left + 1, attacker.stats.strikes_left)
				if attacker.stats.strikes_left > 0 and not (attacker_ref.inventory.weapon_slot and attacker_ref.inventory.weapon_slot.cant_attack):
					var next_damage = attacker_ref.stats.damage_current
					combat_manager.event_queue.enqueue(CombatEvent.attack_animation(attacker_ref, target, next_damage, strike_number + 1))
			else:
				# Final strike done — show next turn total
				combat_manager.event_queue.enqueue(CombatEvent.turn_end_phase(event.entity))
				combat_manager.attack_sequence_active = false

		CombatEvent.EventType.TURN_START_SIGNAL:
			combat_manager.turn_started.emit(event.entity, event.amount)

		CombatEvent.EventType.TURN_END_SIGNAL:
			combat_manager.turn_ended.emit(event.entity)

		_:
			pass

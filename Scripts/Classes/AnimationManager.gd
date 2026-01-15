extends Node
class_name AnimationManager

## Centralized animation coordination system

signal animation_sequence_complete()
signal milestone_complete(milestone_name: String)
signal item_proc_complete(entity, rule: ItemRule)
#signal item_animation_complete(item: Item)

# Animation queue and state
var animation_queue: Array[AnimationRequest] = []
var current_milestone: String = ""
var is_processing: bool = false

# References to UI components
var combat_panel: CombatPanel
var turn_sign_scene = preload("res://Scenes/Elements/combat_turn_sign.tscn")
var item_proc_scene = preload("res://Scenes/Elements/combat_item_proc.tscn")

enum AnimationType {
	MILESTONE,       # "Battle Start", "Turn Start", etc.
	ITEM_SEQUENCE,   # Sequential item processing
	ITEM_HIGHLIGHT,  # Individual item highlighting
	ITEM_EFFECT,     # Item effect animations (damage numbers, etc.)
	ATTACK,          # Attack slide animations
	STATUS_EFFECT,   # Status effect visuals
	DAMAGE_INDICATOR # For damage numbers
}

class AnimationRequest:
	var type: AnimationType
	var data: Dictionary
	var completion_callback: Callable
	
	func _init(anim_type: AnimationType, anim_data: Dictionary, callback: Callable = Callable()):
		type = anim_type
		data = anim_data
		completion_callback = callback

func _ready():
	# Connect to combat manager for speed updates
	if CombatManager:
		CombatManager.combat_started.connect(_on_combat_started)
		CombatManager.combat_ended.connect(_on_combat_ended)

func initialize(panel: CombatPanel):
	"""Initialize with references to UI components"""
	combat_panel = panel

# ===== MILESTONE SYSTEM =====

func _get_animation_variant(base_name: String) -> String:
	"""Get the correct animation variant based on current speed"""
	match CombatSpeed.current_mode:
		CombatSpeed.CombatSpeedMode.NORMAL:
			return base_name
		CombatSpeed.CombatSpeedMode.FAST:
			return base_name + "_fast"
		CombatSpeed.CombatSpeedMode.VERY_FAST:
			return base_name + "_very_fast"
		CombatSpeed.CombatSpeedMode.INSTANT:
			return base_name + "_instant"  # Doesn't matter, won't play
		_:
			return base_name

func play_milestone(milestone_name: String, data: Dictionary = {}):
	"""Play a combat milestone animation"""
	var request = AnimationRequest.new(AnimationType.MILESTONE, {
		"name": milestone_name,
		"data": data
	})
	
	_queue_animation(request)

func _execute_milestone(milestone_name: String, data: Dictionary):
	"""Execute a milestone animation"""
	current_milestone = milestone_name
	print("=== MILESTONE: ", milestone_name, " ===")
	
	match milestone_name:
		"Battle Start":
			await _play_battle_start()
		"Turn Start":
			await _play_turn_start(data.get("entity"), data.get("turn_number", 1))
		"Status Effects":
			await _play_status_effects_milestone()
		"Item Effects":
			await _play_item_effects_milestone()
		"Attacks":
			await _play_attacks_milestone()
		"Turn End":
			await _play_turn_end()
		"Battle End":
			await _play_battle_end(data.get("winner"), data.get("loser"))
	
	milestone_complete.emit(milestone_name)

func _play_battle_start():
	var turn_sign = _create_turn_sign("Battle Start!")
	var duration = CombatSpeed.get_duration("milestone_sign")
	turn_sign.set_timer(duration)
	await turn_sign.turn_animation_done

func _play_turn_start(entity, turn_number: int):
	var entity_name = CombatManager.get_entity_name(entity)
	var message = "Turn %d\n%s's Turn" % [turn_number, entity_name]
	
	var turn_sign = _create_turn_sign(message)
	var duration = CombatSpeed.get_duration("milestone_sign")
	turn_sign.set_timer(duration)
	await turn_sign.turn_animation_done

func _play_status_effects_milestone():
	pass

func _play_item_effects_milestone():
	pass


func _play_attacks_milestone():
	pass


func _play_turn_end():
	pass


func _play_battle_end(winner, loser):
	var winner_name = CombatManager.get_entity_name(winner)
	var message = "Battle Over!\n%s Wins!" % winner_name
	
	# Play death animation for the loser
	if combat_panel:
		if loser == CombatManager.enemy_entity:
			# Enemy death animation
			var anim_name = _get_animation_variant("enemy_die")
			if combat_panel.enemy_anim.has_animation(anim_name):
				combat_panel.enemy_anim.speed_scale = 1.0
				combat_panel.enemy_anim.play(anim_name)
				
				#var anim_length = combat_panel.enemy_anim.get_animation(anim_name).length
				#await CombatSpeed.create_timer(anim_length)		
		else:
			var anim_name = _get_animation_variant("player_die")
			if combat_panel.player_anim.has_animation(anim_name):
				combat_panel.player_anim.speed_scale = 1.0
				combat_panel.player_anim.play(anim_name)
				
				#var anim_length = combat_panel.player_anim.get_animation(anim_name).length
				#await CombatSpeed.create_timer(anim_length)

	var turn_sign = _create_turn_sign(message)
	var duration = CombatSpeed.get_duration("milestone_sign")
	turn_sign.set_timer(duration)
	await turn_sign.turn_animation_done

# ===== SEQUENTIAL ITEM PROCESSING =====

func play_item_sequence(items_to_proc: Array, entity, trigger_type: String):
	"""Play a sequence of item animations in order with proper timing"""
	var request = AnimationRequest.new(AnimationType.ITEM_SEQUENCE, {
		"items": items_to_proc,
		"entity": entity,
		"trigger_type": trigger_type
	})
	
	_queue_animation(request)

func _execute_item_sequence(items: Array, entity, trigger_type: String):
	# Execute sequential item animations with proper timing
	if items.is_empty():
		return
		
	for i in range(items.size()):
		var item_data = items[i]
		var item = item_data				        # item_data["item"]
		var rule = item_data.rules[0]			    # item_data["rule"]
		var slot_index = item_data.slot_index		# item_data.get("slot_index", -1)
		
		## -- JDM: Removing Item highlighting during combat, seems redundant and causes visual noise

		# ----- STEP 1: Highlight the item
		# Highlight the item slot
		#if combat_panel and entity == CombatManager.player_entity:
		#	combat_panel.highlight_item_slot(slot_index, slot_index == -1)

		# Brief moment for highlight to be visible
		#await CombatSpeed.create_timer(CombatSpeed.get_duration("item_highlight_brief"))
		
		# ----- STEP 2: Show Item Proc
		if combat_panel:
			#combat_panel.spawn_item_proc_indicator(item, rule, entity)
			var proc_duration = CombatSpeed.get_duration("item_proc")
			#await CombatSpeed.create_timer(proc_duration * 0.8)  # Wait for most of animation

			# emit completion so the status effects update
			#item_proc_complete.emit(entity, rule)

		## -- JDM: removing this because removing item highlighting, but that if-statement may be useful for overlap timing
		# ----- STEP 3: Clear Highlight, move to next
		#if combat_panel:
		#	combat_panel._clear_all_highlights()
		#	if i < items.size() - 1:
		#		await CombatSpeed.create_timer(CombatSpeed.get_duration("item_highlight_brief"))

		#await CombatSpeed.create_timer(CombatSpeed.get_overlap_duration())
		#item_animation_complete.emit(item)

	# Brief pause after all items complete
	#await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))


# ===== ITEM ANIMATION SYSTEM =====

func play_attack_animation(attacker, target):
	"""Play attack slide animation"""
	var request = AnimationRequest.new(AnimationType.ATTACK, {
		"attacker": attacker,
		"target": target
	})
	
	_queue_animation(request)

func _execute_attack_animation(attacker, target):
	"""Execute attack animation"""
	if not combat_panel:
		return
	
	var is_player_attacking = (attacker == CombatManager.player_entity)
	
	# Play appropriate attack animation
	if is_player_attacking:
		var anim_name = _get_animation_variant("player_attack")
		combat_panel.player_anim.speed_scale = 1.0
		var anim_length = combat_panel.player_anim.get_animation("player_attack").length
		combat_panel.player_anim.play(anim_name)
		#await CombatSpeed.create_timer(anim_length * 0.5)

	else:
		var anim_name = _get_animation_variant("enemy_attack")
		combat_panel.enemy_anim.speed_scale = 1.0
		var anim_length = combat_panel.enemy_anim.get_animation(anim_name).length
		combat_panel.enemy_anim.play(anim_name)

		#await CombatSpeed.create_timer(anim_length * 0.5)

func play_damage_indicator(target, amount: int, damage_stat: Enums.Stats, visual_info: Dictionary):
	"""Queue a damage indicator animation"""
	var request = AnimationRequest.new(AnimationType.DAMAGE_INDICATOR, {
		"target": target,
		"amount": amount,
		"damage_stat": damage_stat,
		"visual_info": visual_info
	})
	
	# Damage indicators don't queue - they play immediately
	# This allows multiple damage sources to show simultaneously
	_execute_damage_indicator(request.data.target, request.data.amount,	request.data.damage_stat, request.data.visual_info)

func _execute_damage_indicator(target, amount: int, damage_stat: Enums.Stats, visual_info: Dictionary):
	if not combat_panel:
		return
	
	print("  -> Damage indicator: %d to %s's %s" % [
		amount,
		CombatManager.get_entity_name(target),
		Enums.get_stat_string(damage_stat)
	])
	
	# Let combat_panel create the visual at the right position
	combat_panel.create_damage_indicator(target, amount, damage_stat, visual_info)

# ===== ANIMATION QUEUE SYSTEM =====

func _queue_animation(request: AnimationRequest):
	"""Add animation to queue and process if not busy"""
	animation_queue.append(request)
	
	if not is_processing:
		_process_animation_queue()

func _process_animation_queue():
	"""Process animation queue sequentially"""
	if is_processing:
		return
	
	is_processing = true
	
	while not animation_queue.is_empty():
		var request = animation_queue.pop_front()
		
		# Execute the animation
		await _execute_animation_request(request)
		
		# Brief gap between animations for clarity
		#await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	
	is_processing = false
	animation_sequence_complete.emit()

func _execute_animation_request(request: AnimationRequest):
	"""Execute a single animation request"""
	match request.type:
		AnimationType.MILESTONE:
			await _execute_milestone(request.data.name, request.data.get("data", {}))

		AnimationType.ITEM_SEQUENCE:  # Testing if this function is unnecessary now
			pass
			#await _execute_item_sequence(
			#	request.data.items,
			#	request.data.entity,
			#	request.data.trigger_type
			#)	

		AnimationType.ITEM_HIGHLIGHT:
			pass #handled in item sequencer now
		
		AnimationType.ITEM_EFFECT:
			pass #handled in item sequencer now

		AnimationType.ATTACK:
			await _execute_attack_animation(
				request.data.attacker,
				request.data.target
			)
		
		AnimationType.STATUS_EFFECT:
			pass #handled in item sequencer now

		AnimationType.DAMAGE_INDICATOR:
			# Damage indicators execute immediately, not queued
			pass

	# Execute callback if provided
	if request.completion_callback.is_valid():
		request.completion_callback.call()

# ===== UTILITY FUNCTIONS =====

func _create_turn_sign(message: String) -> CombatTurnSign:
	var turn_sign = turn_sign_scene.instantiate()
	combat_panel.add_child(turn_sign)
	turn_sign.set_label(message)
	return turn_sign


# ===== EVENT HANDLERS =====

func _on_combat_started(player, enemy):
	# Reset animation manager for new combat
	clear_queue()
	is_processing = false
	current_milestone = ""

func _on_combat_ended(winner, loser):
	# Wait a moment for any final animations
	#await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	
	# Clear everything
	clear_all_animations()
	is_processing = false

func clear_queue():
	animation_queue.clear()

func clear_all_animations():
	"""Force clear all animations and indicators"""
	# Clear the queue
	clear_queue()
	
	# Stop attack animation
	#if combat_panel and combat_panel.slide_animation:
	#	combat_panel.slide_animation.stop()
	
	# Clear all proc indicators
	if combat_panel:
		for child in combat_panel.get_children():
			if child.has_method("_done"):
				child.queue_free()


# ===== PUBLIC INTERFACE =====

func wait_for_attack_animation():
	"""Wait for current attack animation to complete"""
	if combat_panel and combat_panel.slide_animation and combat_panel.slide_animation.is_playing():
		var current_anim = combat_panel.slide_animation.current_animation
		if current_anim:
			await combat_panel.attack_sequence_complete
			return

	if combat_panel and combat_panel.player_anim and (combat_panel.player_anim.get_current_animation() == CombatSpeed.get_animation_variant("player_attack")):
		var current_anim = combat_panel.player_anim.current_animation
		if current_anim:
			await combat_panel.attack_sequence_complete
			return	

	if combat_panel and combat_panel.enemy_anim and (combat_panel.enemy_anim.get_current_animation() == CombatSpeed.get_animation_variant("enemy_attack")):
		var current_anim = combat_panel.enemy_anim.current_animation
		if current_anim:
			await combat_panel.attack_sequence_complete
			return			


func wait_for_current_sequence():
	if is_processing:
		await animation_sequence_complete

	await wait_for_attack_animation()


func wait_for_milestone(milestone_name: String):
	if current_milestone != milestone_name:
		await milestone_complete

func wait_for_all_animations():
	"""Wait for ALL animations to complete"""
	# Wait for queued animations
	if is_processing:
		await animation_sequence_complete
	
	# Wait for attack animations
	await wait_for_attack_animation()
	
	# Wait for any proc indicators to finish
	if combat_panel:
		for child in combat_panel.get_children():
			if child.has_method("stat_animation_done") and child.visible:
				# Wait for proc animation
				await child.stat_animation_done
	
	# Small final pause
	#await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func is_busy() -> bool:
	return is_processing

func get_current_milestone() -> String:
	return current_milestone		
	

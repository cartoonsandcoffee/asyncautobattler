extends Node
class_name AnimationManager

## Centralized animation coordination system

signal animation_sequence_complete()
signal milestone_complete(milestone_name: String)
signal item_animation_complete(item: Item)

# Animation queue and state
var animation_queue: Array[AnimationRequest] = []
var current_milestone: String = ""
var is_processing: bool = false

# References to UI components
var combat_panel: CombatPanel
var turn_sign_scene = preload("res://Scenes/Elements/combat_turn_sign.tscn")
var item_proc_scene = preload("res://Scenes/Elements/combat_item_proc.tscn")

enum AnimationType {
	MILESTONE,      # "Battle Start", "Turn Start", etc.
	ITEM_SEQUENCE,  # Sequential item processing
	ITEM_HIGHLIGHT, # Individual item highlighting
	ITEM_EFFECT,    # Item effect animations (damage numbers, etc.)
	ATTACK,         # Attack slide animations
	STATUS_EFFECT   # Status effect visuals
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
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func _play_item_effects_milestone():
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func _play_attacks_milestone():
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func _play_turn_end():
	# Turn end cleanup
	if combat_panel:
		combat_panel._clear_all_highlights()
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))

func _play_battle_end(winner, loser):
	var winner_name = CombatManager.get_entity_name(winner)
	var message = "Battle Over!\n%s Wins!" % winner_name
	
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
	"""Execute sequential item animations with proper timing"""
	if items.is_empty():
		return
	
	print("Starting %s sequence for %d items" % [trigger_type, items.size()])
	
	for i in range(items.size()):
		var item_data = items[i]
		var item = item_data["item"]
		var rule = item_data["rule"]
		var slot_index = item_data.get("slot_index", -1)
		
		# Wait if paused
		await CombatSpeed.wait_if_paused()
		
		print("  -> Processing: ", item.item_name)
		
		# Highlight the item slot
		if combat_panel and entity == CombatManager.player_entity:
			combat_panel.highlight_item_slot(slot_index, slot_index == -1)
		
		# Brief moment for highlight to be visible
		await CombatSpeed.create_timer(CombatSpeed.get_duration("item_highlight") * 0.3)
		
		# The combat_panel will spawn the proc indicator when it receives the signal
		# We just need to wait for the animation duration
		await CombatSpeed.create_timer(CombatSpeed.get_overlap_duration())
		
		# Clear highlight
		if combat_panel:
			if slot_index == -1 and combat_panel.highlighted_item_slot == combat_panel.weapon_slot_ref:
				combat_panel._clear_all_highlights()
			elif slot_index >= 0 and slot_index < combat_panel.inventory_item_slots.size():
				if combat_panel.highlighted_item_slot == combat_panel.inventory_item_slots[slot_index]:
					combat_panel._clear_all_highlights()
		
		item_animation_complete.emit(item)
	
	# Brief pause after all items complete
	await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	print("Completed %s sequence" % trigger_type)


# ===== ITEM ANIMATION SYSTEM =====

func play_item_highlight(item: Item, entity, slot_index: int = -1):
	"""Play item highlight animation"""
	var request = AnimationRequest.new(AnimationType.ITEM_HIGHLIGHT, {
		"item": item,
		"entity": entity,
		"slot_index": slot_index
	})
	
	_queue_animation(request)

func _execute_item_highlight(item: Item, entity, slot_index: int):
	"""Execute item highlighting with proper timing"""
	print("  -> Highlighting: ", item.item_name)
	
	# Trigger highlight in combat panel
	if combat_panel and entity == CombatManager.player_entity:
		if slot_index == -1:  # Weapon slot
			combat_panel.highlight_item_slot(-1, true)
		else:  # Inventory slot
			combat_panel.highlight_item_slot(slot_index, false)
	
	# Wait for highlight to be visible
	await CombatSpeed.create_timer(CombatSpeed.get_duration("item_highlight"))
	
	item_animation_complete.emit(item)

func play_item_effect(item: Item, rule: ItemRule, entity):
	"""Play item effect animation"""
	var request = AnimationRequest.new(AnimationType.ITEM_EFFECT, {
		"item": item,
		"rule": rule,
		"entity": entity
	})
	
	_queue_animation(request)

func _execute_item_effect(item: Item, rule: ItemRule, entity):
	"""Execute item effect animation"""
	print("    -> Effect: ", rule.get_description())
	
	# Create and show item proc visual
	var item_proc = _create_item_proc(item, rule, entity)
	
	# Wait for item proc animation
	await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc"))
	
	item_animation_complete.emit(item)

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
	
	# Set animation speed based on combat speed
	combat_panel.slide_animation.speed_scale = CombatSpeed.get_multiplier()
	
	# Play appropriate attack animation
	if is_player_attacking:
		combat_panel.slide_animation.play("player_attack")
	else:
		combat_panel.slide_animation.play("enemy_attack")
	
	# Wait for animation to complete
	await combat_panel.slide_animation.animation_finished

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
		
		# Wait if paused
		await CombatSpeed.wait_if_paused()
		
		# Execute the animation
		await _execute_animation_request(request)
		
		# Brief gap between animations for clarity
		await CombatSpeed.create_timer(CombatSpeed.get_duration("turn_gap"))
	
	is_processing = false
	animation_sequence_complete.emit()

func _execute_animation_request(request: AnimationRequest):
	"""Execute a single animation request"""
	match request.type:
		AnimationType.MILESTONE:
			await _execute_milestone(request.data.name, request.data.get("data", {}))

		AnimationType.ITEM_SEQUENCE:  # This calls your new function
			await _execute_item_sequence(
				request.data.items,
				request.data.entity,
				request.data.trigger_type
			)	

		AnimationType.ITEM_HIGHLIGHT:
			await _execute_item_highlight(
				request.data.item,
				request.data.entity,
				request.data.slot_index
			)
		
		AnimationType.ITEM_EFFECT:
			await _execute_item_effect(
				request.data.item,
				request.data.rule,
				request.data.entity
			)
		
		AnimationType.ATTACK:
			await _execute_attack_animation(
				request.data.attacker,
				request.data.target
			)
		
		AnimationType.STATUS_EFFECT:
			await _execute_status_effect(request.data)
	
	# Execute callback if provided
	if request.completion_callback.is_valid():
		request.completion_callback.call()

func _execute_status_effect(data: Dictionary):
	# TODO: Implement status effect visuals
	await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))

# ===== UTILITY FUNCTIONS =====

func _create_turn_sign(message: String) -> CombatTurnSign:
	var turn_sign = turn_sign_scene.instantiate()
	combat_panel.add_child(turn_sign)
	turn_sign.set_label(message)
	return turn_sign

func _create_item_proc(item: Item, rule: ItemRule, entity) -> Control:
	var item_proc = item_proc_scene.instantiate()
	combat_panel.add_child(item_proc)
	
	# Configure the item proc based on rule
	item_proc.set_references()
	item_proc.set_label(rule.effect_amount)
	item_proc.set_info(rule.get_description())
	item_proc.set_item_visuals(item.item_icon, item.item_color)
	
	if rule.effect_type == Enums.EffectType.MODIFY_STAT:
		item_proc.set_stat_visuals(rule.target_stat)
	elif rule.effect_type == Enums.EffectType.APPLY_STATUS:
		item_proc.set_status_visuals(rule.target_status)
	
	# Set animation party
	if entity == CombatManager.player_entity:
		item_proc.run_animation(Enums.Party.PLAYER)
	else:
		item_proc.run_animation(Enums.Party.ENEMY)
	
	return item_proc

# ===== EVENT HANDLERS =====

func _on_combat_started(player, enemy):
	# Reset animation manager for new combat
	clear_queue()
	is_processing = false
	current_milestone = ""

func _on_combat_ended(winner, loser):
	clear_queue()
	is_processing = false

func clear_queue():
	animation_queue.clear()

# ===== PUBLIC INTERFACE =====

func wait_for_current_sequence():
	if is_processing:
		await animation_sequence_complete

func wait_for_milestone(milestone_name: String):
	if current_milestone != milestone_name:
		await milestone_complete

func is_busy() -> bool:
	return is_processing

func get_current_milestone() -> String:
	return current_milestone		



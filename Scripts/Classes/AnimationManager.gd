extends Node
class_name AnimationManager

## Centralized animation coordination system
## Manages timing, sequencing, and speed scaling for all combat visuals

signal animation_sequence_complete()
signal milestone_complete(milestone_name: String)
signal item_animation_complete(item: Item)

# Combat speed integration
var combat_speed_multiplier: float = 1.0
var is_paused: bool = false

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

func set_combat_speed(speed: float):
	"""Update combat speed - affects all animation timing"""
	combat_speed_multiplier = speed
	is_paused = (speed == 0.0)

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
	"""Play battle start milestone"""
	var turn_sign = _create_turn_sign("Battle Start!")
	var duration = 1.5 / combat_speed_multiplier
	turn_sign.set_timer(duration)
	await turn_sign.turn_animation_done

func _play_turn_start(entity, turn_number: int):
	"""Play turn start milestone"""
	var entity_name = CombatManager.get_entity_name(entity)
	var message = "Turn %d\n%s's Turn" % [turn_number, entity_name]
	
	var turn_sign = _create_turn_sign(message)
	var duration = 1.2 / combat_speed_multiplier
	turn_sign.set_timer(duration)
	await turn_sign.turn_animation_done

func _play_status_effects_milestone():
	"""Brief pause before status effects"""
	await _wait_scaled(0.3)

func _play_item_effects_milestone():
	"""Brief pause before item effects"""
	await _wait_scaled(0.2)

func _play_attacks_milestone():
	"""Brief pause before attacks"""
	await _wait_scaled(0.3)

func _play_turn_end():
	"""Turn end cleanup"""
	if combat_panel:
		combat_panel._clear_all_highlights()
	await _wait_scaled(0.2)

func _play_battle_end(winner, loser):
	"""Play battle end milestone"""
	var winner_name = CombatManager.get_entity_name(winner)
	var message = "Battle Over!\n%s Wins!" % winner_name
	
	var turn_sign = _create_turn_sign(message)
	var duration = 2.0 / combat_speed_multiplier
	turn_sign.set_timer(duration)
	await turn_sign.turn_animation_done

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
	var highlight_duration = 1.0 / combat_speed_multiplier
	await _wait_scaled(highlight_duration)
	
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
	var effect_duration = 1.0 / combat_speed_multiplier
	await get_tree().create_timer(effect_duration).timeout
	
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
	combat_panel.slide_animation.speed_scale = combat_speed_multiplier
	
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
		await _wait_for_unpause()
		
		# Execute the animation
		await _execute_animation_request(request)
		
		# Brief gap between animations for clarity
		await _wait_scaled(0.1)
	
	is_processing = false
	animation_sequence_complete.emit()

func _execute_animation_request(request: AnimationRequest):
	"""Execute a single animation request"""
	match request.type:
		AnimationType.MILESTONE:
			await _execute_milestone(request.data.name, request.data.get("data", {}))
		
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
	"""Execute status effect animation"""
	# TODO: Implement status effect visuals
	await _wait_scaled(0.5)

# ===== UTILITY FUNCTIONS =====

func _wait_scaled(base_duration: float):
	"""Wait for duration scaled by combat speed"""
	await _wait_for_unpause()
	
	if combat_speed_multiplier > 0:
		var actual_duration = base_duration / combat_speed_multiplier
		await get_tree().create_timer(actual_duration).timeout

func _wait_for_unpause():
	"""Wait while game is paused"""
	while is_paused:
		await get_tree().process_frame

func _create_turn_sign(message: String) -> CombatTurnSign:
	"""Create and display a turn sign"""
	var turn_sign = turn_sign_scene.instantiate()
	combat_panel.add_child(turn_sign)
	turn_sign.set_label(message)
	return turn_sign

func _create_item_proc(item: Item, rule: ItemRule, entity) -> Control:
	"""Create and display item proc animation"""
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
	"""Reset animation manager for new combat"""
	clear_queue()
	is_processing = false
	current_milestone = ""

func _on_combat_ended(winner, loser):
	"""Clean up when combat ends"""
	clear_queue()
	is_processing = false

func clear_queue():
	"""Clear all pending animations"""
	animation_queue.clear()

# ===== PUBLIC INTERFACE =====

func wait_for_current_sequence():
	"""Wait for current animation sequence to complete"""
	if is_processing:
		await animation_sequence_complete

func wait_for_milestone(milestone_name: String):
	"""Wait for specific milestone to complete"""
	if current_milestone != milestone_name:
		await milestone_complete

func is_busy() -> bool:
	"""Check if animation manager is currently processing"""
	return is_processing

func get_current_milestone() -> String:
	"""Get current milestone name"""
	return current_milestone		

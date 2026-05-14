class_name CombatEvent
extends Resource

enum EventType {
	LOG,
	MODIFY_STAT, APPLY_STATUS, REMOVE_STATUS, DEAL_DAMAGE, EXECUTE_RULE,
	DAMAGE_VISUAL, DEATH_SEQUENCE, DELAY, ATTACK_ANIMATION,
	TURN_START_SIGNAL, TURN_END_SIGNAL, TURN_END_PHASE, ATTACK_PHASE, 
	STATUS_PROC_VISUAL, CHECK_THRESHOLDS
}

@export var event_type: EventType
@export var amount: int
@export var source_item: Item
@export var log_text: String
@export var damage_type: String

var trigger_type: Enums.TriggerType
var stat: Enums.Stats
var stat_type: Enums.StatType
var status: Enums.StatusEffects
var resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE
var entity				# source entity
var target				# target entity
var item: Item			# the Item resource being executed
var rule: ItemRule 		# the ItemRule being executed
var visual_info: Dictionary  	# used by DAMAGE_VISUAL
var amount2: int 				# Used by CHECK_THRESHOLDS: amount = old_value, amount2 = new_value

static func modify_stat(_entity, _stat: Enums.Stats, _amount: int, _stat_type: Enums.StatType = Enums.StatType.CURRENT, _source_item: Item = null, _damage_type: String = "") -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.MODIFY_STAT
	e.entity = _entity
	e.stat = _stat
	e.stat_type = _stat_type
	e.amount = _amount
	e.source_item = _source_item
	e.damage_type = _damage_type
	return e

static func deal_damage(source, _target, _amount: int, _damage_type: String, _source_item: Item = null) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.DEAL_DAMAGE
	e.entity = source
	e.target = _target
	e.amount = _amount
	e.damage_type = _damage_type
	e.source_item = _source_item
	return e

static func log(text: String) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.LOG
	e.log_text = text
	return e

static func apply_status(_entity, _status: Enums.StatusEffects, stacks: int, _source_item: Item = null) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.APPLY_STATUS
	e.entity = _entity
	e.status = _status
	e.amount = stacks
	e.source_item = _source_item
	return e

static func remove_status(_entity, _status: Enums.StatusEffects, stacks: int, _source_item: Item = null) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.REMOVE_STATUS
	e.entity = _entity
	e.status = _status
	e.amount = stacks
	e.source_item = _source_item
	return e

static func execute_rule(item_ref, rule_ref, _entity, _trigger_type: Enums.TriggerType, stat_amount: int = 0, _resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.EXECUTE_RULE
	e.item = item_ref
	e.rule = rule_ref
	e.entity = _entity
	e.trigger_type = _trigger_type
	e.amount = stat_amount
	e.resolved_status = _resolved_status
	return e

static func damage_visual(target_entity, amt: int, d_stat: Enums.Stats, v_info: Dictionary) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.DAMAGE_VISUAL
	e.entity = target_entity
	e.amount = amt
	e.stat = d_stat
	e.visual_info = v_info
	return e

static func death_sequence(dying_entity) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.DEATH_SEQUENCE
	e.entity = dying_entity
	return e

static func delay(duration_sec: float) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.DELAY
	e.amount = int(duration_sec * 1000.0)
	return e

static func attack_animation(attacker, target_entity, damage: int, strike_number: int = 1) -> CombatEvent:
	var e := CombatEvent.new()
	e.event_type = EventType.ATTACK_ANIMATION
	e.entity = attacker
	e.target = target_entity
	e.amount = damage
	e.damage_type = "" 
	e.log_text = str(strike_number)  # reusing log_text to carry strike number
	return e

static func turn_start_signal(p_entity, p_turn_number: int) -> CombatEvent:
	var e = CombatEvent.new()
	e.event_type = EventType.TURN_START_SIGNAL
	e.entity = p_entity
	e.amount = p_turn_number
	return e

static func turn_end_signal(p_entity) -> CombatEvent:
	var e = CombatEvent.new()
	e.event_type = EventType.TURN_END_SIGNAL
	e.entity = p_entity
	return e

static func turn_end_phase(p_entity) -> CombatEvent:
	var e = CombatEvent.new()
	e.event_type = EventType.TURN_END_PHASE
	e.entity = p_entity
	return e

static func attack_phase(p_entity) -> CombatEvent:
	var e = CombatEvent.new()
	e.event_type = EventType.ATTACK_PHASE
	e.entity = p_entity
	return e

static func status_proc_visual(p_entity, p_status: Enums.StatusEffects, p_stat: Enums.Stats, p_amount: int) -> CombatEvent:
	var e = CombatEvent.new()
	e.event_type = EventType.STATUS_PROC_VISUAL
	e.entity = p_entity
	e.status = p_status
	e.stat = p_stat
	e.amount = p_amount
	return e
	
static func check_thresholds(p_entity, p_stat: Enums.Stats, p_old_value: int, p_new_value: int, p_stat_type: Enums.StatType = Enums.StatType.CURRENT) -> CombatEvent:
	var e = CombatEvent.new()
	e.event_type = EventType.CHECK_THRESHOLDS
	e.entity = p_entity
	e.stat = p_stat
	e.amount = p_old_value   # reuse amount for old_value
	e.amount2 = p_new_value  # reuse amount2 for new_value
	e.stat_type = p_stat_type
	return e

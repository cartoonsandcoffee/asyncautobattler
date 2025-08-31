class_name EnemyAbility
extends Resource

enum EffectType {
	DAMAGE_BOOST,
	SHIELD_GAIN,
	HEAL,
	APPLY_POISON,
	APPLY_BURN,
	APPLY_THORNS,
	APPLY_ACID,
	APPLY_STUN,
	STEAL_GOLD,
	REDUCE_PLAYER_DAMAGE,
	DIRECT_DAMAGE,
	DOUBLE_STRIKE,
	GAIN_STRIKES
}

enum TargetType {
	SELF,
	PLAYER,
	BOTH_PARTIES,
	RANDOM
}

@export var ability_name: String = "Unknown Ability"
@export_multiline var description: String = ""

@export var trigger: Enums.TriggerType = Enums.TriggerType.TURN_START
@export var effect_type: EffectType = EffectType.DAMAGE_BOOST
@export var target: TargetType = TargetType.SELF

@export var value: int = 0  # Amount of effect
@export var turn_interval: int = 2  # For EVERY_X_TURNS trigger
@export var countdown_start: int = 3  # For COUNTDOWN trigger

# Runtime state
var current_countdown: int = 0
var times_triggered: int = 0
var turn_counter: int = 0

func _init():
	current_countdown = countdown_start

func reset_for_combat():
	"""Reset runtime values for a new combat"""
	current_countdown = countdown_start
	turn_counter = 0
	times_triggered = 0

func get_description() -> String:
	"""Generate a description of what this ability does"""
	if description != "":
		return description
	
	# Auto-generate description based on effect
	var desc = ""
	match trigger:
		Enums.TriggerType.BATTLE_START:
			desc += "Battle Start: "
		Enums.TriggerType.TURN_START:
			desc += "Turn Start: "
		Enums.TriggerType.ON_HIT:
			desc += "On Hit: "
		Enums.TriggerType.EXPOSED:
			desc += "When Exposed: "
		Enums.TriggerType.WOUNDED:
			desc += "When Wounded: "
		Enums.TriggerType.EVERY_OTHER_TURN:
			desc += "Every " + str(turn_interval) + " turns: "
		Enums.TriggerType.COUNTDOWN:
			desc += "After " + str(countdown_start) + " turns: "
	
	match effect_type:
		EffectType.DAMAGE_BOOST:
			desc += "Gain +" + str(value) + " damage"
		EffectType.SHIELD_GAIN:
			desc += "Gain " + str(value) + " shield"
		EffectType.HEAL:
			desc += "Heal " + str(value) + " HP"
		EffectType.APPLY_POISON:
			desc += "Apply " + str(value) + " poison to player"
		EffectType.APPLY_BURN:
			desc += "Apply " + str(value) + " burn to player"
		EffectType.APPLY_THORNS:
			desc += "Gain " + str(value) + " thorns"
		EffectType.APPLY_ACID:
			desc += "Apply " + str(value) + " acid to player"
		EffectType.APPLY_STUN:
			desc += "Stun player for " + str(value) + " turns"
		EffectType.DIRECT_DAMAGE:
			desc += "Deal " + str(value) + " damage to player"
		EffectType.REDUCE_PLAYER_DAMAGE:
			desc += "Reduce player damage by " + str(value)
		EffectType.DOUBLE_STRIKE:
			desc += "Gain " + str(value) + " extra strikes"
		EffectType.STEAL_GOLD:
			desc += "Steal " + str(value) + " gold from player"
	
	return desc
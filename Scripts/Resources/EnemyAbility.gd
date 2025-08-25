class_name EnemyAbility
extends Resource

enum TriggerType {
	BATTLE_START,
	TURN_START,
	ON_HIT,
	ON_TAKING_DAMAGE,
	EXPOSED,
	WOUNDED,
	EVERY_OTHER_TURN,
	EVERY_X_TURNS,
	WHEN_PLAYER_HEALS,
	COUNTDOWN
}

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
	DOUBLE_STRIKE
}

enum TargetType {
	SELF,
	PLAYER,
	BOTH_PARTIES,
	RANDOM
}

@export var ability_name: String = "Unknown Ability"
@export_multiline var description: String = ""

@export var trigger: TriggerType = TriggerType.TURN_START
@export var effect_type: EffectType = EffectType.DAMAGE_BOOST
@export var target: TargetType = TargetType.SELF

@export var value: int = 0  # Amount of effect
@export var turn_interval: int = 2  # For EVERY_X_TURNS trigger
@export var countdown_start: int = 3  # For COUNTDOWN trigger

# Runtime state
var current_countdown: int = 0
var times_triggered: int = 0

func _init():
	current_countdown = countdown_start
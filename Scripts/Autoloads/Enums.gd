extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
	LEGENDARY,
	MYSTERIOUS,
	GOLDEN,
	DIAMOND,
	CRAFTED
}

enum Stats {
	HITPOINTS,
	DAMAGE,
	SHIELD,
	AGILITY,
	GOLD,
	STRIKES,
	EXPOSED,
	WOUNDED,
	BURN_DAMAGE,
	NONE
}

enum StatType {		# Used for item conditions and rules
    CURRENT,
    BASE,
    MISSING,
    NONE
}

enum RoomType {
	STARTER,
	HALLWAY,
	TOMB,
	CHAMBERS,
	FORGE, 
	LIBRARY,
	COVEN,
	LARDER,
	GALLERY,
	BOSS,
	SPECIAL
}

enum TriggerType {
	PERSISTENT,
	BATTLE_START,
	TURN_START,
	ON_HIT,
	EXPOSED,
	WOUNDED,
	COUNTDOWN,
	ENEMY_HIT_YOU,
	ON_HEAL,
	ON_STAT_GAIN,
	ON_STAT_LOSS,
	ON_TAKING_DAMAGE,
	ON_DEALING_DAMAGE,
	ON_STATUS_GAINED,
	ON_STATUS_REMOVED,
	ONE_HITPOINT_LEFT,
	ON_ITEM_TRIGGERED,
	ON_KILL
}

enum EffectType {
	MODIFY_STAT,
	APPLY_STATUS,
	REMOVE_STATUS,
	DEAL_DAMAGE,
	HEAL,
	TRIGGER_OTHER_ITEMS,
	CONVERT
}

enum StatusEffects {
	POISON,			# damages health not shield
	ACID,			# damages shield not health
	THORNS,			# damages both health and shield
	REGENERATION,	# heals
	STUN,			# skips combat
	BLIND,			# halves damage
	BLESSING,		# on remove: heal 3 and gain 1 damage
	BURN,			# deal BURN_BASE damage for each stack
	BLEED,			# prefer this be 'damages health not shield' instead of poison
	NONE
}

enum TargetType {
	SELF,
	ENEMY,
	BOTH,
	RANDOM,
	NONE
}

enum Party {
	PLAYER,
	ENEMY,
	BOTH,
	RANDOM
}

func get_target_string(_target: Enums.TargetType) -> String:
	match _target:
		Enums.TargetType.SELF:
			return "Your"
		Enums.TargetType.ENEMY:
			return "Your Enemy's"
		Enums.TargetType.BOTH:
			return "Both Parties'"
		Enums.TargetType.RANDOM:
			return "a Random Target's"
		_:
			return "<unknown target>"

func get_target_string_nonpossessive(_target: Enums.TargetType) -> String:
	match _target:
		Enums.TargetType.SELF:
			return "Yourself"
		Enums.TargetType.ENEMY:
			return "Your Enemy"
		Enums.TargetType.BOTH:
			return "Both Parties"
		Enums.TargetType.RANDOM:
			return "a Random Target"
		_:
			return "<unknown target>"

func get_stat_type_string(_stat: Enums.StatType) -> String:
	match _stat:
		Enums.StatType.MISSING:
			return "Missing"
		Enums.StatType.BASE:
			return "Base"
		Enums.StatType.CURRENT:
			return "Current"
		_:
			return "<unknown>"

func get_effect_type_string(_type: Enums.EffectType) -> String:
	match _type:
		Enums.EffectType.APPLY_STATUS:
			return "Apply Status"
		Enums.EffectType.REMOVE_STATUS:
			return "Apply Status"			
		Enums.EffectType.MODIFY_STAT:
			return "Modify Stat"
		Enums.EffectType.DEAL_DAMAGE:
			return "Deal Damage"
		Enums.EffectType.HEAL:
			return "Heal"
		Enums.EffectType.TRIGGER_OTHER_ITEMS:
			return "Trigger other items"
		Enums.EffectType.CONVERT:
			return "Convert"
		_:
			return "<unknown effect>"

func get_trigger_type_string(_trigger: Enums.TriggerType) -> String:
	match _trigger:
		Enums.TriggerType.PERSISTENT:
			return "Persistent"
		Enums.TriggerType.BATTLE_START:
			return "Battle Start"
		Enums.TriggerType.TURN_START:
			return "Turn Start"
		Enums.TriggerType.ON_HIT:
			return "On Hit"
		Enums.TriggerType.EXPOSED:
			return "Exposed"
		Enums.TriggerType.WOUNDED:
			return "Wounded"
		Enums.TriggerType.COUNTDOWN:
			return "Countdown"
		Enums.TriggerType.ENEMY_HIT_YOU:
			return "Enemy Hits You"
		Enums.TriggerType.ON_HEAL:
			return "on heal"
		Enums.TriggerType.ON_STAT_GAIN:
			return "on stat gain"
		Enums.TriggerType.ON_STAT_LOSS:
			return "on stat loss"
		Enums.TriggerType.ON_TAKING_DAMAGE:
			return "on taking damage"
		Enums.TriggerType.ON_DEALING_DAMAGE:
			return "on dealing damage"
		Enums.TriggerType.ON_STATUS_GAINED:
			return "on status gained"
		Enums.TriggerType.ON_STATUS_REMOVED:
			return "on status removed"
		Enums.TriggerType.ONE_HITPOINT_LEFT:
			return "one hitpoint left"
		Enums.TriggerType.ON_ITEM_TRIGGERED:
			return "on item triggered"
		Enums.TriggerType.ON_KILL:
			return "on kill"
		_:
			return "<unknown trigger>"


func get_status_string(_status: Enums.StatusEffects) -> String:
	match _status:
		Enums.StatusEffects.ACID:
			return "acid"
		Enums.StatusEffects.BURN:
			return "burn"
		Enums.StatusEffects.BLIND:
			return "blind"
		Enums.StatusEffects.BLESSING:
			return "blessing"
		Enums.StatusEffects.THORNS:
			return "thorns"
		Enums.StatusEffects.POISON:
			return "poison"
		Enums.StatusEffects.REGENERATION:
			return "regeneration"
		Enums.StatusEffects.STUN:
			return "stun"
		_:
			return "<unknown status effect>"

func get_stat_string(_stat: Enums.Stats) -> String:
	match _stat:
		Enums.Stats.HITPOINTS:
			return "hitpoints"
		Enums.Stats.DAMAGE:
			return "damage"
		Enums.Stats.SHIELD:
			return "shield"
		Enums.Stats.AGILITY:
			return "agility"
		Enums.Stats.GOLD:
			return "gold"
		Enums.Stats.STRIKES:
			return "strikes"
		Enums.Stats.BURN_DAMAGE:
			return "burn"			
		_:
			return "<unknown stat>"
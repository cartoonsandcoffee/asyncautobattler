extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
	LEGENDARY,
	MYSTERIOUS
}

enum Stats {
	HITPOINTS,
	DAMAGE,
	SHIELD,
	AGILITY,
	GOLD,
	STRIKES,
	HP_AND_SHIELD,
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
	FIRST_TURN,
	EVERY_OTHER_TURN,
	EVERY_X_TURNS,
	EVERY_X_HITS,
	EVERY_X_STRIKES,
	ON_HEAL,
	ON_SHIELD_GAIN,
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
	DEAL_DAMAGE,
	HEAL,
	CONVERT_STAT,
	SKIP_ATTACK
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
	NONE
}

enum TargetType {
	SELF,
	ENEMY,
	BOTH,
	RANDOM
}

enum Party {
	PLAYER,
	ENEMY,
	BOTH,
	RANDOM
}

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
		Enums.TriggerType.FIRST_TURN:
			return "First Turn"
		Enums.TriggerType.EVERY_OTHER_TURN:
			return "Every Other Turn"
		Enums.TriggerType.EVERY_X_TURNS:
			return "Every X Turns"
		Enums.TriggerType.EVERY_X_HITS:
			return "every x hits"
		Enums.TriggerType.EVERY_X_STRIKES:
			return "every x strikes"
		Enums.TriggerType.ON_HEAL:
			return "on heal"
		Enums.TriggerType.ON_SHIELD_GAIN:
			return "on shield gain"
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
		_:
			return "<unknown stat>"
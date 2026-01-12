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
	STARTER,		# Always very first room, the Old Man 
	TREASURE,		# Any room that gives you loot
	MERCHANT,		# Any room where you can purchase things
	UTILITY,		# Any room where you can modify cards (upgrade, replace, etc)
	CAMPFIRE,		# Restore player's health, never combat
	BOSS,			# The Asynchronous multiplayer PVP battles
	SPECIAL,
	SKIPPED
}

enum HallwayType {
	TREASURE,
	SHRINE,
	MERCHANT_GENERAL,
	MERCHANT_GLOVE,
	MERCHANT_WEAPON,
	CAMPFIRE,
	UPGRADE_STATION
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
	ON_KILL,
	OVERHEAL,
	TURN_END
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
	RANDOM,			# Randomizes Status
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
			return "your"
		Enums.TargetType.ENEMY:
			return "your Enemy's"
		Enums.TargetType.BOTH:
			return "both parties'"
		Enums.TargetType.RANDOM:
			return "a random target's"
		_:
			return "<unknown target>"

func get_target_string_nonpossessive(_target: Enums.TargetType) -> String:
	match _target:
		Enums.TargetType.SELF:
			return "yourself"
		Enums.TargetType.ENEMY:
			return "your Enemy"
		Enums.TargetType.BOTH:
			return "both parties"
		Enums.TargetType.RANDOM:
			return "a random target"
		_:
			return "<unknown target>"

func get_stat_type_string(_stat: Enums.StatType) -> String:
	match _stat:
		Enums.StatType.MISSING:
			return "missing"
		Enums.StatType.BASE:
			return "base"
		Enums.StatType.CURRENT:
			return "current"
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
			return "On Heal"
		Enums.TriggerType.ON_STAT_GAIN:
			return "On Stat Gain"
		Enums.TriggerType.ON_STAT_LOSS:
			return "On Stat Loss"
		Enums.TriggerType.ON_TAKING_DAMAGE:
			return "On Taking Damage"
		Enums.TriggerType.ON_DEALING_DAMAGE:
			return "On Dealing Damage"
		Enums.TriggerType.ON_STATUS_GAINED:
			return "On Status Gained"
		Enums.TriggerType.ON_STATUS_REMOVED:
			return "On Status Removed"
		Enums.TriggerType.ONE_HITPOINT_LEFT:
			return "One Hitpoint Left"
		Enums.TriggerType.ON_ITEM_TRIGGERED:
			return "On Item Triggered"
		Enums.TriggerType.ON_KILL:
			return "On Kill"
		Enums.TriggerType.TURN_END:
			return "Turn End"
		Enums.TriggerType.OVERHEAL:
			return "Overheal"
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
		Enums.StatusEffects.RANDOM:
			return "random status effect"
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
			return "burn damage"
		_:
			return "<unknown stat>"

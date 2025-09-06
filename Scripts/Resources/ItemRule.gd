# item_rule.gd
class_name ItemRule
extends Resource


@export_group("Trigger")
@export var trigger_type: Enums.TriggerType = Enums.TriggerType.ON_HIT
@export var trigger_stat: Enums.Stats = Enums.Stats.NONE
@export var countdown_value: int = 0  # For countdown triggers
@export var countdown_recurs: bool = false # if the countdown resets
@export var turn_frequency: int = 2   # For "every X turns" triggers

@export_group("Conditions")
@export var has_condition: bool = false
@export var condition_stat: String = ""  # "agility", "damage", "shield", etc.
@export var condition_category: String = ""  # For category-based effects
@export var condition_comparison: String = ">"  # ">", "<", ">=", "<=", "=="
@export var condition_value: int = 0

@export_group("Effect")
@export var effect_type: Enums.EffectType = Enums.EffectType.MODIFY_STAT
@export var target_type: Enums.TargetType = Enums.TargetType.SELF
@export var target_stat: Enums.Stats = Enums.Stats.NONE
@export var target_status: Enums.StatusEffects = Enums.StatusEffects.NONE
@export var effect_amount: int = 0       # Amount to modify/damage/heal

@export_group("Display")
@export var custom_description: String = ""  # Override auto-generated description


# Runtime state
var current_countdown: int = 0
var turn_counter: int = 0

func _init() -> void:
    pass

func get_description() -> String:

    if custom_description != "":
        return custom_description
	
    var desc = ""
	
	# Add trigger
    desc += Enums.get_trigger_type_string(trigger_type) + ": "
	
	# Add condition if any
    if has_condition and condition_stat != "":
        desc += "If %s %s %d, " % [condition_stat, condition_comparison, condition_value]
	
	# Add effect
    match effect_type:
        Enums.EffectType.MODIFY_STAT:
            var change = "+%d" % effect_amount if effect_amount > 0 else str(effect_amount)
            desc += "%s %s" % [change, Enums.get_stat_string(target_stat)]
        Enums.EffectType.APPLY_STATUS:
            desc += "Apply %d %s" % [effect_amount, Enums.get_status_string(target_status)]
        Enums.EffectType.DEAL_DAMAGE:
            desc += "Deal %d damage" % effect_amount
        Enums.EffectType.HEAL:
            desc += "Heal %d HP" % effect_amount
	
	# Add target
    if target_type != Enums.TargetType.SELF:
        desc += " to " + target_type_to_string(target_type)
	
    return desc

func target_type_to_string(target: Enums.TargetType) -> String:
    match target:
        Enums.TargetType.ENEMY: return "enemy"
        Enums.TargetType.BOTH: return "both parties"
        Enums.TargetType.RANDOM: return "random party"
        _: return "self"

func check_condition(entity) -> bool:
    if not has_condition:
        return true
	
	# Get the stat value from entity
    var stat_value = 0
    if entity == Player:  
        match condition_stat:
            "agility": stat_value = entity.stats.agility_current
            "damage": stat_value = entity.stats.damage_current
            "shield": stat_value = entity.stats.shield_current
            "hit_points", "hp": stat_value = entity.stats.hit_points_current
            "gold": stat_value = entity.stats.gold
    else:  # Enemy
        match condition_stat:
            "agility": stat_value = entity.agility_current
            "damage": stat_value = entity.damage_current
            "shield": stat_value = entity.shield_current
            "hit_points", "hp": stat_value = entity.hit_points_current
	
	# Compare
    match condition_comparison:
        ">": return stat_value > condition_value
        "<": return stat_value < condition_value
        ">=": return stat_value >= condition_value
        "<=": return stat_value <= condition_value
        "==": return stat_value == condition_value
	
    return false
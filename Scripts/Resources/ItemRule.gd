@tool
class_name ItemRule
extends Resource

enum ConditionValueType {
    VALUE,
    STAT_VALUE
}

enum ConditionType {
    STAT,
    STATUS
}

@export_group("Trigger")
@export var trigger_type: Enums.TriggerType = Enums.TriggerType.ON_HIT:
    set(value):
        trigger_type = value
        notify_property_list_changed()

@export var trigger_stat: Enums.Stats = Enums.Stats.NONE    # goes with ON_STAT_GAIN/LOSS
@export var trigger_status: Enums.StatusEffects = Enums.StatusEffects.NONE    # goes with ON_STAT_GAIN/LOSS
@export var countdown_value: int = 0  # For countdown triggers
@export var countdown_recurs: bool = false # if the countdown resets
@export var turn_frequency: int = 2   # For "every X turns" triggers

@export_group("Conditions")
@export var has_condition: bool = false:
    set(value):
        has_condition = value
        notify_property_list_changed()  

@export var condition_type: ConditionType = ConditionType.STAT:
    set(value):
        condition_type = value
        notify_property_list_changed()

@export var condition_stat: Enums.Stats = Enums.Stats.NONE  # "agility", "damage", "shield", etc.
@export var condition_status: Enums.StatusEffects = Enums.StatusEffects.NONE  # "poison", "acid", "thorns", etc.
@export var condition_comparison: String = ">"  # ">", "<", ">=", "<=", "=="
@export var compare_to: ConditionValueType = ConditionValueType.VALUE:
    set(value):
        compare_to = value
        notify_property_list_changed()

@export var condition_value: int = 0
@export var condition_party: Enums.TargetType = Enums.TargetType.NONE  # for when comparing like "PLAYERS/ENEMYS missing health"
@export var condition_stat_type: Enums.StatType = Enums.StatType.NONE # for like if "players MISSING health"
@export var condition_party_stat: Enums.Stats = Enums.Stats.NONE  # for like if "players missing HEALTH"

# JDM: If you make it so the first ItemRule in the array fails a condition then it doesn't perform further rules then
#      You won't need to have multiple stat value comparissons or conversions.
#      FOR EXAMPLE: Battle Start: Spend 2 armor to gain 3 speed and 1 attack
#      Would be 3 rules: 1) Battle Start: If armor >=2, Modify stat armor -2  (if it fails if check, don't continue)
#                        2) Battle Start: Modify stat +3 speed
#                        3) Battle Start: Modify stat +1 attack
# ---
#     FOR EXAMPLE: On Hit: Convert 1 armor to 1 attack
#     Would be 2 rules: 1) On Hit: if Armor >= 1, modify stat armor -1
#                       2) On Hit: modify stat + 1 attack

@export_group("Effect")
@export var effect_type: Enums.EffectType = Enums.EffectType.MODIFY_STAT:
    set(value):
        effect_type = value
        notify_property_list_changed()

@export var target_type: Enums.TargetType = Enums.TargetType.SELF
@export var target_stat_type: Enums.StatType = Enums.StatType.CURRENT
@export var target_stat: Enums.Stats = Enums.Stats.NONE
@export var target_status: Enums.StatusEffects = Enums.StatusEffects.NONE
@export var effect_of: ConditionValueType = ConditionValueType.VALUE:
    set(value):
        effect_of = value
        notify_property_list_changed()

@export var effect_amount: int = 0       # Amount to modify/damage/heal
@export var effect_stat_party: Enums.TargetType = Enums.TargetType.NONE  # for when value is a party's stat amount
@export var effect_stat_type: Enums.StatType = Enums.StatType.NONE # for like if gain armor equal to enemys armor
@export var effect_stat_value: Enums.Stats = Enums.Stats.NONE  # for like if "players missing HEALTH"
@export var repeat_effect_X_times: int = 0      # Having this will repeat the entire ItemRule chain additional times.
@export var repeat_effect_for_category: String = "" # Repeats the effect for each item that has a category that matches this string

@export_group("Special")
@export var special_string: String = "" # for special edge-case instructions for persistant rules, like: "exposed-triggers-twice"

@export_group("Display")
@export var custom_description: String = ""  # Override auto-generated description

# Runtime state
var current_countdown: int = 0
var turn_counter: int = 0

func _init() -> void:
    pass

# This function controls which properties are visible in the inspector
func _validate_property(property: Dictionary) -> void:
    var prop_name = property.name
    
    # === TRIGGER GROUP ===
    # Only show trigger_stat for stat-based triggers
    if prop_name == "trigger_stat":
        if trigger_type not in [Enums.TriggerType.ON_STAT_GAIN, Enums.TriggerType.ON_STAT_LOSS]:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Only show trigger_status for status-based triggers
    if prop_name == "trigger_status":
        if trigger_type not in [Enums.TriggerType.ON_STATUS_GAINED, Enums.TriggerType.ON_STATUS_REMOVED]:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Only show countdown_value and countdown_recurs for countdown triggers
    if prop_name in ["countdown_value", "countdown_recurs"]:
        if trigger_type != Enums.TriggerType.COUNTDOWN:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Only show turn_frequency for turn-frequency triggers
    if prop_name == "turn_frequency":
        if trigger_type not in [Enums.TriggerType.EVERY_X_TURNS, Enums.TriggerType.EVERY_X_HITS, Enums.TriggerType.EVERY_X_STRIKES]:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # === CONDITIONS GROUP ===
    # Hide all condition properties if has_condition is false
    if prop_name in ["condition_type", "condition_stat", "condition_status", "condition_comparison", "compare_to", "condition_value", "condition_party", "condition_stat_type", "condition_party_stat"]:
        if not has_condition:
            property.usage = PROPERTY_USAGE_NO_EDITOR
            return
    
    # Show condition_stat only for STAT condition type
    if prop_name == "condition_stat":
        if has_condition and condition_type != ConditionType.STAT:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show condition_status only for STATUS condition type
    if prop_name == "condition_status":
        if has_condition and condition_type != ConditionType.STATUS:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show condition_value only when comparing to VALUE
    if prop_name == "condition_value":
        if has_condition and compare_to != ConditionValueType.VALUE:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show condition_party, condition_stat_type, condition_party_stat only when comparing to STAT_VALUE
    if prop_name in ["condition_party", "condition_stat_type", "condition_party_stat"]:
        if has_condition and compare_to != ConditionValueType.STAT_VALUE:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # === EFFECT GROUP ===
    # Show target_stat only for MODIFY_STAT effect
    if prop_name == "target_stat" || prop_name == "target_stat_type":
        if effect_type != Enums.EffectType.MODIFY_STAT:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show target_status only for status effects
    if prop_name == "target_status":
        if effect_type not in [Enums.EffectType.APPLY_STATUS, Enums.EffectType.REMOVE_STATUS]:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show effect_amount only when effect_of is VALUE
    if prop_name == "effect_amount":
        if effect_of != ConditionValueType.VALUE:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show effect_stat_party, effect_stat_type, effect_stat_value only when effect_of is STAT_VALUE
    if prop_name in ["effect_stat_party", "effect_stat_type", "effect_stat_value"]:
        if effect_of != ConditionValueType.STAT_VALUE:
            property.usage = PROPERTY_USAGE_NO_EDITOR

func get_description() -> String:

    if custom_description != "":
        return custom_description
	
    var desc = ""
	
	# Add trigger
    desc += Enums.get_trigger_type_string(trigger_type) + ": "
	
	# Add condition if any
    if has_condition and condition_stat != Enums.Stats.NONE:
        desc += "If %s %s %d, " % [Enums.get_stat_string(condition_stat), condition_comparison, condition_value]
	
	# Add effect
    match effect_type:
        Enums.EffectType.MODIFY_STAT:
            var change = "+%d" % effect_amount if effect_amount > 0 else str(effect_amount)
            desc += "%s %s" % [change, Enums.get_stat_string(target_stat)]
        Enums.EffectType.APPLY_STATUS:
            desc += "Apply %d %s" % [effect_amount, Enums.get_status_string(target_status)]
        Enums.EffectType.REMOVE_STATUS:
            desc += "Remove %d %s" % [effect_amount, Enums.get_status_string(target_status)]            
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
@tool
class_name ItemRule
extends Resource

enum ConditionValueType {
    VALUE,
    STAT_VALUE,
    STATUS_VALUE
}

enum StatOrStatus {
    STAT,
    STATUS
}

enum ConversionAmountType {
    FIXED_VALUE,     # Convert exactly X (e.g., 1 armor)
    HALF,      # Convert X% (e.g., 50% = half)
    ALL              # Convert 100%
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

@export_group("Conditions")
@export var has_condition: bool = false:
    set(value):
        has_condition = value
        notify_property_list_changed()  

@export var condition_type: StatOrStatus = StatOrStatus.STAT:
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
@export var condition_party_status: Enums.StatusEffects = Enums.StatusEffects.NONE 

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
@export var effect_status_value: Enums.StatusEffects = Enums.StatusEffects.NONE

@export_group("Conversion (when effect_type = CONVERT)")
@export var convert_from_type: StatOrStatus = StatOrStatus.STAT:
    set(value):
        convert_from_type = value
        notify_property_list_changed()

@export var convert_from_party: Enums.TargetType = Enums.TargetType.SELF
@export var convert_from_stat: Enums.Stats = Enums.Stats.NONE
@export var convert_from_status: Enums.StatusEffects = Enums.StatusEffects.NONE

@export var convert_to_type: StatOrStatus = StatOrStatus.STAT
@export var convert_to_party: Enums.TargetType = Enums.TargetType.SELF
@export var convert_to_stat: Enums.Stats = Enums.Stats.NONE
@export var convert_to_status: Enums.StatusEffects = Enums.StatusEffects.NONE

@export var conversion_amount_type: ConversionAmountType = ConversionAmountType.FIXED_VALUE:
    set(value):
        conversion_amount_type = value
        notify_property_list_changed()

@export var conversion_amount_value: int = 1           # Used when FIXED_VALUE
@export var conversion_amount_percentage: float = 0.5  # Used when PERCENTAGE
@export var conversion_ratio: float = 1.0      # How much target per source (1:2 = 2.0)

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
        if has_condition and condition_type != StatOrStatus.STAT:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    
    # Show condition_status only for STATUS condition type
    if prop_name == "condition_status":
        if has_condition and condition_type != StatOrStatus.STATUS:
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

func get_desc_trigger() -> String:
    return Enums.get_trigger_type_string(trigger_type) 

func get_desc_condition() -> String:
    var condition_string: String = ""

    if !has_condition:
        return ""

    condition_string = "If "

    if condition_type == StatOrStatus.STAT:
        condition_string = "your " + Enums.get_stat_string(condition_stat) + " is " 
    if condition_type == StatOrStatus.STATUS:
        condition_string = "you have " + Enums.get_status_string(condition_status)          

    condition_string += get_comparison_string(condition_comparison)

    if compare_to == ConditionValueType.VALUE:
        condition_string += str(condition_value) + " "
    if compare_to == ConditionValueType.STAT_VALUE:
        condition_string += Enums.get_target_string(condition_party) + " " + Enums.get_stat_type_string(condition_stat_type) + " " + Enums.get_stat_string(condition_party_stat)

    return condition_string + "; "

func get_description() -> String:

    if custom_description != "":
        return custom_description
	
    var desc: String  = ""
    var value_str: String = ""

    if effect_of == ConditionValueType.VALUE:
        value_str = " by " + str(effect_amount)
    if effect_of == ConditionValueType.STAT_VALUE:
        value_str = " equal to " + Enums.get_target_string(effect_stat_party) + " " + Enums.get_stat_type_string(effect_stat_type) + " " + Enums.get_stat_string(effect_stat_value)

	# Add effect
    match effect_type:
        Enums.EffectType.MODIFY_STAT:
            var _pre:String = ""

            if target_type == Enums.TargetType.ENEMY:
                if effect_amount >= 0:
                    _pre = " Give enemy "
                else:
                    _pre = " Remove enemy "
            else:
                if effect_amount >= 0:
                    _pre = " Gain "
                else:
                    _pre = " Lose "

            var _max:String = " "
            if target_stat_type == Enums.StatType.BASE: _max = " Max "

            desc += _pre + _max + Enums.get_stat_string(target_stat) + value_str
        Enums.EffectType.APPLY_STATUS:
            if effect_of == ConditionValueType.VALUE:
                value_str = value_str.trim_prefix(" by ")
                desc += "Apply %s %s to %s" % [value_str, Enums.get_status_string(target_status), Enums.get_target_string_nonpossessive(target_type)]
            else:
                desc += "Apply %s to %s %s" % [Enums.get_status_string(target_status), Enums.get_target_string_nonpossessive(target_type), value_str]
        Enums.EffectType.REMOVE_STATUS:
            if effect_of == ConditionValueType.VALUE:
                value_str = value_str.trim_prefix(" by ")
                desc += "Remove %s %s from %s" % [value_str, Enums.get_status_string(target_status), Enums.get_target_string_nonpossessive(target_type)]
            else:
                desc += "Remove %s from %s %s" % [Enums.get_status_string(target_status), Enums.get_target_string_nonpossessive(target_type), value_str]          
        Enums.EffectType.DEAL_DAMAGE:
            if effect_of == ConditionValueType.VALUE:
                value_str = value_str.trim_prefix(" by ")
                desc += "Deal %s damage to %s." % [value_str, Enums.get_target_string_nonpossessive(target_type)]
            else:
                desc += "Deal Damage to %s %s" % [Enums.get_target_string_nonpossessive(target_type), value_str]  
        Enums.EffectType.HEAL:
            if effect_of == ConditionValueType.VALUE:
                value_str = value_str.trim_prefix(" by ")
                desc += "Heal %s for %s hitpoints." % [Enums.get_target_string_nonpossessive(target_type), value_str]
            else:
                desc += "Heal %s for an amount %s." % [Enums.get_target_string_nonpossessive(target_type), value_str]  
	
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

func get_comparison_string(_char: String) -> String:
    match _char:
        ">": return "Greater than "
        "<": return "Less than "
        ">=": return "Greater than or Equal to "
        "<=": return "Less than or Equal to "
        "==": return "Equal to "
        _: return " <unknown comparison >"
# item_rule.gd
class_name ItemRule
extends Resource

## Defines a single rule/mechanic for an item
## Uses trigger conditions and effects to create item synergies

# Common trigger types
const TRIGGER_BATTLE_START = "battle_start"
const TRIGGER_TURN_START = "turn_start"
const TRIGGER_ON_HIT = "on_hit"
const TRIGGER_ON_TAKING_DAMAGE = "on_taking_damage"
const TRIGGER_EXPOSED = "exposed"
const TRIGGER_WOUNDED = "wounded"
const TRIGGER_STATUS_REMOVED = "status_removed"
const TRIGGER_COUNTDOWN = "countdown"
const TRIGGER_EVERY_OTHER_TURN = "every_other_turn"

# Effect types
const EFFECT_MODIFY_STAT = "modify_stat"
const EFFECT_APPLY_STATUS = "apply_status"
const EFFECT_DEAL_DAMAGE = "deal_damage"
const EFFECT_HEAL = "heal"
const EFFECT_TRIGGER_ITEM = "trigger_item"

@export var trigger_type: String = ""
@export var effect_type: String = ""
@export var trigger: Enums.TriggerType 

# Trigger conditions
@export var countdown_value: int = 0  # For countdown triggers
@export var required_stat: String = ""  # For conditional triggers like "if agility > 3"
@export var required_value: int = 0
@export var required_category: String = ""  # For category-based effects

# Effect parameters
@export var target_stat: String = ""
@export var effect_amount: int = 0
@export var target_status: String = ""
@export var target_category: String = ""

# Runtime state
var current_countdown: int = 0
var turn_counter: int = 0

func _init() -> void:
    pass
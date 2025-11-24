# item.gd
class_name Item
extends Resource

## Base item class with rule-based mechanics system
## All items, weapons, armor, etc. inherit from this

enum ItemType {
	WEAPON,
	BODY_ARMOR,
	SHIELD,
	GLOVES, 
	BOOTS,
	HELMET,
	FOOD,
	POTION,
	TOME,
	SCROLL,
	RELIC,
	TOOL,
	PET,
	BUG,
	JEWELRY
}


@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export_multiline var item_desc: String = ""
@export var item_icon: Texture2D
@export var item_color: Color
@export var rules: Array[ItemRule]

@export_group("Repeat Behavior")
@export var repeat_rules_X_times: int = 0
@export var repeat_rules_for_category: String = ""

@export_group("Trigger Limits")
## UNUSED! RESOLVES WITH ORDER. Higher = earlier
@export var trigger_priority: int = 0   
## Item can only trigger once per combat.
@export var trigger_only_once: bool = false 
## Item can trigger every hit, but only during turn 1
@export var trigger_only_first_turn: bool = false  

@export_group("Occurrence")
## 0 = every, 2 = every other, 3 = every 3  (can be conbined with trigger_only_once to know if resets)
@export var trigger_on_occurrence_number: int = 0 
## Does counter reset each turn? 
@export var occurrence_resets_per_turn: bool = false  

@export_group("Stats")
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var categories: Array[String] = []  # Tags like "Sword", "Metal", "Fire"
@export var rng_weight: float = 1.0
@export var unlocked: bool = false

# Stat modifiers this item provides
@export var damage_bonus: int = 0
@export var shield_bonus: int = 0
@export var agility_bonus: int = 0
@export var hit_points_bonus: int = 0
@export var strikes_bonus: int = 0
@export var burn_damage_bonus: int = 0

# Runtime state (reset each combat)
var has_triggered_this_combat: bool = false
var has_triggered_this_turn: bool = false
var last_trigger_turn: int = -1

var instance_id: int = -1 # Add unique instance ID
var slot_index: int = -1  # Track which slot this item is in

var occurrence_count: int = 0

func reset_runtime_state():
	has_triggered_this_combat = false
	has_triggered_this_turn = false
	last_trigger_turn = -1
	occurrence_count = 0 

func reset_per_turn_state():
	# Reset per-turn flags - called at start of each turn
	has_triggered_this_turn = false
	if occurrence_resets_per_turn:
		occurrence_count = 0

func _init():
	instance_id = Time.get_unix_time_from_system() * 1000000 + randi() % 1000000
	slot_index = -1

func create_instance() -> Item:
	var new_instance = duplicate(true)  # Deep duplicate
	new_instance.instance_id = Time.get_unix_time_from_system() * 1000000 + randi() % 1000000
	slot_index = -1
	return new_instance

func has_category(_category: String) -> bool:
	for category in categories:
		if category == _category:
			return true 
	
	return false

func set_position(pos: int):
	slot_index = pos

func get_description() -> String:
	var desc: String = ""
	var prev_trigger: String = ""

	var rule_count: int = 0
	var curr_rule: int = 1

	if item_desc != "":
		return item_desc

	rule_count = rules.size()

	# First display all the triggers:
	if rules:
		if get_occurrence_string(rules[0]) == "":
			for rule in rules:
				if desc != "" && prev_trigger != rule.get_desc_trigger():
					desc += ", " + rule.get_desc_trigger()
				elif prev_trigger == rule.get_desc_trigger():
					continue
				else:
					desc += rule.get_desc_trigger()
				prev_trigger = rule.get_desc_trigger()
		else:
			desc += get_occurrence_string(rules[0])

	if desc!= "":
		desc = desc.strip_edges() + ": " + get_limit_string()

	for rule in rules:
		desc += rule.get_desc_condition()
		desc += rule.get_description()

		if curr_rule < rule_count:
			desc += " and "
			curr_rule += 1
	
	desc += get_repeat_string()

	return desc

func get_limit_string() -> String:
	var _limit: String = ""

	if trigger_only_once:
		_limit += "(Once per combat) "
	if trigger_only_first_turn:
		_limit += "(First turn only) "

	return _limit

func get_repeat_string() -> String:
	var _repeat: String = ""

	if (repeat_rules_X_times > 0):
		_repeat = " Repeat " + str(repeat_rules_X_times) + " times."
	if repeat_rules_for_category:
		if repeat_rules_for_category.strip_edges() != "":
			_repeat = " Repeat for each [color=gray]" + repeat_rules_for_category + "[/color] item you have."

	return _repeat

func get_occurrence_string(rule: ItemRule) -> String:
	var _occurrence: String = ""
	var _type: String = ""
	var _suffix:String  = ""

	if occurrence_resets_per_turn:
		_suffix = " per turn"

	if rule.trigger_type == Enums.TriggerType.TURN_START:
		_type = " turns"
	elif rule.trigger_type == Enums.TriggerType.ON_HIT:
		_type = " hits"
	else:
		_type  = " " + Enums.get_trigger_type_string(rule.trigger_type) + " triggers"

	if trigger_on_occurrence_number > 0:
		_occurrence = "Every " + str(trigger_on_occurrence_number) + _type + _suffix 

	return _occurrence

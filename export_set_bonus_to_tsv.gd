@tool
extends EditorScript

# ── CONFIGURE ────────────────────────────────────────────────────────────────
const RECIPES_DIR := "res://Resources/SetBonus_Recipes/"
const OUTPUT_PATH := "res://setbonus_export.tsv"
const ENUMS_PATH  := "res://Scripts/Autoloads/Enums.gd"   # update if path differs
# ─────────────────────────────────────────────────────────────────────────────

var _e   # Enums instance  — for calling get_*_string() methods
var _E   # Enums class     — for reading enum values

func _run() -> void:
	_E = load(ENUMS_PATH)
	if _E == null:
		push_error("Could not load Enums.gd from: " + ENUMS_PATH)
		return
	_e = _E.new()

	print("Scanning: " + RECIPES_DIR)
	var files := _collect_tres_files(RECIPES_DIR)
	print("Found %d .tres files" % files.size())
	if files.is_empty():
		push_error("No .tres files found — check RECIPES_DIR path")
		return

	var rows: Array[PackedStringArray] = []
	rows.append(_make_header())

	for path in files:
		var recipe = ResourceLoader.load(path) as SetBonus
		if recipe == null:
			push_warning("Skipped (not a SetBonus): " + path)
			continue
		if recipe.setbonus_item == null:
			push_warning("Skipped (no setbonus_item): " + path)
			continue
		rows.append(_recipe_to_row(recipe, path))

	var tsv := ""
	for row in rows:
		var cells: PackedStringArray = []
		for cell in row:
			cells.append(cell.replace("\t", " ").replace("\n", " "))
		tsv += "\t".join(cells) + "\n"

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open: " + OUTPUT_PATH)
		return
	file.store_string(tsv)
	file.close()
	print("! Exported %d set bonuses → %s" % [rows.size() - 1, OUTPUT_PATH])


# ── Header ────────────────────────────────────────────────────────────────────
func _make_header() -> PackedStringArray:
	return PackedStringArray([
		"File Name",
		"Name",
		"Component Items",
		"Bundles",
		"Item Description",
		"HP Bonus",
		"Damage Bonus",
		"Shield Bonus",
		"Agility Bonus",
		"Strikes Bonus",
		"Burn Bonus",
		"Keywords",
		"Rules",
	])


# ── Row ───────────────────────────────────────────────────────────────────────
func _recipe_to_row(recipe: SetBonus, path: String) -> PackedStringArray:
	var item: Item = recipe.setbonus_item

	# Component item names
	var component_names: Array[String] = []
	for req: Item in recipe.required_items:
		component_names.append(req.item_name)

	# Bundles from component items — unique values, preserving order
	var seen_bundles: Dictionary = {}
	var bundle_list: Array[String] = []
	for req: Item in recipe.required_items:
		var b := _bundle_str(req.item_bundle)
		if b not in seen_bundles:
			seen_bundles[b] = true
			bundle_list.append(b)

	return PackedStringArray([
		path.get_file().get_basename(),
		recipe.setbonus_name,
		", ".join(component_names),
		", ".join(bundle_list),
		_strip_bbcode(item.item_desc),
		str(item.hit_points_bonus),
		str(item.damage_bonus),
		str(item.shield_bonus),
		str(item.agility_bonus),
		str(item.strikes_bonus),
		str(item.burn_damage_bonus),
		", ".join(item.keywords),
		_build_rules_text(item),
	])


# ── Rules column ──────────────────────────────────────────────────────────────
func _build_rules_text(item: Item) -> String:
	if item.rules.is_empty():
		return ""
	var parts: Array[String] = []
	for rule: ItemRule in item.rules:
		if rule.custom_description != "":
			parts.append(_strip_bbcode(rule.custom_description))
			continue
		var trigger   := _rule_trigger_str(rule).strip_edges()
		var condition := _rule_condition_str(rule).strip_edges()
		var effect    := _rule_effect_str(rule).strip_edges()
		var text := trigger
		if trigger != "": text += ": "
		if condition != "": text += condition + " "
		text += effect
		parts.append(_strip_bbcode(text.strip_edges()))
	return " | ".join(parts)


# ── Replicated ItemRule.get_desc_trigger() ────────────────────────────────────
func _rule_trigger_str(rule: ItemRule) -> String:
	var s :String = _e.get_trigger_type_string(rule.trigger_type)
	if rule.trigger_type in [_E.TriggerType.ON_STAT_GAIN, _E.TriggerType.ON_STAT_LOSS]:
		if rule.trigger_stat != _E.Stats.NONE:
			s += " " + _e.get_stat_string(rule.trigger_stat) + " "
	if rule.trigger_type in [_E.TriggerType.ON_STATUS_GAINED, _E.TriggerType.ON_STATUS_REMOVED,
							  _E.TriggerType.ON_ENEMY_STATUS_GAIN, _E.TriggerType.ON_ENEMY_STATUS_PROC]:
		if rule.trigger_status != _E.StatusEffects.NONE:
			s += " " + _e.get_status_string(rule.trigger_status) + " "
	return s


# ── Replicated ItemRule.get_desc_condition() ──────────────────────────────────
func _rule_condition_str(rule: ItemRule) -> String:
	if not rule.has_condition:
		return ""
	var cmp := _comparison_str(rule.condition_comparison)
	var entity_val := ""
	if rule.condition_of == _E.TargetType.SELF and rule.condition_type == ItemRule.StatOrStatus.STAT:
		entity_val = "your"
	elif rule.condition_of == _E.TargetType.SELF and rule.condition_type == ItemRule.StatOrStatus.STATUS:
		entity_val = "you have"
	elif rule.condition_of == _E.TargetType.ENEMY and rule.condition_type == ItemRule.StatOrStatus.STAT:
		entity_val = "your enemy's"
	elif rule.condition_of == _E.TargetType.ENEMY and rule.condition_type == ItemRule.StatOrStatus.STATUS:
		entity_val = "your enemy has"
	var condition_str := "If "
	if rule.condition_type == ItemRule.StatOrStatus.STAT:
		condition_str += entity_val + " " + _e.get_stat_string(rule.condition_stat) + " is " + cmp
	elif rule.condition_type == ItemRule.StatOrStatus.STATUS:
		condition_str += entity_val + " " + cmp + " " + _e.get_status_string(rule.condition_status)
	var value_str := ""
	if rule.compare_to == ItemRule.ConditionValueType.VALUE:
		value_str = str(rule.condition_value) + " "
	elif rule.compare_to == ItemRule.ConditionValueType.STAT_VALUE:
		value_str = _e.get_target_string(rule.condition_to_party) + " " \
				  + _e.get_stat_type_string(rule.condition_stat_type) + " " \
				  + _e.get_stat_string(rule.condition_party_stat)
	elif rule.compare_to == ItemRule.ConditionValueType.STATUS_VALUE:
		value_str = _e.get_target_string(rule.condition_to_party) + " " \
				  + _e.get_status_string(rule.condition_party_status)
	condition_str = condition_str.replace("[BLANK]", value_str)
	return condition_str + ";"


# ── Replicated ItemRule.get_description() ─────────────────────────────────────
func _rule_effect_str(rule: ItemRule) -> String:
	if rule.effect_type == _E.EffectType.CONVERT:
		return _rule_conversion_str(rule)
	if rule.effect_type == _E.EffectType.TRIGGER_OTHER_ITEMS:
		return "Trigger all " + _e.get_target_string(rule.retrigger_target) \
			 + " " + _e.get_trigger_type_string(rule.retrigger_type) + " items."
	var value_str := ""
	if rule.effect_of == ItemRule.ConditionValueType.VALUE:
		value_str = str(rule.effect_amount)
	elif rule.effect_of == ItemRule.ConditionValueType.STAT_VALUE:
		value_str = " equal to " + _e.get_target_string(rule.effect_stat_party) \
				  + " " + _e.get_stat_type_string(rule.effect_stat_type) \
				  + " " + _e.get_stat_string(rule.effect_stat_value)
	elif rule.effect_of == ItemRule.ConditionValueType.STATUS_VALUE:
		value_str = " equal to " + _e.get_target_string(rule.effect_stat_party) \
				  + " " + _e.get_status_string(rule.effect_status_value) + " stacks"
	var desc := ""
	match rule.effect_type:
		_E.EffectType.MODIFY_STAT:
			var pre := ""
			if rule.target_type == _E.TargetType.ENEMY:
				pre = " Give enemy " if rule.effect_amount >= 0 else " Remove from enemy "
			else:
				pre = " Gain " if rule.effect_amount >= 0 else " Lose "
			var max_str := " Max " if rule.target_stat_type == _E.StatType.BASE else " "
			if rule.effect_of == ItemRule.ConditionValueType.VALUE:
				desc += pre + value_str + max_str + _e.get_stat_string(rule.target_stat)
			else:
				desc += pre + max_str + _e.get_stat_string(rule.target_stat) + value_str
		_E.EffectType.APPLY_STATUS:
			if rule.effect_of == ItemRule.ConditionValueType.VALUE:
				desc += "Apply %s %s to %s" % [value_str, _e.get_status_string(rule.target_status), _e.get_target_string_nonpossessive(rule.target_type)]
			else:
				desc += "Apply %s to %s %s" % [_e.get_status_string(rule.target_status), _e.get_target_string_nonpossessive(rule.target_type), value_str]
		_E.EffectType.REMOVE_STATUS:
			if rule.effect_of == ItemRule.ConditionValueType.VALUE:
				desc += "Remove %s %s from %s" % [value_str, _e.get_status_string(rule.target_status), _e.get_target_string_nonpossessive(rule.target_type)]
			else:
				desc += "Remove %s from %s %s" % [_e.get_status_string(rule.target_status), _e.get_target_string_nonpossessive(rule.target_type), value_str]
		_E.EffectType.DEAL_DAMAGE:
			if rule.effect_of == ItemRule.ConditionValueType.VALUE:
				desc += "Deal %s damage to %s." % [value_str, _e.get_target_string_nonpossessive(rule.target_type)]
			else:
				desc += "Deal damage to %s %s" % [_e.get_target_string_nonpossessive(rule.target_type), value_str]
		_E.EffectType.HEAL:
			if rule.effect_of == ItemRule.ConditionValueType.VALUE:
				desc += "Heal %s for %s hitpoints." % [_e.get_target_string_nonpossessive(rule.target_type), value_str]
			else:
				desc += "Heal %s for an amount %s." % [_e.get_target_string_nonpossessive(rule.target_type), value_str]
		_E.EffectType.ADD_REPEATS:
			desc += "Add repeats for category: " + rule.target_item_category
	return desc


# ── Replicated ItemRule.get_conversion_description() ─────────────────────────
func _rule_conversion_str(rule: ItemRule) -> String:
	var desc := "Convert "
	match rule.conversion_amount_type:
		ItemRule.ConversionAmountType.FIXED_VALUE: desc += str(rule.conversion_amount_value) + " "
		ItemRule.ConversionAmountType.HALF:        desc += "half of "
		ItemRule.ConversionAmountType.ALL:         desc += "all "
	var src := ""
	if rule.convert_from_party != _E.TargetType.SELF:
		src = _e.get_target_string(rule.convert_from_party).to_lower() + " "
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		desc += src + _e.get_stat_string(rule.convert_from_stat)
	else:
		desc += src + _e.get_status_string(rule.convert_from_status)
	desc += " to "
	if rule.conversion_ratio != 1.0:
		desc += str(rule.conversion_ratio) + "x "
	var tgt := ""
	if rule.convert_to_party != _E.TargetType.SELF:
		tgt = _e.get_target_string(rule.convert_to_party).to_lower() + " "
	if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
		desc += tgt + _e.get_stat_string(rule.convert_to_stat)
	else:
		desc += tgt + _e.get_status_string(rule.convert_to_status)
	return desc


# ── Enum helpers ──────────────────────────────────────────────────────────────
func _bundle_str(b: int) -> String:
	return _e.get_bundle_string(b)

func _comparison_str(c: String) -> String:
	match c:
		">":  return "more than [BLANK]"
		"<":  return "less than [BLANK]"
		">=": return "[BLANK] or more"
		"<=": return "[BLANK] or less"
		"==": return "[BLANK]"
		_:    return c


# ── BBCode stripper ───────────────────────────────────────────────────────────
func _strip_bbcode(text: String) -> String:
	var result := ""
	var inside := false
	for ch in text:
		if ch == "[":   inside = true
		elif ch == "]": inside = false
		elif not inside: result += ch
	return result


# ── Recursive .tres collector ─────────────────────────────────────────────────
func _collect_tres_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var listed = ResourceLoader.list_directory(dir_path)
	if listed != null and not listed.is_empty():
		for f in listed:
			var full := dir_path.path_join(f)
			if f.ends_with(".tres"):
				results.append(full)
			elif not f.contains("."):
				results.append_array(_collect_tres_files(full + "/"))
		return results
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			results.append(dir_path.path_join(fname))
		elif dir.current_is_dir() and fname not in [".", ".."]:
			results.append_array(_collect_tres_files(dir_path.path_join(fname) + "/"))
		fname = dir.get_next()
	dir.list_dir_end()
	return results
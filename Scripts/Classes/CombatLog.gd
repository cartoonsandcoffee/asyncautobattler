class_name CombatLog
extends Node

## Static class for all combat log formatting.
## Owns coloring, icon injection, and canonical line builders.
## CombatManager.add_to_combat_log_string() is still the write point —
## use these helpers to BUILD the string before passing it in.
##
## Usage:
##   combat_manager.add_to_combat_log_string(CombatLog.fmt_damage(target_name, amount, "attack"))
##   combat_manager.add_to_combat_log_string(CombatLog.fmt_status_gain(entity_name, Enums.StatusEffects.POISON, 3, 5))

# ─────────────────────────────────────────────
#  ICON PATHS
# ─────────────────────────────────────────────

const ICON_SIZE := "24x24"

# Stat icons
const ICON_ATTACK    := "res://Resources/StatIcons/icon_attack.tres"
const ICON_HEALTH    := "res://Resources/StatIcons/icon_health.tres"
const ICON_SHIELD    := "res://Resources/StatIcons/icon_shield.tres"
const ICON_SPEED     := "res://Resources/StatIcons/icon_speed.tres"
const ICON_STRIKES   := "res://Resources/StatIcons/stat_strikes.tres"
const ICON_GOLD      := "res://Resources/StatIcons/stat_gold.tres"
const ICON_BURN_DMG  := "res://Resources/StatIcons/stat_burn.tres"
const ICON_WOUNDED   := "res://Resources/StatIcons/stat_wounded.tres"
const ICON_EXPOSED   := "res://Resources/StatIcons/icon_broken_shield.tres"

# Status icons
const ICON_POISON    := "res://Resources/StatIcons/StatusIcons/status_poison.tres"
const ICON_BURN      := "res://Resources/StatIcons/StatusIcons/status_burn.tres"
const ICON_ACID      := "res://Resources/StatIcons/StatusIcons/status_acid.tres"
const ICON_THORNS    := "res://Resources/StatIcons/StatusIcons/status_thorns.tres"
const ICON_REGEN     := "res://Resources/StatIcons/StatusIcons/status_regen.tres"
const ICON_STUN      := "res://Resources/StatIcons/StatusIcons/status_stun.tres"
const ICON_BLIND     := "res://Resources/StatIcons/StatusIcons/status_blind.tres"
const ICON_BLESSING  := "res://Resources/StatIcons/StatusIcons/status_blessing.tres"


# ─────────────────────────────────────────────
#  PRIMITIVE HELPERS
# ─────────────────────────────────────────────

static func img(path: String) -> String:
	## Wraps a texture path in a BBCode img tag.
	return "[img=%s]%s[/img]" % [ICON_SIZE, path]

static func color(text: String, c: Color) -> String:
	## Wraps text in a BBCode color tag.
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]

static func bold(text: String) -> String:
	return "[b]%s[/b]" % text

static func center(text: String) -> String:
	return "[center]%s[/center]" % text

# ─────────────────────────────────────────────
#  ENTITY COLORING  (replaces CombatManager.color_entity)
# ─────────────────────────────────────────────

static func color_entity(entity_name: String) -> String:
	if "Player" in entity_name:
		return color(entity_name, Color.LIGHT_GREEN)
	return color(entity_name, Color.LIGHT_CORAL)


# ─────────────────────────────────────────────
#  STAT ICONS + COLORING  (replaces CombatManager.color_stat)
# ─────────────────────────────────────────────

static func icon_stat(stat: Enums.Stats) -> String:
	## Returns an inline icon for the given stat enum.
	match stat:
		Enums.Stats.DAMAGE:      return img(ICON_ATTACK)
		Enums.Stats.HITPOINTS:   return img(ICON_HEALTH)
		Enums.Stats.SHIELD:      return img(ICON_SHIELD)
		Enums.Stats.AGILITY:     return img(ICON_SPEED)
		Enums.Stats.STRIKES:     return img(ICON_STRIKES)
		Enums.Stats.GOLD:        return img(ICON_GOLD)
		Enums.Stats.BURN_DAMAGE: return img(ICON_BURN_DMG)
		Enums.Stats.WOUNDED:     return img(ICON_WOUNDED)
		Enums.Stats.EXPOSED:     return img(ICON_EXPOSED)
	return ""

static func _stat_color(stat: Enums.Stats) -> Color:
	var gc := GameColors.new()
	match stat:
		Enums.Stats.DAMAGE:      return gc.stats.damage
		Enums.Stats.HITPOINTS:   return gc.stats.hit_points
		Enums.Stats.SHIELD:      return gc.stats.shield
		Enums.Stats.AGILITY:     return gc.stats.agility
		Enums.Stats.STRIKES:     return gc.stats.strikes
		Enums.Stats.GOLD:        return gc.stats.gold
		Enums.Stats.BURN_DAMAGE: return gc.stats.burn
		Enums.Stats.WOUNDED:     return gc.stats.hit_points
		Enums.Stats.EXPOSED:     return gc.stats.shield
	return Color.GRAY

static func color_stat(stat: Enums.Stats) -> String:
	## Returns icon + colored stat name string.
	## Replaces CombatManager.color_stat(stat_name_string).
	var label := Enums.get_stat_string(stat).capitalize()
	return icon_stat(stat) + color(label, _stat_color(stat))

static func color_stat_str(stat_name: String) -> String:
	## Legacy string-based version for call sites that pass raw strings.
	## Maps to the enum version where possible; plain colored text otherwise.
	var lower := stat_name.to_lower()
	if "damage" in lower or "attack" in lower:
		return color_stat(Enums.Stats.DAMAGE)
	elif "shield" in lower or "armor" in lower:
		return color_stat(Enums.Stats.SHIELD)
	elif "hitpoint" in lower or "health" in lower or "hp" in lower:
		return color_stat(Enums.Stats.HITPOINTS)
	elif "agility" in lower or "speed" in lower:
		return color_stat(Enums.Stats.AGILITY)
	elif "strike" in lower:
		return color_stat(Enums.Stats.STRIKES)
	elif "gold" in lower:
		return color_stat(Enums.Stats.GOLD)
	elif "burn_damage" in lower or "burn damage" in lower:
		return color_stat(Enums.Stats.BURN_DAMAGE)
	return stat_name


# ─────────────────────────────────────────────
#  STATUS ICONS + COLORING  (replaces CombatManager.color_status)
# ─────────────────────────────────────────────

static func icon_status(status: Enums.StatusEffects) -> String:
	## Returns an inline icon for the given status enum.
	match status:
		Enums.StatusEffects.POISON:       return img(ICON_POISON)
		Enums.StatusEffects.BURN:         return img(ICON_BURN)
		Enums.StatusEffects.ACID:         return img(ICON_ACID)
		Enums.StatusEffects.THORNS:       return img(ICON_THORNS)
		Enums.StatusEffects.REGENERATION: return img(ICON_REGEN)
		Enums.StatusEffects.STUN:         return img(ICON_STUN)
		Enums.StatusEffects.BLIND:        return img(ICON_BLIND)
		Enums.StatusEffects.BLESSING:     return img(ICON_BLESSING)
	return ""

static func _status_color(status: Enums.StatusEffects) -> Color:
	var gc := GameColors.new()
	match status:
		Enums.StatusEffects.POISON:       return gc.stats.poison
		Enums.StatusEffects.BURN:         return gc.stats.burn
		Enums.StatusEffects.ACID:         return gc.stats.acid
		Enums.StatusEffects.THORNS:       return gc.stats.thorns
		Enums.StatusEffects.REGENERATION: return gc.stats.regeneration
		Enums.StatusEffects.STUN:         return gc.stats.stun
		Enums.StatusEffects.BLIND:        return gc.stats.strikes  # matches combat_item_proc
		Enums.StatusEffects.BLESSING:     return gc.stats.shield
	return Color.GRAY

static func color_status(status: Enums.StatusEffects) -> String:
	## Returns icon + colored status name string.
	## Replaces CombatManager.color_status(status_name_string).
	var label := Enums.get_status_string(status).capitalize()
	return icon_status(status) + color(label, _status_color(status))

static func color_status_str(status_name: String) -> String:
	## Legacy string-based version for call sites that pass raw strings.
	var lower := status_name.to_lower()
	if "poison"       in lower: return color_status(Enums.StatusEffects.POISON)
	if "burn"         in lower: return color_status(Enums.StatusEffects.BURN)
	if "acid"         in lower: return color_status(Enums.StatusEffects.ACID)
	if "thorns"       in lower: return color_status(Enums.StatusEffects.THORNS)
	if "regen"        in lower: return color_status(Enums.StatusEffects.REGENERATION)
	if "stun"         in lower: return color_status(Enums.StatusEffects.STUN)
	if "blind"        in lower: return color_status(Enums.StatusEffects.BLIND)
	if "blessing"     in lower: return color_status(Enums.StatusEffects.BLESSING)
	return status_name

static func color_item(item_name: String, item_obj = null) -> String:
	## Replaces CombatManager.color_item().
	var item_color := Color.GOLD
	if item_obj and item_obj is Item and item_obj.item_color:
		item_color = item_obj.item_color
	return color(item_name, item_color)


# ─────────────────────────────────────────────
#  CANONICAL LINE BUILDERS
#  All return a fully formatted String ready for add_to_combat_log_string().
# ─────────────────────────────────────────────

# --- Damage ---

static func fmt_damage_shield(entity_name: String, amount: int, before: int, after: int) -> String:
	## "   [Player]'s [img]Shield decreased by [5] (10 -> 5)."
	return "     %s's %s decreased by %s (%d → %d)." % [
		color_entity(entity_name),
		color_stat(Enums.Stats.SHIELD),
		color(str(amount), Color.RED),
		before, after
	]

static func fmt_damage_hp(entity_name: String, amount: int, before: int, after: int) -> String:
	## "   [Player]'s [img]Hit Points decreased by [5] (20 -> 15)."
	return "     %s's %s decreased by %s (%d → %d)." % [
		color_entity(entity_name),
		color_stat(Enums.Stats.HITPOINTS),
		color(str(amount), Color.RED),
		before, after
	]

static func fmt_heal(entity_name: String, amount: int, before: int, after: int, source_status: Enums.StatusEffects = Enums.StatusEffects.NONE) -> String:
	## "   [Player] healed for [img]5 HP (15 -> 20)."
	## With source_status: "   [img]Regeneration: [Player] healed for [img]5 HP (15 -> 20)."
	var gc := GameColors.new()
	var prefix := ""
	if source_status != Enums.StatusEffects.NONE:
		prefix = "%s: " % color_status(source_status)
	return "     %s%s healed for %s%s (%d → %d)." % [
		prefix,
		color_entity(entity_name),
		img(ICON_HEALTH),
		color(str(amount), gc.stats.hit_points),
		before, after
	]


# --- Stat changes (non-damage) ---

static func fmt_stat_change(entity_name: String, stat: Enums.Stats, before: int, after: int) -> String:
	## "   +3 [img]Shield for [Player]. (5 -> 8)"
	var delta := after - before
	var x_sign  := "+" if delta >= 0 else ""
	return "     %s%d %s for %s. (%d → %d)" % [
		x_sign, delta,
		color_stat(stat),
		color_entity(entity_name),
		before, after
	]


# --- Status changes ---

static func fmt_overheal(entity_name: String, amount: int) -> String:
	## "   [Player] overhealed for [img]3 HP — already at full."
	var gc := GameColors.new()
	return "     %s OVERHEALED for %s%s — already at full." % [
		color_entity(entity_name),
		img(ICON_HEALTH),
		color(str(amount), gc.stats.hit_points)
	]

static func fmt_status_gain(entity_name: String, status: Enums.StatusEffects, gained: int, total: int) -> String:
	## "   [Player] gains 3 [img]Poison (total: 5)."
	return "     %s gains %d %s (total: %d)." % [
		color_entity(entity_name),
		gained,
		color_status(status),
		total
	]

static func fmt_status_lose(entity_name: String, status: Enums.StatusEffects, lost: int, remaining: int) -> String:
	## "   [Player] loses 1 [img]Poison (remaining: 4)."
	if remaining > 0:
		return "        %s loses %d %s (remaining: %d)." % [
			color_entity(entity_name),
			lost,
			color_status(status),
			remaining
		]
	else:
		return "           %s's %s wears off." % [
			color_entity(entity_name),
			color_status(status)
		]

static func fmt_status_blocked(entity_name: String, blocker_stat: Enums.Stats, status: Enums.StatusEffects, damage: int) -> String:
	## "   [Player]'s [img]Shield blocks 3 [img]Poison damage."
	return "%s's %s blocks %s %s damage." % [
		color_entity(entity_name),
		color_stat(blocker_stat),
		color(str(damage), Color.WHITE),
		color_status(status)
	]

static func fmt_status_proc(status: Enums.StatusEffects, entity_name: String, amount: int, is_extra: bool = false) -> String:
	## "   [img]Poison: [Player] takes 3 damage."
	var label := " (Extra)" if is_extra else ""
	return "%s%s: %s takes %s damage." % [
		color_status(status),
		label,
		color_entity(entity_name),
		color(str(amount), _status_color(status))
	]

static func fmt_status_proc_with_range(status: Enums.StatusEffects, entity_name: String, amount: int, before: int, after: int, stat: Enums.Stats = Enums.Stats.HITPOINTS) -> String:
	## "   [img]Poison: [Player]'s [img]HP decreased by 3 (20 -> 17)."
	return "%s: %s's %s decreased by %s (%d → %d)." % [
		color_status(status),
		color_entity(entity_name),
		color_stat(stat),
		color(str(amount), _status_color(status)),
		before, after
	]


# --- Milestone events ---

static func fmt_wounded(entity_name: String) -> String:
	return bold(color_entity(entity_name) + color(" is WOUNDED!", Color.RED))

static func fmt_exposed(entity_name: String) -> String:
	return bold(color_entity(entity_name) + color(" is EXPOSED!", Color.DODGER_BLUE))

static func fmt_one_hp(entity_name: String) -> String:
	return bold(color_entity(entity_name) + color(" is at ONE HITPOINT!", Color.ORANGE))

static func fmt_death(entity_name: String) -> String:
	return bold(color_entity(entity_name) + color(" has died!", Color.RED))

static func fmt_turn_start(entity_name: String, turn_number: int) -> String:
	return "\n" + center(color_entity(entity_name) + color("'s TURN " + str(turn_number) + ".", Color.GRAY))

static func fmt_combat_alert(text:String) -> String:
	return "\n" + center(bold(color(text, Color.YELLOW))) + "\n"

# --- Item processing ---

static func fmt_items_triggered(count: int) -> String:
	return color(" %d item(s) triggered:" % count, Color.LIGHT_GRAY)

static func fmt_condition_failed() -> String:
	return color("   Condition failed — remaining rules skipped.", Color.DARK_GRAY)

static func fmt_rule_skipped() -> String:
	return color("   Skipping rule (prior condition failed).", Color.DARK_GRAY)

static func fmt_recursion_limit() -> String:
	return color("   Trigger recursion limit reached.", Color.ORANGE)

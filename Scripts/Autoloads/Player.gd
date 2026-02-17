extends Node

signal player_died()
signal inventory_updated(item: Item, slot_index: int)
signal profile_loaded()
signal ears_changed(new_balance: int)

# ============================================
# PERSISTENT PROFILE DATA (Synced with Supabase)
# ============================================
var player_uuid: String = ""
var player_name: String = ""
var ears_balance: int = 0

# Lifetime stats (synced from Supabase)
var active_champions_count: int = 0
var hall_champions_count: int = 0
var champions_killed: int = 0
var total_runs: int = 0

const PLAYER_DATA_PATH = "user://player_data.json"

var stats: GameStats:
	get:
		if stats == null:
			stats = GameStats.new()
		return stats
	set(value):
		stats = value	
var status_effects: StatusEffects:
	get:
		if status_effects == null:
			status_effects = StatusEffects.new()
		return status_effects
	set(value):
		status_effects = value
var inventory: Inventory:
	get:
		if inventory == null:
			inventory = Inventory.new()
		return inventory
	set(value):
		inventory = value

var skin_id: int = 0

# Applied to current weapon (resets on weapon swap)
var current_weapon_stat_upgrades: Dictionary = {
	"damage": 0, 
	"shield": 0, 
	"agility": 0
}
var current_weapon_rule_upgrade: Item = null  # The enchantment item

# Entity state flags
var is_player: bool = false
var has_taken_turn_this_combat: bool = false
var exposed_triggered: bool = false
var wounded_triggered: bool = false

# Run-specific data (resets each run)
var current_rank: int = 1
var current_room: int = 1
var rooms_cleared_this_run: int = 0
var enemies_defeated_this_run: int = 0
var gold_earned_this_run: int = 0
var damage_dealt_this_run: int = 0
var damage_taken_this_run: int = 0
var run_start_time: float = 0.0
var max_gold_this_run: int = 0
var items_found_this_run: int = 0

# town usage variables
var rooms_left_this_rank: int = 0
var total_rooms_per_rank: int = 10
var town_visits_left_this_rank: int = 0
var total_town_visits_per_rank: int = 2
var shrine_uses_left_this_rank: int = 0
var total_shrine_uses_per_rank: int = 1
var is_in_town: bool = false
var popup_open: bool = false


func new_run(nm: String):
	player_name = nm
	stats = GameStats.new()
	inventory = Inventory.new()
	status_effects = StatusEffects.new()
	
	inventory.item_added.connect(_on_inventory_item_added)

	if stats:
		stats.reset_base_stats()
		stats.gold = 50
		stats.reset_to_base_values()
	
	if inventory:
		set_test_inventory()

	current_weapon_stat_upgrades = {
		"damage": 0,
		"shield": 0,
		"agility": 0
	}
	current_weapon_rule_upgrade = null

	current_rank = 1
	current_room = 1
	rooms_cleared_this_run = 0
	enemies_defeated_this_run = 0
	gold_earned_this_run = 0
	damage_dealt_this_run = 0
	damage_taken_this_run = 0

	# Run state tracking
	run_start_time = Time.get_ticks_msec() / 1000.0
	max_gold_this_run = stats.gold
	items_found_this_run = 0

	rooms_left_this_rank = total_rooms_per_rank + 1  # JDM: Adding 1 to offset the first time town is loaded
	town_visits_left_this_rank = total_town_visits_per_rank
	shrine_uses_left_this_rank = total_shrine_uses_per_rank

func set_test_inventory():
	if !inventory:
		return

	inventory.set_inventory_size(4)

	# -- for testing basic rules

	inventory.add_item(ItemsManager.available_items["weapon_fists"])
	#inventory.add_item(ItemsManager.available_items["test_relic"])
	#inventory.add_item(ItemsManager.available_items["testing_boots"])
	inventory.add_item(ItemsManager.available_items["scuttlemite"])
	inventory.add_item(ItemsManager.available_items["corpsehopper"])
	inventory.add_item(ItemsManager.available_items["corpsehopper"])
	inventory.add_item(ItemsManager.available_items["scuttlemite"])
	#inventory.add_item(ItemsManager.available_items["testing_robes"])
	#inventory.add_item(ItemsManager.available_items["testing_shield"])
	#inventory.add_item(ItemsManager.available_items["bramble_belt"])

	#inventory.add_item(ItemsManager.available_items["Fists"])
	#inventory.add_item(ItemsManager.available_items["Liferoot Gauntlets"])
	#inventory.add_item(ItemsManager.available_items["Testing Shield"])
	#inventory.add_item(ItemsManager.available_items["Thorn Shield"])

	# -- More complex set for testing detailed rules
	#inventory.add_item(ItemsManager.available_items["Clearmetal Dagger"])
	#inventory.add_item(ItemsManager.available_items["Metallic Glass"])
	#inventory.add_item(ItemsManager.available_items["Ironskin Potion"])
	#inventory.add_item(ItemsManager.available_items["Clearmetal Crown"])
	#inventory.add_item(ItemsManager.available_items["Reinforced Gauntlets"])
	#inventory.add_item(ItemsManager.available_items["Chainmail Shirt"])
	#inventory.add_item(ItemsManager.available_items["Metalliglass Totem"])
	#inventory.add_item(ItemsManager.available_items["Metalliglass Timepiece"])
	#inventory.add_item(ItemsManager.available_items["Diamond Double Plated Armor"])
	#inventory.add_item(ItemsManager.available_items["Potion of Insecurity"])
	#inventory.add_item(ItemsManager.available_items["Indecent Exposure"])
	#inventory.add_item(ItemsManager.available_items["Golden Battleworn Shield"])
	#inventory.add_item(ItemsManager.available_items["Clearmetal Battle Horn"])

func reset_weapon_bonus():
	current_weapon_stat_upgrades["damage"] = 0
	current_weapon_stat_upgrades["shield"] = 0
	current_weapon_stat_upgrades["agility"] = 0
	current_weapon_rule_upgrade = null 

func update_stats_from_items():
	stats.reset_base_stats()

	# Add regular item bonuses
	for item in inventory.item_slots:
		if item:
			_apply_item_stat_bonuses(item)
	
	# Add weapon bonuses
	if inventory.weapon_slot:
		_apply_item_stat_bonuses(inventory.weapon_slot)

		# Apply weapon upgrades
		stats.increase_base_stat(Enums.Stats.DAMAGE, current_weapon_stat_upgrades["damage"])
		stats.increase_base_stat(Enums.Stats.SHIELD, current_weapon_stat_upgrades["shield"])
		stats.increase_base_stat(Enums.Stats.AGILITY, current_weapon_stat_upgrades["agility"])

	# Add set bonus item bonuses
	for bonus_item in SetBonusManager.get_active_set_bonuses(self):
		_apply_item_stat_bonuses(bonus_item)

	# apply any persistant/special item rules
	_apply_persistent_rules()

	stats.reset_to_base_values()

func _apply_persistent_rules():
	# Collect all persistent rules from inventory
	var all_items = inventory.item_slots.duplicate()
	if inventory.weapon_slot:
		all_items.append(inventory.weapon_slot)
	
	for item in all_items:
		if not item:
			continue
		
		for rule in item.rules:
			if rule.trigger_type != Enums.TriggerType.PERSISTENT:
				continue
			
			# Check condition if present
			if rule.has_condition:
				if not _evaluate_persistent_condition(rule):
					continue
			
			# Execute persistent effect based on special_string
			_execute_persistent_effect(rule, item)	

func _apply_item_stat_bonuses(item: Item):
	if item.damage_bonus != 0:
		stats.increase_base_stat(Enums.Stats.DAMAGE, item.damage_bonus)
	if item.shield_bonus != 0:
		stats.increase_base_stat(Enums.Stats.SHIELD, item.shield_bonus)
	if item.agility_bonus != 0:
		stats.increase_base_stat(Enums.Stats.AGILITY, item.agility_bonus)
	if item.hit_points_bonus != 0:
		stats.increase_base_stat(Enums.Stats.HITPOINTS, item.hit_points_bonus)
	if item.strikes_bonus != 0:
		stats.increase_base_stat(Enums.Stats.STRIKES, item.strikes_bonus)
	if item.burn_damage_bonus != 0:
		stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, item.burn_damage_bonus)

func _handle_special_string_persistent(special: String):
	# Handle special meta-mechanics
	match special:
		"double_armor":
			stats.set_base_stat(Enums.Stats.SHIELD, stats.shield * 2)
		"double_shield":
			stats.set_base_stat(Enums.Stats.SHIELD, stats.shield * 2)
		"double_damage":
			#stats.set_base_stat(Enums.Stats.DAMAGE, stats.damage * 2)
			pass #JDM: Damage stat cannot be doubled outside combat.
		"double_hp":
			stats.set_base_stat(Enums.Stats.HITPOINTS, stats.hit_points * 2)
		"double_agility":
			stats.set_base_stat(Enums.Stats.AGILITY, stats.agility * 2)
		# Add more as needed
		_:
			print("Unknown special_string: ", special)

func _evaluate_persistent_condition(rule: ItemRule):
	# Evaluate conditions for persistent rules (out of combat context)
	# Uses Player stats since we're in exploration

	var entity_value = 0
	var compare_value = 0
	
	# Get condition entity value
	if rule.condition_type == ItemRule.StatOrStatus.STAT:
		match rule.condition_of:
			Enums.TargetType.SELF:
				entity_value = _get_persistent_stat_value(rule.condition_stat, Enums.StatType.CURRENT)
			Enums.TargetType.ENEMY:
				if !CombatManager.combat_active:
					return false
				entity_value = CombatManager.pass_enemy_stats(rule.condition_stat, Enums.StatType.CURRENT)
			_:
				return false  
	elif rule.condition_type == ItemRule.StatOrStatus.STATUS:
		if !CombatManager.combat_active:
			return false
		match rule.condition_of:
			Enums.TargetType.SELF:
				entity_value = status_effects.get_status_value(rule.condition_status)
			Enums.TargetType.ENEMY:
				entity_value = CombatManager.pass_enemy_status(rule.condition_status)
			_:
				return false 
	else:
		# Can't check status effects out of combat
		return false
	
	# Get comparison value
	match rule.compare_to:
		ItemRule.ConditionValueType.VALUE:
			compare_value = rule.condition_value
		ItemRule.ConditionValueType.STAT_VALUE:
			if rule.condition_to_party == Enums.TargetType.SELF:
				compare_value = _get_persistent_stat_value(rule.condition_party_stat, rule.condition_stat_type)
			elif rule.condition_to_party == Enums.TargetType.ENEMY:
				if !CombatManager.combat_active:
					return false
				compare_value = CombatManager.pass_enemy_stats(rule.condition_party_stat, rule.condition_stat_type)
			else:
				return false
		ItemRule.ConditionValueType.STATUS_VALUE:
			if !CombatManager.combat_active:
				return false
			if rule.condition_to_party == Enums.TargetType.SELF:
				compare_value = status_effects.get_status_value(rule.condition_party_status)
			elif rule.condition_to_party == Enums.TargetType.ENEMY:
				compare_value = CombatManager.pass_enemy_status(rule.condition_party_status)
			else:
				return false
		_:
			return false
	
	# Perform comparison
	return _compare_values(entity_value, rule.condition_comparison, compare_value)

func _compare_values(a: int, comparison: String, b: int) -> bool:
	match comparison:
		">": return a > b
		"<": return a < b
		">=": return a >= b
		"<=": return a <= b
		"==": return a == b
		"=": return a == b		
		"!=": return a != b
		_: return false

func _get_persistent_stat_value(stat: Enums.Stats, stat_type: Enums.StatType) -> int:
	match stat:
		Enums.Stats.HITPOINTS:
			if stat_type == Enums.StatType.CURRENT:
				return stats.hit_points_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.hit_points - stats.hit_points_current
			else:
				return stats.hit_points
		Enums.Stats.DAMAGE:
			if stat_type == Enums.StatType.CURRENT:
				return stats.damage_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.damage - stats.damage_current
			else:
				return stats.damage
		Enums.Stats.SHIELD:
			if stat_type == Enums.StatType.CURRENT:
				return stats.shield_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.shield - stats.shield_current
			else:
				return stats.shield
		Enums.Stats.AGILITY:
			if stat_type == Enums.StatType.CURRENT:
				return stats.agility_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.agility - stats.agility_current
			else:
				return stats.agility
		Enums.Stats.STRIKES:
			if stat_type == Enums.StatType.CURRENT:
				return stats.strikes_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.strikes - stats.strikes_current
			else:
				return stats.strikes
		Enums.Stats.BURN_DAMAGE:
			if stat_type == Enums.StatType.CURRENT:
				return stats.burn_damage_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.burn_damage - stats.burn_damage_current
			else:
				return stats.burn_damage
		_:
			return 0

func _execute_persistent_effect(rule: ItemRule, item: Item):
	# Handle special_string meta-mechanics
	if rule.special_string != "":
		_handle_special_string_persistent(rule.special_string)
		return
	
	# Handle standard persistent effects (stat modifications)
	if rule.effect_type == Enums.EffectType.MODIFY_STAT:
		var amount = _calculate_effect_amount(rule)
		
		if rule.target_stat_type == Enums.StatType.BASE:
			# Apply to base stat
			match rule.target_stat:
				Enums.Stats.DAMAGE:
					stats.increase_base_stat(Enums.Stats.DAMAGE, amount)
				Enums.Stats.SHIELD:
					stats.increase_base_stat(Enums.Stats.SHIELD, amount)
				Enums.Stats.AGILITY:
					stats.increase_base_stat(Enums.Stats.AGILITY, amount)
				Enums.Stats.HITPOINTS:
					stats.increase_base_stat(Enums.Stats.HITPOINTS, amount)
				Enums.Stats.STRIKES:
					stats.increase_base_stat(Enums.Stats.STRIKES, amount)
				Enums.Stats.BURN_DAMAGE:
					stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, amount)
		elif rule.target_stat_type == Enums.StatType.CURRENT:
			# Apply to current stat
			match rule.target_stat:
				Enums.Stats.DAMAGE:
					stats.increase_stat(Enums.Stats.DAMAGE, amount)
				Enums.Stats.SHIELD:
					stats.increase_stat(Enums.Stats.SHIELD, amount)
				Enums.Stats.AGILITY:
					stats.increase_stat(Enums.Stats.AGILITY, amount)
				Enums.Stats.HITPOINTS:
					stats.increase_stat(Enums.Stats.HITPOINTS, amount)
				Enums.Stats.STRIKES:
					stats.increase_stat(Enums.Stats.STRIKES, amount)
				Enums.Stats.BURN_DAMAGE:
					stats.increase_stat(Enums.Stats.BURN_DAMAGE, amount)

func _calculate_effect_amount(rule: ItemRule) -> int:
	# Calculate effect amount for persistent rules
	var amount = 0
	
	match rule.effect_of:
		ItemRule.ConditionValueType.VALUE:
			amount = rule.effect_amount
		ItemRule.ConditionValueType.STAT_VALUE:
			# Read from a stat (e.g., "gain HP equal to your shield")
			if rule.effect_stat_party == Enums.TargetType.SELF:
				amount = _get_persistent_stat_value(rule.effect_stat_value, rule.effect_stat_type)
			elif rule.effect_stat_party == Enums.TargetType.ENEMY:
				if !CombatManager.combat_active:
					return 0
				amount = CombatManager.pass_enemy_stats(rule.effect_stat_value, rule.effect_stat_type)
		ItemRule.ConditionValueType.STATUS_VALUE:
			if !CombatManager.combat_active:
				return 0
			if rule.effect_stat_party == Enums.TargetType.SELF:
				amount = status_effects.get_status_value(rule.effect_status_value)
			elif rule.effect_stat_party == Enums.TargetType.ENEMY:
				amount = CombatManager.pass_enemy_status(rule.effect_status_value)
		_:
			amount = 0
	
	return amount

# ============================================
# INVENTORY & STATS HELPERS
# ============================================

func _on_inventory_item_added(item: Item, slot_index: int):
	#print(item.item_name + " - slot: " + str(slot_index))
	SetBonusManager.check_set_bonuses(self)
	inventory_updated.emit(item, slot_index)

func add_gold(value: int):
	Player.stats.gold += value
	Player.max_gold_this_run += value
	stats.stats_updated.emit()

func subtract_gold(value: int):
	if Player.stats.gold >= value:
		Player.stats.gold -= value
		stats.stats_updated.emit()
	else:	
		return false

# ============================================
# PERSISTENT UUID & PROFILE MANAGEMENT
# ============================================

func load_or_generate_uuid() -> String:
	"""Load UUID from local storage or generate new one. DOES NOT load profile from Supabase."""
	if not player_uuid.is_empty():
		return player_uuid
	
	# Try to load from local file
	if FileAccess.file_exists(PLAYER_DATA_PATH):
		var file = FileAccess.open(PLAYER_DATA_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var data = JSON.parse_string(json_string)
			if data and typeof(data) == TYPE_DICTIONARY:
				player_uuid = data.get("player_uuid", "")
				if not player_uuid.is_empty():
					print("[Player] Loaded existing UUID: %s" % player_uuid)
					return player_uuid
	
	# Generate new UUID if not found
	player_uuid = _generate_uuid()
	_save_persistent_data()
	print("[Player] Generated new UUID: %s" % player_uuid)
	return player_uuid

func _generate_uuid() -> String:
	"""Generate a pseudo-UUID v4."""
	var timestamp = Time.get_unix_time_from_system()
	var random_part = randi() % 100000
	
	return "%08x-%04x-%04x-%04x-%012x" % [
		OS.get_process_id(),
		int(timestamp) % 65536,
		4096 + (randi() % 4096),  # Version 4
		32768 + (randi() % 16384),  # Variant
		random_part
	]

func _save_persistent_data():
	"""Save UUID to local file."""
	var data = {
		"player_uuid": player_uuid,
		"last_synced": Time.get_datetime_string_from_system(true)
	}
	
	var file = FileAccess.open(PLAYER_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[Player] Saved persistent data")

func load_profile_from_supabase(profile_data: Dictionary):
	"""Load profile stats from Supabase query result."""
	if profile_data.is_empty():
		push_warning("[Player] Empty profile data provided")
		return
	
	player_name = profile_data.get("username", "Player")
	ears_balance = profile_data.get("ears_balance", 0)
	total_runs = profile_data.get("total_runs", 0)
	champions_killed = profile_data.get("champions_killed", 0)
	
	# These come from the view now (not columns)
	active_champions_count = profile_data.get("active_champions_count", 0)
	hall_champions_count = profile_data.get("hall_champions_count", 0)
	
	print("[Player] Profile loaded:")
	print("  - Name: %s" % player_name)
	print("  - Ears: %d" % ears_balance)
	
	profile_loaded.emit()

func update_ears(new_balance: int):
	"""Update ears balance (called after Supabase sync)."""
	ears_balance = new_balance
	ears_changed.emit(ears_balance)
	print("[Player] Ears updated: %d" % ears_balance)
	
# ============================================
# BOSS DATA SERIALIZATION (For Supabase)
# ============================================

func to_boss_data() -> Dictionary:
	return {
		"player_id": load_or_generate_uuid(),
		"username": player_name,
		"skin_id": skin_id,
		"rank": DungeonManager.current_rank,
		"max_hp": stats.hit_points,
		"curr_hp": stats.hit_points_current,
		"base_damage": stats.damage,
		"shield": stats.shield,
		"agility": stats.agility,
		"strikes": stats.strikes,
		"burn_damage": stats.burn_damage,
		"gold": stats.gold,
		"inventory": _serialize_inventory(),
		"weapon": _serialize_weapon(),
		"weapon_stat_upgrades": current_weapon_stat_upgrades,
		"weapon_enchantment": _serialize_weapon_enchantment()
	}

func _serialize_inventory() -> Array:
	var inv = []
	for i in range(inventory.item_slots.size()):
		var item = inventory.item_slots[i]
		if item and not item.item_id.is_empty():
			inv.append({"id": item.item_id, "slot": i, "name": item.item_name})
	return inv

func _serialize_weapon() -> Dictionary:
	if inventory.weapon_slot and not inventory.weapon_slot.item_id.is_empty():
		return {"id": inventory.weapon_slot.item_id, "name": inventory.weapon_slot.item_name}
	return {}

func _serialize_weapon_enchantment() -> Dictionary:
	"""Serialize the enchantment item applied to the weapon."""
	if current_weapon_rule_upgrade and not current_weapon_rule_upgrade.item_id.is_empty():
		return {"id": current_weapon_rule_upgrade.item_id, "name": current_weapon_rule_upgrade.item_name}
	return {}

func has_rooms_remaining() -> bool:
	"""Check if player can enter another dungeon room"""
	return rooms_left_this_rank > 0

func use_room():
	"""Consume 1 room currency when completing a dungeon room"""
	if rooms_left_this_rank > 0:
		rooms_left_this_rank -= 1
		stats.stats_updated.emit()
		#rooms_used_this_rank += 1
		#rooms_changed.emit(rooms_remaining)
		print("[Player] Room completed. Rooms remaining: %d" % rooms_left_this_rank)
	else:
		push_warning("[Player] Tried to use room but none remaining!")

func add_rooms(amount: int):
	"""Grant bonus rooms (from special encounters, items, etc.)"""
	rooms_left_this_rank += amount
	stats.stats_updated.emit()
	#rooms_changed.emit(rooms_remaining)
	print("[Player] Gained %d bonus room(s)! Total remaining: %d" % [amount, rooms_left_this_rank])

func refill_rooms_for_new_rank():
	"""Called when advancing to new rank - reset to 10 rooms"""
	rooms_left_this_rank += total_rooms_per_rank
	stats.stats_updated.emit()
	#rooms_used_this_rank = 0
	#rooms_changed.emit(rooms_remaining)
	print("[Player] New rank! Rooms refilled to 10")

func complete_rank_boss():
	"""Called after boss victory - advance rank and refill rooms"""
	current_rank += 1

	# Refill rooms for new rank
	refill_rooms_for_new_rank()
	stats.stats_updated.emit()
	
	print("[Player] Rank advanced to %d! Rooms reset to 10" % current_rank)

# ============================================
# SERIALIZATION (For local save/load - future use)
# ============================================

func to_dict() -> Dictionary:
	"""Serialize current run state for local saves."""
	return {
		# Persistent data
		"player_uuid": player_uuid,
		"player_name": player_name,
		"skin_id": skin_id,
		
		# Run state
		"current_rank": current_rank,
		"current_room": current_room,
		"rooms_cleared": rooms_cleared_this_run,
		
		# Stats
		"stats": {
			"hit_points": stats.hit_points,
			"hit_points_current": stats.hit_points_current,
			"damage": stats.damage,
			"shield": stats.shield,
			"agility": stats.agility,
			"strikes": stats.strikes,
			"burn_damage": stats.burn_damage,
			"gold": stats.gold
		},
		
		# Inventory
		"inventory": inventory.get_save_data() if inventory else {},
		
		# Weapon upgrades
		"weapon_stat_upgrades": current_weapon_stat_upgrades,
		"weapon_enchantment": _serialize_weapon_enchantment(),
		
		# Run stats
		"enemies_defeated": enemies_defeated_this_run,
		"gold_earned": gold_earned_this_run,
		"damage_dealt": damage_dealt_this_run,
		"damage_taken": damage_taken_this_run
	}

func from_dict(data: Dictionary):
	"""Restore run state from local save."""
	if data.is_empty():
		push_warning("[Player] Empty save data provided")
		return
	
	# Persistent data
	player_uuid = data.get("player_uuid", "")
	player_name = data.get("player_name", "Player")
	skin_id = data.get("skin_id", 0)
	
	# Run state
	current_rank = data.get("current_rank", 1)
	current_room = data.get("current_room", 1)
	rooms_cleared_this_run = data.get("rooms_cleared", 0)
	
	# Stats
	var stats_data = data.get("stats", {})
	if stats and not stats_data.is_empty():
		stats.hit_points = stats_data.get("hit_points", 10)
		stats.hit_points_current = stats_data.get("hit_points_current", 10)
		stats.damage = stats_data.get("damage", 0)
		stats.shield = stats_data.get("shield", 0)
		stats.agility = stats_data.get("agility", 0)
		stats.strikes = stats_data.get("strikes", 1)
		stats.burn_damage = stats_data.get("burn_damage", 0)
		stats.gold = stats_data.get("gold", 50)
	
	# Inventory
	var inv_data = data.get("inventory", {})
	if inventory and not inv_data.is_empty():
		inventory.load_from_save_data(inv_data)
	
	# Weapon upgrades
	current_weapon_stat_upgrades = data.get("weapon_stat_upgrades", {
		"damage": 0, "shield": 0, "agility": 0
	})
	
	# Weapon enchantment (need to load the actual Item from the ID)
	var enchantment_data = data.get("weapon_enchantment", {})
	if not enchantment_data.is_empty() and enchantment_data.has("id"):
		# Load the enchantment item by ID
		current_weapon_rule_upgrade = ItemsManager.get_item_by_id(enchantment_data.id)
	else:
		current_weapon_rule_upgrade = null
	
	# Run stats
	enemies_defeated_this_run = data.get("enemies_defeated", 0)
	gold_earned_this_run = data.get("gold_earned", 0)
	damage_dealt_this_run = data.get("damage_dealt", 0)
	damage_taken_this_run = data.get("damage_taken", 0)
	
	print("[Player] Loaded save data for: %s (Rank %d)" % [player_name, current_rank])

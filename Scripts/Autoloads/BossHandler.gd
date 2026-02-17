extends Node

## Handles conversion between Supabase data and Enemy entities for async multiplayer boss battles

func create_boss_enemy(opponent_data: Dictionary) -> Enemy:
	"""Convert Supabase opponent data to Enemy resource for combat."""
	if opponent_data.is_empty():
		push_warning("[BossHandler] Empty opponent data - using fallback")
		return get_fallback_boss(1)
		
	var boss = Enemy.new()
	boss.enemy_type = Enemy.EnemyType.BOSS_PLAYER
	boss.enemy_name = opponent_data.get("username", "Unknown Champion")
	boss.description = "A worthy opponent from Rank %d" % opponent_data.get("rank", 1)
	boss.skin_id = opponent_data.get("skin_id", 0)

	# Load sprite
	var sprite_path = "res://Assets/Art/Player/PVP/Player_Skin_%d.png" % boss.skin_id 
	if ResourceLoader.exists(sprite_path):
		boss.sprite = load(sprite_path)
	else:
		# Fallback to default or enemy sprite if boss skin doesn't exist
		if boss.sprite:
			boss.sprite = boss.sprite
			boss.sprite_attack = boss.sprite
			boss.sprite_hit = boss.sprite
		else:
			push_warning("[MapZoomPanel] Boss sprite not found: %s" % sprite_path)

	# Initialize stats from opponent data
	boss.stats = GameStats.new()
	boss.stats.hit_points = opponent_data.get("max_hp", 10)
	boss.stats.hit_points_current = opponent_data.get("curr_hp", 10)
	boss.stats.damage = opponent_data.get("base_damage", 1)
	boss.stats.shield = opponent_data.get("shield", 0)
	boss.stats.agility = opponent_data.get("agility", 0)
	boss.stats.strikes = opponent_data.get("strikes", 1)
	boss.stats.burn_damage = opponent_data.get("burn_damage", 3)
	boss.stats.gold = opponent_data.get("gold", 0)

	# Initialize status effects
	boss.status_effects = StatusEffects.new()
	
	# Initialize inventory (same as Player)
	boss.inventory = Inventory.new()
	boss.inventory.set_inventory_size(12)  # Match player inventory size
	
	_load_boss_inventory(boss, opponent_data)
	
	# Apply weapon upgrades if they exist
	_apply_weapon_upgrades(boss, opponent_data)
	
	# update stats from all the items (might not need to save any stats at all for the players really, just their items.)
	boss.update_stats_from_items()
	
	# Final boss summary
	var weapon_name = boss.inventory.weapon_slot.item_name if boss.inventory.weapon_slot else "None"
	print("[BossHandler] Created boss: %s (HP: %d, DMG: %d, Weapon: %s, Items: %d)" % [
		boss.enemy_name, 
		boss.stats.hit_points, 
		boss.stats.damage,
		weapon_name,
		_count_items(boss.inventory)
	])
	
	return boss

func _apply_weapon_upgrades(boss: Enemy, opponent_data: Dictionary):
	"""Apply weapon stat upgrades and enchantment to the boss's weapon."""
	# Apply weapon stat upgrades
	var weapon_stat_upgrades = opponent_data.get("weapon_stat_upgrades", {})
	if not weapon_stat_upgrades.is_empty():
		# Apply the upgrades (similar to how Player does it)
		var weapon = boss.inventory.weapon_slot
		if weapon:
			# These upgrades are already factored into base_damage, shield, agility
			# from the saved build, so we don't need to apply them again here
			# They're just metadata for display purposes
			print("[BossHandler] Boss has weapon upgrades: %s" % weapon_stat_upgrades)
	
	# Apply weapon enchantment
	var weapon_enchantment = opponent_data.get("weapon_enchantment", {})
	if not weapon_enchantment.is_empty() and weapon_enchantment.has("id"):
		var enchantment_id = weapon_enchantment.get("id", "")
		if not enchantment_id.is_empty():
			var enchantment_item = ItemsManager.get_item_by_id(enchantment_id)
			if enchantment_item:
				boss.current_weapon_rule_upgrade = enchantment_item.create_instance()
				print("[BossHandler] Applied weapon enchantment: %s" % enchantment_item.item_name)

func _load_boss_inventory(boss: Enemy, opponent_data: Dictionary):
	"""Load items and weapon into boss inventory."""
	# Load weapon
	var weapon_data = opponent_data.get("weapon", {})

	# Handle both JSON string and parsed dictionary
	if weapon_data is String:
		weapon_data = JSON.parse_string(weapon_data)

	if weapon_data and not weapon_data.is_empty():
		var weapon_id = weapon_data.get("id", "")
		if not weapon_id.is_empty():
			var weapon_item = ItemsManager.get_item_by_id(weapon_id)
			if weapon_item:
				boss.inventory.set_weapon(weapon_item.create_instance())
			else:
				print("[BossHandler] Weapon not found: %s" % weapon_id)
	
	# Load inventory items
	var inventory_data = opponent_data.get("inventory", [])

	# Handle both JSON string and parsed array
	if inventory_data is String:
		inventory_data = JSON.parse_string(inventory_data)
	
	if inventory_data and inventory_data is Array:
		for item_entry in inventory_data:
			var item_id = item_entry.get("id", "")
			var slot = item_entry.get("slot", -1)
			
			if not item_id.is_empty() and slot >= 0:
				var item = ItemsManager.get_item_by_id(item_id)
				if item:
					var item_instance = item.create_instance()
					boss.inventory.add_item(item_instance)  # JDM: can place in slot if needed: boss.inventory.add_item_at_slot(item_instance, slot)
				else:
					print("[BossHandler] Item not found: %s" % item_id)
	
	print("[BossHandler] Loaded %d items for boss" % _count_items(boss.inventory))

func _count_items(inventory: Inventory) -> int:
	"""Count non-null items in inventory."""
	var count = 0
	for item in inventory.item_slots:
		if item != null:
			count += 1
	return count


## =============================
## DEBUG / FALLBACK
## =============================

func get_fallback_boss(rank: int) -> Enemy:
	"""Get fallback NPC boss when no opponents available."""
	# Try to load pre-designed fallback enemy resource
	var path = "res://Resources/Enemies/Fallback/rank_%d.tres" % rank
	if ResourceLoader.exists(path):
		var fallback = load(path) as Enemy
		print("[BossHandler] Loaded fallback boss from: %s" % path)
		return fallback
	
	# Create generic fallback if no resource exists
	print("[BossHandler] Generating generic fallback boss for rank %d" % rank)
	var fallback = Enemy.new()
	fallback.enemy_type = Enemy.EnemyType.REGULAR
	fallback.enemy_name = "Wandering Spirit"
	fallback.description = "A lost soul from a previous run"
	
	# Scale stats by rank
	fallback.stats = GameStats.new()
	fallback.stats.hit_points = (rank * 10)
	fallback.stats.damage = (rank + 1)
	fallback.stats.shield = (rank * 5)
	fallback.stats.agility = rank
	fallback.stats.strikes = 1
	fallback.stats.burn_damage = 3
	fallback.stats.gold = 10	
	fallback.status_effects = StatusEffects.new()
	#fallback.abilities = []
	
	fallback.reset_to_base_values()
	return fallback


# Debug helper
func print_boss_details(boss: Enemy) -> void:
	"""Print detailed boss information for debugging."""
	print("\n=== BOSS DETAILS ===")
	print("Name: %s" % boss.enemy_name)
	print("Type: %s" % ("BOSS_PLAYER" if boss.enemy_type == Enemy.EnemyType.BOSS_PLAYER else "FALLBACK"))
	print("Stats: HP=%d/%d, DMG=%d, SHD=%d, AGI=%d, STR=%d, BURN=%d" % [
		boss.stats.hit_points_current,
		boss.stats.hit_points,
		boss.stats.damage,
		boss.stats.shield,
		boss.stats.agility,
		boss.stats.strikes,
		boss.stats.burn_damage
	])
	
	# Print weapon
	if boss.inventory and boss.inventory.weapon_slot:
		print("Weapon: %s" % boss.inventory.weapon_slot.item_name)
	else:
		print("Weapon: None")
	
	# Print inventory items
	if boss.inventory:
		var item_count = 0
		for item in boss.inventory.item_slots:
			if item:
				item_count += 1
		
		print("Inventory Items (%d):" % item_count)
		for i in range(boss.inventory.item_slots.size()):
			var item = boss.inventory.item_slots[i]
			if item:
				print("  Slot %d: %s" % [i, item.item_name])
	
	# Also print legacy abilities if any (for backward compatibility)
	if boss.abilities.size() > 0:
		print("Legacy Abilities (%d):" % boss.abilities.size())
		for i in range(boss.abilities.size()):
			var ability = boss.abilities[i]
			print("  %d. %s" % [i, ability.item_name])
	
	print("====================\n")

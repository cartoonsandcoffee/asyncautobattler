extends Node

## Handles conversion between Supabase data and Enemy entities for async multiplayer boss battles

func create_boss_enemy(opponent_data: Dictionary) -> Enemy:
	"""Convert Supabase opponent data to Enemy resource for combat."""
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
		else:
			push_warning("[MapZoomPanel] Boss sprite not found: %s" % sprite_path)

	# Initialize stats from opponent data
	boss.stats = GameStats.new()
	boss.stats.hit_points = opponent_data.get("max_hp", 10)
	boss.stats.hit_points_current = opponent_data.get("curr_hp", 10)
	boss.stats.damage = opponent_data.get("base_damage", 2)
	boss.stats.shield = opponent_data.get("shield", 0)
	boss.stats.agility = opponent_data.get("agility", 0)
	boss.stats.strikes = opponent_data.get("strikes", 1)
	boss.stats.burn_damage = opponent_data.get("burn_damage", 0)
	
	# Initialize status effects
	boss.status_effects = StatusEffects.new()
	
	# Initialize inventory (same as Player)
	boss.inventory = Inventory.new()
	boss.inventory.set_inventory_size(12)  # Match player inventory size
	
	# Convert weapon JSON to item and set in weapon slot
	var weapon_data = opponent_data.get("weapon", "{}")
	
	# Handle both JSON string and parsed dictionary
	if weapon_data is String:
		weapon_data = JSON.parse_string(weapon_data)
	
	if weapon_data and not weapon_data.is_empty():
		var weapon_id = weapon_data.get("id", "")
		var weapon = ItemsManager.get_item_by_id(weapon_id)
		if weapon:
			boss.inventory.set_weapon(weapon)
			print("[BossHandler] Loaded weapon: %s" % weapon.item_name)
		else:
			push_warning("[BossHandler] Boss weapon not found: %s (for %s)" % [weapon_id, boss.enemy_name])
	
	# Convert inventory JSON to items and add to inventory slots
	var inventory_data = opponent_data.get("inventory", "[]")
	
	# DEBUG: What did we get from Supabase?
	print("[BossHandler DEBUG] Raw inventory from Supabase: ", opponent_data.get("inventory"))
	print("[BossHandler DEBUG] inventory_data type: ", typeof(inventory_data))
	
	# Handle both JSON string and parsed array
	if inventory_data is String:
		inventory_data = JSON.parse_string(inventory_data)
		print("[BossHandler DEBUG] Parsed to: ", inventory_data)
	
	# Load each item into inventory
	var items_loaded = 0
	if inventory_data and inventory_data is Array:
		for item_data in inventory_data:
			var item_id = item_data.get("id", "")
			var item = ItemsManager.get_item_by_id(item_id)
			if item:
				if boss.inventory.add_item(item):
					items_loaded += 1
			else:
				push_warning("[BossHandler] Boss item not found: %s (in %s's inventory)" % [item_id, boss.enemy_name])
	
	print("[BossHandler] Loaded %d items into inventory" % items_loaded)
	
	# update stats from all the items (might not need to save any stats at all for the players really, just their items.)
	boss.update_stats_from_items()
	
	# Final boss summary
	var weapon_name = boss.inventory.weapon_slot.item_name if boss.inventory.weapon_slot else "None"
	print("[BossHandler] Created boss: %s (HP: %d, DMG: %d, Weapon: %s, Items: %d)" % [
		boss.enemy_name, 
		boss.stats.hit_points, 
		boss.stats.damage,
		weapon_name,
		items_loaded
	])
	
	return boss


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
	fallback.stats.hit_points = 80 + (rank * 20)
	fallback.stats.damage = 8 + (rank * 3)
	fallback.stats.shield = 5 + rank
	fallback.stats.agility = rank
	fallback.stats.strikes = 1
	fallback.stats.burn_damage = 3
	
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

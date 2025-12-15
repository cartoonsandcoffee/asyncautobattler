extends Node

func _ready():
	print("=== TESTING SUPABASE CONNECTION ===")
	
	# Test serialization
	Player.new_run("TestPlayer")
	var data = Player.to_boss_data()
	print("✓ Serialized: ", JSON.stringify(data, "\t"))
	
	# Test boss creation
	var mock_opponent = {
		"username": "TestBoss",
		"max_hp": 100, "curr_hp": 100,
		"base_damage": 15, "shield": 5,
		"agility": 2, "strikes": 1, "burn_damage": 0,
		"inventory": [
			{"id": "acrid_potion", "slot": 0},
			{"id": "test_relic", "slot": 1}
		],
		"weapon": {"id": "crude_blade"}
	}

	var boss = BossHandler.create_boss_enemy(mock_opponent)

	# Verify inventory
	assert(boss.inventory != null, "Boss should have inventory")
	assert(boss.inventory.weapon_slot != null, "Boss should have weapon")
	
	var item_count = 0
	for item in boss.inventory.item_slots:
		if item:
			item_count += 1
	
	print("✓ Boss has %d items in inventory" % item_count)
	BossHandler.print_boss_details(boss)

	print("✓ Boss created: ", boss.enemy_name, " HP:", boss.stats.hit_points)	

	#await test_connection()
	#await test_create_player()
	#await test_fetch_opponent()
	print("=== TESTS COMPLETE ===")

func test_connection():
	print("\n1. Testing connection...")
	var success = await SupabaseManager.test_connection()
	if success:
		print("✓ Connection test passed!")
	else:
		print("✗ Connection test failed - check credentials")

func test_create_player():
	print("\n2. Testing player creation...")
	# Let Supabase generate the UUID automatically
	var result = await SupabaseManager.create_player_profile("", "TestPlayer_" + str(randi() % 1000))
	
	if result.status == 201:
		print("✓ Player creation test passed!")
		print("  Generated Player ID: ", result.data[0].get("player_id", "unknown"))
		print("  Username: ", result.data[0].get("username", "unknown"))
	elif result.status == 409:
		print("✓ Player already exists (409 conflict)")
	else:
		print("✗ Player creation failed - Status: ", result.status)
		print("  Error details: ", JSON.stringify(result.data, "\t"))
		print("  This is likely a data validation issue - checking schema...")

func test_fetch_opponent():
	print("\n3. Testing opponent fetch...")
	
	# Test each rank WITHOUT player_id filter (for initial testing)
	for rank in range(1, 6):
		# Use empty string so the neq filter is ignored
		var opponent = await SupabaseManager.fetch_opponent_for_rank(rank, "")
		
		if opponent.is_empty():
			print("  Rank %d: ⚠ No opponents found" % rank)
		else:
			print("  Rank %d: ✓ Found opponent '%s'" % [rank, opponent.get("username", "Unknown")])
			print("    Stats: HP=%d/%d, DMG=%d, Shield=%d, Agility=%d, Strikes=%d" % [
				opponent.get("curr_hp", opponent.get("max_hp", 0)),
				opponent.get("max_hp", 0),
				opponent.get("base_damage", 0),
				opponent.get("shield", 0),
				opponent.get("agility", 0),
				opponent.get("strikes", 1)
			])
			
			# Test inventory parsing
			var inventory = opponent.get("inventory", "[]")
			if inventory is String:
				inventory = JSON.parse_string(inventory)
			print("    Inventory items: %d" % inventory.size())
			
			# Test weapon parsing
			var weapon = opponent.get("weapon", "{}")
			if weapon is String:
				weapon = JSON.parse_string(weapon)
			if not weapon.is_empty():
				print("    Weapon: %s" % weapon.get("name", "Unknown"))

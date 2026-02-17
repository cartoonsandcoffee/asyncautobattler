extends Node

const SUPABASE_URL = "https://tlycunaumisczhvhvmjd.supabase.co"
const SUPABASE_ANON_KEY  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRseWN1bmF1bWlzY3podmh2bWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4MTE4ODksImV4cCI6MjA3NjM4Nzg4OX0.NUISxj2iDHXv0EpEC6TkYExv6gHualEmVctg1v_zMLk"

# -- UNCOMMENT THE 2 LINES BELOW INSTEAD OF THE ONES ABOVE AFTER TESTING, FOR PRODUCTION, ETC.
#var SUPABASE_URL = ProjectSettings.get_setting("supabase/url")
#var SUPABASE_ANON_KEY = ProjectSettings.get_setting("supabase/anon_key")
# -----------


# For development: You can hardcode credentials above
# For production: Use environment variables or project settings (see below)

# ============================================
# HTTP REQUEST NODE
# ============================================

var http_request: HTTPRequest
var request_queue: Array = []
var is_processing_request: bool = false

var _initialized: bool = false

const MIN_CHAMPION_POOL = 10  # Minimum active champions in pool

func _ready():
	pass

func initialize():
	if _initialized:
		return
	
	_initialized = true

	# Create HTTPRequest node (built-in to Godot, no installation needed)
	http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Configure HTTPRequest
	http_request.timeout = 30.0  # 30 second timeout
	http_request.use_threads = true  # Use background thread
	
	print("SupabaseManager initialized")
	print("Supabase URL: ", SUPABASE_URL)
	
	# Test connection on startup (optional)
	# await test_connection()

# ============================================
# TEST CONNECTION
# ============================================

func test_connection() -> bool:
	print("Testing Supabase connection...")
	var result = await _supabase_get("/rest/v1/player_profiles?limit=1")
	
	if result.status == 200:
		print("✓ Supabase connection successful!")
		return true
	else:
		push_error("✗ Supabase connection failed! Status: %d" % result.status)
		return false

# ============================================
# PLAYER PROFILE OPERATIONS
# ============================================

func create_player_profile(player_id: String, username: String) -> Dictionary:
	"""Create a new player profile in the database."""
	# Minimal data - let database handle defaults
	var data = {
		"username": username
	}
	
	# Only include player_id if it looks like a valid UUID
	if not player_id.is_empty() and _is_valid_uuid(player_id):
		data["player_id"] = player_id
	
	return await _supabase_post("/rest/v1/player_profiles", data)

func get_player_profile(player_id: String) -> Dictionary:
	"""Get a player's profile by ID."""
	var profile_query = "?player_id=eq.%s&select=*" % player_id
	var profile_result = await _supabase_get("/rest/v1/player_profiles" + profile_query)
	
	if profile_result.status != 200 or profile_result.data.is_empty():
		return {}
	
	var profile = profile_result.data[0]
	
	# Get champion stats from view
	var stats = await get_player_champion_stats(player_id)
	
	# Merge them
	profile["active_champions_count"] = stats.active_champions_count
	profile["hall_champions_count"] = stats.hall_champions_count
	profile["dead_champions_count"] = stats.dead_champions_count
	
	return profile

func get_or_create_player(player_id: String, username: String) -> Dictionary:
	"""Get existing player or create new one if doesn't exist."""
	var profile = await get_player_profile(player_id)
	
	if profile.is_empty():
		var result = await create_player_profile(player_id, username)
		if result.status == 201:
			return result.data[0]
		else:
			push_error("Failed to create player profile: %s" % result.status)
			return {}
	else:
		return profile

func update_player_after_death(player_id: String, final_rank: int):
	"""Update player stats after death."""
	print("=== [DEBUG] update_player_after_death called for %s ===" % player_id)
	
	var profile = await get_player_profile(player_id)
	if profile.is_empty():
		push_error("Player profile not found: %s" % player_id)
		return
	
	var updates = {
		"total_runs": int(profile.total_runs) + 1,  # CONVERT TO INT!
		"last_played": Time.get_datetime_string_from_system(true)
	}
	
	print("=== [DEBUG] Updates to apply: %s ===" % JSON.stringify(updates))
	
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	var result = await _supabase_patch(endpoint, updates)
	
	print("=== [DEBUG] update_player_after_death result: %s ===" % result.status)
	print("[SupabaseManager] Updated death stats for %s" % player_id)

func update_player_after_run(player_id: String, won: bool, final_rank: int):
	"""Update player stats after completing a run."""
	# Get current profile
	var profile = await get_player_profile(player_id)
	if profile.is_empty():
		push_error("Player profile not found: %s" % player_id)
		return
	
	# Calculate new values
	var updates = {
		"total_runs": int(profile.total_runs) + 1,
		"last_played": Time.get_datetime_string_from_system(true)
	}

	# Update database
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	var result = await _supabase_patch(endpoint, updates)

	print("=== [DEBUG] update_player_after_run result: %s ===" % result.status)
	print("[SupabaseManager] Updated stats for %s" % player_id)

func get_player_champion_stats(player_id: String) -> Dictionary:
	"""Get player's champion counts from view."""
	var query = "?player_id=eq.%s&select=*" % player_id
	var result = await _supabase_get("/rest/v1/player_champion_stats" + query)
	
	if result.status == 200 and not result.data.is_empty():
		return result.data[0]
	else:
		# No champions yet, return zeros
		return {
			"active_champions_count": 0,
			"hall_champions_count": 0,
			"dead_champions_count": 0
		}

## =============================================================================
## ADD get_leaderboard() for Phase 3 UI
## =============================================================================

func get_leaderboard(limit: int = 50, sort_by: String = "champions_killed") -> Array:
	"""Get global leaderboard sorted by specified column."""
	# Valid sort columns: champions_killed, ears_balance, total_runs
	var query = "?select=*&order=%s.desc&limit=%d" % [sort_by, limit]
	var result = await _supabase_get("/rest/v1/player_profiles" + query)
	
	if result.status != 200:
		push_error("[SupabaseManager] Failed to fetch leaderboard: %d" % result.status)
		return []
	
	return result.data


# ============================================
# BOSS BUILD OPERATIONS
# ============================================

func save_boss_build(build_data: Dictionary) -> Dictionary:
	"""Save player's build after defeating a rank boss."""
	
	# CRITICAL FIX: Don't double-stringify!
	# The inventory and weapon are already in the correct format from Player.to_boss_data()
	# Just send the data as-is - Supabase will handle the JSON conversion
	
	print("[SupabaseManager] Saving boss build...")
	print("  - Username: %s" % build_data.get("username"))
	print("  - Rank: %d" % build_data.get("rank"))
	print("  - Inventory type: %s" % typeof(build_data.get("inventory")))
	print("  - Weapon type: %s" % typeof(build_data.get("weapon")))
	
	# Check what format we received
	var final_data = build_data.duplicate()
	
	# If inventory is a string (JSON), parse it to array
	if final_data.get("inventory") is String:
		var parsed = JSON.parse_string(final_data["inventory"])
		final_data["inventory"] = parsed if parsed else []
		print("  - Parsed inventory from string to array")
	
	# If weapon is a string (JSON), parse it to dictionary
	if final_data.get("weapon") is String:
		var parsed = JSON.parse_string(final_data["weapon"])
		final_data["weapon"] = parsed if parsed else {}
		print("  - Parsed weapon from string to dict")
	
	# Use upsert (insert or update if exists)
	var endpoint = "/rest/v1/boss_builds"
	var result = await _supabase_post(endpoint, final_data)
	
	print("[SupabaseManager] Response status: %d" % result.status)
	if result.status != 201:
		print("[SupabaseManager] Error: %s" % result.data)
	
	return result

func fetch_opponent_for_rank(rank: int, player_id: String) -> Dictionary:
	"""Fetch a random opponent build for matchmaking."""
	# For ranks 1-5: Get non-champion builds
	# For rank 6: Use fetch_champion_opponent() instead
	
	if rank == 6:
		push_warning("[SupabaseManager] Use fetch_champion_opponent() for rank 6!")
		return await fetch_champion_opponent(player_id)
	
	# For ranks 1-5, we just want any build at that rank
	var query = "?rank=eq.%d&select=*&order=created_at.desc&limit=20" % rank
	
	print("DEBUG: Fetching opponents for rank %d" % rank)
	print("DEBUG: Full query: ", query)
	print("DEBUG: Full URL: ", SUPABASE_URL + "/rest/v1/boss_builds" + query)
	
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	print("DEBUG: Response status: ", result.status)
	if result.status != 200:
		print("DEBUG: Error response: ", JSON.stringify(result.data, "\t"))
	
	if result.status != 200:
		push_warning("Failed to fetch opponents: %d" % result.status)
		return {}
	
	var builds = result.data
	if builds.is_empty():
		print("No opponents found for rank %d" % rank)
		return {}
	
	print("DEBUG: Found %d opponents" % builds.size())
	
	# Pick random from the most recent 20
	var random_index = randi() % builds.size()
	return builds[random_index]

func get_boss_preview(build_id: String) -> Dictionary:
	"""Get detailed boss info for preview screen."""
	var query = "?id=eq.%s&select=username,rank,max_hp,curr_hp,base_damage,shield,agility,strikes,burn_damage,inventory,weapon" % build_id
	
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	if result.status == 200 and not result.data.is_empty():
		return result.data[0]
	else:
		return {}

func has_build_for_rank(player_id: String, rank: int) -> bool:
	"""Check if player has already saved a build for this rank."""
	var query = "?player_id=eq.%s&rank=eq.%d&select=id" % [player_id, rank]
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	return result.status == 200 and not result.data.is_empty()

# ============================================
# CHAMPION SYSTEM
# ============================================

func fetch_champion_opponent(player_id: String) -> Dictionary:
	"""Fetch a random champion opponent. If pool < 10, fill with shadows."""
	print("[SupabaseManager] Fetching champion opponent...")
	
	# Get all active champions (excluding player's own)
	var query = "?is_champion=eq.true&status=eq.active&player_id=neq.%s&select=*" % player_id
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	if result.status != 200:
		push_error("[SupabaseManager] Failed to fetch champions: %d" % result.status)
		return {}
	
	var champions: Array = result.data
	print("[SupabaseManager] Found %d active champions" % champions.size())
	
	# If pool is too small, fill with shadows
	if champions.size() < MIN_CHAMPION_POOL:
		var shadows_needed = MIN_CHAMPION_POOL - champions.size()
		print("[SupabaseManager] Pool too small, creating %d shadows..." % shadows_needed)
		
		var shadows = await _create_shadow_champions(shadows_needed)
		champions.append_array(shadows)
		
		print("[SupabaseManager] Pool now has %d champions (including shadows)" % champions.size())
	
	# Pick random champion
	if champions.is_empty():
		push_error("[SupabaseManager] No champions available!")
		return {}
	
	var opponent = champions.pick_random()
	print("[SupabaseManager] Selected opponent: %s (shadow: %s)" % [
		opponent.get("username", "Unknown"),
		opponent.get("is_shadow", false)
	])
	
	return opponent

func _create_shadow_champions(count: int) -> Array:
	"""Create shadow champions from Hall of Fame builds."""
	# Get Hall of Fame champions to copy
	var query = "?status=eq.hall_of_fame&select=*&order=hall_of_fame_date.desc&limit=20"
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	if result.status != 200 or result.data.is_empty():
		push_warning("[SupabaseManager] No Hall of Fame champions to create shadows from!")
		return []
	
	var hall_champions: Array = result.data
	var shadows: Array = []
	
	for i in range(count):
		# Pick random hall champion
		var original = hall_champions.pick_random()
		
		# Create handicapped copy
		var shadow = _create_shadow_copy(original)
		shadows.append(shadow)
	
	print("[SupabaseManager] Created %d shadow champions" % shadows.size())
	return shadows

func _create_shadow_copy(original: Dictionary) -> Dictionary:
	"""Create a handicapped copy of a Hall of Fame champion."""
	# Deep copy the original
	var shadow = original.duplicate(true)
	
	# Mark as shadow
	shadow["is_shadow"] = true
	shadow["original_player"] = original.get("username", "Unknown")
	
	# HANDICAP: Remove 1 random item from inventory
	var inventory = shadow.get("inventory", [])
	if inventory.size() > 0:
		var remove_index = randi() % inventory.size()
		inventory.remove_at(remove_index)
		shadow["inventory"] = inventory
		print("[SupabaseManager] Shadow created from %s (removed 1 item)" % shadow.original_player)
	
	# Optional: Add other handicaps
	# shadow["max_hp"] = int(shadow.max_hp * 0.9)  # 10% HP reduction
	# shadow["base_damage"] = int(shadow.base_damage * 0.9)  # 10% damage reduction
	
	return shadow

func get_active_champions_count() -> int:
	"""Get total count of active champions in the system."""
	var result = await _supabase_get("/rest/v1/active_champions?select=id")
	
	if result.status == 200:
		return result.data.size()
	return 0

func promote_to_champion(build_id: String):
	"""Promote a rank 5 build to champion status."""
	print("[SupabaseManager] Promoting build to champion: %s" % build_id)
	return await _supabase_rpc("promote_to_champion", {"p_build_id": build_id})

func record_champion_victory(build_id: String):
	"""Record victory for champion (increments count, awards ears, handles retirement)."""
	print("[SupabaseManager] Recording champion victory for build: %s" % build_id)
	return await _supabase_rpc("record_champion_victory", {"p_build_id": build_id})

func record_champion_defeat(build_id: String):
	"""Record defeat for champion (retires if soft cap allows)."""
	print("[SupabaseManager] Recording champion defeat for build: %s" % build_id)
	return await _supabase_rpc("record_champion_defeat", {"p_build_id": build_id})

func get_player_champions(player_id: String) -> Dictionary:
	"""Get player's champions organized by status."""
	# Active champions (status = 'active')
	var active_query = "?player_id=eq.%s&is_champion=eq.true&status=eq.active&select=*&order=champion_victories.desc" % player_id
	var active_result = await _supabase_get("/rest/v1/boss_builds" + active_query)
	
	# Hall of Fame champions (status = 'hall_of_fame')
	var hall_query = "?player_id=eq.%s&status=eq.hall_of_fame&select=*&order=hall_of_fame_date.desc" % player_id
	var hall_result = await _supabase_get("/rest/v1/boss_builds" + hall_query)
	
	# Dead champions (status = 'dead')
	var dead_query = "?player_id=eq.%s&status=eq.dead&select=*&order=created_at.desc&limit=30" % player_id
	var dead_result = await _supabase_get("/rest/v1/boss_builds" + dead_query)
	
	return {
		"active": active_result.data if active_result.status == 200 else [],
		"hall_of_fame": hall_result.data if hall_result.status == 200 else [],
		"dead": dead_result.data if dead_result.status == 200 else []
	}

## =============================================================================
## hall of champions stuff
## =============================================================================

func get_hall_of_fame(limit: int = 50) -> Array:
	"""Get global Hall of Champions (all players)."""
	var query = "?select=*&order=hall_of_fame_date.desc&limit=%d" % limit
	var result = await _supabase_get("/rest/v1/hall_of_champions" + query)
	return result.data if result.status == 200 else []

func get_global_hall_of_fame(limit: int = 100) -> Array:
	"""Get global Hall of Fame champions (all players)."""
	var query = "?status=eq.hall_of_fame&select=*&order=hall_of_fame_date.desc&limit=%d" % limit
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	if result.status != 200:
		push_error("[SupabaseManager] Failed to fetch global hall: %d" % result.status)
		return []
	
	return result.data

func get_champion_notifications(player_id: String, since_timestamp: String = "") -> Dictionary:
	"""
	Get notifications about player's champions defeating others.
	Returns: {champion_name: victory_count, ...}
	
	TODO: This requires battle_history tracking to work properly.
	For now, we'll calculate from champion_victories field changes.
	"""
	# This is a simplified version - in production you'd track this in battle_history
	var champions = await get_player_champions(player_id)
	var active = champions.get("active", [])
	
	var notifications = {}
	for champion in active:
		var victories = champion.get("champion_victories", 0)
		if victories > 0:
			notifications[champion.get("username", "Unknown")] = victories
	
	return notifications

## =============================================================================
## increment_times_faced() for tracking boss battles
## =============================================================================

func increment_times_faced(build_id: String):
	"""Increment times_faced counter for any boss build."""
	# Use RPC to increment atomically
	var result = await _supabase_rpc("increment_times_faced", {"p_build_id": build_id})
	
	if result.status == 204:
		print("[SupabaseManager] Incremented times_faced for build %s" % build_id)
	else:
		push_warning("[SupabaseManager] Failed to increment times_faced: %d" % result.status)

# ============================================
# EARS CURRENCY
# ============================================

func award_ears(player_id: String, amount: int, reason: String):
	"""Award ears to a player with transaction logging."""
	return await _supabase_rpc("award_ears", {
		"p_player_id": player_id,
		"p_amount": amount,
		"p_transaction_type": "reward",
		"p_description": reason
	})

func spend_ears(player_id: String, amount: int, reason: String) -> bool:
	"""Spend ears (returns false if insufficient funds)."""
	var result = await _supabase_rpc("spend_ears", {
		"p_player_id": player_id,
		"p_amount": amount,
		"p_transaction_type": "purchase",
		"p_description": reason
	})
	
	# Function returns boolean indicating success
	return result.data == true if result.status == 200 else false

func get_ears_history(player_id: String, limit: int = 50) -> Array:
	"""Get player's ears transaction history."""
	var query = "?player_id=eq.%s&select=*&order=created_at.desc&limit=%d" % [player_id, limit]
	
	var result = await _supabase_get("/rest/v1/ears_transactions" + query)
	return result.data if result.status == 200 else []

# ============================================
# BATTLE HISTORY (OPTIONAL)
# ============================================

func record_battle(attacker_id: String, defender_build_id: String, rank: int, attacker_won: bool, attacker_stats: Dictionary = {}, defender_stats: Dictionary = {}):
	"""Record a battle outcome for analytics/replay."""
	var battle_data = {
		"attacker_id": attacker_id,
		"defender_build_id": defender_build_id,
		"rank": rank,
		"attacker_won": attacker_won,
		"attacker_stats": JSON.stringify(attacker_stats) if not attacker_stats.is_empty() else null,
		"defender_stats": JSON.stringify(defender_stats) if not defender_stats.is_empty() else null
	}
	
	return await _supabase_post("/rest/v1/battle_history", battle_data)

func get_player_battles(player_id: String, limit: int = 20) -> Array:
	"""Get player's battle history."""
	var query = "?attacker_id=eq.%s&select=*&order=battle_timestamp.desc&limit=%d" % [player_id, limit]
	
	var result = await _supabase_get("/rest/v1/battle_history" + query)
	return result.data if result.status == 200 else []

# ============================================
# HTTP HELPER FUNCTIONS
# ============================================

func _supabase_get(endpoint: String) -> Dictionary:
	"""Perform a GET request to Supabase."""
	var url = SUPABASE_URL + endpoint
	var headers = [
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("HTTP request failed to start: %d" % error)
		return {"status": 0, "data": null}
	
	var response = await http_request.request_completed
	var status_code = response[1]
	var body = response[3].get_string_from_utf8()
	
	var parsed_data = JSON.parse_string(body) if body else null
	
	return {
		"status": status_code,
		"data": parsed_data if parsed_data != null else []
	}

func _supabase_post(endpoint: String, data: Dictionary) -> Dictionary:
	"""Perform a POST request to Supabase."""
	var url = SUPABASE_URL + endpoint
	var headers = [
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Prefer: return=representation"  # Return created data
	]
	var body = JSON.stringify(data)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("HTTP request failed to start: %d" % error)
		return {"status": 0, "data": null}
	
	var response = await http_request.request_completed
	var status_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	
	var parsed_data = JSON.parse_string(response_body) if response_body else null
	
	return {
		"status": status_code,
		"data": parsed_data if parsed_data != null else []
	}

func _supabase_patch(endpoint: String, data: Dictionary) -> Dictionary:
	"""Send PATCH request to Supabase (for updating records)."""
	print("=== [DEBUG PATCH] Endpoint: %s ===" % endpoint)
	print("=== [DEBUG PATCH] Data: %s ===" % JSON.stringify(data))
	
	var url = SUPABASE_URL + endpoint
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Prefer: return=representation"  # Return updated data
	]
	
	var body = JSON.stringify(data)
	var error = http_request.request(url, headers, HTTPClient.METHOD_PATCH, body)
	
	if error != OK:
		push_error("[SupabaseManager] PATCH request failed: %d" % error)
		return {"status": 0, "data": {}}
	
	var response = await http_request.request_completed
	
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	
	print("=== [DEBUG PATCH] Response code: %d ===" % response_code)
	print("=== [DEBUG PATCH] Response body: %s ===" % response_body)
	
	var parsed_data = {}
	if not response_body.is_empty():
		var parsed = JSON.parse_string(response_body)
		parsed_data = parsed if parsed != null else {}
	
	return {
		"status": response_code,
		"data": parsed_data
	}

func _supabase_rpc(function_name: String, params: Dictionary = {}) -> Dictionary:
	"""Call a Supabase stored procedure/function."""
	print("=== [DEBUG RPC] Calling function: %s ===" % function_name)
	print("=== [DEBUG RPC] Params: %s ===" % JSON.stringify(params))
	
	var url = SUPABASE_URL + "/rest/v1/rpc/" + function_name
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]
	
	var body = JSON.stringify(params)
	print("=== [DEBUG RPC] Request body: %s ===" % body)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		push_error("[SupabaseManager] RPC request failed: %d" % error)
		return {"status": 0, "data": {}}
	
	# Wait for response
	var response = await http_request.request_completed
	
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	
	print("=== [DEBUG RPC] Response code: %d ===" % response_code)
	print("=== [DEBUG RPC] Response body: %s ===" % response_body)
	
	# Parse response
	var data = {}
	if not response_body.is_empty():
		var parsed = JSON.parse_string(response_body)
		data = parsed if parsed != null else {}
	
	print("=== [DEBUG RPC] Parsed data: %s ===" % JSON.stringify(data))
	
	return {
		"status": response_code,
		"data": data
	}

# ============================================
# UTILITY FUNCTIONS
# ============================================

func _is_valid_uuid(uuid: String) -> bool:
	"""Check if string is a valid UUID format."""
	# UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	var uuid_regex = RegEx.new()
	uuid_regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return uuid_regex.search(uuid) != null

func generate_uuid() -> String:
	"""Generate a UUID v4 (simple implementation)."""
	# For production, consider using a proper UUID library
	# For now, use a hash-based approach
	var time = Time.get_ticks_msec()
	var random = randi()
	return str(time) + "_" + str(random)


# ============================================
# USERNAME MANAGEMENT
# ============================================

func is_username_available(username: String) -> bool:
	"""Check if username is available (not taken by another player)."""
	var query = "?username=eq.%s&select=player_id" % username.uri_encode()
	var result = await _supabase_get("/rest/v1/player_profiles" + query)
	
	if result.status == 200:
		# If we got results, username is taken
		return result.data.is_empty()
	else:
		push_error("[SupabaseManager] Error checking username: %d" % result.status)
		return false

func update_username(player_id: String, new_username: String) -> Dictionary:
	"""Update player's username. Returns success/error result."""
	# First check if username is available
	var available = await is_username_available(new_username)
	if not available:
		return {"success": false, "error": "Username already taken"}
	
	# Update the username
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	var updates = {"username": new_username}
	var result = await _supabase_patch(endpoint, updates)
	
	if result.status in [200, 204]:
		return {"success": true}
	else:
		return {"success": false, "error": "Database error: %d" % result.status}

# ============================================
# PROFILE LOADING & SYNCING
# ============================================

func get_or_create_player_with_username(player_id: String, username: String) -> Dictionary:
	"""
	Enhanced version that handles username conflicts.
	Returns: {success: bool, profile: Dictionary, needs_username: bool}
	"""
	# Try to get existing profile
	var profile = await get_player_profile(player_id)
	
	if not profile.is_empty():
		# Profile exists, return it
		return {
			"success": true,
			"profile": profile,
			"needs_username": false
		}
	
	# Profile doesn't exist - need to create
	# First check if username is available
	var username_available = await is_username_available(username)
	
	if not username_available:
		# Username taken - need user to pick a new one
		return {
			"success": false,
			"profile": {},
			"needs_username": true,
			"error": "Username '%s' is already taken" % username
		}
	
	# Create new profile
	var result = await create_player_profile(player_id, username)
	
	if result.status == 201:
		return {
			"success": true,
			"profile": result.data[0],
			"needs_username": false
		}
	else:
		return {
			"success": false,
			"profile": {},
			"needs_username": false,
			"error": "Failed to create profile: %d" % result.status
		}

# ============================================
# EARS CURRENCY MANAGEMENT
# ============================================

func award_ears_simple(player_id: String, amount: int, reason: String) -> bool:
	"""Award ears to player. Returns true on success."""
	# Get current profile
	var profile = await get_player_profile(player_id)
	if profile.is_empty():
		push_error("[SupabaseManager] Player not found: %s" % player_id)
		return false
	
	# Calculate new balance (with 10,000 cap)
	var new_balance: int = min(int(profile.ears_balance) + amount, 10000)
	
	# Update database
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	var updates = {"ears_balance": new_balance}
	var result = await _supabase_patch(endpoint, updates)
	
	if result.status in [200, 204]:
		print("[SupabaseManager] Awarded %d ears for: %s (New balance: %d)" % [amount, reason, new_balance])
		return true
	else:
		push_error("[SupabaseManager] Failed to award ears: %d" % result.status)
		return false

func spend_ears_simple(player_id: String, amount: int, reason: String) -> bool:
	"""Spend ears. Returns false if insufficient funds."""
	# Get current profile
	var profile = await get_player_profile(player_id)
	if profile.is_empty():
		push_error("[SupabaseManager] Player not found: %s" % player_id)
		return false
	
	# Check if enough ears
	if profile.ears_balance < amount:
		print("[SupabaseManager] Insufficient ears: Need %d, have %d" % [amount, profile.ears_balance])
		return false
	
	# Calculate new balance
	var new_balance: int = int(profile.ears_balance) - amount
	
	# Update database
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	var updates = {"ears_balance": new_balance}
	var result = await _supabase_patch(endpoint, updates)
	
	if result.status in [200, 204]:
		print("[SupabaseManager] Spent %d ears for: %s (New balance: %d)" % [amount, reason, new_balance])
		return true
	else:
		push_error("[SupabaseManager] Failed to spend ears: %d" % result.status)
		return false

# ============================================
# PROFILE STATS UPDATES
# ============================================

func increment_champions_killed(player_id: String):
	"""Increment champion kill count."""
	print("=== [DEBUG] increment_champions_killed called for %s ===" % player_id)
	
	var profile = await get_player_profile(player_id)
	if profile.is_empty():
		push_error("Player profile not found: %s" % player_id)
		return
	
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	var updates = {
		"champions_killed": int(profile.champions_killed) + 1  # CONVERT TO INT!
	}
	
	print("=== [DEBUG] Updates to apply: %s ===" % JSON.stringify(updates))
	
	var result = await _supabase_patch(endpoint, updates)
	
	print("=== [DEBUG] increment_champions_killed result: %s ===" % result.status)
	print("[SupabaseManager] Incremented champion kills for %s" % player_id)

# ============================================
# BUILD CLEANUP (50 per rank limit)
# ============================================

func cleanup_old_builds_at_rank(rank: int):
	"""Delete oldest builds if more than 50 exist at this rank."""
	# Count builds at this rank
	var count_query = "?rank=eq.%d&select=id" % rank
	var result = await _supabase_get("/rest/v1/boss_builds" + count_query)
	
	if result.status != 200:
		return
	
	var count = result.data.size()
	if count <= 50:
		return  # Within limit
	
	# Get IDs of oldest builds to delete
	var excess = count - 50
	var oldest_query = "?rank=eq.%d&select=id&order=created_at.asc&limit=%d" % [rank, excess]
	var oldest_result = await _supabase_get("/rest/v1/boss_builds" + oldest_query)
	
	if oldest_result.status != 200 or oldest_result.data.is_empty():
		return
	
	# Delete the oldest builds
	for build in oldest_result.data:
		var delete_endpoint = "/rest/v1/boss_builds?id=eq.%s" % build.id
		await _supabase_delete(delete_endpoint)
	
	print("[SupabaseManager] Cleaned up %d old builds at rank %d" % [excess, rank])

# ============================================
# HELPER: DELETE REQUEST
# ============================================

func _supabase_delete(endpoint: String) -> Dictionary:
	"""Send DELETE request to Supabase."""
	var url = SUPABASE_URL + endpoint
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_DELETE)
	
	if error != OK:
		push_error("[SupabaseManager] Delete request failed: %d" % error)
		return {"status": 0, "data": {}}
	
	# Wait for response
	var response = await http_request.request_completed
	
	return {
		"status": response[1],
		"data": {}
	}

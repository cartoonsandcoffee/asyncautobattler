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

func _ready():
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
	var query = "?player_id=eq.%s&select=*" % player_id
	var result = await _supabase_get("/rest/v1/player_profiles" + query)
	
	if result.status == 200 and not result.data.is_empty():
		return result.data[0]
	else:
		return {}

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

func update_player_after_run(player_id: String, won: bool, final_rank: int):
	"""Update player stats after completing a run."""
	# Get current profile
	var profile = await get_player_profile(player_id)
	if profile.is_empty():
		push_error("Player profile not found: %s" % player_id)
		return
	
	# Calculate new values
	var updates = {
		"total_runs": profile.total_runs + 1,
		"last_played": Time.get_datetime_string_from_system(true)
	}
	
	if won:
		updates["total_victories"] = profile.total_victories + 1
	else:
		updates["total_deaths"] = profile.total_deaths + 1
	
	if final_rank > profile.highest_rank_achieved:
		updates["highest_rank_achieved"] = final_rank
	
	# Update database
	var endpoint = "/rest/v1/player_profiles?player_id=eq.%s" % player_id
	return await _supabase_patch(endpoint, updates)

func get_leaderboard(limit: int = 10) -> Array:
	"""Get top players by total victories."""
	var query = "?select=username,total_victories,highest_rank_achieved,ears_balance&order=total_victories.desc,highest_rank_achieved.desc&limit=%d" % limit
	
	var result = await _supabase_get("/rest/v1/player_profiles" + query)
	return result.data if result.status == 200 else []

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
	# Build query without whitespace (URLs can't have newlines/tabs)
	var query = "?rank=eq.%d&retired=eq.false&select=*&order=created_at.desc&limit=20" % rank
	
	# Only add player_id filter if provided
	#if not player_id.is_empty():
	#	query += "&player_id=neq.%s" % player_id
	
	print("DEBUG: Fetching opponents for rank %d" % rank)
	#if not player_id.is_empty():
	#	print("DEBUG: Excluding player_id: %s" % player_id)
	print("DEBUG: Full query: ", query)
	print("DEBUG: Full URL: ", SUPABASE_URL + "/rest/v1/boss_builds" + query)
	
	var result = await _supabase_get("/rest/v1/boss_builds" + query)
	
	print("DEBUG: Response status: ", result.status)
	if result.status != 200:
		print("DEBUG: Error response: ", JSON.stringify(result.data, "\t"))
	print("DEBUG: Response data type: ", typeof(result.data))
	print("DEBUG: Response data size: ", result.data.size() if result.data is Array else 0)
	
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

func promote_to_champion(build_id: String):
	"""Promote a rank 5 build to champion status."""
	return await _supabase_rpc("promote_to_champion", {"p_build_id": build_id})

func get_active_champions(player_id: String) -> Array:
	"""Get player's active champions (not yet retired)."""
	var query = "?player_id=eq.%s&select=*&order=champion_victories.desc" % player_id
	
	var result = await _supabase_get("/rest/v1/active_champions" + query)
	return result.data if result.status == 200 else []

func record_champion_victory(build_id: String):
	"""Record a victory for a champion build (awards ears automatically)."""
	return await _supabase_rpc("increment_boss_victory", {"p_build_id": build_id})

func record_champion_defeat(build_id: String):
	"""Record a defeat for a champion build."""
	return await _supabase_rpc("increment_boss_defeat", {"p_build_id": build_id})

func get_hall_of_fame(limit: int = 50) -> Array:
	"""Get retired champions in Hall of Fame."""
	var query = "?select=*&limit=%d" % limit
	var result = await _supabase_get("/rest/v1/hall_of_champions" + query)
	return result.data if result.status == 200 else []

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
	"""Perform a PATCH request to Supabase (update)."""
	var url = SUPABASE_URL + endpoint
	var headers = [
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]
	var body = JSON.stringify(data)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_PATCH, body)
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

func _supabase_rpc(function_name: String, params: Dictionary = {}) -> Dictionary:
	"""Call a Supabase database function (RPC)."""
	var url = SUPABASE_URL + "/rest/v1/rpc/" + function_name
	var headers = [
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]
	var body = JSON.stringify(params)
	
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
		"data": parsed_data
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
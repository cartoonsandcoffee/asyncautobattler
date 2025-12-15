class_name BossRoomEvent
extends RoomEvent

## Boss battle event with comic-book style animations and rank progression

@onready var flavor_animation: AnimationPlayer  = $animFlavor # "A dangerous figure approaches..."
# Note: Continue button and staircase animation are in main_game, not here

var boss_enemy: Enemy = null

func _ready():
	# Get main game reference
	main_game_ref = get_tree().get_root().get_node_or_null("MainGame")
	if not main_game_ref:
		push_error("[BossRoom] Could not find MainGame node!")
		return
	
	reset_all_animations()
	
	# Get animation player if it exists in scene
	flavor_animation = get_node_or_null("animFlavor")
	
	# Don't call super._ready() - we have custom flow
	await _boss_battle_sequence()

# Override parent's automatic sequence
func _begin_event_sequence():
	# Do nothing - we handle our own sequence in _ready()
	pass

func _boss_battle_sequence():
	"""Main boss battle flow: flavor -> combat -> victory."""
	print("[BossRoom] Starting boss battle sequence")
	
	# 1. Get boss from DungeonManager (already loaded at rank start)
	boss_enemy = DungeonManager.current_boss_enemy
	
	if not boss_enemy:
		push_error("[BossRoom] No boss enemy available from DungeonManager!")
		complete_event()
		return
	
	print("[BossRoom] Boss: %s (HP: %d)" % [boss_enemy.enemy_name, boss_enemy.stats.hit_points])
	
	# 2. Play flavor animation
	await _play_flavor_animation()
	
	# 3. Start combat (uses existing combat panel)
	# Combat panel will detect boss via enemy_type == BOSS_PLAYER
	combat_requested.emit(boss_enemy)
	
	if not main_game_ref.has_method("request_combat"):
		push_error("[BossRoom] MainGame doesn't have request_combat method!")
		complete_event()
		return
	
	var victory = await main_game_ref.request_combat(boss_enemy)
	player_won_combat = victory
	
	# 4. Handle victory or defeat
	if victory:
		await _handle_victory()
	else:
		await _handle_defeat()
	
	# 5. Complete event
	complete_event()

func _play_flavor_animation():
	"""Play comic-book panel animation: 'A dangerous figure approaches...'"""
	if flavor_animation:
		print("[BossRoom] Playing flavor animation")
		flavor_animation.play("boss_approach")
		await flavor_animation.animation_finished
	else:
		# No animation in scene - brief delay for testing
		print("[BossRoom] No flavor animation - using brief delay")
		await get_tree().create_timer(1.0).timeout

func _handle_victory():
	"""Handle boss defeat: save build, wait for continue, trigger rank advancement."""
	print("[BossRoom] Victory! Handling post-combat sequence")
	
	# 1. Boss death animation happens in combat_panel (not here)
	
	# 2. Victory popup/combat summary appears in combat_panel (existing system)
	
	# 3. Save player build to Supabase
	await _save_player_build()
	
	# 4. Wait for player to click continue button in main_game
	# The continue button will trigger:
	#   - Staircase animation (in main_game)
	#   - DungeonManager.advance_rank()
	#   - Load first room of new rank
	
	# NOTE: We don't handle rank advancement here - main_game does it
	# when player clicks the continue/staircase button
	
	print("[BossRoom] Victory sequence complete, waiting for player to continue")

func _save_player_build():
	"""Save player's build to Supabase after boss victory."""
	if not has_node("/root/SupabaseManager"):
		print("[BossRoom] SupabaseManager not available - skipping save")
		return
	
	print("[BossRoom] Saving player build to Supabase...")
	
	var build_data = Player.to_boss_data()

	# DEBUG: Print what we're sending
	print("[BossRoom] Build data to save:")
	print("  - Username: %s" % build_data.get("username"))
	print("  - Rank: %d" % build_data.get("rank"))
	print("  - HP: %d/%d" % [build_data.get("curr_hp"), build_data.get("max_hp")])
	print("  - Damage: %d" % build_data.get("base_damage"))
	print("  - Weapon: %s" % build_data.get("weapon"))
	var inventory_data = build_data.get("inventory", [])
	var inventory_count = 0
	if inventory_data is Array:
		inventory_count = inventory_data.size()
	elif inventory_data is String:
		var parsed = JSON.parse_string(inventory_data)
		inventory_count = parsed.size() if parsed else 0
	print("  - Inventory size: %d items" % inventory_count)
		
	var result = await SupabaseManager.save_boss_build(build_data)

	# DEBUG: Print full response
	print("[BossRoom] Supabase response:")
	print("  - Status: %s" % (result.status if result else "null"))
	print("  - Data: %s" % (result.data if result else "null"))

	if result and result.status == 201:
		print("[BossRoom] ! Build saved to rank %d opponent pool!" % DungeonManager.current_rank)
		
		# Check if rank 5 - promote to champion
		if DungeonManager.current_rank == 5:
			var build_id = result.data[0].get("id")
			if build_id:
				await SupabaseManager.promote_to_champion(build_id)
				print("[BossRoom] - Promoted to Champion!")
	else:
		var status = result.status if result else "null"
		push_warning("[BossRoom] Failed to save build (status: %s)" % status)

func _handle_defeat():
	"""Handle player defeat - game over or retry."""
	print("[BossRoom] Defeat. Game over.")
	
	# TODO: Implement defeat logic
	# - Show game over screen?
	# - Offer retry?
	# - Return to main menu?
	
	# For now, just complete the event
	pass

## =============================================================================
## SCENE STRUCTURE REQUIREMENTS
## =============================================================================

# Minimal scene structure:
# BossRoomEvent (Control) + this script
# └─ FlavorAnimation (AnimationPlayer) - Optional
#    Create animation named "boss_approach" with:
#    - Label fade in: "A dangerous figure approaches from the shadows..."
#    - Comic-book panel effects
#    - Duration: 2-3 seconds

# Notes:
# - Continue button is in main_game.tscn, NOT in this scene
# - Staircase animation is in main_game.tscn, NOT in this scene
# - Victory popup/combat summary is in combat_panel, NOT in this scene
# - This scene is MINIMAL - just flavor animation before combat

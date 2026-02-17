class_name BossRoomEvent
extends RoomEvent

## Boss battle event with comic-book style animations and rank progression

@onready var flavor_animation: AnimationPlayer  = $animFlavor # "A dangerous figure approaches..."
@onready var anim_done: AnimationPlayer  = $animDone
@onready var anim_ears: AnimationPlayer  = $animOnward

@onready var lbl_promo: Label  = $panelFinished/panelBlack/MarginContainer/panelBorder/VBoxContainer/lblPromo


# Note: Continue button and staircase animation are in main_game, not here

var boss_enemy: Enemy = null

func _ready():
	# Get main game reference
	main_game_ref = get_tree().get_root().get_node_or_null("MainGame")
	CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL) #Always default to normal speed for boss battles
	if not main_game_ref:
		push_error("[BossRoom] Could not find MainGame node!")
		return
	
	reset_all_animations()
	
	# manually increment player room count so battles don't cost room points
	Player.add_rooms(2)

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
	
	# log the number of times the boss has been faced.
	var boss_build_id = DungeonManager.current_boss_data.get("id", "")
	if not boss_build_id.is_empty():
		await SupabaseManager.increment_times_faced(boss_build_id)
		print("[BossRoom] Incremented times_faced for boss %s" % boss_build_id)

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
	#complete_event()

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
	
	# 3. Handle which progress comes next
	if DungeonManager.current_rank == 5:
		anim_ears.play("show_panel")
	elif DungeonManager.current_rank == 6:
		anim_ears.play("show_final")
	else:
		lbl_promo.text = "You  advance  to  Rank " + str(DungeonManager.current_rank + 1) + "!"
		anim_done.play("show_popup")

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

		# Cleanup old builds (keep only 50 per rank) - except for champions
		if DungeonManager.current_rank < 6:
			await SupabaseManager.cleanup_old_builds_at_rank(DungeonManager.current_rank)
		
		# If it was rank 6, promote to champion
		if DungeonManager.current_rank == 6:
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
	
	## Supabase logging happening in the Combat_Panel.gd for the on_click events of the defeat menu.

### =========================================================================
### POPUP STUFF
### =========================================================================

func play_popup_open_sfx():
	AudioManager.play_synced_sound("popup_open")

func play_popup_close_sfx():
	AudioManager.play_synced_sound("popup_close")

func _on_btn_champion_pressed() -> void:
	var player_id = Player.load_or_generate_uuid()
	await _save_player_build()

	await SupabaseManager.award_ears_simple(player_id, 1, "Challenging for Glory")
	
	# Update local ears count
	var profile = await SupabaseManager.get_player_profile(player_id)
	if not profile.is_empty():
		Player.update_ears(profile.ears_balance)
	
		# Reload profile to sync local stats
	if not profile.is_empty():
		Player.load_profile_from_supabase(profile)	

	# Show "Quit While Ahead" choice (for Phase 2)
	print("[Game] Rank 5 complete, continuing to Champions...")
	main_game_ref.boss_room_completed("challenge")


func _on_btn_end_pressed() -> void:
	var player_id = Player.load_or_generate_uuid()
	await _save_player_build()
	await SupabaseManager.award_ears_simple(player_id, 2, "Rank 5 Victory")
	
	# Update local ears count
	var profile = await SupabaseManager.get_player_profile(player_id)
	if not profile.is_empty():
		Player.update_ears(profile.ears_balance)
	
	if not profile.is_empty():
		Player.load_profile_from_supabase(profile)	

	# Show "Quit While Ahead" choice (for Phase 2)
	print("[Game] Rank 5 complete! +2 ears earned")
	main_game_ref.boss_room_completed("end")


func _on_btn_continue_pressed() -> void:
	await _save_player_build()
	main_game_ref.boss_room_completed("continue")
	

func _on_btn_final_victory_pressed() -> void:
	"""Handle victory against a champion (rank 6)."""
	print("[BossRoom] Champion defeated!")
	
	# 1. Record the champion's defeat
	var defeated_champion_id = DungeonManager.current_boss_data.get("id", "")
	if not defeated_champion_id.is_empty():
		await SupabaseManager.record_champion_defeat(defeated_champion_id)
		print("[BossRoom] Recorded champion defeat")
	
	await _save_player_build()

	# 4. Increment player's champion kill count
	var player_id = Player.load_or_generate_uuid()
	await SupabaseManager.award_ears_simple(player_id, 1, "First Champion Beat")
	await SupabaseManager.increment_champions_killed(player_id)

	# 4. Reload profile to sync local stats
	var profile = await SupabaseManager.get_player_profile(player_id)
	if not profile.is_empty():
		Player.load_profile_from_supabase(profile)

	print("[BossRoom] Player is now a champion!")	
	main_game_ref.boss_room_completed("final")

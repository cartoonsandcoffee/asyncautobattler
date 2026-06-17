class_name BossRoomEvent
extends RoomEvent

## Boss battle event with comic-book style animations and rank progression

@onready var anim_done: AnimationPlayer  = $animDone
@onready var anim_ears: AnimationPlayer  = $animOnward
@onready var anim_shadow: AnimationPlayer  = $animShadow

@onready var lbl_promo: Label  = $panelFinished/panelBlack/MarginContainer/panelBorder/VBoxContainer/lblPromo

@onready var btn_end :Button = $panelOnward/panelBox/VBoxContainer/twoChoices/panelEnd/btnEnd
@onready var btn_champ :Button = $panelOnward/panelBox/VBoxContainer/twoChoices/panelContinue/btnChampion
@onready var btn_continue: Button = $panelFinished/panelBlack/MarginContainer/panelBorder/VBoxContainer/btnContinue
@onready var btn_final:Button = $panelFinalVictory/panelBlack/VBoxContainer/panelBody/VBoxContainer/btnFinalVictory

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
	_enable_all_buttons()

	# manually increment player room count so battles don't cost room points
	Player.add_rooms(2)

	# Don't call super._ready() - we have custom flow
	await _boss_battle_sequence()

# Override parent's automatic sequence
func _begin_event_sequence():
	# Do nothing - we handle our own sequence in _ready()
	pass

func _disable_all_buttons():
	btn_end.disabled = true
	btn_final.disabled = true
	btn_champ.disabled = true
	btn_continue.disabled = true

func _enable_all_buttons():
	btn_end.disabled = false
	btn_final.disabled = false
	btn_champ.disabled = false
	btn_continue.disabled = false

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
		anim_shadow.play("hide_shadow")
		await _handle_victory()
	else:
		anim_shadow.play("hide_shadow")
		await _handle_defeat()
	
	if main_game_ref:
		main_game_ref.fight_or_flee.instant_toggle.show_me()
		
	# 5. Complete event
	#complete_event()

func _handle_victory():
	"""Handle boss defeat: save build, wait for continue, trigger rank advancement."""
	print("[BossRoom] Victory! Handling post-combat sequence")
	
	# 1. Boss death animation happens in combat_panel (not here)

	# 2. Victory popup/combat summary appears in combat_panel (existing system)
	
	# 3. Handle which progress comes next
	if DungeonManager.current_rank == 5:
		Player.popup_open = true
		anim_ears.play("show_panel")
	elif DungeonManager.current_rank == 6:
		Player.popup_open = true
		anim_ears.play("show_final")
	else:
		Player.popup_open = true
		lbl_promo.text = "You  advance  to  Rank " + str(DungeonManager.current_rank + 1) + "!"
		anim_done.play("show_popup")

	print("[BossRoom] Victory sequence complete, waiting for player to continue")

func _save_player_build(player_won: bool = true) -> String:
	## -- Save player's build to Supabase. Returns saved build ID or empty string.
	if not has_node("/root/SupabaseManager"):
		print("[BossRoom] SupabaseManager not available - skipping save")
		return ""
	
	print("[BossRoom] Saving player build (won: %s) to Supabase..." % player_won)
	
	var build_data = Player.to_boss_data()
	build_data["player_won"] = player_won
	
	var result = await SupabaseManager.save_boss_build(build_data)
	
	if result and result.status == 201:
		var build_id = result.data[0].get("id", "")
		print("[BossRoom] Build saved to rank %d pool (id: %s)" % [DungeonManager.current_rank, build_id])
		
		if DungeonManager.current_rank < 6:
			await SupabaseManager.cleanup_old_builds_at_rank(DungeonManager.current_rank)
		
		if DungeonManager.current_rank == 6 and player_won:
			await SupabaseManager.promote_to_champion(build_id)
			print("[BossRoom] Promoted to Champion!")
		
		return build_id
	else:
		push_warning("[BossRoom] Failed to save build (status: %s)" % (result.status if result else "null"))
		return ""

func _handle_defeat():
	# Defeat flow for boss battles is handled entirely in CombatPanel._update_defeat_stats()
	# combat_completed signal is never emitted on defeat, so this function is unreachable
	# from the boss battle path. Kept for structural clarity only.
	pass

### =========================================================================
### POPUP STUFF
### =========================================================================

func play_popup_open_sfx():
	AudioManager.play_synced_sound("popup_open")

func play_popup_close_sfx():
	AudioManager.play_synced_sound("popup_close")

func _on_btn_champion_pressed() -> void:
	_disable_all_buttons()
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

	Player.popup_open = false
	# Show "Quit While Ahead" choice (for Phase 2)
	print("[Game] Rank 5 complete, continuing to Champions...")
	main_game_ref.boss_room_completed("challenge")


func _on_btn_end_pressed() -> void:
	_disable_all_buttons()
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
	Player.popup_open = false
	main_game_ref.boss_room_completed("end")


func _on_btn_continue_pressed() -> void:
	_disable_all_buttons()
	await _save_player_build()
	Player.popup_open = false
	main_game_ref.boss_room_completed("continue")
	

func _on_btn_final_victory_pressed() -> void:
	"""Handle victory against a champion (rank 6)."""
	print("[BossRoom] Champion defeated!")
	_disable_all_buttons()

	# 1. Record the champion's defeat
	var defeated_champion_id = DungeonManager.current_boss_data.get("id", "")
	if not defeated_champion_id.is_empty():
		await SupabaseManager.record_champion_defeat(defeated_champion_id)
	
	var player_id = Player.load_or_generate_uuid()
	var attacker_build_id = await _save_player_build(true)  # promote_to_champion fires inside
	
	# Record in battle_history
	if not attacker_build_id.is_empty() and not defeated_champion_id.is_empty():
		await SupabaseManager.record_rank6_battle(player_id, attacker_build_id, defeated_champion_id, true)
	
	await SupabaseManager.award_ears_simple(player_id, 1, "First Champion Beat")
	await SupabaseManager.increment_champions_killed(player_id)
	
	var profile = await SupabaseManager.get_player_profile(player_id)
	if not profile.is_empty():
		Player.load_profile_from_supabase(profile)
	
	Player.popup_open = false
	print("[BossRoom] Player is now a champion!")
	main_game_ref.boss_room_completed("final")


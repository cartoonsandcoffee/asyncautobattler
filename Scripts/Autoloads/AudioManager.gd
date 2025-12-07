extends Node

## =============================================================================
## AUDIO PLAYERS
## =============================================================================

# Music players (for crossfading)
var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var current_music_player: AudioStreamPlayer
var fading_music_player: AudioStreamPlayer

# UI SFX player pool (for overlapping sounds)
var ui_sfx_players: Array[AudioStreamPlayer] = []
const UI_SFX_POOL_SIZE = 5

# Ambient sound player
var ambient_player: AudioStreamPlayer

## =============================================================================
## MUSIC TRACKS
## =============================================================================

# Store loaded music tracks
var music_tracks: Dictionary = {}

# Music contexts (priority order: higher = more important)
enum MusicContext {
	NONE = 0,
	GENERAL = 1,      # Default exploration music
	COMBAT_NPC = 2,   # Fighting regular enemies
	COMBAT_PVP = 3,   # Fighting boss (player builds)
	ROOM_OVERRIDE = 4 # Room-specific music (highest priority)
}

# Current music state
var current_context: MusicContext = MusicContext.NONE
var room_override_track: String = ""  # Set by rooms for special music
var current_track_name: String = ""

# Crossfade settings
var crossfade_duration: float = 2.0  # Seconds for music transition

## =============================================================================
## UI SOUND EFFECTS
## =============================================================================

# Store loaded UI sounds
var ui_sounds: Dictionary = {}
var is_ready: bool = false

# UI sound names (define all your UI sounds here)
const UI_SOUND_NAMES = {
	"button_hover": "res://Assets/Audio/SFX/UI/drop_001.ogg",
	"button_click": "res://Assets/Audio/SFX/UI/glass_003.ogg",
	"item_hover": "res://Assets/Audio/SFX/UI/glass_002.ogg",
	"item_pickup": "res://Assets/Audio/SFX/UI/drop_001.ogg",
	"item_drop": "res://Assets/Audio/SFX/UI/drop_003.ogg",
	"popup_open": "res://Assets/Audio/SFX/UI/maximize_008.ogg",
	"popup_close": "res://Assets/Audio/SFX/UI/minimize_008.ogg",
	"panel_slide": "res://Assets/Audio/SFX/UI/woosh1.ogg",
	"text_type": "res://Assets/Audio/SFX/UI/scroll_002.ogg",
	"combat_footstep": "res://Assets/Audio/SFX/COMBAT/footstep_grass_004.ogg",
	"combat_coins": "res://Assets/Audio/SFX/COMBAT/handleCoins.ogg",
	"combat_player_hit_light": "res://Assets/Audio/SFX/COMBAT/Player_Hit_Light.ogg",
	"combat_player_hit_heavy": "res://Assets/Audio/SFX/COMBAT/Player_Hit_Heavy.ogg",
	"combat_enemy_hit": "res://Assets/Audio/SFX/COMBAT/Enemy_Hit.ogg",
	"item_proc": "res://Assets/Audio/SFX/COMBAT/impactPlank_medium_003.ogg",
}

## =============================================================================
## INITIALIZATION
## =============================================================================

func _ready():
	print("[AudioManager] Initializing audio system...")
	
	# Create music players
	_create_music_players()
	
	# Create UI SFX player pool
	_create_ui_sfx_pool()
	
	# Create ambient player
	_create_ambient_player()
	
	# Load music tracks
	_load_music_tracks()
	
	# Load UI sounds
	_load_ui_sounds()
	
	# Connect to GameSettings for volume changes
	if GameSettings:
		GameSettings.volume_changed.connect(_on_volume_changed)
	
	is_ready = true
	print("[AudioManager] Audio system ready!")

func _create_music_players():
	"""Create two music players for crossfading."""
	music_player_a = AudioStreamPlayer.new()
	music_player_a.name = "MusicPlayerA"
	music_player_a.bus = "Music"
	add_child(music_player_a)
	
	music_player_b = AudioStreamPlayer.new()
	music_player_b.name = "MusicPlayerB"
	music_player_b.bus = "Music"
	add_child(music_player_b)
	
	current_music_player = music_player_a
	fading_music_player = music_player_b

func _create_ui_sfx_pool():
	"""Create pool of UI sound players for overlapping sounds."""
	for i in range(UI_SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "UISFXPlayer%d" % i
		player.bus = "SFX"
		add_child(player)
		ui_sfx_players.append(player)

func _create_ambient_player():
	"""Create ambient sound player."""
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambience"
	add_child(ambient_player)

## =============================================================================
## LOAD AUDIO RESOURCES
## =============================================================================

func _load_music_tracks():
	"""Load all music tracks into memory."""
	# Add your music tracks here
	# Format: music_tracks["name"] = "path/to/file.ogg"
	
	# Example structure:
	music_tracks["general_exploration"] = "res://Assets/Audio/Music/Main Theme (Dark - OGG).ogg"
	music_tracks["combat_npc"] = "res://Assets/Audio/Music/Combat Theme.mp3"
	music_tracks["combat_pvp"] = "res://Assets/Audio/Music/Main Theme (Epic).mp3"
	music_tracks["boss_victory"] = "res://Assets/Audio/Music/Piano Theme OGG.ogg"
	
	# Room-specific tracks (examples)
	music_tracks["starter_room"] = "res://Assets/Audio/Music/Piano Theme OGG.ogg"
	# music_tracks["treasure_room"] = "res://Audio/Music/treasure_jingle.ogg"
	
	# Preload all tracks
	for track_name in music_tracks.keys():
		var path = music_tracks[track_name]
		if ResourceLoader.exists(path):
			var stream = load(path)
			music_tracks[track_name] = stream
			print("[AudioManager] Loaded music: %s" % track_name)
		else:
			push_warning("[AudioManager] Music not found: %s" % path)
			music_tracks.erase(track_name)

func _load_ui_sounds():
	"""Load all UI sound effects."""
	for sound_name in UI_SOUND_NAMES.keys():
		var path = UI_SOUND_NAMES[sound_name]
		if ResourceLoader.exists(path):
			ui_sounds[sound_name] = load(path)
			print("[AudioManager] Loaded UI sound: %s" % sound_name)
		else:
			push_warning("[AudioManager] UI sound not found: %s at %s" % [sound_name, path])

## =============================================================================
## MUSIC CONTROL - PUBLIC API
## =============================================================================

func play_general_music():
	if not is_ready:
		push_warning("[AudioManager] Not ready yet, deferring music")
		call_deferred("play_general_music")
		return

	if not music_tracks.has("general_exploration"):
		push_warning("[AudioManager] General music not loaded yet")
		return

	_switch_music_context(MusicContext.GENERAL, "general_exploration")

func play_combat_music(is_pvp: bool = false):
	if not is_ready:
		push_warning("[AudioManager] Not ready yet, deferring music")
		return

	var track_name = "combat_pvp" if is_pvp else "combat_npc"
	
	if not music_tracks.has(track_name):
		push_warning("[AudioManager] Combat music not loaded: %s" % track_name)
		return
	
	var context = MusicContext.COMBAT_PVP if is_pvp else MusicContext.COMBAT_NPC
	_switch_music_context(context, track_name)

func play_room_music(track: Variant):
	# Override with room-specific music.
	# Can accept either:
	# - AudioStream resource
	# - String track name from music_tracks dictionary
	# - null to clear

	if track == null:
		clear_room_override()
		return
	
	var stream: AudioStream = null
	var track_name: String = ""
	
	# Handle AudioStream resource
	if track is AudioStream:
		stream = track
		# Use filename as track name for debug
		track_name = track.resource_path.get_file().get_basename()
		room_override_track = track_name
		print("[AudioManager] Playing room music from resource: %s" % track_name)
	
	# Handle string track name (lookup in library)
	elif track is String:
		if track.is_empty():
			clear_room_override()
			return
		
		if not music_tracks.has(track):
			push_warning("[AudioManager] Room music not found in library: %s" % track)
			return
		
		stream = music_tracks[track]
		track_name = track
		room_override_track = track_name
		print("[AudioManager] Playing room music from library: %s" % track_name)
	
	else:
		push_warning("[AudioManager] Invalid music track type: %s" % typeof(track))
		return
	
	# Update context and crossfade
	current_context = MusicContext.ROOM_OVERRIDE
	current_track_name = track_name
	_crossfade_to_track(stream)

func clear_room_override():
	if room_override_track.is_empty():
		# No override was set, nothing to clear
		print("[AudioManager] No room override to clear")
		return

	print("[AudioManager] Clearing room override: %s" % room_override_track)
	var was_override = room_override_track
	room_override_track = ""
	
	# Only change music if we were actually playing the room override
	if current_context == MusicContext.ROOM_OVERRIDE and current_track_name == was_override:
		print("[AudioManager] → Room override was playing, restoring appropriate music")
		current_context = MusicContext.NONE
		_restore_appropriate_music()
	else:
		# Override existed but wasn't playing (e.g., combat was playing)
		print("[AudioManager] → Override cleared but not playing, keeping: %s" % current_track_name)

func stop_music(fade_out: bool = true):
	"""Stop all music."""
	if fade_out:
		_crossfade_to_silence()
	else:
		current_music_player.stop()
		fading_music_player.stop()
	
	current_context = MusicContext.NONE
	current_track_name = ""

## =============================================================================
## MUSIC CONTROL - INTERNAL
## =============================================================================

func _switch_music_context(new_context: MusicContext, track_name: String, stream: AudioStream = null):
	# Check priority
	if new_context < current_context:
		return
	
	# Don't restart same track
	if track_name == current_track_name and current_music_player.playing:
		return

	if track_name == current_track_name and current_music_player.playing:
		print("[AudioManager] Already playing %s, no change needed" % track_name)
		
		# Update context but don't crossfade
		current_context = new_context
		return  # ← Skip crossfade!

	# Get the music stream - ADD NULL CHECK
	if not music_tracks.has(track_name):
		push_warning("[AudioManager] Music track not found: %s" % track_name)
		return
	
	var new_stream = music_tracks[track_name]
	
	# ADD: Check if stream is valid
	if not new_stream:
		push_warning("[AudioManager] Music stream is null: %s" % track_name)
		return
	
	print("[AudioManager] Switching music: %s → %s" % [current_track_name, track_name])
	
	# Update state
	current_context = new_context
	current_track_name = track_name
	
	# Start crossfade
	_crossfade_to_track(new_stream)

func _crossfade_to_track(new_stream: AudioStream):
	if not new_stream:
		push_warning("[AudioManager] Cannot crossfade to null stream")
		return

	# Swap players (current becomes fading, fading becomes current)
	var temp = current_music_player
	current_music_player = fading_music_player
	fading_music_player = temp
	
	# Set new stream and start playing
	current_music_player.stream = new_stream
	current_music_player.volume_db = -80  # Start silent
	current_music_player.play()
	
	# Create tween for crossfade
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in new music
	tween.tween_property(current_music_player, "volume_db", 0, crossfade_duration)
	
	# Fade out old music
	if fading_music_player.playing:
		tween.tween_property(fading_music_player, "volume_db", -80, crossfade_duration)
	
	# Stop old music after fade
	tween.tween_callback(func(): 
		if fading_music_player.playing:
			fading_music_player.stop()
	).set_delay(crossfade_duration)

func _crossfade_to_silence():
	"""Fade out current music."""
	if not current_music_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(current_music_player, "volume_db", -80, crossfade_duration)
	tween.tween_callback(func(): current_music_player.stop())

func _restore_appropriate_music():
	print("[AudioManager] Restoring appropriate music...")

	# Priority 1: Room override (if set)
	if not room_override_track.is_empty():
		print("[AudioManager] → Room has override: %s" % room_override_track)
		play_room_music(room_override_track)
		return
	
	# Priority 2: Combat (if active)
	if CombatManager and CombatManager.has_method("is_combat_active"):
		if CombatManager.combat_active:
			print("[AudioManager] → Combat is active")
			var is_pvp = false
			if CombatManager.enemy_entity:
				is_pvp = CombatManager.enemy_entity.enemy_type == Enemy.EnemyType.BOSS_PLAYER
			play_combat_music(is_pvp)
			return
	
	# Priority 3: Default to general music
	print("[AudioManager] → Defaulting to general music")
	play_general_music()

## =============================================================================
## UI SOUND EFFECTS - PUBLIC API
## =============================================================================

func play_ui_sound(sound_name: String):
	"""Play a UI sound effect (non-positional)."""
	if not ui_sounds.has(sound_name):
		push_warning("[AudioManager] UI sound not found: %s" % sound_name)
		return
	
	# Find available player
	var player = _get_available_ui_player()
	if not player:
		push_warning("[AudioManager] No available UI sound players!")
		return
	
	player.stream = ui_sounds[sound_name]
	player.play()

func play_synced_sound(sound_name: String):
	"""Play sound synced with animation (call from AnimationPlayer)."""
	play_ui_sound(sound_name)

func _get_available_ui_player() -> AudioStreamPlayer:
	"""Get an available UI sound player from pool."""
	for player in ui_sfx_players:
		if not player.playing:
			return player
	
	# All busy, return first one (will interrupt)
	return ui_sfx_players[0]

## =============================================================================
## AMBIENT SOUNDS
## =============================================================================

func play_ambient(ambient: Variant, loop: bool = true):
	#Play ambient sound (like wind, rain, dungeon atmosphere, etc.)
	#
	#Args:
	#	ambient: Can be either:
	#		- AudioStream resource
	#		- String name from loaded ambient sounds
	#	loop: Whether to loop the ambient sound (default: true)
	
	if ambient == null:
		stop_ambient()
		return
	
	var stream: AudioStream = null
	
	# Handle AudioStream resource
	if ambient is AudioStream:
		stream = ambient
		print("[AudioManager] Playing ambient from resource: %s" % stream.resource_path.get_file())
	
	# Handle string name (if you want to preload ambients like music)
	elif ambient is String:
		# You could add ambient_sounds dictionary similar to music_tracks
		# For now, try to load directly
		if ResourceLoader.exists(ambient):
			stream = load(ambient)
			print("[AudioManager] Playing ambient from path: %s" % ambient)
		else:
			push_warning("[AudioManager] Ambient sound not found: %s" % ambient)
			return
	
	else:
		push_warning("[AudioManager] Invalid ambient type: %s" % typeof(ambient))
		return
	
	# Set stream and play
	ambient_player.stream = stream
	ambient_player.play()
	
	print("[AudioManager] Ambient sound started")

func stop_ambient(fade_out: bool = true):
	"""Stop ambient sound."""
	if fade_out:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80, 1.0)
		tween.tween_callback(func(): ambient_player.stop())
	else:
		ambient_player.stop()

## =============================================================================
## COMBAT INTEGRATION
## =============================================================================

func on_combat_started(is_boss_fight: bool):
	"""Called when combat starts - switch to combat music."""
	play_combat_music(is_boss_fight)

func on_combat_ended():
	print("[AudioManager] Combat ended, restoring music...")
	
	# Reset combat context
	if current_context == MusicContext.COMBAT_NPC or current_context == MusicContext.COMBAT_PVP:
		current_context = MusicContext.NONE
	
	# Check if we have a room override to return to
	if not room_override_track.is_empty():
		# Room has special music, return to it
		print("[AudioManager] → Returning to room music: %s" % room_override_track)
		play_room_music(room_override_track)
	else:
		# No room override, return to general music
		print("[AudioManager] → Returning to general music")
		play_general_music()

## =============================================================================
## ROOM INTEGRATION
## =============================================================================

func on_room_entered(room_music: Variant = null):
	# Called when entering a room - check for music override.
	# Args:
	#	- room_music: Can be AudioStream resource or String track name
	
	if room_music:
		play_room_music(room_music)
	else:
		# If no combat, play general music
		if not CombatManager or not CombatManager.combat_active:
			play_general_music()

func on_room_exited():
	"""Called when leaving a room - clear override."""
	clear_room_override()

## =============================================================================
## VOLUME CONTROL
## =============================================================================

func _on_volume_changed(bus_name: String, volume: float):
	"""React to GameSettings volume changes."""
	# Volumes are handled automatically by audio bus system
	# This is just for any special handling if needed
	pass

## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

func is_music_playing() -> bool:
	"""Check if any music is currently playing."""
	return current_music_player.playing or fading_music_player.playing

func get_current_music_name() -> String:
	"""Get name of currently playing music."""
	return current_track_name
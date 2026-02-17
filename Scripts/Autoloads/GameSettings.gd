extends Node

## =============================================================================
## SETTINGS DATA
## =============================================================================

# Audio Settings
var master_volume: float = 1.0  # 0.0 to 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var ambience_volume: float = 1.0

# Graphics Settings
var crt_effect_enabled: bool = false
var screen_shake_enabled: bool = true
var vsync_enabled: bool = true
var fullscreen_enabled: bool = false
var skip_opening: bool = false

# Gameplay Settings (for future use)
var combat_speed: int = 1  # 0=slow, 1=normal, 2=fast
var show_damage_numbers: bool = true
var show_combat_log: bool = true

# Save file path
const SETTINGS_FILE = "user://game_settings.cfg"

# Signal emitted when settings change
signal settings_changed
signal volume_changed(bus_name: String, volume: float)
signal graphics_changed(setting: String, value)

var _initialized: bool = false

## =============================================================================
## INITIALIZATION
## =============================================================================

func _ready():
	pass

func initialize():
	if _initialized:
		return
	_initialized = true

	load_settings()
	apply_all_settings()

## =============================================================================
## AUDIO SETTINGS
## =============================================================================

func set_master_volume(value: float):
	"""Set master volume (0.0 to 1.0)."""
	master_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("Master", master_volume)
	volume_changed.emit("Master", master_volume)
	settings_changed.emit()

func set_sfx_volume(value: float):
	"""Set SFX volume (0.0 to 1.0)."""
	sfx_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)
	volume_changed.emit("SFX", sfx_volume)
	settings_changed.emit()

func set_music_volume(value: float):
	"""Set music volume (0.0 to 1.0)."""
	music_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)
	volume_changed.emit("Music", music_volume)
	settings_changed.emit()

func set_ambience_volume(value: float):
	"""Set ambience volume (0.0 to 1.0)."""
	ambience_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("Ambience", ambience_volume)
	volume_changed.emit("Ambience", ambience_volume)
	settings_changed.emit()

func _set_bus_volume(bus_name: String, volume: float):
	"""Internal: Set audio bus volume in dB."""
	var bus_index = AudioServer.get_bus_index(bus_name)
	
	if bus_index == -1:
		push_warning("[GameSettings] Audio bus '%s' not found" % bus_name)
		return
	
	# Convert linear volume (0-1) to dB (-80 to 0)
	if volume <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		var db = linear_to_db(volume)
		AudioServer.set_bus_volume_db(bus_index, db)

## =============================================================================
## GRAPHICS SETTINGS
## =============================================================================

func set_crt_effect(enabled: bool):
	"""Enable/disable CRT effect shader."""
	crt_effect_enabled = enabled
	graphics_changed.emit("crt_effect", enabled)
	settings_changed.emit()
	

func set_screen_shake(enabled: bool):
	"""Enable/disable screen shake effects."""
	screen_shake_enabled = enabled
	graphics_changed.emit("screen_shake", enabled)
	settings_changed.emit()

func set_skip_opening(enabled: bool):
	skip_opening = enabled
	graphics_changed.emit("skip_opening", enabled)
	settings_changed.emit()
	
func set_vsync(enabled: bool):
	"""Enable/disable V-Sync."""
	vsync_enabled = enabled
	
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	graphics_changed.emit("vsync", enabled)
	settings_changed.emit()

func set_fullscreen(enabled: bool):
	"""Toggle fullscreen mode."""
	fullscreen_enabled = enabled
	
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	graphics_changed.emit("fullscreen", enabled)
	settings_changed.emit()

## =============================================================================
## SAVE/LOAD
## =============================================================================

func save_settings():
	"""Save all settings to file."""
	var config = ConfigFile.new()
	
	# Audio section
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "ambience_volume", ambience_volume)
	
	# Graphics section
	config.set_value("graphics", "crt_effect", crt_effect_enabled)
	config.set_value("graphics", "screen_shake", screen_shake_enabled)
	config.set_value("graphics", "vsync", vsync_enabled)
	config.set_value("graphics", "fullscreen", fullscreen_enabled)
	config.set_value("graphics", "skip_opening", skip_opening)

	# Gameplay section (for future)
	config.set_value("gameplay", "combat_speed", combat_speed)
	config.set_value("gameplay", "show_damage_numbers", show_damage_numbers)
	config.set_value("gameplay", "show_combat_log", show_combat_log)
	
	var error = config.save(SETTINGS_FILE)
	
	if error == OK:
		print("[GameSettings] Settings saved to %s" % SETTINGS_FILE)
	else:
		push_error("[GameSettings] Failed to save settings: %d" % error)

func load_settings():
	"""Load settings from file."""
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_FILE)
	
	if error != OK:
		print("[GameSettings] No settings file found, using defaults")
		return
	
	# Audio settings
	master_volume = config.get_value("audio", "master_volume", 1.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 1.0)
	ambience_volume = config.get_value("audio", "ambience_volume", 1.0)
	
	# Graphics settings
	crt_effect_enabled = config.get_value("graphics", "crt_effect", false)
	screen_shake_enabled = config.get_value("graphics", "screen_shake", true)
	vsync_enabled = config.get_value("graphics", "vsync", true)
	fullscreen_enabled = config.get_value("graphics", "fullscreen", false)
	skip_opening = config.get_value("graphics", "skip_opening", false)


	# Gameplay settings
	combat_speed = config.get_value("gameplay", "combat_speed", 1)
	show_damage_numbers = config.get_value("gameplay", "show_damage_numbers", true)
	show_combat_log = config.get_value("gameplay", "show_combat_log", true)
	
	print("[GameSettings] Settings loaded from file")

func apply_all_settings():
	"""Apply all settings to the game."""
	# Apply audio
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("Ambience", ambience_volume)
	
	# Apply graphics
	set_vsync(vsync_enabled)
	set_fullscreen(fullscreen_enabled)
	set_crt_effect(crt_effect_enabled)
	

func reset_to_defaults():
	"""Reset all settings to default values."""
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 1.0
	ambience_volume = 1.0
	
	crt_effect_enabled = true
	screen_shake_enabled = true
	vsync_enabled = true
	fullscreen_enabled = false
	skip_opening = false

	combat_speed = 1
	show_damage_numbers = true
	show_combat_log = true
	
	apply_all_settings()
	save_settings()
	
	settings_changed.emit()

## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

func get_volume_percent(volume: float) -> int:
	"""Convert volume float (0-1) to percentage (0-100)."""
	return int(volume * 100)

func set_volume_from_percent(bus_type: String, percent: int):
	"""Set volume from percentage (0-100)."""
	var volume = percent / 100.0
	
	match bus_type:
		"Master":
			set_master_volume(volume)
		"SFX":
			set_sfx_volume(volume)
		"Music":
			set_music_volume(volume)
		"Ambience":
			set_ambience_volume(volume)
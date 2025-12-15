extends Control

## =============================================================================
## UI REFERENCES - UPDATE PATHS TO MATCH YOUR SCENE
## =============================================================================

# Audio sliders
@onready var slider_master: HSlider
@onready var slider_sfx: HSlider
@onready var slider_music: HSlider
@onready var slider_ambience: HSlider

# Volume labels (to show percentage)
@onready var lbl_master_volume: Label
@onready var lbl_sfx_volume: Label
@onready var lbl_music_volume: Label
@onready var lbl_ambience_volume: Label

# Graphics checkboxes
@onready var check_crt_effect: CheckBox
@onready var check_screen_shake: CheckBox
@onready var check_vsync: CheckBox
@onready var check_fullscreen: CheckBox
@onready var check_skip_opening: CheckBox

# Buttons
@onready var btn_apply: Button
@onready var btn_cancel: Button
@onready var btn_reset: Button

## =============================================================================
## INITIALIZATION
## =============================================================================

func _ready():
	# Get UI references (update these paths!)
	_get_ui_references()
	
	# Connect signals
	_connect_signals()
	
	# Load current settings
	load_current_settings()
	
	# Hide panel initially (main menu will show it)
	visible = false

func _get_ui_references():
	"""Get references to UI elements - UPDATE THESE PATHS!"""
	# Audio sliders - adjust paths to match your scene structure
	slider_master = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/MasterVolume/sliderMaster")
	slider_sfx = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/SFXVolue/sliderSFX")
	slider_music = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/MusicVolume/sliderMusic")
	slider_ambience = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/AmbientVolume/sliderAmbient")
	
	# Volume labels
	lbl_master_volume = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/MasterVolume/lblMaster")
	lbl_sfx_volume = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/SFXVolue/lblSFX")
	lbl_music_volume = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/MusicVolume/lblMusic")
	lbl_ambience_volume = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelAudio/MarginContainer/VBoxContainer/AmbientVolume/lblAmbient")
	
	# Graphics checkboxes
	check_crt_effect = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelGraphics/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/checkCRT")
	check_screen_shake = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelGraphics/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/checkShake")
	check_vsync = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelGraphics/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/checkVSYNC")
	check_fullscreen = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelGraphics/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/checkFullscreen")
	check_skip_opening = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/panelGraphics/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/checkSkipOpening")

	# Buttons
	btn_apply = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/Buttons/btnApply")
	btn_cancel = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/Buttons/btnCancel")
	btn_reset = get_node_or_null("Panel/pnlBlackBack/pnlBorder/VBoxContainer/Buttons/btnReset")

func _connect_signals():
	"""Connect all UI signals."""
	# Audio sliders
	if slider_master:
		slider_master.value_changed.connect(_on_master_volume_changed)
	if slider_sfx:
		slider_sfx.value_changed.connect(_on_sfx_volume_changed)
	if slider_music:
		slider_music.value_changed.connect(_on_music_volume_changed)
	if slider_ambience:
		slider_ambience.value_changed.connect(_on_ambience_volume_changed)
	
	# Graphics checkboxes
	if check_crt_effect:
		check_crt_effect.toggled.connect(_on_crt_effect_toggled)
	if check_screen_shake:
		check_screen_shake.toggled.connect(_on_screen_shake_toggled)
	if check_vsync:
		check_vsync.toggled.connect(_on_vsync_toggled)
	if check_fullscreen:
		check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	if check_skip_opening:
		check_skip_opening.toggled.connect(_on_skip_opening_toggled)

	# Buttons
	if btn_apply:
		btn_apply.pressed.connect(_on_apply_pressed)
	if btn_cancel:
		btn_cancel.pressed.connect(_on_cancel_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)

## =============================================================================
## LOAD/SAVE SETTINGS
## =============================================================================

func load_current_settings():
	"""Load current settings from GameSettings autoload."""
	# Audio sliders (0-100 range)
	if slider_master:
		slider_master.value = GameSettings.get_volume_percent(GameSettings.master_volume)
		_update_volume_label(lbl_master_volume, slider_master.value, "Master ")
	
	if slider_sfx:
		slider_sfx.value = GameSettings.get_volume_percent(GameSettings.sfx_volume)
		_update_volume_label(lbl_sfx_volume, slider_sfx.value, "SFX ")
	
	if slider_music:
		slider_music.value = GameSettings.get_volume_percent(GameSettings.music_volume)
		_update_volume_label(lbl_music_volume, slider_music.value, "Music ")
	
	if slider_ambience:
		slider_ambience.value = GameSettings.get_volume_percent(GameSettings.ambience_volume)
		_update_volume_label(lbl_ambience_volume, slider_ambience.value, "Ambience ")
	
	# Graphics checkboxes
	if check_crt_effect:
		check_crt_effect.button_pressed = GameSettings.crt_effect_enabled
	if check_screen_shake:
		check_screen_shake.button_pressed = GameSettings.screen_shake_enabled
	if check_vsync:
		check_vsync.button_pressed = GameSettings.vsync_enabled
	if check_fullscreen:
		check_fullscreen.button_pressed = GameSettings.fullscreen_enabled
	if check_skip_opening:
		check_skip_opening.button_pressed = GameSettings.skip_opening

func apply_settings():
	"""Apply all settings to GameSettings and save."""
	GameSettings.save_settings()
	print("[SettingsPanel] Settings applied and saved")

## =============================================================================
## AUDIO CALLBACKS
## =============================================================================

func _on_master_volume_changed(value: float):
	GameSettings.set_volume_from_percent("Master", int(value))
	_update_volume_label(lbl_master_volume, value)

func _on_sfx_volume_changed(value: float):
	GameSettings.set_volume_from_percent("SFX", int(value))
	_update_volume_label(lbl_sfx_volume, value)

func _on_music_volume_changed(value: float):
	GameSettings.set_volume_from_percent("Music", int(value))
	_update_volume_label(lbl_music_volume, value)

func _on_ambience_volume_changed(value: float):
	GameSettings.set_volume_from_percent("Ambience", int(value))
	_update_volume_label(lbl_ambience_volume, value)

func _update_volume_label(label: Label, value: float, _lbl:String = ""):
	"""Update volume label with percentage."""
	if label:
		label.text = _lbl + "%d%%" % int(value)

## =============================================================================
## GRAPHICS CALLBACKS
## =============================================================================

func _on_crt_effect_toggled(enabled: bool):
	GameSettings.set_crt_effect(enabled)

func _on_screen_shake_toggled(enabled: bool):
	GameSettings.set_screen_shake(enabled)

func _on_vsync_toggled(enabled: bool):
	GameSettings.set_vsync(enabled)

func _on_fullscreen_toggled(enabled: bool):
	GameSettings.set_fullscreen(enabled)

func _on_skip_opening_toggled(enabled: bool):
	GameSettings.set_skip_opening(enabled)

## =============================================================================
## BUTTON CALLBACKS
## =============================================================================

func _on_apply_pressed():
	"""Apply settings and close panel."""
	apply_settings()
	hide_panel()

func _on_cancel_pressed():
	"""Cancel changes and close panel."""
	# Reload original settings
	load_current_settings()
	GameSettings.apply_all_settings()
	hide_panel()

func _on_reset_pressed():
	"""Reset all settings to defaults."""
	GameSettings.reset_to_defaults()
	load_current_settings()

## =============================================================================
## SHOW/HIDE
## =============================================================================

func show_panel():
	"""Show settings panel."""
	load_current_settings()
	visible = true

func hide_panel():
	"""Hide settings panel."""
	visible = false

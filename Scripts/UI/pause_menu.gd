extends Control

signal new_run_requested()

@onready var btn_resume: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnResume
@onready var btn_newrun: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnNewRun
@onready var btn_settings: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnSettings
@onready var btn_quit: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnQuit

# Reference to settings panel (will be in main game scene)
var settings_panel: Control

func _ready():
	# Hide by default
	visible = false
	
	# Connect buttons
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_newrun.pressed.connect(_on_new_run_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	btn_resume.mouse_entered.connect(_on_button_hover_on)
	btn_newrun.mouse_entered.connect(_on_button_hover_on)
	btn_settings.mouse_entered.connect(_on_button_hover_on)
	btn_quit.mouse_entered.connect(_on_button_hover_on)

	btn_resume.mouse_exited.connect(_on_button_hover_exit)
	btn_newrun.mouse_exited.connect(_on_button_hover_exit)
	btn_settings.mouse_exited.connect(_on_button_hover_exit)
	btn_quit.mouse_exited.connect(_on_button_hover_exit)

	# Handle input
	set_process_input(true)

func _input(event):
	# Toggle pause with Escape
	if event.is_action_pressed("pause"):
		if visible:
			_on_resume_pressed()
		else:
			show_pause_menu()
		get_viewport().set_input_as_handled()

func show_pause_menu():
	"""Show pause menu and pause game."""
	visible = true
	get_tree().paused = true
	print("[PauseMenu] Game paused")

func hide_pause_menu():
	"""Hide pause menu and resume game."""
	visible = false
	get_tree().paused = false
	print("[PauseMenu] Game resumed")

func _on_resume_pressed():
	hide_pause_menu()
	if AudioManager:
		AudioManager.play_ui_sound("button_click")

func _on_settings_pressed():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	
	# Find settings panel
	if not settings_panel:
		settings_panel = get_tree().root.find_child("SettingsPanel", true, false)
	
	if settings_panel:
		#hide_pause_menu()  # Hide pause menu
		settings_panel.show()  # Show settings
		print("[PauseMenu] Opening settings")
	else:
		push_warning("[PauseMenu] Settings panel not found!")

func _on_quit_pressed():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	
	# Unpause before changing scene
	get_tree().paused = false
	
	# Return to main menu
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_new_run_pressed():
	new_run_requested.emit()

func _on_button_hover_on():
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("button_hover")

func _on_button_hover_exit():
	CursorManager.reset_cursor()

extends Control

signal new_run_requested()
signal menu_closed()

@onready var btn_resume: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnResume
@onready var btn_newrun: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnNewRun
@onready var btn_settings: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnSettings
@onready var btn_quit: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnQuit
@onready var btn_compendium: Button = $Panel/panelBlackBack/panelBorder/VBoxContainer/btnCompendium

@onready var confirm_popup: Control = $ConfirmBox


# Reference to settings panel (will be in main game scene)
var settings_panel: Control
var compendium_panel: Control

var _pending_action: Callable

func _ready():
	# Hide by default
	visible = false
	
	# Connect buttons
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_newrun.pressed.connect(_on_new_run_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_compendium.pressed.connect(_on_compendium_pressed)

	btn_resume.mouse_entered.connect(_on_button_hover_on)
	btn_newrun.mouse_entered.connect(_on_button_hover_on)
	btn_settings.mouse_entered.connect(_on_button_hover_on)
	btn_quit.mouse_entered.connect(_on_button_hover_on)
	btn_compendium.mouse_entered.connect(_on_button_hover_on)

	btn_resume.mouse_exited.connect(_on_button_hover_exit)
	btn_newrun.mouse_exited.connect(_on_button_hover_exit)
	btn_settings.mouse_exited.connect(_on_button_hover_exit)
	btn_quit.mouse_exited.connect(_on_button_hover_exit)
	btn_compendium.mouse_exited.connect(_on_button_hover_exit)

	confirm_popup.confirmed.connect(_on_confirm_proceed)
	confirm_popup.cancelled.connect(_on_confirm_cancelled) 

	# Handle input
	set_process_input(true)

func _input(event):
	# Toggle pause with Escape
	if event.is_action_pressed("pause"):
		if visible:
			if not _close_open_submenu():
				_on_resume_pressed()
		else:
			show_pause_menu()
		get_viewport().set_input_as_handled()

func show_pause_menu():
	"""Show pause menu and pause game."""
	visible = true
	get_tree().paused = true

func hide_pause_menu():
	"""Hide pause menu and resume game."""
	visible = false
	menu_closed.emit()
	get_tree().paused = false

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
	else:
		push_warning("[PauseMenu] Settings panel not found!")

func _on_compendium_pressed():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	
	# Find settings panel
	if not compendium_panel:
		compendium_panel = get_tree().root.find_child("Compendium", true, false)
	
	if compendium_panel:
		compendium_panel.show_panel(true)
	else:
		push_warning("[PauseMenu] Compendium not found!")

func _on_quit_pressed():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	
	_show_confirm("Are you sure?\nYour current run will be lost.", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	)

func _on_new_run_pressed():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	_show_confirm("Are you sure?\nYour current run will be lost.", func():
		hide_pause_menu()
		new_run_requested.emit()
	)

func _on_button_hover_on():
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("button_hover")

func _on_button_hover_exit():
	CursorManager.reset_cursor()

func _close_open_submenu() -> bool:
	if settings_panel and settings_panel.visible:
		settings_panel._on_cancel_pressed()
		if AudioManager:
			AudioManager.play_ui_sound("button_click")
		return true
	
	if compendium_panel and compendium_panel.visible:
		compendium_panel.hide_panel()
		if AudioManager:
			AudioManager.play_ui_sound("button_click")
		return true
	
	return false

func _show_confirm(message: String, action: Callable) -> void:
	_pending_action = action
	confirm_popup.show_confirm(message)

func _on_confirm_proceed() -> void:
	if _pending_action.is_valid():
		_pending_action.call()

func _on_confirm_cancelled() -> void:
	pass  # popup already hides itself; add anything extra here if needed
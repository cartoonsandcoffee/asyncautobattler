extends Control

signal username_confirmed(username: String)

@onready var lbl: Label = $Label
@onready var lbl_ship: Label = $controlMainMenu/lblShip

@onready var control_loading: Control = $controlLoading
@onready var control_menu: Control = $controlMainMenu
@onready var anim_planet: AnimationPlayer = $animPlanet

@onready var lbl_menu: Label = $controlMainMenu/smallButtonHolder/MarginContainer/VBoxContainer/HBoxContainer/lblMenu
@onready var btn_quit: Button = $controlMainMenu/smallButtonHolder/MarginContainer/VBoxContainer/HBoxContainer/btnQuit
@onready var btn_info: Button = $controlMainMenu/smallButtonHolder/MarginContainer/VBoxContainer/HBoxContainer/btnInfo
@onready var btn_settings: Button = $controlMainMenu/smallButtonHolder/MarginContainer/VBoxContainer/HBoxContainer/btnSettings

@onready var anim_play: AnimationPlayer = $animPlay
@onready var anim_hall: AnimationPlayer = $animHall
@onready var anim_play_idle: AnimationPlayer = $animPlayIdle
@onready var anim_hall_idle: AnimationPlayer = $animHallIdle
@onready var anim_fader: AnimationPlayer = $animFade

@onready var btn_play: Button = $controlMainMenu/controlPlay/picPlay/btnPlay
@onready var btn_hall: Button = $controlMainMenu/controlHall/picHall/btnHall

@onready var txt_error: Label = $panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/txtError
@onready var txt_name: TextEdit = $panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/txtName
@onready var btn_name: Button = $panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/btnName
@onready var panel_name: Panel = $panelName
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var info_panel: Control = $GameInfo
@onready var champion_panel: Control = $HallofChampions
@onready var settings_panel: Control = $SettingsPanel

var good_name: bool = false
var uuid: String = ""

func _ready():
	# Defer actual game loading to next frame so UI renders
	anim_planet.play("planet_idle")
	call_deferred("_initialize_systems")

func _process(delta: float) -> void:
	if panel_name.visible:
		if txt_name.text.length() < 4:
			txt_error.text = "Your name must be at least 4 characters."
			good_name = false
		elif txt_name.text.length() > 30:
			txt_error.text = "Your name cannot exceed 30 characters."
			good_name = false
		else:
			good_name = true
			txt_error.text = ""
			
		btn_name.disabled = !good_name

func _initialize_systems():
	await get_tree().process_frame

	# Load items
	ItemsManager.initialize()
	await get_tree().process_frame
	lbl.text += "."
	
	RoomRegistry.initialize()
	await get_tree().process_frame
	lbl.text += "."

	SupabaseManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	AudioManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	DungeonManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	CombatManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	SetBonusManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	CursorManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	await _load_player_profile()
	lbl.text += "."

	SkinManager.initialize()
	await get_tree().process_frame
	lbl.text += "."

	SupabaseManager.initialize()
	AudioManager.initialize()
	CursorManager.initialize()
	GameSettings.initialize()
	await get_tree().process_frame
	lbl.text += "."
	
	_load_game()

func _load_game():
	# Let one frame pass for UI to appear
	await get_tree().process_frame
	
	# Now load your actual main scene
	AudioManager.play_main_theme()
	await anim_planet.animation_finished
	control_menu.visible = true
	load_menu_screen()
	
func load_menu_screen():
	btn_quit.pressed.connect(_on_btn_quit_pressed) 
	btn_info.pressed.connect(_on_btn_info_pressed) 
	btn_settings.pressed.connect(_on_btn_settings_pressed) 
	btn_play.pressed.connect(_on_btn_play_pressed) 
	btn_hall.pressed.connect(_on_btn_hall_pressed)

	btn_quit.mouse_entered.connect(generic_hover.bind("Quit")) 
	btn_info.mouse_entered.connect(generic_hover.bind("Game Info")) 
	btn_settings.mouse_entered.connect(generic_hover.bind("Settings")) 
	btn_play.mouse_entered.connect(btn_play_hover)
	btn_hall.mouse_entered.connect(btn_hall_hover)

	btn_quit.mouse_exited.connect(generic_unhover) 
	btn_info.mouse_exited.connect(generic_unhover) 
	btn_settings.mouse_exited.connect(generic_unhover) 
	btn_play.mouse_exited.connect(btn_play_unhover)
	btn_hall.mouse_exited.connect(btn_hall_unhover)

	anim_play.play("show_play")
	await anim_play.animation_finished
	anim_play_idle.play("play_idle")
	anim_hall.play("show_hall")
	await anim_hall.animation_finished
	anim_hall_idle.play("hall_idle")

	btn_play.disabled = false
	btn_hall.disabled = false

func _on_btn_name_pressed() -> void:
	print("BTN PRESSED - good_name: ", good_name, " text: ", txt_name.text)
	AudioManager.play_ui_sound("button_click")
	# Emit the signal to continue profile loading
	var username = txt_name.text.strip_edges()
	username_confirmed.emit(username)

func _on_txt_name_text_changed() -> void:
	var current_text = txt_name.text
	var regex = RegEx.new()
	regex.compile("[a-zA-Z0-9_]+")  # Allows alphanumeric characters and spaces
	var filtered_text = ""
	for chr in current_text:
		if regex.search(chr):  # Check if each character matches the regex
			filtered_text += chr
	if filtered_text != current_text:
		var caret_column = txt_name.get_caret_column()
		var caret_line = txt_name.get_caret_line()
		txt_name.text = filtered_text
		txt_name.set_caret_column(min(caret_column, txt_name.text.length())) # Adjust caret position
		txt_name.set_caret_line(caret_line)


func _load_player_profile():
	# Show loading message
	lbl.text = "Connecting to server..."

	# Load UUID
	uuid = Player.load_or_generate_uuid()

	# Fetch from Supabase
	var profile = await SupabaseManager.get_player_profile(uuid)

	if profile != null and profile is Dictionary and not profile.is_empty():
		# Existing player
		Player.load_profile_from_supabase(profile)
		lbl.text = "Welcome back, %s!" % Player.player_name
		lbl_ship.text = Player.player_name
	else:
		# New player - show name input and WAIT for completion
		enter_new_player()
		
		# Wait for user to submit username
		var username = await username_confirmed
		
		# Validate username availability
		lbl.text = "Checking username..."
		var is_available = await SupabaseManager.is_username_available(username)
		
		# Keep asking until we get a valid username
		while not is_available:
			txt_error.text = "Username already taken! Try another."
			username = await username_confirmed
			lbl.text = "Checking username..."
			is_available = await SupabaseManager.is_username_available(username)
		
		# Create profile
		lbl.text = "Creating profile..."
		var result = await SupabaseManager.create_player_profile(uuid, username)
		
		if result.status == 201:
			Player.load_profile_from_supabase(result.data[0])
			lbl.text = "Welcome, %s!" % username
			animation_player.play("namebox_flyout")  # Hide the name panel
			await get_tree().create_timer(1.0).timeout
		else:
			push_error("Failed to create profile: %d" % result.status)
			txt_error.text = "Server error! Please try again."
			# Could loop back to try again, or use default name
		

func generic_hover(_lbl: String):
	lbl_menu.text = _lbl
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("button_hover")

func generic_unhover():
	lbl_menu.text = ""
	CursorManager.reset_cursor()

func _on_btn_settings_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	if settings_panel:
		settings_panel.show_panel()
	else:
		push_warning("[MainMenu] Settings panel not found!")

func _on_btn_info_pressed() -> void:
	info_panel.visible = true

func _on_btn_quit_pressed() -> void:
	get_tree().quit()

func _on_btn_hall_pressed() -> void:
	champion_panel.visible = true

func _on_btn_play_pressed() -> void:
	anim_fader.play("fade_out")
	await anim_fader.animation_finished
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func enter_new_player():
	animation_player.play("namebox_flyin")

func btn_play_hover():
	anim_play.play("show_hover")
	AudioManager.play_ui_sound("vine_hover")
	CursorManager.set_interact_cursor()

func btn_play_unhover():
	anim_play.play("hide_hover")
	CursorManager.reset_cursor()

func btn_hall_hover():
	anim_hall.play("show_hover")
	AudioManager.play_ui_sound("vine_hover")
	CursorManager.set_interact_cursor()

func btn_hall_unhover():
	anim_hall.play("hide_hover")
	CursorManager.reset_cursor()

func play_sound_drop():
	AudioManager.play_ui_sound("vine_drop")

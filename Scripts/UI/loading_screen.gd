extends Control

signal username_confirmed(username: String)

@onready var lbl: Label = $Label

@onready var txt_error: Label = $panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/txtError
@onready var txt_name: TextEdit = $panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/txtName
@onready var btn_name: Button = $panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/btnName
@onready var panel_name: Panel = $panelName
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var good_name: bool = false
var uuid: String = ""

func _ready():
	# Defer actual game loading to next frame so UI renders
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
	_load_game()

func _load_game():
	# Let one frame pass for UI to appear
	await get_tree().process_frame
	
	# Now load your actual main scene
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_btn_name_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
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

	if not profile.is_empty():
		# Existing player
		Player.load_profile_from_supabase(profile)
		lbl.text = "Welcome back, %s!" % Player.player_name
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
		

func enter_new_player():
	animation_player.play("namebox_flyin")
extends Control

@onready var animation_player: AnimationPlayer = $Panel/AnimationPlayer
@onready var anim_back: AnimationPlayer = $animBack
@onready var txt_error: Label = $Panel/panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/txtError
@onready var txt_name: TextEdit = $Panel/panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/txtName
@onready var btn_name: Button = $Panel/panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/btnName
@onready var panel_name: Panel = $Panel/panelName
@onready var settings_panel = $Panel/SettingsPanel
@onready var compendium_panel = $Panel/Compendium
@onready var info_panel = $Panel/GameInfo

const GAME_SCENE = preload("res://Scenes/main_game.tscn")
var good_name: bool = false

func _ready() -> void:
	if not SaveManager.save_exists():
		#btn_continue.disabled = true
		pass
	_setup_button_audio()
	
	AudioManager.play_general_music()
	anim_back.play("back_flicker")


func _on_btn_quit_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	get_tree().quit()


func _on_btn_new_game_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	animation_player.play("namebox_flyin")
	#get_tree().change_scene_to_packed(GAME_SCENE)

func _on_btn_continue_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	pass # Replace with function body.


func _on_btn_name_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	Player.new_run(txt_name.text)
	get_tree().change_scene_to_packed(GAME_SCENE)

func _process(delta: float) -> void:
	if panel_name.visible:
		if txt_name.text.length() < 5:
			txt_error.text = "Your name must be at least 5 characters."
			good_name = false
		elif txt_name.text.length() > 30:
			txt_error.text = "Your name cannot exceed 30 characters."
			good_name = false
		else:
			good_name = true
			txt_error.text = ""
			
	btn_name.disabled = !good_name

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


func _on_btn_settings_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	if settings_panel:
		settings_panel.show_panel()
	else:
		push_warning("[MainMenu] Settings panel not found!")

func _setup_button_audio():
	# Automatically add audio to all buttons in scene tree.
	for button in _get_all_buttons(self):
		# Connect hover
		if not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover.bind(button))

func _get_all_buttons(node: Node) -> Array[Button]:
	# Recursively find all buttons in tree.
	var buttons: Array[Button] = []
	
	if node is Button:
		buttons.append(node)
	
	for child in node.get_children():
		buttons.append_array(_get_all_buttons(child))
	
	return buttons	

func _on_button_hover(button: Button):
	if not button.disabled:
		AudioManager.play_ui_sound("woosh")

func play_popup_open_sfx():
	AudioManager.play_synced_sound("popup_open")

func play_popup_close_sfx():
	AudioManager.play_synced_sound("popup_close")


func _on_btn_compendium_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	if compendium_panel:
		compendium_panel.show_panel()
	else:
		push_warning("[MainMenu] Settings panel not found!")


func _on_btn_info_pressed() -> void:
	info_panel.visible = true

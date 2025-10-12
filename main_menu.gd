extends Control

@onready var btn_continue: Button = $Panel/panelMenu/NinePatchRect/PanelContainer/MarginContainer/VBoxContainer/btnContinue
@onready var animation_player: AnimationPlayer = $Panel/AnimationPlayer
@onready var txt_error: Label = $Panel/panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/txtError
@onready var txt_name: TextEdit = $Panel/panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/txtName
@onready var btn_name: Button = $Panel/panelName/panelBox/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/btnName
@onready var panel_name: Panel = $Panel/panelName

const GAME_SCENE = preload("res://Scenes/main_game.tscn")
var good_name: bool = false

func _ready() -> void:
	if not SaveManager.save_exists():
		btn_continue.disabled = true

func _on_btn_quit_pressed() -> void:
	get_tree().quit()


func _on_btn_new_game_pressed() -> void:
	animation_player.play("namebox_flyin")
	#get_tree().change_scene_to_packed(GAME_SCENE)

func _on_btn_continue_pressed() -> void:
	pass # Replace with function body.


func _on_btn_name_pressed() -> void:
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

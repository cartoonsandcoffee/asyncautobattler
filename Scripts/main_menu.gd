extends Control

@onready var anim_back: AnimationPlayer = $animBack
@onready var settings_panel = $Panel/SettingsPanel
@onready var compendium_panel = $Panel/Compendium
@onready var info_panel = $Panel/GameInfo
@onready var hall_of_fame = $Panel/HallofChampions

@onready var lbl_ears: Label = $Panel/panelMenu/NinePatchRect/PanelContainer/MarginContainer/VBoxContainer/playerInfoPanel/earPanel/MarginContainer/HBoxContainer/lblEars
@onready var txt_playerinfo: RichTextLabel = $Panel/panelMenu/NinePatchRect/PanelContainer/MarginContainer/VBoxContainer/playerInfoPanel/txtPlayerInfo

const GAME_SCENE = preload("res://Scenes/main_game.tscn")
var good_name: bool = false

func _ready() -> void:
	confirm_systems_initialized()

	if not SaveManager.save_exists():
		#btn_continue.disabled = true
		pass
	_setup_button_audio()
	
	AudioManager.play_general_music()
	anim_back.play("back_flicker")

	player_loaded()

func confirm_systems_initialized():
	if not SupabaseManager._initialized:
		SupabaseManager.initialize()
	if not AudioManager._initialized:
		AudioManager.initialize()
	if not CursorManager._initialized:
		CursorManager.initialize()
	if not GameSettings._initialized:
		GameSettings.initialize()

func player_loaded() -> void:
	lbl_ears.text = str(Player.ears_balance)
	txt_playerinfo.text = "[b]" + Player.player_name + "[/b]\n"
	txt_playerinfo.text += "   - Champion Kills: " + str(Player.champions_killed) + "\n"
	txt_playerinfo.text += "   - Active Champions: " + str(Player.active_champions_count) + "\n"	

func _on_btn_quit_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	get_tree().quit()


func _on_btn_new_game_pressed() -> void:
	AudioManager.play_ui_sound("button_hover")
	Player.new_run(Player.player_name)
	get_tree().change_scene_to_packed(GAME_SCENE)


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


func _on_btn_heroes_pressed() -> void:
	hall_of_fame.visible = true

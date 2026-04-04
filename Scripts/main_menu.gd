extends Control

@onready var anim_back: AnimationPlayer = $animBack
@onready var settings_panel = $Panel/SettingsPanel
@onready var compendium_panel = $Panel/Compendium
@onready var info_panel = $Panel/GameInfo
@onready var hall_of_fame = $Panel/HallofChampions
@onready var skin_selector: Control = $Panel/skinPanel

@onready var lbl_ears: Label = $Panel/CharacterSelectMenu/backPanel/VBoxContainer/playerInfoPanel/HBoxContainer/lblEars
@onready var lbl_name: Label = $Panel/CharacterSelectMenu/backPanel/VBoxContainer/panelName/MarginContainer/lblName
@onready var lbl_champkills: Label = $Panel/CharacterSelectMenu/backPanel/VBoxContainer/playerInfoPanel/lblChampKills
@onready var lbl_activechamps: Label = $Panel/CharacterSelectMenu/backPanel/VBoxContainer/playerInfoPanel/lblActiveChamps

@onready var pic_skin: TextureRect = $Panel/CharacterSelectMenu/backPanel/picChar

@onready var btn_new_run: Button = $Panel/panelBottom/HBoxContainer/panMid/MarginContainer/btnNewGame
@onready var btn_compendium: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/btnCompendium
@onready var btn_hall: Button = $Panel/CharacterSelectMenu/backPanel/VBoxContainer/playerInfoPanel/btnHeroes
@onready var btn_info: Button = $Panel/panelBottom/HBoxContainer/panLeft/VBoxContainer/iconButtons/btnInfo
@onready var btn_settings: Button = $Panel/panelBottom/HBoxContainer/panLeft/VBoxContainer/iconButtons/btnSettings
@onready var btn_quit: Button = $Panel/panelBottom/HBoxContainer/panLeft/VBoxContainer/iconButtons/btnQuit

@onready var bun_revenge: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/toggleBundle/bunRevenge
@onready var bun_honor: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/toggleBundle/bunHonor
@onready var bun_greed: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/toggleBundle/bunGreed
@onready var bun_duty: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/toggleBundle/bunDuty
@onready var bun_shame: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/toggleBundle/bunShame
@onready var bun_chaos: Button = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/toggleBundle/bunChaos
@onready var lbl_bundles: RichTextLabel = $Panel/loadoutPanel/PanelContainer/MarginContainer/PanelContainer/VBoxContainer/lblBundleInfo
@onready var crt_shader: CanvasLayer = $CRT_Shader

@onready var version_label: Label = $Panel/panelBottom/HBoxContainer/panRight/VBoxContainer/versionLabel

const MAX_BUNDLES: int = 3
const GAME_SCENE = preload("res://Scenes/main_game.tscn")
var good_name: bool = false

func _ready() -> void:
	confirm_systems_initialized()
	skin_selector.refresh_skin.connect(_refresh_skin)

	if not SaveManager.save_exists():
		pass

	AudioManager.stop_music()
	var dungeon_ambient = load("res://Assets/Audio/Ambient/Ambience 01.mp3")
	AudioManager.play_ambient(dungeon_ambient, true)

	if GameSettings.item_bundles.size() > 0:
		Player.item_bundles.assign(GameSettings.item_bundles.map(func(b): return b as Enums.ItemBundles))
	_refresh_bundle_buttons()

	player_loaded()
	_refresh_skin()
	bind_button_hovers()
	_refresh_bundle_buttons()
	check_crt_filter()

	version_label.text = "     Game Build: v" + Player.GAME_VERSION

func bind_button_hovers():
	btn_compendium.mouse_entered.connect(mouse_entered_info.bind("Compendium"))
	btn_hall.mouse_entered.connect(mouse_entered_info.bind("Hall of Champions"))
	btn_info.mouse_entered.connect(mouse_entered_info.bind("Game Information"))
	btn_settings.mouse_entered.connect(mouse_entered_info.bind("Settings"))
	btn_quit.mouse_entered.connect(mouse_entered_info.bind("Quit"))

	btn_new_run.mouse_exited.connect(mouse_exited_info)
	btn_compendium.mouse_exited.connect(mouse_exited_info)
	btn_hall.mouse_exited.connect(mouse_exited_info)
	btn_info.mouse_exited.connect(mouse_exited_info)
	btn_settings.mouse_exited.connect(mouse_exited_info)
	btn_quit.mouse_exited.connect(mouse_exited_info)

	bun_revenge.mouse_entered.connect(on_bundle_hover.bind(Enums.ItemBundles.REVENGE))
	bun_greed.mouse_entered.connect(on_bundle_hover.bind(Enums.ItemBundles.GREED))
	bun_honor.mouse_entered.connect(on_bundle_hover.bind(Enums.ItemBundles.HONOR))
	bun_duty.mouse_entered.connect(on_bundle_hover.bind(Enums.ItemBundles.DUTY))
	bun_shame.mouse_entered.connect(on_bundle_hover.bind(Enums.ItemBundles.SHAME))
	bun_chaos.mouse_entered.connect(on_bundle_hover.bind(Enums.ItemBundles.CHAOS))

	bun_revenge.mouse_exited.connect(on_bundle_exit)
	bun_greed.mouse_exited.connect(on_bundle_exit)
	bun_honor.mouse_exited.connect(on_bundle_exit)
	bun_duty.mouse_exited.connect(on_bundle_exit)
	bun_shame.mouse_exited.connect(on_bundle_exit)
	bun_chaos.mouse_exited.connect(on_bundle_exit)

	settings_panel.settings_menu_closed.connect(check_crt_filter)
	
func mouse_entered_info(_lbl: String):
	lbl_name.text = _lbl
	AudioManager.play_ui_sound("woosh")

func mouse_exited_info():
	lbl_name.text = Player.player_name 

func confirm_systems_initialized():
	if not SupabaseManager._initialized:
		SupabaseManager.initialize()
	if not AudioManager._initialized:
		AudioManager.initialize()
	if not CursorManager._initialized:
		CursorManager.initialize()
	if not GameSettings._initialized:
		GameSettings.initialize()

func _refresh_skin():
	var _skin: SkinData = SkinManager.get_selected_skin()
	if _skin:
		pic_skin.texture = _skin.sprite

func player_loaded() -> void:
	lbl_ears.text = str(Player.ears_balance)
	lbl_name.text = Player.player_name 
	lbl_champkills.text = "Champion Kills:  " + str(Player.champions_killed) 
	lbl_activechamps.text = "Active Champions:  " + str(Player.active_champions_count) 

func _on_btn_quit_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	get_tree().quit()


func _on_btn_new_game_pressed() -> void:
	AudioManager.play_ui_sound("new_run_click")
	GameSettings.item_bundles.assign(Player.item_bundles.map(func(b): return int(b)))
	GameSettings.save_settings()
	Player.new_run(Player.player_name)
	get_tree().change_scene_to_packed(GAME_SCENE)


func _on_btn_settings_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
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

func check_crt_filter():
	# CRT SHADER SETTING
	if GameSettings.crt_effect_enabled:
		crt_shader.visible = true
	else:
		crt_shader.visible = false

func _on_button_hover(button: Button):
	if not button.disabled:
		AudioManager.play_ui_sound("woosh")

func play_popup_open_sfx():
	AudioManager.play_synced_sound("popup_open")

func play_popup_close_sfx():
	AudioManager.play_synced_sound("popup_close")


func _on_btn_compendium_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	if compendium_panel:
		compendium_panel.show_panel()
	else:
		push_warning("[MainMenu] Settings panel not found!")


func _on_btn_info_pressed() -> void:
	info_panel.visible = true


func _on_btn_heroes_pressed() -> void:
	hall_of_fame.visible = true

func handle_bundle_selection(_bundle: Enums.ItemBundles):
	if _bundle in Player.item_bundles:
		Player.item_bundles.erase(_bundle)
	elif Player.item_bundles.size() < MAX_BUNDLES:
		Player.item_bundles.append(_bundle)
	_refresh_bundle_buttons()

func check_bundle_requirement():
	if Player.item_bundles.size() < MAX_BUNDLES:
		btn_new_run.disabled = true
		btn_new_run.text = "Select 3 'Motives' to Begin"
	else:
		btn_new_run.disabled = false
		btn_new_run.text = "New Run"

func _refresh_bundle_buttons():
	# Set button pressed state to match Player.item_bundles
	bun_greed.button_pressed = (Enums.ItemBundles.GREED) in Player.item_bundles
	bun_honor.button_pressed = (Enums.ItemBundles.HONOR) in Player.item_bundles
	bun_revenge.button_pressed = (Enums.ItemBundles.REVENGE) in Player.item_bundles
	bun_shame.button_pressed = (Enums.ItemBundles.SHAME) in Player.item_bundles
	bun_duty.button_pressed = (Enums.ItemBundles.DUTY) in Player.item_bundles
	bun_chaos.button_pressed = (Enums.ItemBundles.CHAOS) in Player.item_bundles
	check_bundle_requirement()

func _on_bun_greed_pressed() -> void:
	handle_bundle_selection(Enums.ItemBundles.GREED)

func _on_bun_honor_pressed() -> void:
	handle_bundle_selection(Enums.ItemBundles.HONOR)

func _on_bun_revenge_pressed() -> void:
	handle_bundle_selection(Enums.ItemBundles.REVENGE)

func _on_bun_duty_pressed() -> void:
	handle_bundle_selection(Enums.ItemBundles.DUTY)

func _on_bun_shame_pressed() -> void:
	handle_bundle_selection(Enums.ItemBundles.SHAME)

func _on_bun_chaos_pressed() -> void:
	handle_bundle_selection(Enums.ItemBundles.CHAOS)

func on_bundle_hover(_bundle: Enums.ItemBundles):
	AudioManager.play_ui_sound("button_hover")
	match _bundle:
		Enums.ItemBundles.REVENGE:
			lbl_bundles.text = "Equal parts Dark, Clearmetal, and Thorn items."
		Enums.ItemBundles.HONOR:
			lbl_bundles.text = "Vampiric, Blind, and some Agility centric items."
		Enums.ItemBundles.GREED:
			lbl_bundles.text = "Rings and Jewely, additional Blind, Dark and Thorn items."
		Enums.ItemBundles.DUTY:
			lbl_bundles.text = "Heavy focus on Regeneration, Burn and poison items."
		Enums.ItemBundles.SHAME:
			lbl_bundles.text = "Acid and Blessing and items with status removal."
		Enums.ItemBundles.CHAOS:
			lbl_bundles.text = "Heavy Acid and Stun focus, with a dash of Clearmetal"

func on_bundle_exit():
	lbl_bundles.text = "Select 3 bundles.  Each includes approximately 30 unique items."

func _on_btn_new_game_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_new_game_mouse_entered() -> void:
	lbl_name.text = "New Game"
	AudioManager.play_ui_sound("new_run_hover")


func _on_btn_random_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	var all_bundles: Array = Enums.ItemBundles.values().filter(
		func(b): return b != Enums.ItemBundles.GENERAL and b != Enums.ItemBundles.ALL and b != Enums.ItemBundles.NONE
	)
	all_bundles.shuffle()
	Player.item_bundles.clear()
	Player.item_bundles.assign(all_bundles.slice(0, MAX_BUNDLES))
	_refresh_bundle_buttons()

extends Control

@onready var anim_back: AnimationPlayer = $animBack
@onready var settings_panel = $Panel/SettingsPanel
@onready var compendium_panel = $Panel/Compendium
@onready var info_panel = $Panel/GameInfo
@onready var hall_of_fame = $Panel/HallofChampions
@onready var path_unlock_screen = $Panel/PathUnlockScreen

@onready var skin_menu: HBoxContainer = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/skinPanel/skinsBox
@onready var skin_selector: Control = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/skinPanel
@onready var skin_card: SkinCard = $Panel/skinPanel/SkinCard

@onready var lbl_ears: Label = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/skinPanel/skinsBox/HBoxContainer/lblEars
@onready var lbl_name: Label = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/lblName

@onready var btn_new_run: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/mainButtons/btnNewGame
@onready var btn_continue: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/mainButtons/btnContinue
@onready var btn_compendium: Button = $Panel/CompendiumHolder/picDesk/btnCompendium
@onready var btn_hall: Button = $Panel/HallHolder/picDesk/btnHall

@onready var btn_info: Button = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/btnInfo
@onready var btn_settings: Button = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/btnSettings
@onready var btn_quit: Button = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/btnQuit

@onready var custom_bundle_box: HBoxContainer = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle
@onready var bun_revenge: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/toggleBundle/bunRevenge
@onready var bun_honor: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/toggleBundle/bunHonor
@onready var bun_greed: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/toggleBundle/bunGreed
@onready var bun_duty: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/toggleBundle/bunDuty
@onready var bun_shame: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/toggleBundle/bunShame
@onready var bun_chaos: Button = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/toggleBundle/bunChaos
@onready var lbl_bundles: RichTextLabel = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/customBundle/motivations/lblBundleInfo

@onready var path_btn_0: PathSelectButton = $Panel/mainScreen/VBoxContainer/midPanel/MarginContainer/VBoxContainer/panelSkin/charBox/pathSelectRow/pathUntamed
@onready var path_btn_1: PathSelectButton = $Panel/mainScreen/VBoxContainer/midPanel/MarginContainer/VBoxContainer/panelSkin/charBox/pathSelectRow/pathGilded
@onready var path_btn_2: PathSelectButton = $Panel/mainScreen/VBoxContainer/midPanel/MarginContainer/VBoxContainer/panelSkin/charBox/pathSelectRow/pathCorrupted
@onready var path_btn_3: PathSelectButton = $Panel/mainScreen/VBoxContainer/midPanel/MarginContainer/VBoxContainer/panelSkin/charBox/pathSelectRow/pathCustom

@onready var path_info_box: HBoxContainer = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo
@onready var lbl_path:Label = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/lblPath
@onready var lbl_path_desc: RichTextLabel = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/descPath

@onready var bundle_disp_revenge: Control = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/showMotivesBox/showRevenge
@onready var bundle_disp_honor:   Control = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/showMotivesBox/showHonor
@onready var bundle_disp_greed:   Control = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/showMotivesBox/showGreed
@onready var bundle_disp_duty:    Control = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/showMotivesBox/showDuty
@onready var bundle_disp_shame:   Control = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/showMotivesBox/showShame
@onready var bundle_disp_chaos:   Control = $Panel/mainScreen/VBoxContainer/topPanel/MarginContainer/LoadoutButtons/bundleInfo/VBoxContainer/HBoxContainer/showMotivesBox/showChaos

@onready var anim_compendium: AnimationPlayer = $animCompendium
@onready var anim_hall: AnimationPlayer = $animHall

@onready var crt_shader: CanvasLayer = $CRT_Shader

@onready var version_label: Label = $Panel/mainScreen/VBoxContainer/bottomPanel/MarginContainer/systemButtons/versionLabel

const GAME_SCENE = preload("res://Scenes/main_game.tscn")

const PATHS = [
	{
		"name": "The Untamed Path",
		"desc": "Raw and relentless. High [color=#ff4444]damage[/color] though slow to attack, survivable with immense pools of [color=#44ff44]hitpoints[/color]. Calls upon [color=996633]thorns[/color] for extra defensive damage, and [color=99dfffff]blessing[/color] for additional healing.",
		"bundles": [Enums.ItemBundles.REVENGE, Enums.ItemBundles.CHAOS, Enums.ItemBundles.SHAME],
		"skin_id": 0
	},
	{
		"name": "The Gilded Path",
		"desc": "Swift and persistent. Hits fast and [color=d0db9eff]strikes[/color] many times, chaining strikes for deadly combos. They love fancy rings and shiny armor. Calls upon [color=ff4444]vampiric[/color] healing and [color=00ff88]regeneration[/color] for extra sustain.",
		"bundles": [Enums.ItemBundles.GREED, Enums.ItemBundles.HONOR, Enums.ItemBundles.DUTY],
		"skin_id": 1
	},
	{
		"name": "The Corrupted Path",
		"desc": "A combination of the others, uses primal magic to [color=ff6600]burn[/color] or [color=a749a7]poison[/color] without striking while chaining status effects that accumulate slow but kill fast. [color=bdb280ff]Stuns[/color] the enemy for additional control.",
		"bundles": [Enums.ItemBundles.DUTY, Enums.ItemBundles.CHAOS, Enums.ItemBundles.SHAME],
		"skin_id": 2
	},
	{
		"name": "Custom Path",
		"desc": "Choose your own 3 motives and forge your own fate.",
		"bundles": [],
		"skin_id": 3
	}
]

var path_buttons: Array[PathSelectButton] = []
var _unlock_queue: Array[int] = []
var _bundle_disp_map: Dictionary  # populated in _ready()

func _ready() -> void:
	confirm_systems_initialized()
	skin_selector.assign_skin_card(skin_card)
	skin_selector.assign_label(lbl_name)
	skin_selector.refresh_skin.connect(_refresh_skin)

	btn_continue.visible = SaveManager.has_saved_run()

	AudioManager.stop_music()
	var dungeon_ambient = load("res://Assets/Audio/Ambient/Ambience 01.mp3")
	AudioManager.play_ambient(dungeon_ambient, true)

	Player.selected_path_index = GameSettings.selected_path
	if GameSettings.selected_path == 3 and GameSettings.item_bundles.size() > 0:
		Player.item_bundles.assign(GameSettings.item_bundles.map(func(b): return b as Enums.ItemBundles))

	path_buttons = [path_btn_0, path_btn_1, path_btn_2, path_btn_3]
	for btn in path_buttons:
		btn.path_selected.connect(_on_path_selected)
		btn.path_hovered.connect(_on_path_hovered)
		btn.path_hover_exited.connect(_on_path_hover_exited)

	_apply_path(Player.selected_path_index)
	#_update_custom_button_skin()

	player_loaded()
	#_refresh_skin()
	bind_button_hovers()
	#_refresh_bundle_buttons()
	check_crt_filter()

	## - Display unlocks if they exist
	PathUnlockManager.initialize()
	_update_path_lock_states()
	_check_pending_unlocks()
	path_unlock_screen.dismissed.connect(_on_unlock_screen_dismissed)

	_bundle_disp_map = {
		Enums.ItemBundles.REVENGE: bundle_disp_revenge,
		Enums.ItemBundles.HONOR:   bundle_disp_honor,
		Enums.ItemBundles.GREED:   bundle_disp_greed,
		Enums.ItemBundles.DUTY:    bundle_disp_duty,
		Enums.ItemBundles.SHAME:   bundle_disp_shame,
		Enums.ItemBundles.CHAOS:   bundle_disp_chaos,
	}

	_update_bundle_display(Player.item_bundles)
	version_label.text = "     Game Build: v" + Player.GAME_VERSION + "   "

func bind_button_hovers():
	btn_compendium.mouse_entered.connect(compendium_mouse_entered)
	btn_hall.mouse_entered.connect(hall_mouse_entered)
	btn_info.mouse_entered.connect(mouse_entered_info.bind("Game Information"))
	btn_settings.mouse_entered.connect(mouse_entered_info.bind("Settings"))
	btn_quit.mouse_entered.connect(mouse_entered_info.bind("Quit"))
	btn_continue.mouse_entered.connect(mouse_entered_info.bind("Load and Continue Last Run"))

	btn_new_run.mouse_exited.connect(mouse_exited_info)
	btn_continue.mouse_exited.connect(mouse_exited_info)
	btn_compendium.mouse_exited.connect(compendium_mouse_exited)
	btn_hall.mouse_exited.connect(hall_mouse_exited)
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
	lbl_name.modulate = Color.WHITE
	lbl_name.text = _lbl
	AudioManager.play_ui_sound("woosh")

func compendium_mouse_entered():
	lbl_name.text = "Compendium"
	anim_compendium.play("hover_compendium")
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("computer_01")

func hall_mouse_entered():
	lbl_name.text = "Nearby Souls Detected"
	anim_hall.play("hover_hall")
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("computer_02")

func compendium_mouse_exited():
	reset_main_label()
	CursorManager.reset_cursor()
	anim_compendium.play("unhover_compendium")

func hall_mouse_exited():
	reset_main_label()
	CursorManager.reset_cursor()
	anim_hall.play("unhover_hall")

func mouse_exited_info():
	reset_main_label()

func reset_main_label():
	lbl_name.text = "What path will your spirit walk, " + Player.player_name + "?"

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
	if Player.selected_path_index == 3 and SkinManager.selected_skin_id >= 3:
		GameSettings.custom_skin_id = SkinManager.selected_skin_id
		GameSettings.save_settings()
	_update_custom_button_skin()

func _update_custom_button_skin() -> void:
	var _skin: SkinData = SkinManager.get_skin(GameSettings.custom_skin_id)
	if _skin:
		path_btn_3.pic_active.texture = _skin.sprite
		path_btn_3.active_texture = _skin.sprite

func player_loaded() -> void:
	lbl_ears.text = str(Player.ears_balance)
	reset_main_label()
	#lbl_champkills.text = "Champion Kills:  " + str(Player.champions_killed) 
	#lbl_activechamps.text = "Active Champions:  " + str(Player.active_champions_count) 

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



## --------------------------------------------------------------------------
## Bundle and Path Handling
## --------------------------------------------------------------------------

func _apply_path(index: int) -> void:
	## - Make sure it's unlocked first
	if not PathUnlockManager.is_path_unlocked(index):
		return

	var path = PATHS[index]
	lbl_path.text = path["name"] + " is motivated by  "
	lbl_path_desc.text = path["desc"]

	for i in range(path_buttons.size()):
		path_buttons[i].set_active(i == index)

	var is_custom = path["bundles"].is_empty()
	custom_bundle_box.visible = is_custom
	path_info_box.visible = !is_custom
	skin_menu.visible = is_custom
	lbl_name.visible = !is_custom

	GameSettings.selected_path = index

	if not is_custom:
		Player.item_bundles.clear()
		Player.item_bundles.assign(path["bundles"])
		SkinManager.select_skin(path["skin_id"])
		btn_new_run.disabled = false
		btn_new_run.text = "New Run"
	else:
		SkinManager.select_skin(GameSettings.custom_skin_id)
		_update_custom_button_skin()
		_refresh_bundle_buttons()

func handle_bundle_selection(_bundle: Enums.ItemBundles):
	if _bundle in Player.item_bundles:
		Player.item_bundles.erase(_bundle)
	elif Player.item_bundles.size() < GameSettings.max_bundles:
		Player.item_bundles.append(_bundle)
	GameSettings.item_bundles.assign(Player.item_bundles.map(func(b): return int(b)))
	_refresh_bundle_buttons()

func check_bundle_requirement():
	if Player.item_bundles.size() < GameSettings.max_bundles:
		btn_new_run.disabled = true
		btn_new_run.text = "Select " + str(GameSettings.max_bundles) + " 'Motives' to Begin"
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

func _on_btn_random_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	var all_bundles: Array = Enums.ItemBundles.values().filter(
		func(b): return b != Enums.ItemBundles.GENERAL and b != Enums.ItemBundles.ALL and b != Enums.ItemBundles.NONE
	)
	all_bundles.shuffle()
	Player.item_bundles.clear()
	Player.item_bundles.assign(all_bundles.slice(0, GameSettings.max_bundles))
	#_refresh_bundle_buttons()
	
	Player.selected_path_index = 3
	_apply_path(Player.selected_path_index)

## --------------------------------------------------------------------------
## Button Funx
## --------------------------------------------------------------------------


func _on_btn_compendium_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	if compendium_panel:
		compendium_panel.show_panel()
	else:
		push_warning("[MainMenu] Settings panel not found!")

func _on_btn_info_pressed() -> void:
	info_panel.visible = true

func _on_btn_heroes_pressed() -> void:
	hall_of_fame.load_default_tab()

func _on_btn_new_game_mouse_entered() -> void:
	lbl_name.text = "New Run"
	AudioManager.play_ui_sound("new_run_hover")

func _on_btn_continue_pressed() -> void:
	if SaveManager.load_run():
		# DungeonManager bag is already restored via from_dict
		# Skip new_run(), go straight to town or current room
		get_tree().change_scene_to_file("res://Scenes/main_game.tscn")
	else:
		push_error("Failed to load saved run")

func _on_btn_skin_menu_mouse_entered() -> void:
	mouse_entered_info("Skins")
	CursorManager.set_interact_cursor()

func _on_btn_skin_menu_mouse_exited() -> void:
	mouse_exited_info()
	CursorManager.reset_cursor()

func _on_skins_box_mouse_entered() -> void:
	mouse_entered_info("Skins")
	CursorManager.set_interact_cursor()

func _on_skins_box_mouse_exited() -> void:
	mouse_exited_info()
	CursorManager.reset_cursor()

func _on_path_selected(index: int) -> void:
	Player.selected_path_index = index
	_apply_path(index)

func _on_path_hovered(index: int) -> void:
	lbl_name.text = PATHS[index]["name"]
	lbl_path.text = PATHS[index]["name"] + " is motivated by  "
	lbl_path_desc.text = PATHS[index]["desc"]
	_update_bundle_display(PATHS[index]["bundles"])

func _on_path_hover_exited(_index: int) -> void:
	reset_main_label()
	lbl_path.text = PATHS[Player.selected_path_index]["name"] + " is motivated by  "
	lbl_path_desc.text = PATHS[Player.selected_path_index]["desc"]
	_update_bundle_display(PATHS[Player.selected_path_index]["bundles"])

func _update_bundle_display(bundles: Array) -> void:
	for bundle in _bundle_disp_map:
		_bundle_disp_map[bundle].visible = bundle in bundles

## -----------------------------------------------------------------------------------------
## - Unlocks
## -----------------------------------------------------------------------------------------

func _update_path_lock_states() -> void:
	path_btn_0.set_locked(!PathUnlockManager.is_path_unlocked(0))
	path_btn_1.set_locked(!PathUnlockManager.is_path_unlocked(1))
	path_btn_2.set_locked(!PathUnlockManager.is_path_unlocked(2))
	path_btn_3.set_locked(!PathUnlockManager.is_path_unlocked(3))

func _check_pending_unlocks() -> void:
	var pending = PathUnlockManager.consume_pending_unlocks()
	if pending.is_empty():
		return
	_unlock_queue.assign(pending)
	_show_next_unlock()

func _show_next_unlock() -> void:
	if _unlock_queue.is_empty():
		return
	var idx = _unlock_queue.pop_front()
	var path_data = PATHS[idx]
	path_unlock_screen.show_unlock(path_data["name"], path_data["desc"])

func _on_unlock_screen_dismissed() -> void:
	_show_next_unlock()

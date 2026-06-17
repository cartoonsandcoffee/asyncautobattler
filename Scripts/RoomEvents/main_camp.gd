class_name MainCampEvent
extends RoomEvent

@onready var shrine_popup: ItemCombiner = $shrine_popup
@onready var forge_popup: ItemCombiner = $forge_popup
@onready var crafting_popup: ItemCombiner = $crafting_popup
@onready var merchant_popup: PopupTownStore = $PopupStore
@onready var mapmaker_popup: PopupMapMaker = $PopupMapMaker
@onready var banish_popup: ItemCombiner = $banish_popup
@onready var boss_warning_popup: Control = $BossWarningPopup

@onready var camp_map_button: Control = $FullScreenBlack/CampMap

@onready var anim_upgrade: AnimationPlayer = $animUpgrade
@onready var lbl_tip: Label = $FullScreenBlack/LabelContainer/lblTip

@onready var btn_champion: Control = $FullScreenBlack/CenterButtons/CampChampion
@onready var btn_shrine: Control = $FullScreenBlack/CenterButtons/CampShrine

func _ready():
	print("main_camp -> ready")
	super._ready()  # Call parent's _ready

	forge_popup.combiner_closed.connect(_check_forge_indicator)
	shrine_popup.combiner_closed.connect(_check_forge_indicator)
	crafting_popup.combiner_closed.connect(_check_forge_indicator)
	merchant_popup.store_closed.connect(_check_forge_indicator)
	mapmaker_popup.destination_selected.connect(_on_map_maker_destination_selected)

	set_champion_available()
	set_shrine_available()

func set_champion_available():
	var is_avail: bool = true

	if Player.rooms_cleared_this_run < 5:
		is_avail = false

	btn_champion.set_available(is_avail)

func set_shrine_available():
	var is_avail: bool = true

	if Player.shrine_uses_left_this_rank <= 0:
		is_avail = false 

	btn_shrine.set_available(is_avail)

func initialize_event():
	print("main_camp -> initialize_event")

func _run_room_event():
	print("main_camp -> _run_room_event (post-combat)")
	Player.popup_open = false
	AudioManager.play_general_music()
	heal_player()
	Player.is_in_town = true
	_check_forge_indicator()
	_show_map_maker()

func heal_player():
	Player.stats.hit_points_current = Player.stats.hit_points
	if main_game_ref and main_game_ref.has_method("set_player_stats"):
		main_game_ref.set_player_stats()

func _check_forge_indicator():
	var item_counts: Dictionary = {}
	for item in Player.inventory.item_slots:
		if not item or (item.rarity != Enums.Rarity.COMMON and item.rarity != Enums.Rarity.GOLDEN):
			continue
		item_counts[item.item_id] = item_counts.get(item.item_id, 0) + 1
		if item_counts[item.item_id] >= 2:
			if item.rarity == Enums.Rarity.COMMON:
				anim_upgrade.play("RESET")
				anim_upgrade.play("show_gold")
			elif item.rarity == Enums.Rarity.GOLDEN:
				anim_upgrade.play("RESET")
				anim_upgrade.play("show_diamond")
			else:
				anim_upgrade.play("RESET")
			return
	anim_upgrade.play("RESET")
	set_shrine_available()

func _check_map_maker() -> bool:
	if Player.map_makers_left_this_rank > 0:
		if Player.times_returned_to_town_this_rank > 0:
			if randf() <= 0.5:  ## - Should be 0.35 for a 35% chance to get the map maker
				return true

	return false

func _show_map_maker():
	camp_map_button.visible = _check_map_maker()
	if camp_map_button.visible:
		mapmaker_popup.roll_destinations()
		camp_map_button.play_detail_anim()

func _on_map_maker_destination_selected(room_id: String) -> void:
	var _room_data: RoomData = DungeonManager.get_room_data_by_id(room_id)
	if not _room_data:
		return
	Player.map_makers_left_this_rank -= 1
	Player.add_rooms(1)
	Player.is_in_town = false
	main_game_ref.fade_out()
	main_game_ref.load_room(_room_data)

## ---------------- BUTTON FUNCTIONS ---------------
func generic_hover():
	if Player.popup_open == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_random_voice()

func generic_unhover():
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		lbl_tip.text = ""

func _on_camp_shrine_button_exited() -> void:
	generic_unhover()

func _on_camp_shrine_button_entered() -> void:
	#generic_hover()
	if btn_shrine.check_available():
		lbl_tip.text = "A Shrine. Make an offering at the Shrine?"
		AudioManager.play_ui_sound("shrine")
	else:
		lbl_tip.text = "Someone is praying at the shrine now, maybe later."
		AudioManager.play_random_voice_no()

func _on_camp_shrine_button_clicked() -> void:
	if Player.shrine_uses_left_this_rank <= 0:
		return 
	
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		shrine_popup.show_popup()
		set_shrine_available()

func _on_camp_champion_button_exited() -> void:
	generic_unhover()

func _on_camp_champion_button_entered() -> void:
	if btn_champion.check_available():
		lbl_tip.text = "Challenge the next Champion to advance your Rank."
		AudioManager.play_ui_sound("cheer_short")
	else:
		lbl_tip.text = "The Champion's arena... You're not quite ready."
		AudioManager.play_ui_sound("chains")

func _on_camp_champion_button_clicked() -> void:
	if btn_champion.check_available():
		main_game_ref.check_boss_panel.show_panel()
	else:
		boss_warning_popup.show_popup()

func _on_camp_banish_button_exited() -> void:
	generic_unhover()

func _on_camp_banish_button_entered() -> void:
	if Player.banishes_left_this_rank <= 0:
		lbl_tip.text = "You can only banish " + str(GameSettings.total_banishes_per_rank) + " items per rank."
	else:
		lbl_tip.text = "Banish an item into the abyss."

func _on_camp_banish_button_clicked() -> void:
	if Player.banishes_left_this_rank <= 0:
		return 

	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		banish_popup.show_popup()

func _on_camp_map_button_exited() -> void:
	generic_unhover()

func _on_camp_map_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "A wandering map maker."

func _on_camp_map_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		mapmaker_popup.show_popup()


func _on_camp_combiner_button_exited() -> void:
	generic_unhover()

func _on_camp_combiner_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Combine identical Common or Golden items."

func _on_camp_combiner_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		forge_popup.show_popup()


func _on_camp_store_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Buy items and weapons from the Merchant."

func _on_camp_store_button_exited() -> void:
	generic_unhover()

func _on_camp_store_button_clicked() -> void:
	if Player.popup_open == false:	
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		merchant_popup.show_store()


func _on_camp_bug_button_exited() -> void:
	generic_unhover()

func _on_camp_bug_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Talk with the bug collector."

func _on_camp_bug_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		crafting_popup.show_popup()


func _on_camp_dungeon_button_entered() -> void:
	if Player.rooms_left_this_rank <= 0:
		lbl_tip.text = "Not enough time! You must challenge the Champion."
	else:
		lbl_tip.text = "Delve the deeps for items and loot."

func _on_camp_dungeon_button_exited() -> void:
	generic_unhover()

func _on_camp_dungeon_button_clicked() -> void:
	if not Player.has_rooms_remaining():
		return

	main_game_ref.fade_out()
	
	var next_room: RoomData = DungeonManager.get_random_dungeon_room()

	# Load it
	Player.is_in_town = false
	main_game_ref.load_room(next_room)


func _on_camp_pet_button_clicked() -> void:
	main_game_ref.pet_interface.open_popup()

func _on_camp_pet_button_entered() -> void:
	lbl_tip.text = "Dinglemeyer"

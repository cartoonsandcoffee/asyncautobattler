class_name TownEvent
extends RoomEvent


@onready var shrine_popup: ItemCombiner = $shrine_popup
@onready var forge_popup: ItemCombiner = $forge_popup
@onready var crafting_popup: ItemCombiner = $crafting_popup
@onready var merchant_popup: ItemTownStore = $merchant_popup
@onready var banish_popup: ItemCombiner = $banish_popup
@onready var anim_upgrade: AnimationPlayer = $animUpgrade
@onready var lbl_tip: Label = $PanelContainer/lblTip


func _ready():
	print("town -> ready")
	super._ready()  # Call parent's _ready

	forge_popup.combiner_closed.connect(_check_forge_indicator)
	shrine_popup.combiner_closed.connect(_check_forge_indicator)
	crafting_popup.combiner_closed.connect(_check_forge_indicator)
	merchant_popup.store_closed.connect(_check_forge_indicator)

func initialize_event():
	print("town -> initialize_event")

func _run_room_event():
	print("town -> _run_room_event (post-combat)")
	Player.popup_open = false
	AudioManager.play_general_music()
	
	heal_player()
	Player.is_in_town = true
	_check_forge_indicator()

func heal_player():
	Player.stats.hit_points_current = Player.stats.hit_points
	if main_game_ref and main_game_ref.has_method("set_player_stats"):
		main_game_ref.set_player_stats()

func generic_hover():
	if Player.popup_open == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_random_voice()

func generic_unhover():
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		lbl_tip.text = ""

func _on_btn_camp_pressed() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("fire01")

		# heal to full
		Player.stats.hit_points_current = Player.stats.hit_points
		if main_game_ref and main_game_ref.has_method("set_player_stats"):
			main_game_ref.set_player_stats()

func _on_btn_shrine_button_clicked() -> void:
	if Player.shrine_uses_left_this_rank <= 0:
		return 
	
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		shrine_popup.show_popup()


func _on_btn_venture_button_clicked() -> void:
	if not Player.has_rooms_remaining():
		return

	main_game_ref.fade_out()
	
	var next_room: RoomData = null
	if (DungeonManager.current_rank == 1 && DungeonManager.rooms_visited_this_rank == 0):
		next_room = DungeonManager.get_starter_room()
	else:
		# Get random dungeon room
		next_room = DungeonManager.get_random_dungeon_room()

	# Load it
	Player.is_in_town = false
	main_game_ref.load_room(next_room)


func _on_btn_champion_button_clicked() -> void:
	main_game_ref.check_boss_panel.show_panel()


func _on_btn_forge_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		forge_popup.show_popup()

func _on_btn_store_button_clicked() -> void:
	if Player.popup_open == false:	
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		merchant_popup.show_store()

func _on_btn_bugs_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		crafting_popup.show_popup()



func _on_btn_venture_button_entered() -> void:
	if Player.rooms_left_this_rank <= 0:
		lbl_tip.text = "Not enough time! You must challenge the Champion."
	else:
		lbl_tip.text = "Delve the deeps for items and loot."

func _on_btn_champion_button_entered() -> void:
	lbl_tip.text = "Challenge the next Champion to advance your Rank."

func _on_btn_bugs_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Talk with the bug collector."

func _on_btn_shrine_button_entered() -> void:
	generic_hover()
	if Player.shrine_uses_left_this_rank <= 0:
		lbl_tip.text = "You can only visit the shrine once per rank."
	else:
		lbl_tip.text = "Make an offering at the Shrine."

func _on_btn_forge_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Combine identical Common or Golden items."

func _on_btn_store_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Buy items and weapons from the Merchant."


func _on_btn_banish_button_clicked() -> void:
	if Player.banishes_left_this_rank <= 0:
		return 

	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("popup_open")
		banish_popup.show_popup()


func _on_btn_banish_button_entered() -> void:
	if Player.banishes_left_this_rank <= 0:
		lbl_tip.text = "You can only banish " + str(Player.total_banishes_per_rank) + " items per rank."
	else:
		lbl_tip.text = "Banish an item into the abyss."
	
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
				anim_upgrade.play("upgrade_ready")
			return
	anim_upgrade.play("RESET")

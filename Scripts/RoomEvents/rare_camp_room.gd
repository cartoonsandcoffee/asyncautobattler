class_name RareCampRoom
extends RoomEvent


@onready var shrine_popup: ItemCombiner = $shrine_popup
@onready var forge_popup: ItemCombiner = $forge_popup
@onready var crafting_popup: ItemCombiner = $crafting_popup
@onready var merchant_popup: ItemTownStore = $merchant_popup
@onready var banish_popup: ItemCombiner = $banish_popup

@onready var lbl_tip: Label = $PanelContainer/lblTip

@onready var store_fancy: ItemStore = $store_fancy
@onready var store_bug: ItemStore = $store_bug
@onready var potion_mixer: ItemStore = $potion_store

func _ready():
	print("rare_camp -> ready")
	super._ready()  # Call parent's _ready

func initialize_event():
	print("rare_camp -> initialize_event")

func _run_room_event():
	print("rare_camp -> _run_room_event (post-combat)")
	Player.rare_camp_events_left -= 1
	heal_player()

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


func _on_btn_venture_button_entered() -> void:
	if Player.rooms_left_this_rank <= 0:
		lbl_tip.text = "Head back to the main camp."
	else:
		lbl_tip.text = "Return to the dungeon for more glory and gold."

func _on_btn_bugs_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "Talk with the bug collector."

func _on_btn_store_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "A purveyor of extra special items."
	
func _on_btn_potions_button_entered() -> void:
	generic_hover()
	lbl_tip.text = "An extravagant potion mixer."


func _on_btn_well_button_entered() -> void:
	lbl_tip.text = "A crumbling old well."


func _on_btn_potions_button_clicked() -> void:
	potion_mixer.show_store()

func _on_btn_well_button_clicked() -> void:
	pass # Replace with function body.

func _on_btn_bugs_button_clicked() -> void:
	store_bug.show_store()

func _on_btn_store_button_clicked() -> void:
	store_fancy.show_store()

func _on_btn_venture_button_clicked() -> void:
	var next_room: RoomData = null

	if not Player.has_rooms_remaining():
		next_room = DungeonManager.get_town_room()
	else:
		next_room = DungeonManager.get_random_dungeon_room()

	# Load it
	AudioManager.clear_room_override()
	main_game_ref.load_room(next_room)
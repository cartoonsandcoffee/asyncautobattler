class_name TownEvent
extends RoomEvent


@onready var shrine_popup: ItemCombiner = $shrine_popup
@onready var forge_popup: ItemCombiner = $forge_popup
@onready var crafting_popup: ItemCombiner = $crafting_popup
@onready var merchant_popup: ItemStore = $merchant_popup


@onready var anim_dungeon: AnimationPlayer = $animDungeon
@onready var anim_tower: AnimationPlayer = $animTower
@onready var anim_merchant: AnimationPlayer = $animMerchant
@onready var anim_camp: AnimationPlayer = $animCamp

func _ready():
	print("town -> ready")
	super._ready()  # Call parent's _ready

func initialize_event():
	print("town -> initialize_event")

func _run_room_event():
	print("town -> _run_room_event (post-combat)")
	#item_combiner.item_skipped.connect(_on_item_skipped)
	#item_combiner.combiner_closed.connect(_on_item_skipped)
	anim_merchant.play("merchant_idle")


func generic_hover():
	if Player.popup_open == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_ui_sound("woosh")

func generic_unhover():
	if Player.popup_open == false:
		CursorManager.reset_cursor()

func _on_btn_forge_mouse_exited() -> void:
	generic_unhover()


func _on_btn_forge_mouse_entered() -> void:
	generic_hover()


func _on_btn_forge_pressed() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("chomp")
		forge_popup.show_popup()



func _on_btn_shrine_mouse_exited() -> void:
	generic_unhover()

func _on_btn_shrine_mouse_entered() -> void:
	generic_hover()

func _on_btn_shrine_pressed() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("kneel")
		shrine_popup.show_popup()


func _on_btn_tower_mouse_exited() -> void:
	generic_unhover()
	anim_tower.play("stop_hover")


func _on_btn_tower_mouse_entered() -> void:
	generic_hover()
	anim_tower.play("start_hover")

func _on_btn_tower_pressed() -> void:
	pass # Replace with function body.


func _on_btn_dungeon_mouse_exited() -> void:
	generic_unhover()
	anim_dungeon.play("stop_hover")


func _on_btn_dungeon_mouse_entered() -> void:
	generic_hover()
	anim_dungeon.play("start_hover")

func _on_btn_dungeon_pressed() -> void:
	if not Player.has_rooms_remaining():
		return

	var next_room: RoomData = null
	if (DungeonManager.current_rank == 1 && DungeonManager.rooms_visited_this_rank == 0):
		next_room = DungeonManager.get_starter_room()
	else:
		# Get random dungeon room
		next_room = DungeonManager.get_random_dungeon_room()

	# Load it
	main_game_ref.load_room(next_room)




func _on_btn_merchant_mouse_exited() -> void:
	generic_unhover()

func _on_btn_merchant_mouse_entered() -> void:
	if Player.popup_open == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("mmm")

func _on_btn_merchant_pressed() -> void:
	if Player.popup_open == false:	
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("ooo")
		merchant_popup.show_store()

func _on_btn_craft_mouse_entered() -> void:
	generic_hover()

func _on_btn_craft_mouse_exited() -> void:
	generic_unhover()

func _on_btn_craft_pressed() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("corpse")
		crafting_popup.show_popup()


func _on_btn_camp_mouse_entered() -> void:
	if Player.popup_open == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("campfire")

func _on_btn_campt_mouse_exited() -> void:
	generic_unhover()

func _on_btn_camp_pressed() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("fire01")

		# heal to full
		Player.stats.hit_points_current = Player.stats.hit_points
		if main_game_ref and main_game_ref.has_method("set_player_stats"):
			main_game_ref.set_player_stats()


func _on_btn_shrine_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("kneel")
		shrine_popup.show_popup()


func _on_btn_venture_button_clicked() -> void:
	if not Player.has_rooms_remaining():
		return

	var next_room: RoomData = null
	if (DungeonManager.current_rank == 1 && DungeonManager.rooms_visited_this_rank == 0):
		next_room = DungeonManager.get_starter_room()
	else:
		# Get random dungeon room
		next_room = DungeonManager.get_random_dungeon_room()

	# Load it
	main_game_ref.load_room(next_room)


func _on_btn_champion_button_clicked() -> void:
	main_game_ref.zoom_panel.show_panel()


func _on_btn_forge_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("chomp")
		forge_popup.show_popup()

func _on_btn_store_button_clicked() -> void:
	if Player.popup_open == false:	
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("ooo")
		merchant_popup.show_store()

func _on_btn_bugs_button_clicked() -> void:
	if Player.popup_open == false:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("corpse")
		crafting_popup.show_popup()

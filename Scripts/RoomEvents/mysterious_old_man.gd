class_name MysteriousOldManEvent
extends RoomEvent


@onready var item_choice_container: GridContainer = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/itemContainer
@onready var name_label: Label = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblDialog
@onready var btn_event: Button = $eventHolder1/picEvent/btnEvent
@onready var panel_offer: Panel = $panelOffer
@onready var btn_next:Button =$picFarBack/centerPoint/btnNext

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_label: AnimationPlayer = $animLabel
@onready var anim_box: AnimationPlayer = $animBox
@onready var anim_blood:AnimationPlayer = $animBlood

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var offered_items: Array[Item] = []
var items_offered: int = 3

func initialize_event():
	#slideshow_player.close_slideshow.connect(_close_slideshow)
	#anim_slides.play("open_slideshow")

	generate_item_choices()
	disable_button()

	start_old_man()


func disable_button():
	btn_event.disabled = true

func sfx_drip():
	AudioManager.play_event_sound("drop_01")

func sfx_splash():
	AudioManager.play_event_sound("drop_02")

func play_blood():
	anim_blood.play("show_blood")

func start_old_man():
	anim_event.play("show_event")

func slide_in_the_menus():
	DungeonManager.slide_in_menus()

func generate_item_choices():
	# Get 3 random common items
	offered_items = ItemsManager.get_items_by_item_type(items_offered, Item.ItemType.WEAPON, true, Enums.Rarity.COMMON)
	
	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(100, 100)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.item_selected.connect(_on_item_selected)

func show_item_box():
	anim_box.play("show_box")

func _on_item_selected(item: Item):
	# Add chosen item to player inventory
	Player.inventory.add_item(item)
	Player.update_stats_from_items()
	disable_button()
	finish_event()

func finish_event():
	# Hide item choices
	anim_box.play("hide_box")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished

	main_game_ref.show_bottom_panel(false)
	btn_next.disabled = false

	# Complete the event
	#complete_event()

func _on_btn_event_pressed() -> void:
	AudioManager.play_event_sound("corpse")
	CursorManager.reset_cursor()
	anim_label.play("hide_label")
	disable_button()
	show_item_box()


func _on_btn_event_mouse_exited() -> void:
	if !panel_offer.visible:
		CursorManager.reset_cursor()
		anim_label.play("hide_label")


func _on_btn_event_mouse_entered() -> void:
	if !panel_offer.visible:
		anim_label.play("show_label")
		CursorManager.set_interact_cursor()


func _on_dungeon_button_clicked() -> void:
	main_game_ref.fade_out()
	
	var next_room: RoomData = DungeonManager.get_town_room()

	main_game_ref.load_room(next_room)


func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func _on_btn_skip_pressed() -> void:
	finish_event()



func _on_btn_next_mouse_exited() -> void:
	if !panel_offer.visible:
		CursorManager.reset_cursor()

func _on_btn_next_mouse_entered() -> void:
	if !panel_offer.visible:
		CursorManager.set_navigation_cursor()

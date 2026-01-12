class_name MysteriousOldManEvent
extends RoomEvent


@onready var item_choice_container: GridContainer = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/itemContainer
@onready var name_label: Label = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblDialog
@onready var slideshow_player: Control = $SlidePlayer
@onready var btn_event: Button = $picEvent/btnEvent
@onready var panel_offer: Panel = $panelOffer

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_label: AnimationPlayer = $animLabel
@onready var anim_box: AnimationPlayer = $animBox
@onready var anim_slides: AnimationPlayer = $animSlides
@onready var anim_opening: AnimationPlayer = $animOpening
@onready var anim_rope: AnimationPlayer = $animRope
@onready var lbl_opening: RichTextLabel = $picOpening/lblOpening
@onready var anim_blood:AnimationPlayer = $animBlood

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var offered_items: Array[Item] = []
var items_offered: int = 3

var msg_speed: float = 0.75
var show_opening: bool = false
var current_panel: int = 0
var total_panels: int = 4

func initialize_event():
	slideshow_player.close_slideshow.connect(_close_slideshow)
	#anim_slides.play("open_slideshow")
	
	generate_item_choices()
	disable_button()

	if GameSettings.skip_opening == false:
		start_intro_movie()
	else:
		anim_opening.play("skip_opening")
		start_old_man()


func start_intro_movie():
	lbl_opening.text = ""
	lbl_opening.visible_ratio = 0
	current_panel = 1
	
	show_opening = true
	anim_opening.play("opening_show_panel_1")

func disable_button():
	btn_event.disabled = true

func _process(delta: float) -> void:
	if show_opening:
		if lbl_opening.visible_ratio < 1:
			lbl_opening.visible_ratio += msg_speed * delta

func show_text_panel_1():
	lbl_opening.visible_ratio = 0
	AudioManager.play_synced_sound("text_type")	
	lbl_opening.text = "Can you remember how you got here?"

func show_panel_2():
	current_panel = 2
	anim_opening.play("opening_show_panel_2")
	await CombatSpeed.create_timer(0.5)
	lbl_opening.visible_ratio = 0
	AudioManager.play_synced_sound("text_type")	
	lbl_opening.text = "Before your mind is lost to madness..."

func show_panel_3():
	current_panel = 3
	anim_opening.play("opening_show_panel_3")
	await CombatSpeed.create_timer(0.5)
	lbl_opening.visible_ratio = 0
	AudioManager.play_synced_sound("text_type")	
	lbl_opening.text = "Suddenly, opportunity..."

func show_panel_4():
	current_panel = 4
	anim_opening.play("opening_show_panel_4")
	await CombatSpeed.create_timer(0.5)
	lbl_opening.visible_ratio = 0
	AudioManager.play_synced_sound("text_type")	
	lbl_opening.text = "Is escape even possible? Or will you lose yourself to their will."

func finish_opening():
	show_opening = false
	anim_opening.play("opening_close")

func sfx_drip():
	AudioManager.play_event_sound("drop_01")

func sfx_splash():
	AudioManager.play_event_sound("drop_02")

func play_blood():
	anim_blood.play("show_blood")

func start_old_man():
	anim_event.play("show_event")

func start_slideshow():
	slideshow_player.play_slideshow()

func _close_slideshow():
	anim_slides.play("close_slideshow")

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

	anim_rope.play("show_rope")
	await anim_rope.animation_finished
	anim_rope.play("rope_sway")
	
	await DungeonManager.slide_in_menus()

	# Complete the event
	complete_event()

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
		AudioManager.play_ui_sound("woosh")



func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func _on_btn_skip_pressed() -> void:
	finish_event()

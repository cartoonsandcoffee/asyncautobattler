class_name MysteriousOldManEvent
extends RoomEvent


@onready var item_choice_container: GridContainer = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/itemContainer
@onready var name_label: Label = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblDialog
@onready var slideshow_player: Control = $SlidePlayer

@onready var anim_old_man: AnimationPlayer = $animOldMan
@onready var anim_box: AnimationPlayer = $animBox
@onready var anim_starter: AnimationPlayer = $animStarter
@onready var anim_opening: AnimationPlayer = $animOpening
@onready var lbl_opening: RichTextLabel = $picOpening/lblOpening

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var offered_items: Array[Item] = []
var items_offered: int = 3

var msg_speed: float = 0.75
var show_opening: bool = false
var current_panel: int = 0
var total_panels: int = 4

func initialize_event():
	slideshow_player.close_slideshow.connect(_close_slideshow)
	#anim_starter.play("open_slideshow")
	
	start_intro_movie()

	generate_item_choices()

func start_intro_movie():
	lbl_opening.text = ""
	lbl_opening.visible_ratio = 0
	current_panel = 1
	
	show_opening = true
	anim_opening.play("opening_show_panel_1")

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


func start_old_man():
	anim_old_man.play("walk_in")

func start_slideshow():
	slideshow_player.play_slideshow()

func _close_slideshow():
	anim_starter.play("close_slideshow")

func slide_in_the_menus():
	DungeonManager.slide_in_menus()

func generate_item_choices():
	# Get 3 random common items
	offered_items = ItemsManager.get_random_common_items(items_offered)
	
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
	
	# Hide item choices
	anim_box.play("hide_box")
	await anim_box.animation_finished
	
	anim_old_man.play("walk_out")
	await anim_old_man.animation_finished
	await DungeonManager.slide_in_menus()

	# Complete the event
	complete_event()

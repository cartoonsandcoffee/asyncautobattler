class_name MysteriousOldManEvent
extends RoomEvent


@onready var item_choice_container: GridContainer = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/itemContainer
@onready var name_label: Label = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $panelOffer/PanelContainer/MarginContainer/VBoxContainer/lblDialog
@onready var slideshow_player: Control = $SlidePlayer

@onready var anim_old_man: AnimationPlayer = $animOldMan
@onready var anim_box: AnimationPlayer = $animBox
@onready var anim_starter: AnimationPlayer = $animStarter

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var offered_items: Array[Item] = []
var items_offered: int = 3



func initialize_event():
	slideshow_player.close_slideshow.connect(_close_slideshow)
	anim_starter.play("open_slideshow")
	generate_item_choices()


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

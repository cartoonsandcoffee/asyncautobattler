class_name ItemOffering
extends Control

signal item_selected(Item)
signal item_skipped()
signal need_item_replace(Item)

@onready var item_choice_container: GridContainer = $Panel/panelBlack/PanelContainer/VBoxContainer/itemsContainer
@onready var name_label: Label = $Panel/panelBlack/PanelContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $Panel/panelBlack/PanelContainer/VBoxContainer/MarginContainer/txtDesc
@onready var btn_skip: Button = $Panel/panelBlack/PanelContainer/VBoxContainer/btnSkip

@export var item_rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var items_offered: int = 3
@export var box_name:String = ""
@export_multiline var box_desc:String = ""
@export var include_extra_rare: bool = false

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var offered_items: Array[Item] = []
var selection_locked: bool = false

func _ready() -> void:
	add_to_group("item_selection_events") 
	item_choice_container.columns = items_offered
	if include_extra_rare: item_choice_container.columns = items_offered + 1
	generate_item_choices()
	setup_labels()

func setup_labels():
	name_label.text = box_name
	dialogue_label.text = box_desc
	if box_desc == "" || box_desc == null:
		dialogue_label.visible = false

func generate_item_choices():
	# Get 3 random common items
	offered_items = ItemsManager.get_random_items(items_offered, item_rarity, include_extra_rare)
	
	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(110, 110)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.item_selected.connect(_on_item_selected)

func _on_item_selected(item: Item):
	if selection_locked:
		return
	
	selection_locked = true
	btn_skip.disabled = true

	if Player.inventory.has_empty_slot():
		Player.inventory.add_item(item)
		Player.update_stats_from_items()
		item_selected.emit(item)	
	else:
		need_item_replace.emit(item)

func _on_btn_skip_pressed() -> void:
	item_skipped.emit()

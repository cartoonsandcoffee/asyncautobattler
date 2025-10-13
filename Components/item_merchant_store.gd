class_name ItemStore
extends Control

signal item_selected(Item)
signal store_closed()
signal need_item_replace(Item)

@onready var item_choice_container: GridContainer = $Panel/BlackBack/PanelContainer/VBoxContainer/itemsContainer
@onready var name_label: Label = $Panel/BlackBack/PanelContainer/VBoxContainer/lblName
@onready var dialogue_label: RichTextLabel = $Panel/BlackBack/PanelContainer/VBoxContainer/MarginContainer/txtDesc
@onready var btn_cancel: Button = $Panel/BlackBack/PanelContainer/VBoxContainer/btnCancel
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var refresh_panel: PanelContainer = $Panel/sidePanelBlack
@onready var refresh_cost: Label = $Panel/sidePanelBlack/PanelContainer/HBoxContainer/HBoxContainer2/lblRerollCost
@onready var btn_refresh: Button = $Panel/sidePanelBlack/btnReroll

@export var item_rarity: Enums.Rarity = Enums.Rarity.UNCOMMON
@export var items_offered: int = 6
@export var item_columns: int = 3

@export var box_name:String = ""
@export_multiline var box_desc:String = ""
@export var include_extra_rare: bool = false
@export var allow_refresh: bool = true

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var empty_item = preload("res://Scenes/Elements/empty_choice.tscn")

var offered_items: Array[Item] = []
var is_store_open: bool = false

func _ready() -> void:
	item_choice_container.columns = item_columns
	refresh_panel.visible = allow_refresh
	add_to_group("item_selection_events") 
	generate_item_choices()
	setup_labels()

func setup_labels():
	name_label.text = box_name
	dialogue_label.text = box_desc
	if box_desc == "" || box_desc == null:
		dialogue_label.visible = false

func generate_item_choices():
	#clear old items
	for child in item_choice_container.get_children():
		child.queue_free()
		
	# Get 3 random common items
	offered_items = ItemsManager.get_random_items(items_offered, item_rarity)
	
	# Create choice buttons for each item
	for item in offered_items:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(110, 140)
		item_choice_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.setup_for_store()
		choice_button.item_purchased.connect(_on_item_selected)
	
	check_affordability()

func _on_item_selected(item: ItemChoice):
	purchase_item_from_store(item)

func _on_btn_cancel_pressed() -> void:
	hide_store()


func show_store():
	anim_player.play("show_store")
	await anim_player.animation_finished
	is_store_open = true

func hide_store():
	anim_player.play("hide_store")
	await anim_player.animation_finished	
	is_store_open = false
	store_closed.emit()

func replace_item_with_empty(target_item: Item):
	var children = item_choice_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		# Check if this slot contains the target item
		if item_slot.has_method("get_current_item") and item_slot.get_current_item() == target_item:
			# Remove the old slot
			item_choice_container.remove_child(item_slot)
			item_slot.queue_free()
			
			# Create and add empty slot
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = item_slot.custom_minimum_size  # Keep same size
			item_choice_container.add_child(empty_slot)
			
			# Move to correct position in grid
			item_choice_container.move_child(empty_slot, i)
			break

func check_affordability():
	var children = item_choice_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		if item_slot.has_method("get_current_item"):
			if item_slot.item_cost > Player.stats.gold:
				item_slot.cannot_afford()
			else:
				item_slot.can_afford()


func purchase_item_from_store(purchased_item: ItemChoice):
	if Player.stats.gold >= purchased_item.item_cost:
		Player.subtract_gold(purchased_item.item_cost)

		if Player.inventory.has_empty_slot():
			Player.inventory.add_item(purchased_item.current_item)
			Player.update_stats_from_items()
			item_selected.emit(purchased_item.current_item)	
			replace_item_with_empty(purchased_item.current_item)
		else:
			need_item_replace.emit(purchased_item.current_item)
			replace_item_with_empty(purchased_item.current_item)

		check_affordability()

# Alternative approach if you want to rebuild the entire grid:
func refresh_store_display():
	# Clear all existing children
	if Player.stats.gold >= Player.stats.refresh_cost:
		Player.stats.gold -= Player.stats.refresh_cost
		Player.stats.refresh_cost += 1
		refresh_cost.text = str(Player.stats.refresh_cost)
	
		# Add items back (including empty slots for null items)
		generate_item_choices()		


func _on_btn_reroll_pressed() -> void:
	refresh_store_display()

extends Control

@onready var item_grid: GridContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelItems/ScrollContainer/gridItems
@onready var filter_type: OptionButton = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/optTypes
@onready var filter_rarity: OptionButton = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/optRarity

var item_scene = preload("res://Scenes/item.tscn")
var all_items: Array[Item] = []
var subset_items: Array[Item] = []

func _ready() -> void:
	load_all_items()
	show_items()

func load_all_items():
	all_items.clear()
	subset_items.clear()

	all_items = ItemsManager.get_all_items()
	subset_items = all_items

func show_items():
	#clear old items
	for child in item_grid.get_children():
		child.queue_free()
		
	# Create choice buttons for each item
	for item in subset_items:
		var choice_button = item_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(120, 120)
		item_grid.add_child(choice_button)
		choice_button.set_is_from_compendium(true)
		choice_button.set_item(item)

func get_items_by_item_type(_selection: int) -> void:
	subset_items.clear()
	all_items = ItemsManager.get_all_items()

	var armor_states: Array[Item.ItemType] = [Item.ItemType.BODY_ARMOR, Item.ItemType.HELMET, Item.ItemType.GLOVES, Item.ItemType.BELT, Item.ItemType.SHIELD, Item.ItemType.JEWELRY]
	var tool_states: Array[Item.ItemType] = [Item.ItemType.TOOL, Item.ItemType.SCROLL, Item.ItemType.TOME]
	var bug_states: Array[Item.ItemType] = [Item.ItemType.BUG, Item.ItemType.PET]
	var potion_states: Array[Item.ItemType] = [Item.ItemType.POTION, Item.ItemType.FOOD]

	var check_states: Array[Item.ItemType]

	if _selection == 1:
		check_states = [Item.ItemType.WEAPON]
	elif _selection == 2:
		check_states = armor_states
	elif _selection == 3:
		check_states = tool_states
	elif _selection == 4:
		check_states = bug_states
	elif _selection == 5:
		check_states = potion_states

	# Filter for common rarity only
	for item in all_items:
		if item.item_type in check_states:
			if filter_rarity.selected == 0:
				subset_items.append(item)
			elif filter_rarity.selected == 1 and (item.rarity == Enums.Rarity.COMMON):
				subset_items.append(item)
			elif filter_rarity.selected == 2 and (item.rarity == Enums.Rarity.UNCOMMON):
				subset_items.append(item)
			elif filter_rarity.selected == 3 and (item.rarity == Enums.Rarity.RARE):
				subset_items.append(item)
			elif filter_rarity.selected == 4 and (item.rarity == Enums.Rarity.LEGENDARY):
				subset_items.append(item)
			elif filter_rarity.selected == 5 and (item.rarity in [Enums.Rarity.CRAFTED, Enums.Rarity.DIAMOND, Enums.Rarity.GOLDEN]):
				subset_items.append(item)

	show_items()


func _on_btn_done_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_done_mouse_entered() -> void:
	#AudioManager.play_ui_sound("button_hover")
	pass

func _on_btn_done_pressed() -> void:
	hide_panel()

func hide_panel():
	visible = false

func show_panel():
	show_items()
	visible = true


func _on_opt_rarity_item_selected(index:int) -> void:
	get_items_by_item_type(filter_type.selected)

func _on_opt_types_item_selected(index:int) -> void:
	if index == 0:
		subset_items = all_items
		show_items()
	else:
		get_items_by_item_type(index)

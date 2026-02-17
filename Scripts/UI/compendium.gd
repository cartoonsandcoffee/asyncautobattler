extends Control

@onready var item_grid: GridContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelItems/ScrollContainer/gridItems
@onready var filter_type: OptionButton = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/optTypes
@onready var filter_rarity: OptionButton = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer2/optRarity
@onready var lbl_filters: Label = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/lblFilters

@onready var category_chips_container: HFlowContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxCategories

var selected_categories: Array[String] = []
var category_buttons: Dictionary = {} # category_name -> Button

var item_scene = preload("res://Scenes/item.tscn")
var all_items: Array[Item] = []
var subset_items: Array[Item] = []

var is_populating: bool = false


func _ready() -> void:
	load_all_items()
	show_items()
	_setup_category_chips()

func load_all_items():
	all_items.clear()
	subset_items.clear()

	all_items = ItemsManager.get_all_items()
	subset_items = all_items

func show_items():
	if is_populating:
		return
	
	is_populating = true

	#clear old items
	for child in item_grid.get_children():
		child.queue_free()
		
	# Wait one frame for cleanup
	await get_tree().process_frame
	
	# Populate in batches
	var batch_size = 10  # Adjust this number - higher = faster but more frame drops
			
	for i in range(0, subset_items.size(), batch_size):
		var batch_end = mini(i + batch_size, subset_items.size())
		
		for j in range(i, batch_end):
			var item = subset_items[j]
			var choice_button = item_scene.instantiate()
			choice_button.custom_minimum_size = Vector2(120, 120)
			item_grid.add_child(choice_button)
			choice_button.set_is_from_compendium(true)
			choice_button.set_item(item)
		
		# Wait one frame before next batch
		await get_tree().process_frame
	
	set_label(subset_items.size())
	is_populating = false

func get_items_by_item_type(_selection: int) -> void:
	subset_items.clear()
	all_items = ItemsManager.get_all_items()

	var armor_states: Array[Item.ItemType] = [Item.ItemType.BODY_ARMOR, Item.ItemType.HELMET, Item.ItemType.GLOVES, Item.ItemType.BELT, Item.ItemType.SHIELD, Item.ItemType.JEWELRY]
	var tool_states: Array[Item.ItemType] = [Item.ItemType.TOOL, Item.ItemType.SCROLL, Item.ItemType.TOME, Item.ItemType.RELIC, Item.ItemType.CRYSTAL]
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

	var skip_this_item: bool = false

	# Filter for common rarity only
	for item in all_items:
		skip_this_item = false 

		if selected_categories.size() > 0:
			for category in selected_categories:
				if category not in item.categories:
					skip_this_item = true
					break	

		if !skip_this_item:
			if _selection == 0:
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
			elif item.item_type in check_states:
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
	get_items_by_item_type(index)

func set_label(_count: int):
	lbl_filters.text = "- Showing " + str(_count) + " items. -"

func _setup_category_chips() -> void:
	# Clear existing chips
	for child in category_chips_container.get_children():
		child.queue_free()
	category_buttons.clear()
	
	# Gather all unique categories from items
	var all_categories: Array[String] = []
	for item in all_items:
		for category in item.categories:
			if category not in all_categories:
				all_categories.append(category)
	
	all_categories.sort()
	
	# Create a button for each category
	for category in all_categories:
		var button = Button.new()
		button.text = category
		button.toggle_mode = true
		button.button_pressed = false
		
		# Style as chip
		button.add_theme_stylebox_override("normal", _create_chip_style(false))
		button.add_theme_stylebox_override("pressed", _create_chip_style(true))
		button.add_theme_stylebox_override("hover", _create_chip_style(false, true))
		button.add_theme_font_size_override("font_size", 14)
		
		button.pressed.connect(_on_category_chip_toggled.bind(category))
		
		category_chips_container.add_child(button)
		category_buttons[category] = button

func _create_chip_style(pressed: bool, hover: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	if pressed:
		style.bg_color = Color(0.3, 0.6, 0.9, 1.0)  # Blue when selected
	elif hover:
		style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # Lighter on hover
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray default
	
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	
	return style

func _on_category_chip_toggled(category: String) -> void:
	if category in selected_categories:
		selected_categories.erase(category)
	else:
		selected_categories.append(category)
	
	get_items_by_item_type(filter_type.selected)

extends Control

@onready var item_grid: GridContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelItems/ScrollContainer/gridItems
@onready var filter_type: OptionButton = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/optTypes
@onready var filter_rarity: OptionButton = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/optRarity
@onready var lbl_filters: Label = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/MarginContainer2/lblFilters

@onready var category_chips_container: HFlowContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxCategories
@onready var keyword_chips_container: HFlowContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxKeywords

@onready var bundle_general: Button = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxBundles/bunGeneral
@onready var bundle_revenge: Button = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxBundles/bunRevenge
@onready var bundle_honor: Button = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxBundles/bunHonor
@onready var bundle_greed: Button = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxBundles/bunGreed

@onready var box_bundles: VBoxContainer = $Panel/pnlBlackBack/MarginContainer/pnlBorder/VBoxContainer/panelFilters/VBoxContainer/VBoxContainer/HBoxContainer/boxBundles

var selected_keywords: Array[String] = []
var keyword_buttons: Dictionary = {}

var selected_categories: Array[String] = []
var category_buttons: Dictionary = {}

var selected_bundles: Array[Enums.ItemBundles] = [Enums.ItemBundles.GENERAL, Enums.ItemBundles.REVENGE, Enums.ItemBundles.HONOR, Enums.ItemBundles.GREED]

var item_scene = preload("res://Scenes/item.tscn")
var all_item_nodes: Array = []  # Store references to instantiated item nodes
var is_populating: bool = false
var has_loaded:bool = false

# Current filter state
var current_type_filter: int = 0
var current_rarity_filter: int = 0

func _ready() -> void:
	pass

# Create all items ONCE on startup
func populate_all_items():
	if is_populating:
		return
	
	is_populating = true
	all_item_nodes.clear()
	
	# Clear old items
	for child in item_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var all_items = ItemsManager.get_all_items(false)

	# Sort by Rarity, then Type, then Name
	all_items.sort_custom(func(a: Item, b: Item) -> bool:
		# First compare rarity
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		
		# If rarity is same, compare type
		if a.item_type != b.item_type:
			return a.item_type < b.item_type
		
		# If both are same, compare name
		return a.item_name < b.item_name
	)
		
	var batch_size = 15
	
	for i in range(0, all_items.size(), batch_size):
		var batch_end = mini(i + batch_size, all_items.size())
		
		for j in range(i, batch_end):
			var item = all_items[j]
			var choice_button = item_scene.instantiate()
			choice_button.custom_minimum_size = Vector2(120, 120)
			item_grid.add_child(choice_button)
			choice_button.set_is_from_compendium(true)
			choice_button.set_item(item)
			
			# Store reference with item data
			all_item_nodes.append({
				"node": choice_button,
				"item": item
			})
		
		await get_tree().process_frame
	
	is_populating = false

# Fast filtering - just toggle visibility
func apply_filters() -> void:
	var visible_count = 0
	
	var armor_types: Array[Item.ItemType] = [Item.ItemType.BODY_ARMOR, Item.ItemType.HELMET, Item.ItemType.GLOVES, Item.ItemType.BELT, Item.ItemType.SHIELD, Item.ItemType.BOOTS]
	var tool_types: Array[Item.ItemType] = [Item.ItemType.TOOL, Item.ItemType.SCROLL, Item.ItemType.TOME, Item.ItemType.RELIC, Item.ItemType.CRYSTAL, Item.ItemType.JEWELRY]
	var bug_types: Array[Item.ItemType] = [Item.ItemType.BUG, Item.ItemType.PET]
	var potion_types: Array[Item.ItemType] = [Item.ItemType.POTION, Item.ItemType.FOOD]
	
	var check_types: Array[Item.ItemType] = []
	
	if current_type_filter == 1:
		check_types = [Item.ItemType.WEAPON]
	elif current_type_filter == 2:
		check_types = armor_types
	elif current_type_filter == 3:
		check_types = tool_types
	elif current_type_filter == 4:
		check_types = bug_types
	elif current_type_filter == 5:
		check_types = potion_types
	elif current_type_filter == 6:
		check_types = [Item.ItemType.WEAPON]
	
	for item_data in all_item_nodes:
		var item: Item = item_data.item
		var node = item_data.node
		var is_visible = true
		
		# Type filter
		if current_type_filter == 6:
			if item.item_type in check_types:
				is_visible = false			
		elif current_type_filter != 0:
			if item.item_type not in check_types:
				is_visible = false
		
		# Rarity filter
		if is_visible and current_rarity_filter != 0:
			if current_rarity_filter == 1 and item.rarity != Enums.Rarity.COMMON:
				is_visible = false
			elif current_rarity_filter == 2 and item.rarity != Enums.Rarity.UNCOMMON:
				is_visible = false
			elif current_rarity_filter == 3 and item.rarity != Enums.Rarity.RARE:
				is_visible = false
			elif current_rarity_filter == 4 and item.rarity != Enums.Rarity.LEGENDARY:
				is_visible = false
			elif current_rarity_filter == 5 and item.rarity not in [Enums.Rarity.CRAFTED, Enums.Rarity.DIAMOND, Enums.Rarity.GOLDEN]:
				is_visible = false
		
		# Bundle filter (must have ALL selected bundles)
		if is_visible and selected_bundles.size() > 0:
			if item.item_bundle not in selected_bundles:
				is_visible = false

		# Category filter (must have ALL selected categories)
		if is_visible and selected_categories.size() > 0:
			for category in selected_categories:
				if category not in item.categories:
					is_visible = false
					break
		
		# Keyword filter (must have ALL selected keywords)
		if is_visible and selected_keywords.size() > 0:
			for keyword in selected_keywords:
				if keyword not in item.keywords:
					is_visible = false
					break
		
		node.visible = is_visible
		if is_visible:
			visible_count += 1
	
	set_label(visible_count)

func _on_btn_done_mouse_exited() -> void:
	pass

func _on_btn_done_mouse_entered() -> void:
	#AudioManager.play_ui_sound("button_hover")
	pass

func _on_btn_done_pressed() -> void:
	hide_panel()

func hide_panel():
	visible = false

func show_panel():
	visible = true
	if !has_loaded:
		await populate_all_items()
		_setup_category_chips()
		_setup_keyword_chips()
		apply_filters()
		connect_bundle_buttons()
		box_bundles.visible = true
		has_loaded = true

func connect_bundle_buttons():
	bundle_general.pressed.connect(_on_bundle_toggle.bind(Enums.ItemBundles.GENERAL))
	bundle_revenge.pressed.connect(_on_bundle_toggle.bind(Enums.ItemBundles.REVENGE))
	bundle_honor.pressed.connect(_on_bundle_toggle.bind(Enums.ItemBundles.HONOR))
	bundle_greed.pressed.connect(_on_bundle_toggle.bind(Enums.ItemBundles.GREED))

func _on_opt_rarity_item_selected(index: int) -> void:
	current_rarity_filter = index
	apply_filters()

func _on_opt_types_item_selected(index: int) -> void:
	current_type_filter = index
	apply_filters()

func set_label(_count: int):
	lbl_filters.text = "- Showing " + str(_count) + " items. -"

func _setup_category_chips() -> void:
	# Clear existing chips
	for child in category_chips_container.get_children():
		child.queue_free()
	category_buttons.clear()
	
	# Gather all unique categories from items
	var all_categories: Array[String] = []
	for item_data in all_item_nodes:
		var item: Item = item_data.item
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
	
	apply_filters()

func _on_bundle_toggle(_bundle: Enums.ItemBundles) -> void:
	if _bundle in selected_bundles:
		selected_bundles.erase(_bundle)
	else:
		selected_bundles.append(_bundle)
	
	apply_filters()

func _setup_keyword_chips() -> void:
	# Clear existing chips
	for child in keyword_chips_container.get_children():
		child.queue_free()
	keyword_buttons.clear()
	
	# Gather all unique keywords from items
	var all_keywords: Array[String] = []
	for item_data in all_item_nodes:
		var item: Item = item_data.item
		for keyword in item.keywords:
			if keyword not in all_keywords:
				all_keywords.append(keyword)
	
	all_keywords.sort()
	
	# Create a button for each keyword
	for keyword in all_keywords:
		var button = Button.new()
		button.text = keyword
		button.toggle_mode = true
		button.button_pressed = false
		
		# Style as chip
		button.add_theme_stylebox_override("normal", _create_chip_style(false))
		button.add_theme_stylebox_override("pressed", _create_chip_style(true))
		button.add_theme_stylebox_override("hover", _create_chip_style(false, true))
		button.add_theme_font_size_override("font_size", 14)
		
		button.pressed.connect(_on_keyword_chip_toggled.bind(keyword))
		
		keyword_chips_container.add_child(button)
		keyword_buttons[keyword] = button

func _on_keyword_chip_toggled(keyword: String) -> void:
	if keyword in selected_keywords:
		selected_keywords.erase(keyword)
	else:
		selected_keywords.append(keyword)
	
	apply_filters()

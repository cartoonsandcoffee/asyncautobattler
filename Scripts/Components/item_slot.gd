extends Control
class_name ItemSlot

signal drag_started(slot: ItemSlot)
signal drag_ended(slot: ItemSlot)
signal slot_dropped_on(slot: ItemSlot, dragged_item: Item)
signal slot_clicked(slot: ItemSlot)
signal slot_double_clicked()

enum ItemType {
	WEAPON,
	OTHER
}


@onready var panel_border: PanelContainer
@onready var order_container: PanelContainer
@onready var lbl_order: Label 
@onready var lbl_countdown: Label 
@onready var item_icon: TextureRect 
@onready var anim_hover: AnimationPlayer
@onready var anim_highlight: AnimationPlayer
#@onready var tooltip: Control
#@onready var tooltip_panel: Panel
@onready var button: Button
@onready var pic_rarity: TextureRect
@onready var pnl_rarity: Panel
@export var item_type: ItemType = ItemType.OTHER
@export var current_item: Item = null

var item_instance_id: int = -1  # Track the specific instance
var slot_index: int = -1  # to track position
var is_dragging: bool = false  
var is_combat_highlighted: bool = false

# stuff for double click
var click_count: int = 0
var click_timer: float = 0.0
var double_click_time: float = 0.3  # Time window for double-click

var is_from_compendium: bool = false
var gamecolors: GameColors

func _ready() -> void:
	set_references()

func set_references():
	gamecolors = GameColors.new()
	panel_border = $Panel/VBoxContainer/itemContainer
	order_container = $Panel/VBoxContainer/orderContainer
	lbl_order = $Panel/VBoxContainer/orderContainer/MarginContainer/lblOrder
	item_icon = $Panel/VBoxContainer/itemContainer/MarginContainer/item_icon
	anim_hover = $animSelect
	button = $Panel/Button
	anim_highlight = $animHighlight
	pic_rarity = $Panel/pnlRare/picRarity
	pnl_rarity = $Panel/pnlRare
	lbl_countdown = $Panel/VBoxContainer/itemContainer/lblCountdown

	if !button.button_down.is_connected(_on_button_down):
		button.button_down.connect(_on_button_down)

	if !button.button_up.is_connected(_on_button_up):
		button.button_up.connect(_on_button_up)
	
	if !button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

	if !button.gui_input.is_connected(_on_button_gui_input):	
		button.gui_input.connect(_on_button_gui_input)

func set_item(item: Item):
	set_references()

	if item:
		current_item = item
		item_instance_id = item.instance_id  
		update_visuals()
		set_item_type_desc()	
		button.disabled = false
		pnl_rarity.visible = false

		# Initialize countdown display
		if item.trigger_on_occurrence_number > 0:
			lbl_countdown.text = str(item.trigger_on_occurrence_number)
			lbl_countdown.visible = true
		else:
			lbl_countdown.visible = false
	else:
		set_empty()

func set_item_type_desc():
	if current_item:
		match current_item.item_type:
			Item.ItemType.WEAPON:
				lbl_order.text = "weapon"			
			Item.ItemType.BODY_ARMOR:
				lbl_order.text = "armor"
			Item.ItemType.BOOTS:
				lbl_order.text = "boots"
			Item.ItemType.GLOVES:
				lbl_order.text = "gloves"
			Item.ItemType.SHIELD:
				lbl_order.text = "shield"
			Item.ItemType.HELMET:
				lbl_order.text = "helmet"
			Item.ItemType.BELT:
				lbl_order.text = "belt"
			Item.ItemType.POTION:
				lbl_order.text = "potion"
			Item.ItemType.JEWELRY:
				lbl_order.text = "jewelry"
			Item.ItemType.TOME:
				lbl_order.text = "tome"
			Item.ItemType.SCROLL:
				lbl_order.text = "scroll"
			Item.ItemType.RELIC:
				lbl_order.text = "relic"
			Item.ItemType.FOOD:
				lbl_order.text = "food"
			Item.ItemType.BUG:
				lbl_order.text = "bug"
			Item.ItemType.PET:
				lbl_order.text = "pet"
			Item.ItemType.CRYSTAL:
				lbl_order.text = "crystal"
			Item.ItemType.TOOL:
				lbl_order.text = "tool"
			_:
				lbl_order.text = "<other>"

func start_combat_highlight():
	anim_hover.play("hover")
	anim_highlight.play("combat_highlight")

func stop_combat_highlight():
	anim_hover.play("stop")
	anim_highlight.play("stop_highlight")
	
func set_empty():
	current_item = null
	item_instance_id = -1 
	panel_border.self_modulate = Color.WHITE
	button.disabled = true
	pnl_rarity.visible = false
	lbl_countdown.visible = false

func update_visuals():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		if (current_item.item_type == Item.ItemType.WEAPON):
			set_weapon_text_color()
		item_icon.texture = current_item.item_icon
		set_rarity_color()

func set_rarity_color():
	var rarity_common: Texture2D = load("res://Resources/Rarity/common.tres")
	var rarity_uncommon: Texture2D = load("res://Resources/Rarity/uncommon.tres")
	var rarity_rare: Texture2D = load("res://Resources/Rarity/rare.tres")
	var rarity_legendary: Texture2D = load("res://Resources/Rarity/legendary.tres")
	var rarity_mystic: Texture2D = load("res://Resources/Rarity/mystic.tres")


	if current_item.rarity == Enums.Rarity.COMMON:
		pic_rarity.texture = rarity_common
		pic_rarity.self_modulate = gamecolors.rarity.common
		panel_border.self_modulate = gamecolors.rarity.common
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		pic_rarity.texture = rarity_uncommon
		pic_rarity.self_modulate = gamecolors.rarity.uncommon
		panel_border.self_modulate = gamecolors.rarity.uncommon
	elif current_item.rarity == Enums.Rarity.RARE:
		pic_rarity.texture = rarity_rare
		pic_rarity.self_modulate = gamecolors.rarity.rare
		panel_border.self_modulate = gamecolors.rarity.rare
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		pic_rarity.texture = rarity_legendary
		pic_rarity.self_modulate = gamecolors.rarity.legendary
		panel_border.self_modulate = gamecolors.rarity.legendary
	elif current_item.rarity == Enums.Rarity.MYSTERIOUS:
		pic_rarity.texture = rarity_mystic
		pic_rarity.self_modulate = gamecolors.rarity.mysterious
		panel_border.self_modulate = gamecolors.rarity.mysterious
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		pic_rarity.texture = rarity_common
		pic_rarity.self_modulate = gamecolors.rarity.golden
		panel_border.self_modulate = gamecolors.rarity.golden
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		pic_rarity.texture = rarity_common
		pic_rarity.self_modulate = gamecolors.rarity.diamond
		panel_border.self_modulate = gamecolors.rarity.diamond

func set_order(order: int):
	set_references()
	lbl_order.text = str(order)
	slot_index = order - 1 

func set_bonus():
	set_references()
	lbl_order.text = "Set Bonus"
	order_container.visible = false
	panel_border.self_modulate = Color.BLACK
	$Panel.scale = Vector2(0.5, 0.5)

func set_weapon_text_color():
	lbl_order.text = "weapon"
	lbl_order.set("theme_override_colors/font_color", Color("#D9A5A5"))
	order_container.self_modulate = Color("#8a1d1dff")

func get_item_instance() -> Item:
	# Return the specific instance, not just any item
	if current_item and current_item.instance_id == item_instance_id:
		return current_item
	return null

func set_is_from_compendium(_isit: bool):
	is_from_compendium = _isit
	
func show_tooltip():
	if current_item:
		# Use global tooltip manager with item's global position
		TooltipManager.show_item_tooltip(current_item, global_position, size, is_from_compendium)

func update_countdown_display(remaining: int):
	"""Update the countdown label for occurrence-based items"""
	if not current_item:
		lbl_countdown.visible = false
		return
	
	if current_item.trigger_on_occurrence_number > 0:
		if remaining == 0 and current_item.trigger_only_once:
			# Item has triggered and can't trigger again
			lbl_countdown.text = "X"  
			lbl_countdown.modulate = Color.GRAY
			lbl_countdown.visible = true
		elif remaining >= 0:
			lbl_countdown.text = str(remaining)
			lbl_countdown.modulate = Color.WHITE
			lbl_countdown.visible = true
		else:
			lbl_countdown.visible = false
	else:
		lbl_countdown.visible = false

func _on_button_mouse_exited() -> void:
	anim_hover.play("stop")
	CursorManager.reset_cursor()
	TooltipManager.hide_tooltip()  # Use global manager
	panel_border.modulate = Color.WHITE

func _on_button_mouse_entered() -> void:
	if current_item && current_item.item_type != Item.ItemType.SET_BONUS:
		if !button.disabled:
			if current_item && !is_dragging:  # Only if slot has item
				CursorManager.set_item_hover_cursor()
				AudioManager.play_ui_sound("item_hover")
			anim_hover.play("hover")
			show_tooltip()
	if current_item && current_item.item_type == Item.ItemType.SET_BONUS:
		CursorManager.set_interact_cursor()
		show_tooltip()

	if get_parent().has_method("is_dragging"):
		if get_parent().is_dragging():
			panel_border.modulate = Color(1.2, 1.2, 1.2)		

func _on_button_down():
	if CombatManager.combat_active:
		return null  # Disable dragging during combat	
	
	if is_dragging:
		return

	if current_item:
		if current_item.item_type == Item.ItemType.SET_BONUS:
			return
		is_dragging = true
		drag_started.emit(self)
		CursorManager.set_item_grab_cursor()
		AudioManager.play_ui_sound("item_pickup")
		modulate.a = 0.5  # Make semi-transparent while dragging

func _on_button_up():
	if is_dragging:
		is_dragging = false
		drag_ended.emit(self)
		CursorManager.reset_cursor()
		AudioManager.play_ui_sound("item_drop")
		modulate.a = 1.0

func _on_button_pressed():
	click_count += 1
	click_timer = 0.0
	
	if CombatManager.combat_active:
		return false  # Disable dropping during combat



	if click_count == 1:
		# Start timer for potential double-click
		pass
	elif click_count == 2:
		# Double-click detected
		slot_double_clicked.emit()
		click_count = 0



func _on_button_gui_input(event: InputEvent):
	if event is InputEventMouseMotion and is_dragging:
		# Update drag preview position if needed
		CursorManager.set_item_grab_cursor()
		pass

func set_selectable(_set: bool):
	pass #button.disabled = !_set

func _can_drop_data(position: Vector2, data) -> bool:
	# Allow dropping if we're an empty slot or swapping
	return data is Dictionary and data.has("item")

func _drop_data(position: Vector2, data):
	if data.has("from_slot"):
		slot_dropped_on.emit(self, data.item)

func _on_click_timeout():
	if click_count == 1:
		# Single click - emit normal click signal
		slot_clicked.emit(self)

func _process(delta):
	if click_count > 0:
		click_timer += delta
		if click_timer >= double_click_time:
			_on_click_timeout()
			click_count = 0

extends Control
class_name ItemSlot

signal drag_started(slot: ItemSlot)
signal drag_ended(slot: ItemSlot)
signal slot_dropped_on(slot: ItemSlot, dragged_item: Item)


enum ItemType {
	WEAPON,
	OTHER
}


@onready var panel_border: PanelContainer
@onready var order_container: PanelContainer
@onready var lbl_order: Label 
@onready var item_icon: TextureRect 
@onready var anim_hover: AnimationPlayer
@onready var anim_highlight: AnimationPlayer
@onready var tooltip: Control
@onready var tooltip_panel: Panel
@onready var button: Button

@export var item_type: ItemType = ItemType.OTHER
@export var current_item: Item = null

var item_instance_id: int = -1  # Track the specific instance
var slot_index: int = -1  # to track position
var is_dragging: bool = false  
var is_combat_highlighted: bool = false

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
	tooltip = $ToolTip/ItemTooltip
	tooltip_panel = $ToolTip
	button = $Panel/Button
	anim_highlight = $animHighlight

	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	button.gui_input.connect(_on_button_gui_input)

func set_item(item: Item):
	set_references()

	if item:
		current_item = item
		item_instance_id = item.instance_id  
		update_visuals()
		tooltip.set_item(item)
		button.disabled = false
	else:
		set_empty()
	
func start_combat_highlight():
	anim_highlight.play("combat_highlight")

func stop_combat_highlight():
	anim_highlight.play("stop_highlight")
	
func set_empty():
	current_item = null
	item_instance_id = -1 
	panel_border.self_modulate = Color.WHITE
	button.disabled = true


func update_visuals():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		if (current_item.item_type == Item.ItemType.WEAPON):
			set_weapon_text_color()
		item_icon.texture = current_item.item_icon
		set_rarity_color()

func set_rarity_color():
	if current_item.rarity == Enums.Rarity.COMMON:
		panel_border.self_modulate = gamecolors.rarity.common
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		panel_border.self_modulate = gamecolors.rarity.uncommon
	elif current_item.rarity == Enums.Rarity.RARE:
		panel_border.self_modulate = gamecolors.rarity.rare
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		panel_border.self_modulate = gamecolors.rarity.legendary	

func set_order(order: int):
	set_references()
	lbl_order.text = str(order)
	slot_index = order - 1 

func set_weapon_text_color():
	lbl_order.text = "weapon"
	lbl_order.set("theme_override_colors/font_color", Color("#D9A5A5"))
	order_container.self_modulate = Color("#8a1d1dff")

func get_item_instance() -> Item:
	# Return the specific instance, not just any item
	if current_item and current_item.instance_id == item_instance_id:
		return current_item
	return null


func _on_button_mouse_exited() -> void:
	anim_hover.play("stop")
	tooltip_panel.visible = false
	panel_border.modulate = Color.WHITE

func _on_button_mouse_entered() -> void:
	if !button.disabled:
		anim_hover.play("hover")
		tooltip_panel.visible = true

	if get_parent().get_parent().has_method("is_dragging"):
		if get_parent().get_parent().is_dragging():
			panel_border.modulate = Color(1.2, 1.2, 1.2)		

func _on_button_down():
	if current_item:
		is_dragging = true
		drag_started.emit(self)
		modulate.a = 0.5  # Make semi-transparent while dragging

func _on_button_up():
	if is_dragging:
		is_dragging = false
		drag_ended.emit(self)
		modulate.a = 1.0

func _on_button_gui_input(event: InputEvent):
	if event is InputEventMouseMotion and is_dragging:
		# Update drag preview position if needed
		pass

func _can_drop_data(position: Vector2, data) -> bool:
	# Allow dropping if we're an empty slot or swapping
	return data is Dictionary and data.has("item")

func _drop_data(position: Vector2, data):
	if data.has("from_slot"):
		slot_dropped_on.emit(self, data.item)

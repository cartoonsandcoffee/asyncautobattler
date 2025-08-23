extends Control
class_name ItemSlot

enum ItemType {
	WEAPON,
	OTHER
}

@onready var panel_border: PanelContainer
@onready var order_container: PanelContainer
@onready var lbl_order: Label 
@onready var item_icon: TextureRect 
@onready var anim_hover: AnimationPlayer
@onready var tooltip: Control
@onready var tooltip_panel: Panel
@onready var button: Button

@export var item_type: ItemType = ItemType.OTHER
@export var current_item: Item = null

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

func set_item(item: Item):
	set_references()

	if item:
		current_item = item
		update_visuals()
		tooltip.set_item(item)
		button.disabled = false
	else:
		set_empty()
	

func set_empty():
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
	if current_item.rarity == Item.Rarity.COMMON:
		panel_border.self_modulate = gamecolors.rarity.common
	elif current_item.rarity == Item.Rarity.UNCOMMON:
		panel_border.self_modulate = gamecolors.rarity.uncommon
	elif current_item.rarity == Item.Rarity.RARE:
		panel_border.self_modulate = gamecolors.rarity.rare
	elif current_item.rarity == Item.Rarity.LEGENDARY:
		panel_border.self_modulate = gamecolors.rarity.legendary	

func set_order(order: int):
	set_references()
	lbl_order.text = str(order)

func set_weapon_text_color():
	lbl_order.text = "weapon"
	lbl_order.set("theme_override_colors/font_color", Color("#D9A5A5"))
	order_container.self_modulate = Color("#8a1d1dff")

func _on_button_mouse_exited() -> void:
	anim_hover.play("stop")
	tooltip_panel.visible = false

func _on_button_mouse_entered() -> void:
	if !button.disabled:
		anim_hover.play("hover")
		tooltip_panel.visible = true

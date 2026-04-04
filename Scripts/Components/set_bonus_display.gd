extends Control
class_name SetBonusDisplay


@onready var item_icon: TextureRect
@onready var button: Button
@onready var panel_hover: PanelContainer
@onready var shader: ColorRect

@export var current_item: Item = null
@export var recipe: SetBonus = null

var item_instance_id: int = -1  # Track the specific instance
var is_from_compendium: bool = false
var owner_entity = null

var gamecolors: GameColors

func _ready() -> void:
	set_references()

func set_recipe(_recipe: SetBonus):
	recipe = _recipe

func set_references():
	gamecolors = GameColors.new()
	item_icon = $picSetBonus
	button = $picSetBonus/Button
	panel_hover = $panelHover
	shader = $picSetBonus/ShaderRect

	if !button.mouse_entered.is_connected(_on_button_mouse_entered):
		button.mouse_entered.connect(_on_button_mouse_entered)

	if !button.mouse_exited.is_connected(_on_button_mouse_exited):
		button.mouse_exited.connect(_on_button_mouse_exited)

func set_bonus(item: Item):
	set_references()

	if item:
		current_item = item
		item_instance_id = item.instance_id  
		update_visuals()
		button.disabled = false
	else:
		set_empty()

func turn_off_shader():
	shader.visible = false

func set_empty():
	current_item = null
	item_instance_id = -1 
	button.disabled = true
	turn_off_shader()

func update_visuals():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		item_icon.texture = current_item.item_icon

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
		TooltipManager.show_setbonus_tooltip(current_item, global_position, size, is_from_compendium, recipe)

func _on_button_mouse_exited() -> void:
	panel_hover.visible = false
	CursorManager.reset_cursor()
	TooltipManager.hide_tooltip()  # Use global manager

func _on_button_mouse_entered() -> void:
	if current_item && current_item.item_type == Item.ItemType.SET_BONUS:
		panel_hover.visible = true
		CursorManager.set_interact_cursor()
		show_tooltip()

## USED FOR CUSTOM SELECTOR CONTROL

extends Control
class_name ChoiceOption

@export var choice_text: String = "Option" : set = set_choice_text
@export var choice_color: Color = Color.WHITE : set = set_choice_color  
@export var choice_value: int = 0

@onready var button: Button = $Button

signal choice_selected(value: int, option: ChoiceOption)

func _ready():
	if not button:
		button = $Button

	if button:
		setup_button()

func setup_button():
	button.text = choice_text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(100, 25)
	button.pressed.connect(_on_button_pressed)
	
	# Apply color styling
	_update_button_style(false)

func _on_button_pressed():
	choice_selected.emit(choice_value, self)

func set_selected(selected: bool):
	if button:
		button.button_pressed = selected
		_update_button_style(selected)

func is_selected() -> bool:
	return button.button_pressed if button else false

func set_choice_text(value: String):
	choice_text = value
	if button:
		button.text = value

func set_choice_color(value: Color):
	choice_color = value
	if button:
		_update_button_style(button.button_pressed)

func _update_button_style(is_selected: bool):
	var style_normal = StyleBoxFlat.new()
	
	if is_selected:
		# Selected: use choice_color at full intensity
		style_normal.bg_color = choice_color
		button.add_theme_color_override("font_color", Color.WHITE)
	else:
		# Unselected: desaturated version of choice_color
		style_normal.bg_color = choice_color.darkened(0.6)
		button.add_theme_color_override("font_color", choice_color.lightened(0.3))
	
	# Border styling
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = choice_color.lightened(0.2)
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	
	# Hover state
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = choice_color.lightened(0.2)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_normal)


extends Control
class_name ChoiceSelector

@export var default_selection_value: int = -1
@export var allow_deselection: bool = false

signal selection_changed(value: int, option: ChoiceOption)
signal no_selection()

var choice_options: Array[ChoiceOption] = []
var selected_option: ChoiceOption = null
var button_group: ButtonGroup

@onready var container: HBoxContainer = $HBoxContainer

func _ready():
	setup_button_group()
	collect_choice_options()
	setup_initial_selection()

func setup_button_group():
	button_group = ButtonGroup.new()
	if allow_deselection:
		button_group.allow_unpress = true

func collect_choice_options():
	"""Find all ChoiceOption children and set them up."""
	choice_options.clear()
	
	for child in container.get_children():
		if child is ChoiceOption:
			var option = child as ChoiceOption
			option.setup_button()
			choice_options.append(option)
			
			# Add to button group
			option.button.button_group = button_group
			
			# Connect signal
			option.choice_selected.connect(_on_choice_selected)

func setup_initial_selection():
	"""Select default option if specified."""
	if default_selection_value == -1:
		return
		
	for option in choice_options:
		if option.choice_value == default_selection_value:
			select_option_by_value(default_selection_value)
			break

func _on_choice_selected(value: int, option: ChoiceOption):
	var was_selected = (selected_option == option)
	
	if allow_deselection and was_selected:
		# Deselecting current option
		selected_option = null
		no_selection.emit()
	else:
		# Selecting new option
		selected_option = option
		selection_changed.emit(value, option)

func select_option_by_value(value: int) -> bool:
	"""Programmatically select option by value. Returns true if found."""
	for option in choice_options:
		if option.choice_value == value:
			option.set_selected(true)
			selected_option = option
			return true
	return false

func select_option_by_index(index: int) -> bool:
	"""Programmatically select option by index. Returns true if valid."""
	if index >= 0 and index < choice_options.size():
		choice_options[index].set_selected(true)
		selected_option = choice_options[index]
		return true
	return false

func get_selected_value() -> int:
	return selected_option.choice_value if selected_option else -1

func get_selected_option() -> ChoiceOption:
	return selected_option

func clear_selection():
	if button_group:
		var pressed_button = button_group.get_pressed_button()
		if pressed_button:
			pressed_button.button_pressed = false
	selected_option = null
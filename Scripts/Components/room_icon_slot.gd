class_name RoomIconSlot
extends Control

signal icon_clicked(room_index: int)

var room_index: int = 0
var room_data: RoomData = null
var is_boss: bool = false
var is_current_room: bool = false

@onready var texture_rect: TextureRect = $Panel/MarginContainer/TextureRect
@onready var border: Panel = $Panel
@onready var icon_button: Button = $Panel/MarginContainer/Button

# Icon resources
var question_mark_texture: AtlasTexture
var crown_texture: AtlasTexture

func _ready():
	set_references()

func set_references():
	_setup_visuals()
	_load_icons()

func _setup_visuals():
	texture_rect = $Panel/MarginContainer/TextureRect
	border = $Panel
	icon_button = $Panel/MarginContainer/Button
	
	if not icon_button.pressed.is_connected(_on_button_pressed):
		icon_button.pressed.connect(_on_button_pressed)

	if not icon_button.mouse_entered.is_connected(_on_mouse_entered):
		icon_button.mouse_entered.connect(_on_mouse_entered)

	if not icon_button.mouse_exited.is_connected(_on_mouse_exited):
		icon_button.mouse_exited.connect(_on_mouse_exited)


func _load_icons():
	# Load question mark icon
	question_mark_texture = preload("res://Resources/Icons/icon_question.tres")
	# Load crown icon for boss
	crown_texture = preload("res://Resources/Icons/icon_crown.tres")


func set_visited_room(data: RoomData):
	room_data = data
	is_boss = false
	
	if room_data and room_data.room_definition:
		texture_rect.texture = room_data.room_definition.room_icon
		texture_rect.modulate = room_data.room_definition.room_color
		_set_border(room_data.room_definition.room_color, 2)
		
		# Set tooltip
		icon_button.tooltip_text = room_data.room_definition.room_name + "\n" + room_data.room_definition.room_desc

func set_boss_room():
	is_boss = true
	room_data = null
	
	texture_rect.texture = crown_texture
	texture_rect.modulate = Color.GOLD
	_set_border(Color.GOLD, 2)
	icon_button.tooltip_text = "Boss Room - Coming Soon"

func set_unknown():
	room_data = null
	is_boss = false
	
	texture_rect.texture = question_mark_texture
	texture_rect.modulate = Color.WHITE
	_set_border(Color.DARK_GRAY, 2)
	icon_button.tooltip_text = "Unexplored"

func set_current(is_current: bool):
	is_current_room = is_current
	
	if is_current:
		# Add glow effect
		var style = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color.YELLOW
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		border.add_theme_stylebox_override("panel", style)
	else:
		_set_border(texture_rect.modulate, 2)

func _set_border(color: Color, bsize: int):
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.border_width_left = bsize
	style.border_width_right = bsize
	style.border_width_top = bsize
	style.border_width_bottom = bsize
	border.add_theme_stylebox_override("panel", style)

func set_room_type(room_data: RoomData):
	"""Display abstract room type icon (for future/current rooms)"""
	if not room_data or not room_data.room_definition:
		set_unknown()
		return
	
	var room_def = room_data.room_definition
	
	# Set abstract type icon
	if room_def.room_icon:
		texture_rect.texture = room_def.room_icon
	else:
		texture_rect.texture = question_mark_texture
	
	# Set type color
	texture_rect.modulate = room_def.room_color
	
	# Show combat indicator if room has combat
	if room_data.has_combat_this_instance:
		# TODO: Add combat indicator overlay (sword icon)
		# For now, just slightly darken rooms with combat
		texture_rect.modulate = texture_rect.modulate.darkened(0.2)
	
	# Set border
	_set_border(Color(0.4, 0.4, 0.4), 2)

	# Set tooltip
	tooltip_text = room_def.room_name

func _on_button_pressed():
	if is_boss:
		# Boss room clicked - show panel
		icon_clicked.emit(room_index)
	elif room_data:
		pass
		# Visited room - just show tooltip on hover

func _on_mouse_entered():
	# Could add hover effect here
	pass

func _on_mouse_exited():
	# Remove hover effect
	pass

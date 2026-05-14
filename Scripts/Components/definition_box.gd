extends Control

@onready var keyword_label: Label 
@onready var desc_label: Label 
@onready var anim_player: AnimationPlayer
@onready var pic_icon: TextureRect 
@onready var panel_container: PanelContainer

func set_references():
	keyword_label = $PanelContainer/MarginContainer2/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/lblKeyword
	desc_label = $PanelContainer/MarginContainer2/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/lblDefinition
	anim_player = $AnimationPlayer
	pic_icon = $PanelContainer/MarginContainer2/PanelContainer/MarginContainer/HBoxContainer/picIcon
	panel_container = $PanelContainer

func setup(keyword: String, description: String, color: Color):
	set_references()
	keyword_label.text = keyword.capitalize() + ":"
	keyword_label.modulate = color
	desc_label.text = description
	hide_pic()

func hide_pic():
	pic_icon.visible = false

func show_pic(pic: Texture, color: Color):
	pic_icon.texture = pic
	pic_icon.modulate = color
	pic_icon.visible = true

func justify_left():
	keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func justify_right():
	keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func show_def():
	anim_player.play("tooltip_show")

func set_min_width(min_width: float = 0.0):
	panel_container.custom_minimum_size.x = min_width

extends Control

@onready var keyword_label: Label 
@onready var desc_label: RichTextLabel 
@onready var anim_player: AnimationPlayer 

func set_references():
	keyword_label = $PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/lblKeyword
	desc_label = $PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/lblDefinition
	anim_player = $AnimationPlayer

func setup(keyword: String, description: String, color: Color):
	set_references()
	keyword_label.text = keyword.capitalize() + ":"
	keyword_label.modulate = color
	desc_label.text = description

func justify_left():
	keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func justify_right():
	keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func show_def():
	anim_player.play("tooltip_show")
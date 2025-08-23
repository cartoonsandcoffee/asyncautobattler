extends Control

@onready var keyword_label: Label = $PanelContainer/MarginContainer/VBoxContainer/lblKeyword
@onready var desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/lblDefinition

func set_references():
	keyword_label = $PanelContainer/MarginContainer/VBoxContainer/lblKeyword
	desc_label = $PanelContainer/MarginContainer/VBoxContainer/lblDefinition

func setup(keyword: String, description: String, color: Color):
	set_references()
	keyword_label.text = keyword.capitalize() + ":"
	keyword_label.modulate = color
	desc_label.text = description

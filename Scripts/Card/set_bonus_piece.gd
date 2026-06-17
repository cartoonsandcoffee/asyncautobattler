extends Control

@onready var lbl_name: Label 
@onready var pic_item: TextureRect
var _refs_set: bool = false

func set_references():
	if _refs_set:
		return
	_refs_set = true	
	
	lbl_name = $PanelContainer/VBoxContainer/lblName
	pic_item = $PanelContainer/VBoxContainer/picItem


func setup(ingredient: Item):
	set_references()
	lbl_name.text = ingredient.item_name
	#lbl_name.modulate = ingredient.item_color
	pic_item.texture = ingredient.item_icon
	pic_item.modulate = ingredient.item_color


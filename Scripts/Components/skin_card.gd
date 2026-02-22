extends Control
class_name SkinCard 

@onready var lbl_name: Label
@onready var lbl_action: Label
@onready var lbl_cost: Label
@onready var pic_ear: TextureRect
@onready var pic_skin: TextureRect

var skin_id = 0
var _skin: SkinData

func set_references() -> void:
	lbl_name = $Panel/PanelContainer/VBoxContainer/lblSkinName
	lbl_action = $Panel/PanelContainer/VBoxContainer/costBox/lblLabel
	lbl_cost = $Panel/PanelContainer/VBoxContainer/costBox/lblPrice
	pic_ear = $Panel/PanelContainer/VBoxContainer/costBox/picEar
	pic_skin = $Panel/PanelContainer/VBoxContainer/picSkin

func set_unlocked():
	var is_unlocked := SkinManager.is_unlocked(_skin.skin_id)
	var is_selected := SkinManager.selected_skin_id == _skin.skin_id

	if is_selected:
		lbl_action.text = "Equipped"
		lbl_cost.visible = false
		pic_ear.visible = false
	elif is_unlocked:
		lbl_action.text = "Equip"
		lbl_cost.visible = false
		pic_ear.visible = false
	else:
		lbl_cost.visible = true
		pic_ear.visible = true
		lbl_action.text = "Pay"

func set_labels():
	lbl_name.text = _skin.display_name
	lbl_cost.text = str(_skin.cost)
	
func setup(skin: SkinData):
	set_references()
	_skin = skin
	pic_skin.texture = _skin.sprite
	pic_skin.modulate = Player.skin_color
	set_labels()
	set_unlocked()

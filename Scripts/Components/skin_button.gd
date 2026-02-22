extends Control
class_name SkinButton

signal buy_pressed()
signal select_pressed()
signal hover_on()
signal hover_out()

@onready var pic_button: TextureRect
@onready var btn_action: Button

var _skin: SkinData

var LOCKED_ICON:Texture2D = load("res://Assets/UI/Locked.png")

func set_references():
	pic_button = $MarginContainer/picButton
	btn_action = $Button

func setup(skin: SkinData):
	set_references()
	_skin = skin

	if SkinManager.is_unlocked(_skin.skin_id):
		pic_button.texture = _skin.skin_icon
	else:
		pic_button.texture = LOCKED_ICON

	btn_action.pressed.connect(_on_action_pressed)

func _on_button_mouse_exited() -> void:
	hover_out.emit()

func _on_button_mouse_entered() -> void:
	hover_on.emit()

func _on_action_pressed() -> void:
	if SkinManager.is_unlocked(_skin.skin_id):
		select_pressed.emit()
	else:
		buy_pressed.emit()
extends Control
class_name CustomStoreButton

signal button_clicked(button_string: String)
signal button_entered()
signal button_exited()

@onready var button: Button = $PanelStore/Button
@onready var anim_player: AnimationPlayer = $animMain
@onready var anim_hover: AnimationPlayer = $animHover
@onready var pic_button: TextureRect = $PanelStore/picStore

@export var button_image: AtlasTexture = null
@export var button_string: String = ""

func _on_button_pressed() -> void:
	button_clicked.emit(button_string)

func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_hover.play("RESET")
	button_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_hover.play("hover")
	button_entered.emit()

func show_button():
	if button_image:
		pic_button.texture = button_image
	anim_player.play("appear")


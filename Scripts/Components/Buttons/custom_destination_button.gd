extends Control
class_name CustomDestinationButton

signal button_entered()
signal button_exited()
signal destination_chosen(dest_string: String)

var destination_id: String = ""

@onready var button: Button = $PanelHolder/Button
@onready var anim_player: AnimationPlayer = $animMain
@onready var anim_hover: AnimationPlayer = $animHover
@onready var pic_button: TextureRect = $PanelHolder/picCutton

func _on_button_pressed() -> void:
	destination_chosen.emit(destination_id)

func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_hover.play("RESET")
	button_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_hover.play("hover")
	button_entered.emit()

func setup(dest_id: String, label: String, icon_tex: Texture2D = null) -> void:
	destination_id = dest_id
	button.tooltip_text = label
	if icon_tex:
		pic_button.texture = icon_tex

	anim_player.play("appear")
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

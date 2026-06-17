extends Control
class_name CustomNextPrevButton

signal button_entered()
signal button_exited()
signal button_clicked()

@onready var button: Button = $PanelContainer/Button
@onready var anim_hover: AnimationPlayer = $animHover
@onready var pic_button: TextureRect = $PanelContainer/picButton

@export var flip_horizontal: bool = false

func _on_button_pressed() -> void:
	CursorManager.reset_cursor()
	anim_hover.play("click")
	button_clicked.emit()

func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_hover.play("RESET")
	button_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_hover.play("hover")
	button_entered.emit()

func _ready() -> void:
	pic_button.flip_h = flip_horizontal
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

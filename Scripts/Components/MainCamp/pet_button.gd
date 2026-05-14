extends Control

signal button_clicked()
signal button_entered()
signal button_exited()

@onready var button: Button = $picButton/btnPet
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

func _on_button_pressed() -> void:
	button_clicked.emit()


func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_player.play("hide_hover")
	button_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_player.play("show_hover")
	button_entered.emit()

func is_enabled(_on_or_off: bool):
	visible = _on_or_off

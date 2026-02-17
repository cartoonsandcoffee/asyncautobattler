extends Control

signal button_clicked()

@onready var button: Button = $Panel/PanelContainer/Button
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _on_button_pressed() -> void:
	button_clicked.emit()


func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_player.play("shop")

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_player.play("hover")

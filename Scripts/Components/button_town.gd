extends Control

signal button_clicked()
signal button_entered()
signal button_exited()

@onready var button: Button = $Panel/PanelContainer/Button
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _on_button_pressed() -> void:
	button_clicked.emit()


func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_player.play("shop")
	button_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_player.play("hover")
	button_entered.emit()

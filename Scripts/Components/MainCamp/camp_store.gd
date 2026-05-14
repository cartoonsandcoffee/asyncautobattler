extends Control

signal button_clicked()
signal button_entered()
signal button_exited()

@onready var button: Button = $controlMain/PanelContainer/picMain/Button
@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var anim_hover: AnimationPlayer = $animHover

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

func _on_button_pressed() -> void:
	button_clicked.emit()


func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_player.play("mouse_exit")
	#anim_hover.play("stop_hover")
	button_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_player.play("mouse_over")
	#anim_hover.play("hover")
	button_entered.emit()

#func stop_hover_anim():
#	anim_hover.play("stop_hover")

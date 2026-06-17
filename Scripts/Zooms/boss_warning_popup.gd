extends Control

@onready var button: Button = $PanelContainer/Button
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	button.pressed.connect(button_pressed)

func show_popup():
	anim_player.play("show_popup")

func button_pressed():
	anim_player.play("hide_popup")
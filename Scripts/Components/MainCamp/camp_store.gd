extends Control

signal button_clicked()
signal button_entered()
signal button_exited()

@onready var button: Button = $controlMain/PanelContainer/picMain/Button
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_detail: AnimationPlayer
@onready var pic_unavail: TextureRect
@onready var audio_player: AudioStreamPlayer2D

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

func _on_button_pressed() -> void:
	button_clicked.emit()

func set_available(is_avail: bool):
	pic_unavail = $controlMain/PanelContainer/picUnavail
	pic_unavail.visible = !is_avail

func check_available() -> bool:
	if pic_unavail and pic_unavail != null:
		return !pic_unavail.visible
	return true

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

func play_detail_anim():
	anim_detail = $animDetail
	if anim_detail and anim_detail != null:
		anim_detail.play("play_detail")

func load_sound():
	audio_player = $AudioStreamPlayer2D
	if audio_player and audio_player != null:
		audio_player.play()
		
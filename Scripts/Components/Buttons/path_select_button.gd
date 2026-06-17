extends Button
class_name PathSelectButton

signal path_selected(index: int)
signal path_hovered(index: int)
signal path_hover_exited(index: int)

@onready var pic_active: TextureRect = $buttonAnimHolder/picSelected
@onready var anim_player:AnimationPlayer = $AnimationPlayer

@export var active_texture:Texture2D
@export var path_index:int = 0

var is_selected: bool = false
var _is_locked: bool = false

func _ready() -> void:
	pic_active.texture = active_texture
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	AudioManager.play_ui_sound("button_hover")
	if not is_selected:
		anim_player.play("hover")
	path_hovered.emit(path_index)

func _on_mouse_exited() -> void:
	if not is_selected:
		anim_player.play("unhover")
	path_hover_exited.emit(path_index)

func _on_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	path_selected.emit(path_index)

func set_active(_active: bool) -> void:
	is_selected = _active
	if _active:
		anim_player.play("selected")
	else:
		anim_player.play("unselected")

func set_locked(locked: bool) -> void:
	_is_locked = locked
	visible = !locked
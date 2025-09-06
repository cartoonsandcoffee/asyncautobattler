extends Control
class_name CombatTurnSign

signal turn_animation_done()

@onready var lbl_main: Label = $Panel/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/lblMain
@onready var panel_main: Panel = $Panel
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var gamecolors: GameColors
var is_showing: bool = false

var time_elapsed: float = 0.0
var timer_duration: float = 2.0

func set_references():
	gamecolors = GameColors.new()
	lbl_main = $Panel/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/lblMain
	progress_bar = $Panel/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar
	anim_player = $AnimationPlayer

func _process(delta: float) -> void:
	if is_showing:
		time_elapsed += delta
		progress_bar.value = (time_elapsed/timer_duration)
		if time_elapsed >= timer_duration:
			_on_timer_timeout()

func set_label(value: String):
	set_references()
	lbl_main.text =  value 
	start_timer()

func set_timer(_sec: float):
	timer_duration = _sec

func start_timer():
	is_showing = true
	anim_player.play("fade_in")
	time_elapsed = 0.0

func _done():
	await anim_player.animation_finished
	is_showing = false

	anim_player.play("hide")
	turn_animation_done.emit()

	await anim_player.animation_finished
	queue_free()

func fade_in():
	anim_player.play("fade_in")

func fade_out():
	anim_player.play("fade_out")


func _on_timer_timeout() -> void:
	is_showing = false
	fade_out()

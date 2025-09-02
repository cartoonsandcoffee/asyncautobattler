extends Control
class_name CombatTurnSign

signal turn_animation_done()

@onready var lbl_main: Label = $Panel/PanelContainer/MarginContainer/lblMain
@onready var panel_main: PanelContainer = $Panel/PanelContainer
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var gamecolors: GameColors

func set_references():
	gamecolors = GameColors.new()
	lbl_main = $Panel/PanelContainer/MarginContainer/lblMain
	panel_main = $Panel/PanelContainer
	anim_player = $AnimationPlayer



func set_label(value: String):
	set_references()
	lbl_main.text =  value 


func _done():
	await anim_player.animation_finished
	
	anim_player.play("hide")
	turn_animation_done.emit()

	await anim_player.animation_finished
	queue_free()

func fade_in():
	anim_player.play("fade_in")

func fade_out():
	anim_player.play("fade_out")
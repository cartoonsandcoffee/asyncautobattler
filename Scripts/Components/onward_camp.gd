class_name OnwardOrCamp
extends Control

signal chose_camp()
signal chose_onward()

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_onward: AnimationPlayer = $animOnward
@onready var anim_camp: AnimationPlayer = $animCamp
@onready var anim_onward2: AnimationPlayer = $animOnward2
@onready var anim_camp2: AnimationPlayer = $animCamp2




func _on_btn_camp_pressed() -> void:
	anim_player.play("hide_popup")
	await anim_player.animation_finished
	CursorManager.reset_cursor()
	chose_camp.emit()

func _on_btn_onward_pressed() -> void:
	anim_player.play("hide_popup")
	await anim_player.animation_finished
	CursorManager.reset_cursor()
	chose_onward.emit()

func _on_btn_camp_mouse_entered() -> void:
	anim_camp2.play("camp_hover")
	CursorManager.set_interact_cursor()

func _on_btn_camp_mouse_exited() -> void:
	anim_camp2.play("camp_unhover")
	CursorManager.reset_cursor()

func _on_btn_onward_mouse_exited() -> void:
	anim_onward2.play("onward_unhighlight")
	CursorManager.reset_cursor()

func _on_btn_onward_mouse_entered() -> void:
	anim_onward2.play("onward_highlight")
	CursorManager.set_interact_cursor()

func play_camp_hover():
	anim_camp.play("camp_idle")

func play_onward_hover():
	anim_onward.play("onward_idle")

func show_popup():
	anim_player.play("show_popup")


func play_camp_show():
	anim_camp.play("camp_show")

func play_onward_show():
	anim_onward.play("onward_show")

func reset_anims():
	anim_onward.play("RESET")
	anim_onward2.play("RESET")
	anim_camp.play("RESET")
	anim_camp2.play("RESET")
	anim_player.play("RESET")
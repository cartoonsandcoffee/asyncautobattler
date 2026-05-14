class_name FightOrFlee
extends Control

signal chose_fight()
signal chose_run()

@onready var anim_panel: AnimationPlayer = $animPanel
@onready var anim_fight: AnimationPlayer = $animFight
@onready var anim_run: AnimationPlayer = $animRun
@onready var instant_toggle: Control = $dimBack/centerBox/toggleInstant/instant_combat_toggle

@onready var btn_fight: Button = $dimBack/centerBox/choiceFight/fightColor/btnFight
@onready var btn_run: Button = $dimBack/centerBox/choiceFlee/runColor/btnRun

var can_run: bool = true
var is_boss: bool = false

func _on_btn_fight_pressed() -> void:
	#AudioManager.play_ui_sound("combat_footstep")
	anim_panel.play("hide_popup")
	await anim_panel.animation_finished
	CursorManager.reset_cursor()
	chose_fight.emit()

func _on_btn_run_pressed() -> void:
	#AudioManager.play_ui_sound("combat_footstep")
	anim_panel.play("hide_popup")
	await anim_panel.animation_finished
	CursorManager.reset_cursor()
	chose_run.emit()

func buttons_active() -> bool:
	if !btn_fight.disabled && !can_run:
		return true
	elif !btn_fight.disabled && !btn_run.disabled:
		return true
	else:
		return false 

func _on_btn_fight_mouse_exited() -> void:
	if buttons_active():
		CursorManager.reset_cursor()
		anim_run.play("run_back_to_normal")

func _on_btn_run_mouse_exited() -> void:
	if buttons_active():
		CursorManager.reset_cursor()
		anim_fight.play("fight_back_to_normal")

func _on_btn_fight_mouse_entered() -> void:
	if buttons_active():	
		CursorManager.set_interact_cursor()
		anim_run.play("run_deselect")

func _on_btn_run_mouse_entered() -> void:
	if buttons_active():
		CursorManager.set_interact_cursor()
		anim_fight.play("fight_deselect")

func play_fight_idle():
	anim_fight.play("fight_idle")

func play_run_idle():
	anim_run.play("run_idle")

func show_popup(_can_run: bool = true, _is_boss: bool = false):
	can_run = _can_run
	anim_fight.play("RESET")
	anim_run.play("RESET")

	instant_toggle.visible = !_is_boss

	await get_tree().process_frame
	anim_panel.play("show_popup")
	await anim_panel.animation_finished
	
	if _is_boss:
		btn_run.tooltip_text = "You cannot flee, this is inevitable!"
		btn_run.disabled = true
		anim_run.play("show_run_broken")
	elif !can_run:
		btn_run.tooltip_text = "Enemy is too fast to escape!"
		btn_run.disabled = true
		anim_run.play("show_run_broken")
	else:
		btn_run.tooltip_text = "Flee from combat"
		btn_run.disabled = false
		anim_run.play("show_run")

	anim_fight.play("show_fight")
	await anim_run.animation_finished

func impact_sfx():
	AudioManager.play_ui_sound("combat_player_hit_heavy")

class_name OnwardButton
extends Control

signal chose_camp()
signal chose_onward()

@onready var anim_onward: AnimationPlayer = $animOnward
@onready var anim_camp: AnimationPlayer = $animCampHover
@onready var anim_camp_idle: AnimationPlayer = $animCampIdle
@onready var anim_popup: AnimationPlayer = $animPopup
@onready var onward_control: TextureRect = $OnwardControl/picOnward

@onready var btn_onward: Button = $OnwardControl/picOnward/btnOnward
@onready var btn_camp: Button = $CampControl/controlMain/PanelContainer/picButton/btnCamp
@onready var particles: CPUParticles2D = $OnwardControl/picOnward/DoorCenterPoint/CPUParticles2D

func _ready() -> void:
	btn_onward.pressed.connect(_on_btn_onward_pressed)
	btn_onward.mouse_entered.connect(_on_btn_onward_mouse_entered) 
	btn_onward.mouse_exited.connect(_on_btn_onward_mouse_exited)

	btn_camp.pressed.connect(_on_btn_camp_pressed)
	btn_camp.mouse_entered.connect(_on_btn_camp_mouse_entered)
	btn_camp.mouse_exited.connect(_on_btn_camp_mouse_exited)

func _on_btn_camp_pressed() -> void:
	anim_popup.play("hide_popup")
	await anim_popup.animation_finished
	CursorManager.reset_cursor()
	chose_camp.emit()

func _on_btn_onward_pressed() -> void:
	anim_popup.play("hide_popup")
	await anim_popup.animation_finished
	CursorManager.reset_cursor()
	chose_onward.emit()

func _on_btn_camp_mouse_entered() -> void:
	if !btn_camp.disabled:
		anim_camp.play("show_hover")
		CursorManager.set_interact_cursor()

func _on_btn_camp_mouse_exited() -> void:
	if !btn_camp.disabled:	
		anim_camp.play("hide_hover")
		anim_camp_idle.pause()
		CursorManager.reset_cursor()

func _on_btn_onward_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_onward_mouse_entered() -> void:
	particles.emitting = true
	CursorManager.set_navigation_cursor()

func play_camp_idle():
	anim_camp_idle.play("camp_idle")

func show_popup(_color: Color = Color.WHITE):
	onward_control.modulate = _color	
	anim_popup.play("show_popup")
	#await anim_popup.animation_finished
	anim_camp.play("show_camp")
	anim_onward.play("show_onward")

func reset_anims():
	anim_onward.play("RESET")
	anim_camp.play("RESET")
	anim_camp_idle.play("RESET")
	anim_popup.play("RESET")
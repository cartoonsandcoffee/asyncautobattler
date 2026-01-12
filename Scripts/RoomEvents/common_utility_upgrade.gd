class_name CommonUtilityUpgradeRoom
extends RoomEvent


@onready var button: Button = $mainEvent/Button
@onready var lbl_action: Label = $mainEvent/lblAction
@onready var anim_label: AnimationPlayer = $animText
@onready var anim_guy: AnimationPlayer = $animGuy
@onready var anim_event: AnimationPlayer = $animEvent
@onready var upgrade_weapon: UpgradeWeaponStats = $UpgradeWeaponStats

func _ready() -> void:
	super._ready()  # Call parent's _ready

func initialize_event():
	upgrade_weapon.bonus_completed.connect(_on_bonus_complete)

func start_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func play_idle():
	anim_guy.play("guy_idle")

func _on_bonus_complete():
	complete_bonus()

func complete_bonus():
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func enable_button():
	button.disabled = false

func _on_button_pressed() -> void:
	if upgrade_weapon.visible == false:
		AudioManager.play_event_sound("mmm")
		CursorManager.reset_cursor()
		button.disabled = true
		upgrade_weapon.show_popup()

func _on_button_mouse_exited() -> void:
	if upgrade_weapon.visible == false:
		CursorManager.reset_cursor()

func _on_button_mouse_entered() -> void:
	if upgrade_weapon.visible == false:
		CursorManager.set_talk_cursor()
		AudioManager.play_event_sound("ooo")

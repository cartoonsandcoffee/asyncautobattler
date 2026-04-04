class_name HallwayEvent_Gold
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_labels: AnimationPlayer = $animLabel
@onready var anim_items: AnimationPlayer = $animItems
@onready var button: Button = $picEvent/btnEvent

@onready var particles: CPUParticles2D = $particles
@onready var panel_pop: PanelContainer = $panelDone
@onready var lbl_gold: Label = $panelDone/PanelContainer/VBoxContainer/Label

const GOLD_REWARD: int = 10

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func disable_button():
	button.disabled = true

func complete_hallway():
	disable_button()
	AudioManager.play_ui_sound("popup_close")
	anim_items.play("hide_items")
	await anim_items.animation_finished

	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()


func _on_btn_event_pressed() -> void:
	disable_button()
	particles.emitting = false
	CursorManager.reset_cursor()
	lbl_gold.text = "You find " + str(GOLD_REWARD + Player.current_rank) + " gold!"
	AudioManager.play_event_sound("coins_fall")
	anim_labels.play("hide_label")
	anim_items.play("show_items")

func _on_btn_event_mouse_exited() -> void:
	if panel_pop.visible == false:
		CursorManager.reset_cursor()
		anim_labels.play("hide_label")

func _on_btn_event_mouse_entered() -> void:
	if panel_pop.visible == false && !button.disabled:	
		AudioManager.play_ui_sound("woosh")
		CursorManager.set_interact_cursor()
		anim_labels.play("show_label")


func _on_button_pressed() -> void:
	Player.add_gold(GOLD_REWARD + Player.current_rank)
	complete_hallway()
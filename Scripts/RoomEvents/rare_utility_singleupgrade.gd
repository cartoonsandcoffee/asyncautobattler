class_name SuperUpgradeEvent
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_label: AnimationPlayer = $animLabel
@onready var button: Button = $picEvent/btnEvent
@onready var item_combiner: ItemCombiner = $ItemCombiner

@onready var particles: CPUParticles2D = $Particles

func _ready():
	print("super_upgrade -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("super_upgrade -> initialize_event")

func _run_room_event():
	print("super_upgrade -> _run_room_event (post-combat)")
	item_combiner.item_skipped.connect(_on_item_skipped)
	button.disabled = false
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_item_skipped():
	await item_combiner.hide_popup()
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()


func _on_btn_event_pressed() -> void:
	disable_button()
	particles.emitting = false
	anim_label.play("hide_label")
	CursorManager.reset_cursor()
	item_combiner.show_popup()

func _on_btn_event_mouse_entered() -> void:
	if item_combiner.visible == false:	
		CursorManager.set_talk_cursor()
		AudioManager.play_random_voice()
		anim_label.play("show_label")

func _on_btn_event_mouse_exited() -> void:
	if item_combiner.visible == false:
		CursorManager.reset_cursor()
		anim_label.play("hide_label")

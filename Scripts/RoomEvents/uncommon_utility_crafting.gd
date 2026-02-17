class_name CraftingRoomEvent
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_text: AnimationPlayer = $animText
@onready var anim_box: AnimationPlayer = $animBox
@onready var button: Button = $Control/picCauldron/Button
@onready var item_combiner: ItemOffering = $FreeItemOffering

@onready var particles: CPUParticles2D = $Control/gut_particles

func _ready():
	print("crafting_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("crafting_room_event -> initialize_event")
	item_combiner.item_skipped.connect(_on_item_skipped)

func _run_room_event():
	print("crafting_room_event -> _run_room_event (post-combat)")
	item_combiner.item_skipped.connect(_on_item_skipped)
	item_combiner.item_selected.connect(_need_item_replace)
	item_combiner.need_item_replace.connect(_need_item_replace)
	button.disabled = false
	show_event()

func show_event():
	anim_event.play("show_event")

func play_idle():
	anim_event.play("event_idle")

func show_text():
	anim_text.play("show_text")

func hide_text():
	anim_text.play("hide_text")

func disable_button():
	button.disabled = true

func _on_button_mouse_exited() -> void:
	if item_combiner.visible == false:
		CursorManager.reset_cursor()
		anim_text.play("hide_text")

func _on_button_mouse_entered() -> void:
	if item_combiner.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_ui_sound("woosh")
		anim_text.play("show_text")

func _on_button_pressed() -> void:
	disable_button()
	particles.emitting = false
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("corpse")
	anim_text.play("hide_text")
	anim_box.play("show_box")

func _need_item_replace(item: Item):
	_on_item_skipped()

func _on_item_skipped():
	anim_box.play("hide_box")
	await anim_box.animation_finished
	anim_event.play("hide_animation")
	await anim_event.animation_finished

	complete_event()

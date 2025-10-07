class_name AltarRoomEvent
extends RoomEvent

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var button: Button = $picEvent/Button
@onready var item_combiner: ItemCombiner = $ItemCombiner

func _ready():
	print("altar_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("altar_room_event -> initialize_event")
	

func _run_room_event():
	print("altar_room_event -> _run_room_event (post-combat)")
	item_combiner.item_skipped.connect(_on_item_skipped)
	item_combiner.combiner_closed.connect(_on_item_skipped)
	button.disabled = false
	show_event()

func show_event():
	anim_player.play("show_event")
	await anim_player.animation_finished

func event_idle():
	anim_player.play("event_idle")

func hide_event():
	anim_player.play("hide_event")
	await anim_player.animation_finished

func hover_text():
	anim_player.play("text_hover")

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_button_pressed() -> void:
	disable_button()
	anim_player.play("hide_text")
	anim_player.play("openBox")

func close_box():
	anim_player.play("closeBox")
	await anim_player.animation_finished

func _on_button_mouse_exited() -> void:
	if item_combiner.visible == false:
		anim_player.play("hide_text")

func _on_button_mouse_entered() -> void:
	if item_combiner.visible == false:	
		anim_player.play("show_text")

func _on_item_skipped():
	close_box()
	hide_event()
	complete_event()


class_name SuperUpgradeEvent
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_label: AnimationPlayer = $animLabel
@onready var button: Button = $picEvent/btnEvent
@onready var item_combiner: ItemCombiner = $ItemCombiner
@onready var btn_door: Button = $centerPoint/picDoor/btnDoor
@onready var door_container: Control = $centerPoint
@onready var anim_door: AnimationPlayer = $animDoor

@onready var particles: CPUParticles2D = $Particles

func _ready():
	print("super_upgrade -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("super_upgrade -> initialize_event")

func _run_room_event():
	print("super_upgrade -> _run_room_event (post-combat)")
	door_container.modulate = room_data.room_definition.room_color
	item_combiner.item_skipped.connect(_on_item_skipped)
	btn_door.pressed.connect(_door_pressed)
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
	_show_door()

func _show_door():
	anim_door.play("show_door")
	btn_door.disabled = false

func _door_pressed():
	var next_room: RoomData = null

	if not Player.has_rooms_remaining():
		next_room = DungeonManager.get_town_room()
	else:
		next_room = DungeonManager.get_random_dungeon_room()

	main_game_ref.fade_out()

	main_game_ref.load_room(next_room)

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

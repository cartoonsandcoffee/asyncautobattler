class_name GraveRoomEvent
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_hover: AnimationPlayer = $animHover
@onready var button: Button = $controlEvent/eventContainer/picTreasure/Button
@onready var items_offering: DisplayItemChoicesFree = $DisplayItemChoicesFree

@onready var particles: CPUParticles2D = $controlEvent/eventContainer/picTreasure/jar_particles

func _ready():
	print("grave_room -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("grave_room -> initialize_event")

func _run_room_event():
	print("grave_room -> _run_room_event (post-combat)")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)
	button.disabled = false
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_button_pressed() -> void:
	disable_button()
	particles.emitting = false
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("sarcophagus")
	anim_event.play("open")
	await anim_event.animation_finished	
	items_offering.show_popup()

func close_box():
	items_offering.hide_popup()

func _on_button_mouse_exited() -> void:
	if items_offering.visible == false:
		CursorManager.reset_cursor()
		anim_hover.play("un_hover")

func _on_button_mouse_entered() -> void:
	if items_offering.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("ah")
		anim_hover.play("hover")

func _on_item_selected(item: Item):
	complete_room()

func _on_item_skipped():
	complete_room()

func _on_need_item_replace(item: Item):
	complete_room()

func complete_room():
	items_offering.hide_popup()

	anim_event.play("hide_event")
	await anim_event.animation_finished

	complete_event()

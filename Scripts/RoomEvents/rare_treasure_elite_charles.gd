class_name EliteMechanicalRoomEvent
extends RoomEvent

@onready var anim_box: AnimationPlayer = $animItems
@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_label: AnimationPlayer = $animLabel
@onready var button: Button = $Event/picEvent/Button
@onready var items_offering: ItemOffering = $FreeItemOffering

@onready var particles: CPUParticles2D = $Event/picEvent/particles

func _ready():
	print("eilte_mechanical -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("eilte_mechanical -> initialize_event")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)

func _run_room_event():
	print("eilte_mechanical -> _run_room_event (post-combat)")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)
	button.disabled = false
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished
	enable_button()

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_item_selected(item: Item):
	AudioManager.play_ui_sound("popup_close")
	anim_box.play("hide_items")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func _on_item_skipped():
	AudioManager.play_ui_sound("popup_close")
	anim_box.play("hide_items")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func _on_need_item_replace(item: Item):
	AudioManager.play_ui_sound("popup_close")
	anim_box.play("hide_items")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func _on_button_mouse_exited() -> void:
	if items_offering.visible == false:
		CursorManager.reset_cursor()
		anim_label.play("hide_label")

func _on_button_mouse_entered() -> void:
	if items_offering.visible == false:	
		CursorManager.set_interact_cursor()
		#AudioManager.play_event_sound("corpse")
		anim_label.play("show_label")


func _on_button_pressed() -> void:
	Player.tinker_events_left -= 1	# Only one use per run
	DungeonManager.exhaust_room("Tinker's Workshop")
	disable_button()
	particles.emitting = false
	anim_label.play("hide_label")
	CursorManager.reset_cursor()
	AudioManager.play_ui_sound("popup_open")
	anim_box.play("show_items")

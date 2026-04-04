class_name EliteBugRoomEvent
extends RoomEvent

@onready var anim_box: AnimationPlayer = $animItem
@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_label: AnimationPlayer = $animLabel
@onready var button: Button = $picEvent/btnEvent
@onready var items_offering: ItemOffering = $FreeItemOffering

@onready var particles: CPUParticles2D = $Particles

func _ready():
	print("eilte_bug -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("eilte_bug -> initialize_event")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)

func _run_room_event():
	print("eilte_bug -> _run_room_event (post-combat)")
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

func _on_item_selected(item: Item):
	AudioManager.play_ui_sound("popup_close")
	anim_box.play("hide_box")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func _on_item_skipped():
	AudioManager.play_ui_sound("popup_close")
	anim_box.play("hide_box")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func _on_need_item_replace(item: Item):
	AudioManager.play_ui_sound("popup_close")
	anim_box.play("hide_box")
	await anim_box.animation_finished
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()


func _on_btn_event_pressed() -> void:
	Player.scorpion_encounters_left -= 1	# Only one use per run
	DungeonManager.exhaust_room("An Inset Nest")
	disable_button()
	particles.emitting = false
	anim_label.play("hide_label")
	CursorManager.reset_cursor()
	AudioManager.play_ui_sound("popup_open")
	anim_box.play("show_box")

func _on_btn_event_mouse_entered() -> void:
	if items_offering.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("corpse")
		anim_label.play("show_label")

func _on_btn_event_mouse_exited() -> void:
	if items_offering.visible == false:
		CursorManager.reset_cursor()
		anim_label.play("hide_label")

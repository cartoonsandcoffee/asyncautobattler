class_name TreasureJarRoomEvent
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_hover: AnimationPlayer = $animHover

@onready var button: Button = $controlEvent/eventContainer/picTreasure/Button
@onready var items_offering: DisplayItemChoicesFree = $DisplayItemChoicesFree

@onready var particles: CPUParticles2D = $controlEvent/eventContainer/picTreasure/particleBlood


func _ready():
	print("treasure_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("treasure_room_event -> initialize_event")

func _run_room_event():
	print("treasure_room_event -> _run_room_event (post-combat)")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)
	button.disabled = false
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func complete_room():
	items_offering.hide_popup()

	anim_event.play("hide_event")
	await anim_event.animation_finished

	complete_event()

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_button_pressed() -> void:
	disable_button()
	particles.emitting = false
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("corpse")
	anim_event.play("open")
	await anim_event.animation_finished	
	items_offering.show_popup()

func _on_button_mouse_exited() -> void:
	if items_offering.visible == false:
		CursorManager.reset_cursor()
		anim_hover.play("un_hover")

func _on_button_mouse_entered() -> void:
	if items_offering.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("corpse")
		anim_hover.play("hover")

func _on_item_selected(item: Item):
	complete_room()

func _on_item_skipped():
	complete_room()

func _on_need_item_replace(item: Item):
	complete_room()

class_name HallwayEvent_Grave
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_hover: AnimationPlayer = $animHover

@onready var button: Button = $controlEvent/eventContainer/picEvent/btnEvent
@onready var items_offering: DisplayItemChoicesFree = $DisplayItemChoicesFree

@onready var particles: CPUParticles2D = $controlEvent/eventContainer/picEvent/particles

func _ready():
	print("grave_hallway -> ready")
	super._ready()  # Call parent's _ready

func initialize_event():
	print("grave_hallway -> initialize_event")

	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func disable_button():
	button.disabled = true

func _on_item_selected(item: Item):
	complete_hallway()

func _on_item_skipped():
	complete_hallway()

func _on_need_item_replace(item: Item):
	complete_hallway()

func complete_hallway():
	items_offering.hide_popup()

	anim_event.play("hide_event")
	await anim_event.animation_finished

	complete_event()

func _on_btn_event_pressed() -> void:
	disable_button()
	particles.emitting = false
	AudioManager.play_event_sound("dig_grave")
	anim_event.play("open")
	await anim_event.animation_finished
	CursorManager.reset_cursor()
	items_offering.show_popup()

func _on_btn_event_mouse_exited() -> void:
	if items_offering.visible == false:
		CursorManager.reset_cursor()
		anim_hover.play("un_hover")

func _on_btn_event_mouse_entered() -> void:
	if items_offering.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("fill_grave")
		anim_hover.play("hover")

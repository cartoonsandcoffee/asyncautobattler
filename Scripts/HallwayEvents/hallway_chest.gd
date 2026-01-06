class_name HallwayEvent_Chest
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_labels: AnimationPlayer = $animLabel
@onready var anim_items: AnimationPlayer = $animItems
@onready var button: Button = $picEvent/btnEvent
@onready var items_offering: ItemOffering = $FreeItemOffering

@onready var particles: CPUParticles2D = $particles

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
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
	AudioManager.play_event_sound("coins_fall")
	anim_labels.play("hide_label")
	anim_items.play("show_items")

func _on_btn_event_mouse_exited() -> void:
	if items_offering.visible == false:
		CursorManager.reset_cursor()
		anim_labels.play("hide_label")

func _on_btn_event_mouse_entered() -> void:
	if items_offering.visible == false && !button.disabled:	
		AudioManager.play_ui_sound("woosh")
		CursorManager.set_interact_cursor()
		anim_labels.play("show_label")

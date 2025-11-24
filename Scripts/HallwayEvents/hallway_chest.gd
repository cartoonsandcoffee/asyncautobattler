class_name HallwayEvent_Chest
extends HallwayEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_labels: AnimationPlayer = $animLabel
@onready var anim_items: AnimationPlayer = $animItems
@onready var button: Button = $picEvent/btnEvent
@onready var btn_continue: Button = $btnContinue
@onready var items_offering: ItemOffering = $FreeItemOffering

@onready var particles: CPUParticles2D = $particles

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.disabled = true

	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)
	show_event()

func show_event():
	btn_continue.disabled = false
	anim_event.play("show_event")
	await anim_event.animation_finished

func hide_event():
	anim_event.play("hide_event")
	await anim_event.animation_finished

func disable_button():
	button.disabled = true

func close_box():
	anim_items.play("hide_items")
	await anim_items.animation_finished

func _on_item_selected(item: Item):
	complete_hallway()

func _on_item_skipped():
	complete_hallway()

func _on_need_item_replace(item: Item):
	complete_hallway()

func _on_continue_pressed():
	complete_hallway()

func complete_hallway():
	close_box()
	hide_event()
	event_completed()


func _on_btn_event_pressed() -> void:
	disable_button()
	particles.emitting = false
	anim_labels.play("hide_label")
	anim_items.play("show_items")

func _on_btn_event_mouse_exited() -> void:
	if items_offering.visible == false:
		anim_labels.play("hide_label")

func _on_btn_event_mouse_entered() -> void:
	if items_offering.visible == false:	
		anim_labels.play("show_label")

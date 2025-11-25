class_name HallwayEvent_Peddler
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_labels: AnimationPlayer = $animLabel
@onready var button: Button = $picEvent/btnEvent
@onready var btn_continue: Button = $btnContinue
@onready var item_store: ItemStore = $item_merchant_store

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.disabled = true

	item_store.item_selected.connect(_on_item_selected)
	item_store.store_closed.connect(close_up_shop)
	#show_event()

func start_event():
	btn_continue.disabled = false
	anim_event.play("show_event")
	await anim_event.animation_finished

func hide_event():
	anim_event.play("hide_event")
	await anim_event.animation_finished

func disable_button():
	button.disabled = true

func anim_merchant_idle():
	anim_event.play("event_idle")

func _on_continue_pressed():
	complete_hallway()

func complete_hallway():
	hide_event()
	complete_event()

func close_up_shop():
	complete_hallway()

func _on_btn_event_pressed() -> void:
	disable_button()
	anim_labels.play("hide_label")
	item_store.show_store()

func _on_btn_event_mouse_exited() -> void:
	if item_store.visible == false:
		anim_labels.play("hide_label")

func _on_btn_event_mouse_entered() -> void:
	if item_store.visible == false:	
		anim_labels.play("show_label")

func _on_item_selected(item: Item):
	pass

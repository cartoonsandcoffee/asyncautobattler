class_name BasicMerchantRoomEvent
extends RoomEvent

@onready var button: Button = $picEvent/Button
@onready var item_store: ItemStore = $item_merchant_store
@onready var lbl_action: Label = $lblAction

@onready var anim_label: AnimationPlayer = $animLabel
@onready var anim_event: AnimationPlayer = $animEvent

func _on_button_mouse_exited() -> void:
	anim_label.play("hide_label")
	await anim_label.animation_finished


func _on_button_mouse_entered() -> void:
	anim_label.play("show_label")
	await anim_label.animation_finished


func _ready() -> void:
	print("basic_merchant_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("basic_merchant_room_event -> initialize_event")
	item_store.item_selected.connect(_on_item_selected)
	button.disabled = true

func _run_room_event():
	print("basic_merchantroom_event -> _run_room_event (post-combat)")
	item_store.item_selected.connect(_on_item_selected)
	item_store.store_closed.connect(close_up_shop)
	button.disabled = false
	show_merchant()

func show_merchant():
	anim_event.play("show_event")
	await anim_event.animation_finished

func play_merchant_idle():
	anim_event.play("event_idle")

func _on_button_pressed() -> void:
	item_store.show_store()

func close_up_shop():
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func _on_item_selected(item: Item):
	pass
class_name HallwayEvent_Peddler
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_labels: AnimationPlayer = $animLabel
@onready var button: Button = $picEvent/btnEvent
@onready var item_store: ItemStore = $item_merchant_store

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
	item_store.item_selected.connect(_on_item_selected)
	item_store.store_closed.connect(close_up_shop)

func start_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func hide_event():
	anim_event.play("hide_event")
	await anim_event.animation_finished

func disable_button():
	button.disabled = true

func play_sfx_footstep():
	AudioManager.play_synced_sound("combat_footstep")

func anim_merchant_idle():
	anim_event.play("event_idle")

func _on_continue_pressed():
	complete_hallway()

func complete_hallway():
	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()

func close_up_shop():
	complete_hallway()

func _on_btn_event_pressed() -> void:
	disable_button()
	CursorManager.reset_cursor()
	anim_labels.play("hide_label")
	AudioManager.play_event_sound("ooo")
	item_store.show_store()

func _on_btn_event_mouse_exited() -> void:
	if item_store.visible == false:
		CursorManager.reset_cursor()
		anim_labels.play("hide_label")

func _on_btn_event_mouse_entered() -> void:
	if item_store.visible == false:	
		CursorManager.set_talk_cursor()
		anim_labels.play("show_label")
		AudioManager.play_event_sound("mmm")

func _on_item_selected(item: Item):
	pass

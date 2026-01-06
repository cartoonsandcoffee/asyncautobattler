class_name RareMerchantRoomEvent
extends RoomEvent

@onready var anim_player: AnimationPlayer = $animMerchant
@onready var button: Button = $merchantControl/merchantLight/Button
@onready var item_store: ItemStore = $item_merchant_store
@onready var lbl_action: Label = $lblAction
@onready var anim_label: AnimationPlayer = $animLabel
@onready var smoke: CPUParticles2D = $smoke

func _on_button_mouse_exited() -> void:
	if !item_store.visible:
		anim_label.play("hide_label")
		CursorManager.reset_cursor()


func _on_button_mouse_entered() -> void:
	if !item_store.visible:
		anim_label.play("show_label")
		AudioManager.play_event_sound("mmm")
		CursorManager.set_talk_cursor()

func pipe_sfx():
	AudioManager.play_event_sound("pipe")

func play_idle():
	anim_player.play("merchant_idle")
	button.disabled = false

func _ready() -> void:
	print("rare_merchant_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("rare_merchant_room_event -> initialize_event")
	item_store.item_selected.connect(_on_item_selected)
	button.disabled = true

func _run_room_event():
	print("rare_merchantroom_event -> _run_room_event (post-combat)")
	item_store.item_selected.connect(_on_item_selected)
	item_store.store_closed.connect(close_up_shop)
	button.disabled = false
	show_merchant()

func show_merchant():
	anim_player.play("show_merchant")
	await anim_player.animation_finished

func play_merchant_idle():
	anim_player.play("merchant_idle")

func _on_button_pressed() -> void:
	anim_label.play("hide_label")
	button.disabled = true
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("ooo")
	item_store.show_store()
	anim_player.stop()

func close_up_shop():
	anim_player.play("merchant_close")
	await anim_player.animation_finished
	complete_event()

func _on_item_selected(item: Item):
	pass

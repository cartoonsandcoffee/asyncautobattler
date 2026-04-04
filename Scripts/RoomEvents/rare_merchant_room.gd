class_name RareMerchantRoomEvent
extends RoomEvent

@onready var anim_player: AnimationPlayer = $animMerchant
@onready var button: Button = $merchantControl/merchantLight/Button
@onready var lbl_action: Label = $merchantControl/lblAction
@onready var anim_label: AnimationPlayer = $animLabel
@onready var anim_choice: AnimationPlayer = $animChoice
@onready var smoke: CPUParticles2D = $smoke

@onready var store_bugs: ItemStore = $store_bugs
@onready var store_potion: ItemStore = $store_potions
@onready var store_weapons: ItemStore = $store_weapons

func _on_button_mouse_exited() -> void:
	if is_any_store_visible():
		anim_label.play("hide_label")
		CursorManager.reset_cursor()


func _on_button_mouse_entered() -> void:
	if !is_any_store_visible() && !button.disabled:
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
	store_bugs.item_selected.connect(_on_item_selected)
	store_potion.item_selected.connect(_on_item_selected)
	store_weapons.item_selected.connect(_on_item_selected)
	button.disabled = true

func _run_room_event():
	print("rare_merchantroom_event -> _run_room_event (post-combat)")
	store_bugs.item_selected.connect(_on_item_selected)
	store_potion.item_selected.connect(_on_item_selected)
	store_weapons.item_selected.connect(_on_item_selected)

	store_bugs.store_closed.connect(close_up_shop)
	store_potion.store_closed.connect(close_up_shop)
	store_weapons.store_closed.connect(close_up_shop)

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
	AudioManager.play_ui_sound("popup_open")
	anim_choice.play("show_choice")
	anim_player.stop()

func close_up_shop():	
	anim_player.play("merchant_close")
	await anim_player.animation_finished
	complete_event()

func _on_item_selected(item: Item):
	pass

func is_any_store_visible() -> bool:
	if store_bugs.visible:
		return true

	if store_potion.visible:
		return true

	if store_weapons.visible: 
		return true
	
	return false




func _on_btn_leave_pressed() -> void:
	AudioManager.play_ui_sound("popup_close")
	anim_choice.play("hide_choice")
	close_up_shop()


func _on_btn_potions_pressed() -> void:
	AudioManager.play_ui_sound("popup_close")
	anim_choice.play("hide_choice")
	store_potion.show_store()


func _on_btn_weapons_pressed() -> void:
	AudioManager.play_ui_sound("popup_close")
	anim_choice.play("hide_choice")
	store_weapons.show_store()

func _on_btn_bugs_pressed() -> void:
	AudioManager.play_ui_sound("popup_close")
	anim_choice.play("hide_choice")
	store_bugs.show_store()

class_name AltarRoomEvent
extends RoomEvent

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var box_anim: AnimationPlayer = $boxAnim
@onready var text_anim: AnimationPlayer = $textAnim
@onready var button: Button = $picEvent/Button
@onready var item_combiner: ItemOffering = $FreeItemOffering

func _ready():
	print("altar_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("altar_room_event -> initialize_event")
	

func _run_room_event():
	print("altar_room_event -> _run_room_event (post-combat)")
	item_combiner.item_skipped.connect(_on_item_skipped)
	item_combiner.item_selected.connect(_on_item_selected)
	item_combiner.need_item_replace.connect(_on_item_selected)
	show_event()

func show_event():
	anim_player.play("show_event")

	var anim_length = anim_player.get_animation("show_event").length
	await CombatSpeed.create_timer(anim_length)

	button.disabled = false

func hide_event():
	anim_player.play("hide_event")
	var anim_length = anim_player.get_animation("hide_event").length
	await CombatSpeed.create_timer(anim_length)
	disable_button()

func hover_text():
	text_anim.play("text_hover")

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_button_pressed() -> void:
	disable_button()
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("corpse")
	text_anim.play("altar_hide_text")
	box_anim.play("altar_open_box")


func close_box():
	box_anim.play("altar_close_box")
	await box_anim.animation_finished
	enable_button()

func _on_button_mouse_exited() -> void:
	if item_combiner.visible == false:
		CursorManager.reset_cursor()
		text_anim.play("altar_hide_text")

func _on_button_mouse_entered() -> void:
	if item_combiner.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("ah")
		text_anim.play("altar_show_text")

func _on_item_skipped():
	box_anim.play("altar_close_box")
	await box_anim.animation_finished

	anim_player.play("hide_event")
	var anim_length = anim_player.get_animation("hide_event").length
	await CombatSpeed.create_timer(anim_length)
	
	disable_button()

	complete_event()

func _on_item_selected(item: Item):
	_on_item_skipped()

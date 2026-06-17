class_name HallwayEvent_Chest
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_hover: AnimationPlayer = $animHover
@onready var button: Button = $eventControl/PanelContainer/picEvent/btnEvent
@onready var popup_chest: DisplayItemChoicesFree = $DisplayItemChoicesFree

@onready var particles: CPUParticles2D = $eventControl/PanelContainer/picEvent/particles

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
	popup_chest.item_selected.connect(_on_item_selected)
	popup_chest.item_skipped.connect(_on_item_skipped)
	popup_chest.need_item_replace.connect(_on_need_item_replace)
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
	popup_chest.hide_popup()

	anim_event.play("hide_event")
	await anim_event.animation_finished
	complete_event()


func _on_btn_event_pressed() -> void:
	disable_button()
	particles.emitting = false
	AudioManager.play_ui_sound("chest_open")
	anim_event.play("open")
	await anim_event.animation_finished
	CursorManager.reset_cursor()
	popup_chest.show_popup()

func _on_btn_event_mouse_exited() -> void:
	if popup_chest.visible == false:
		anim_hover.play("un_hover")
		CursorManager.reset_cursor()

func _on_btn_event_mouse_entered() -> void:
	if popup_chest.visible == false && !button.disabled:	
		AudioManager.play_ui_sound("chest_hover")
		anim_hover.play("hover")
		CursorManager.set_interact_cursor()

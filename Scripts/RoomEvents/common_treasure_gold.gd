class_name HallwayEvent_Gold
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animEvent
@onready var anim_labels: AnimationPlayer = $animLabel
@onready var anim_items: AnimationPlayer = $animItems
@onready var anim_coins: AnimationPlayer = $controlCoinsAnim/animCoinGet

@onready var button: Button = $picEvent/btnEvent
@onready var stat_gold: StatItem = $controlCoinsAnim/centerPt/StatItem

@onready var particles: CPUParticles2D = $picEvent/particles

@onready var coin_anim_area: Control = $controlCoinsAnim

const GOLD_REWARD: int = 10

func _ready():
	super._ready()  # Call parent's _ready

func initialize_event():
	stat_gold.update_stat("gold", "+" + str(GOLD_REWARD + Player.current_rank))
	show_event()

func show_event():
	anim_event.play("show_event")
	await anim_event.animation_finished

func disable_button():
	button.disabled = true

func complete_hallway():
	complete_event()


func _on_btn_event_pressed() -> void:
	disable_button()
	anim_event.play("hide_event")
	coin_anim_area.visible = true
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("coins_fall")

	anim_coins.play("get_gold")
	await anim_coins.animation_finished
	Player.add_gold(GOLD_REWARD + Player.current_rank)
	complete_hallway()	

func _on_btn_event_mouse_exited() -> void:
	if !button.disabled:
		CursorManager.reset_cursor()
		anim_labels.play("hide_label")

func _on_btn_event_mouse_entered() -> void:
	if !button.disabled:	
		AudioManager.play_ui_sound("woosh")
		CursorManager.set_interact_cursor()
		anim_labels.play("show_label")


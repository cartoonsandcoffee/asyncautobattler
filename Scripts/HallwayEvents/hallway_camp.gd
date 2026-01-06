class_name HallwayEvent_Camp
extends RoomEvent

@onready var anim_event: AnimationPlayer = $animFire
@onready var anim_label: AnimationPlayer = $animText
@onready var anim_main: AnimationPlayer = $animMain
@onready var btn_continue: Button = $btnDone
@onready var label: RichTextLabel = $lblRested
@onready var particles: CPUParticles2D = $smoke

var event_active: bool = true

func _ready():
	print("grave_hallway -> ready")
	super._ready()  # Call parent's _ready

func initialize_event():
	print("grave_hallway -> initialize_event")
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.disabled = true
	show_event()

func disable_button():
	btn_continue.disabled = true

func show_event():
	btn_continue.disabled = false
	#AudioManager.play_synced_sound("campfire")	
	anim_event.play("fire_glow")

	# -- Heal the player
	Player.stats.hit_points_current = Player.stats.hit_points
	if main_game_ref and main_game_ref.has_method("set_player_stats"):
		main_game_ref.set_player_stats()
		
func _on_continue_pressed():
	if event_active:
		CursorManager.reset_cursor()
		AudioManager.play_event_sound("fire_02")
		event_active = false
		disable_button()

		anim_main.play("show_event")
		var anim_length = anim_main.get_animation("show_event").length + 1.0
		await CombatSpeed.create_timer(anim_length)

		AudioManager.play_event_sound("fire_out")
		particles.emitting = false
		anim_main.play("campfire_hide_event")
		anim_length = anim_main.get_animation("campfire_hide_event").length
		await CombatSpeed.create_timer(anim_length)

		complete_event()

func change_fire():
	anim_event.play("fire_out")

func _on_btn_continue_mouse_exited() -> void:
	CursorManager.reset_cursor()

func _on_btn_continue_mouse_entered() -> void:
	if event_active:
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("fire_01")


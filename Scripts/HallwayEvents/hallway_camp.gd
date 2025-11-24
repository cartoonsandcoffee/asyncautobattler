class_name HallwayEvent_Camp
extends HallwayEvent

@onready var anim_event: AnimationPlayer = $animFire
@onready var anim_label: AnimationPlayer = $animText
@onready var btn_continue: Button = $btnContinue
@onready var label: RichTextLabel = $lblRested
@onready var particles: CPUParticles2D = $smoke

func _ready():
	print("grave_hallway -> ready")
	super._ready()  # Call parent's _ready

func initialize_event():
	print("grave_hallway -> initialize_event")
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.disabled = true
	show_event()

func show_event():
	btn_continue.disabled = false
	anim_event.play("fire_glow")

	# -- Heal the player
	Player.stats.hit_points_current = Player.stats.hit_points
	if main_game_ref and main_game_ref.has_method("set_player_stats"):
		main_game_ref.set_player_stats()
		
func hide_event():
	particles.emitting = false
	anim_event.play("hide_event")
	await anim_event.animation_finished

func _on_continue_pressed():
	complete_hallway()

func complete_hallway():
	hide_event()
	event_completed()

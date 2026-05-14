class_name ForgeRoomEvent
extends RoomEvent

@onready var anim_jars: AnimationPlayer = $animJars
@onready var anim_open: AnimationPlayer = $animOpen
@onready var button: Button = $picTreasure/Button
@onready var weapon_upgrader: WeaponUpgrader = $WeaponUpgrader

@onready var particles: CPUParticles2D = $picTreasure/jar_particles


func _ready():
	print("forge_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("forge_room_event -> initialize_event")


func _run_room_event():
	print("forge_room_event -> _run_room_event (post-combat)")
	weapon_upgrader.item_selected.connect(_on_item_selected)
	weapon_upgrader.upgrader_closed.connect(_on_item_skipped)
	button.disabled = false
	show_jars()

func show_jars():
	anim_jars.play("show_jars")
	await anim_jars.animation_finished

func hover_text():
	anim_open.play("text_hover")

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_button_pressed() -> void:
	disable_button()
	particles.emitting = false
	CursorManager.reset_cursor()
	AudioManager.play_event_sound("forge")
	anim_open.play("hide_text")
	weapon_upgrader.show_store()

func _on_button_mouse_exited() -> void:
	if weapon_upgrader.visible == false:
		CursorManager.reset_cursor()
		anim_open.play("hide_text")

func _on_button_mouse_entered() -> void:
	if weapon_upgrader.visible == false:	
		CursorManager.set_interact_cursor()
		AudioManager.play_event_sound("chomp")
		anim_open.play("show_text")

func _on_item_selected(item: Item):
	anim_jars.play("jars_done")
	await anim_jars.animation_finished

	complete_event()

func _on_item_skipped():
	anim_jars.play("jars_done")
	await anim_jars.animation_finished

	complete_event()

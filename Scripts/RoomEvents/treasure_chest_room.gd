class_name TreasureJarRoomEvent
extends RoomEvent

@onready var anim_box: AnimationPlayer = $animBox
@onready var anim_jars: AnimationPlayer = $animJars
@onready var anim_open: AnimationPlayer = $animOpen
@onready var button: Button = $picTreasure/Button
@onready var items_offering: ItemOffering = $FreeItemOffering

@onready var particles: CPUParticles2D = $jar_particles


func _ready():
	print("treasure_room_event -> ready")
	button.disabled = true
	super._ready()  # Call parent's _ready

func initialize_event():
	print("treasure_room_event -> initialize_event")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)

func _run_room_event():
	print("treasure_room_event -> _run_room_event (post-combat)")
	items_offering.item_selected.connect(_on_item_selected)
	items_offering.item_skipped.connect(_on_item_skipped)
	items_offering.need_item_replace.connect(_on_need_item_replace)
	button.disabled = false
	show_jars()

func show_jars():
	anim_jars.play("show_jars")
	await anim_jars.animation_finished

func jar_bounce():
	anim_jars.play("jars_bounce")

func hide_jars():
	anim_jars.play("jars_done")
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
	anim_open.play("hide_text")
	anim_box.play("openBox")

func close_box():
	anim_box.play("closeBox")
	await anim_box.animation_finished

func _on_button_mouse_exited() -> void:
	if items_offering.visible == false:
		anim_open.play("hide_text")

func _on_button_mouse_entered() -> void:
	if items_offering.visible == false:	
		anim_open.play("show_text")

func _on_item_selected(item: Item):
	close_box()
	hide_jars()
	complete_event()

func _on_item_skipped():
	close_box()
	hide_jars()
	complete_event()

func _on_need_item_replace(item: Item):
	close_box()
	hide_jars()
	complete_event()
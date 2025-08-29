class_name TreasureJarRoomEvent
extends RoomEvent

@onready var anim_box: AnimationPlayer = $animBox
@onready var anim_jars: AnimationPlayer = $animJars
@onready var anim_open: AnimationPlayer = $animOpen
@onready var button: Button = $picTreasure/Button
@onready var items_offering: ItemOffering = $FreeItemOffering


func initialize_event():
	items_offering.item_selected.connect(_on_item_selected)
	show_jars()

func show_jars():
	anim_jars.play("show_jars")

func jar_bounce():
	anim_jars.play("jars_bounce")

func hide_jars():
	anim_jars.play("jars_done")

func hover_text():
	anim_open.play("text_hover")

func enable_button():
	button.disabled = false

func disable_button():
	button.disabled = true

func _on_button_pressed() -> void:
	disable_button()
	anim_open.play("hide_text")
	anim_box.play("openBox")


func _on_button_mouse_exited() -> void:
	if items_offering.visible == false:
		anim_open.play("hide_text")

func _on_button_mouse_entered() -> void:
	if items_offering.visible == false:	
		anim_open.play("show_text")

func _on_item_selected(item: Item):
	complete_event()
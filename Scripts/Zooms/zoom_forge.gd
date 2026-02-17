extends ZoomEvent

@onready var pic_item: TextureRect = $panelBlack/panelMain/picItem

@onready var anim_back: AnimationPlayer = $animBackColor
@onready var anim_items: AnimationPlayer = $animItem
@onready var anim_display: AnimationPlayer = $animDisplay

var new_item: Item = null

func show_popup(_item1:Item, _item2:Item, _item3: Item = null):
	if _item1:
		new_item = _item1
		set_items()
	else:
		push_warning("[ZoomForge] No item set")
		return

	visible = true
	AudioManager.play_synced_sound("popup_open")
	anim_display.play("show_panel")
	await anim_display.animation_finished
	play_effect()

func set_items():
	pic_item.texture = new_item.item_icon
	pic_item.self_modulate = new_item.item_color

func hide_popup():
	anim_display.play("hide_panel")
	AudioManager.play_synced_sound("popup_close")
	await anim_display.animation_finished
	visible = false

func play_effect():
	AudioManager.play_event_sound("forge")
	anim_back.play("back_color")
	anim_items.play("show_item")

	var anim_length = anim_items.get_animation("show_item").length
	await CombatSpeed.create_timer(anim_length)

	hide_popup()
	zoom_completed.emit()

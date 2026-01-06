extends ZoomEvent

@onready var txt_label: RichTextLabel = $panelBlack/panelBorder/txtLabel
@onready var pic_item: TextureRect = $panelBlack/panelBorder/picItem
@onready var pic_newitem: TextureRect = $panelBlack/panelBorder/picNewItem

@onready var anim_effects: AnimationPlayer = $animEffects
@onready var anim_items: AnimationPlayer = $animItem
@onready var anim_display: AnimationPlayer = $animDisplay

var old_item: Item = null
var new_item: Item = null

func show_popup(_item1:Item, _item2:Item):
	if _item1 && _item2:
		old_item = _item1
		new_item = _item2
		set_items()
	else:
		push_warning("[ZoomAltar] No items set")
		return

	AudioManager.play_synced_sound("popup_open")
	anim_display.play("show_popup")
	await anim_display.animation_finished
	play_effect()

func set_items():
	pic_item.texture = old_item.item_icon
	pic_item.self_modulate = old_item.item_color

	pic_newitem.texture = new_item.item_icon
	pic_newitem.self_modulate = new_item.item_color

func hide_popup():
	anim_display.play("hide_popup")
	AudioManager.play_synced_sound("popup_close")
	await anim_display.animation_finished

func play_effect():
	AudioManager.play_event_sound("altar")
	anim_effects.play("show_effects")
	anim_items.play("item_swap")

	var anim_length = anim_items.get_animation("item_swap").length
	await CombatSpeed.create_timer(anim_length)

	hide_popup()
	zoom_completed.emit()

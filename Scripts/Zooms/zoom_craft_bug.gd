extends ZoomEvent

@onready var anim_bugs: AnimationPlayer = $animBugs
@onready var anim_display: AnimationPlayer = $animDisplay

@onready var pic_bug1: TextureRect = $panelBack/panelMain/picBug1
@onready var pic_bug2: TextureRect = $panelBack/panelMain/picBug2

@onready var part_bug1: GPUParticles2D = $panelBack/panelMain/particleBug1
@onready var part_bug2: GPUParticles2D = $panelBack/panelMain/particleBug2

var old_bug1: Item = null
var old_bug2: Item = null
var new_bug: Item = null

func show_popup(_item1:Item, _item2:Item, _item3: Item = null):
	if _item1 && _item2:
		old_bug1 = _item1
		old_bug2 = _item2
		new_bug = _item3
		set_items()
	else:
		push_warning("[ZoomBugCrafting] No bugs set")
		return
	
	visible = true
	AudioManager.play_synced_sound("popup_open")
	anim_display.play("show_popup")
	await anim_display.animation_finished
	play_effect()

func set_items():
	pic_bug1.texture = old_bug1.item_icon
	pic_bug1.modulate = old_bug1.item_color
	pic_bug2.texture = old_bug2.item_icon
	pic_bug2.modulate = old_bug2.item_color

	part_bug1.texture = new_bug.item_icon
	part_bug1.self_modulate = new_bug.item_color

	part_bug2.texture = new_bug.item_icon
	part_bug2.self_modulate = new_bug.item_color

func play_effect():
	anim_bugs.play("throw_bugs")

	var anim_length = anim_bugs.get_animation("throw_bugs").length
	await CombatSpeed.create_timer(anim_length)

	hide_popup()
	zoom_completed.emit()

func hide_popup():
	anim_display.play("hide_popup")
	AudioManager.play_synced_sound("popup_close")
	await anim_display.animation_finished
	visible = false
	
func play_woosh():
	AudioManager.play_ui_sound("woosh")

func play_corpse():
	AudioManager.play_event_sound("corpse")
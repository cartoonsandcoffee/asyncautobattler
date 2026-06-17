extends Control
class_name StatusBox

@onready var lbl_amount: Label = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/lblAmount
@onready var pic_status: TextureRect = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/picStatus
@onready var panel_main: Panel = $mainPanel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var stat_color: Color = Color.WHITE
var gamecolors: GameColors
var _refs_set: bool = false

@export var status: Enums.StatusEffects

const ICON_POISON   	= preload("res://Resources/StatIcons/StatusIcons/status_poison.tres")
const ICON_BURN     	= preload("res://Resources/StatIcons/StatusIcons/status_burn.tres")
const ICON_ACID     	= preload("res://Resources/StatIcons/StatusIcons/status_acid.tres")
const ICON_THORNS    	= preload("res://Resources/StatIcons/StatusIcons/status_thorns.tres")
const ICON_REGEN     	= preload("res://Resources/StatIcons/StatusIcons/status_regen.tres")
const ICON_BLESSING   	= preload("res://Resources/StatIcons/StatusIcons/status_blessing.tres")
const ICON_BLIND   		= preload("res://Resources/StatIcons/StatusIcons/status_blind.tres")
const ICON_STUN   		= preload("res://Resources/StatIcons/StatusIcons/status_stun.tres")
const ICON_BLEED   		= preload("res://Resources/StatIcons/StatusIcons/status_poison.tres")

func set_references():
	if _refs_set:
		return
	_refs_set = true
	
	gamecolors = GameColors.new()
	lbl_amount = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/lblAmount
	pic_status = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/picStatus
	panel_main = $mainPanel
	anim_player = $AnimationPlayer

func show_box():
	await get_tree().process_frame
	anim_player.play("show_box")


func hide_box():
	anim_player.play("hide_box")
	await anim_player.animation_finished

func update_label(_new_val: int):
	anim_player.play("update_box")
	lbl_amount.text = str(_new_val)
	
func set_status(_stat: Enums.StatusEffects, amount: int):
	set_references()
	status = _stat
	match _stat:
		Enums.StatusEffects.POISON:
			stat_color = gamecolors.stats.poison
			pic_status.texture = ICON_POISON
		Enums.StatusEffects.THORNS:
			stat_color = gamecolors.stats.thorns
			pic_status.texture = ICON_THORNS
		Enums.StatusEffects.ACID:
			stat_color = gamecolors.stats.acid
			pic_status.texture = ICON_ACID
		Enums.StatusEffects.REGENERATION:
			stat_color = gamecolors.stats.regeneration
			pic_status.texture = ICON_REGEN
		Enums.StatusEffects.BURN:
			stat_color = gamecolors.stats.burn
			pic_status.texture = ICON_BURN
		Enums.StatusEffects.STUN:
			stat_color = gamecolors.stats.stun
			pic_status.texture = ICON_STUN
		Enums.StatusEffects.BLIND:
			stat_color = gamecolors.stats.strikes
			pic_status.texture = ICON_BLIND	
		Enums.StatusEffects.BLESSING:
			stat_color = gamecolors.stats.blessing
			pic_status.texture = ICON_BLESSING
		Enums.StatusEffects.BLEED:
			stat_color = gamecolors.stats.damage
			pic_status.texture = ICON_BLEED
		_:
			pass

	panel_main.self_modulate = stat_color
	pic_status.self_modulate = stat_color
	lbl_amount.text = str(amount) 

func done():
	queue_free()
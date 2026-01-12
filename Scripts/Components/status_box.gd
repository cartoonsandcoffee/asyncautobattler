extends Control
class_name StatusBox

@onready var lbl_amount: Label = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/lblAmount
@onready var pic_status: TextureRect = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/picStatus
@onready var panel_main: Panel = $mainPanel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var stat_color: Color = Color.WHITE
var gamecolors: GameColors

@export var status: Enums.StatusEffects

func set_references():
	gamecolors = GameColors.new()
	lbl_amount = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/lblAmount
	pic_status = $mainPanel/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/picStatus
	panel_main = $mainPanel
	anim_player = $AnimationPlayer

func show_box():
	anim_player.play("show_box")

func hide_box():
	anim_player.play("hide_box")

func update_label(_new_val: int):
	anim_player.play("update_box")
	lbl_amount.text = str(_new_val)
	
func set_status(_stat: Enums.StatusEffects, amount: int):
	set_references()
	var status_acid: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_acid.tres")
	var status_blessing: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_blessing.tres")
	var status_blind: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_blind.tres")
	var status_burn: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_burn.tres")
	var status_poison: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_poison.tres")
	var status_regen: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_regen.tres")
	var status_stun: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_stun.tres")
	var status_thorns: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_thorns.tres")

	status = _stat
	match _stat:
		Enums.StatusEffects.POISON:
			stat_color = gamecolors.stats.poison
			pic_status.texture = status_poison
		Enums.StatusEffects.THORNS:
			stat_color = gamecolors.stats.thorns
			pic_status.texture = status_thorns
		Enums.StatusEffects.ACID:
			stat_color = gamecolors.stats.acid
			pic_status.texture = status_acid
		Enums.StatusEffects.REGENERATION:
			stat_color = gamecolors.stats.regeneration
			pic_status.texture = status_regen
		Enums.StatusEffects.BURN:
			stat_color = gamecolors.stats.burn
			pic_status.texture = status_burn
		Enums.StatusEffects.STUN:
			stat_color = gamecolors.stats.stun
			pic_status.texture = status_stun
		Enums.StatusEffects.BLIND:
			stat_color = gamecolors.stats.strikes
			pic_status.texture = status_blind	
		Enums.StatusEffects.BLESSING:
			stat_color = gamecolors.stats.shield
			pic_status.texture = status_blessing					
		_:
			pass

	panel_main.self_modulate = stat_color
	pic_status.self_modulate = stat_color
	lbl_amount.text = str(amount) 

func done():
	queue_free()
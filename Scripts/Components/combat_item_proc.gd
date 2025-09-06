extends Control
class_name CombatItemProc

signal stat_animation_done()

@onready var lbl_amount: Label = $Panel/mainPanel/MarginContainer/HBoxContainer/lblAmount
@onready var lbl_info: Label = $Panel/mainPanel/MarginContainer/VBoxContainer/lblInfo
@onready var pic_item: TextureRect = $Panel/mainPanel/MarginContainer/HBoxContainer/picItem
@onready var pic_stat: TextureRect = $Panel/mainPanel/MarginContainer/HBoxContainer/panelStat/picStat
@onready var panel_stat: PanelContainer = $Panel/mainPanel/MarginContainer/HBoxContainer/panelStat
@onready var anim_player: AnimationPlayer = $AnimationPlayer


@export var item: Item = null

var stat_color: Color = Color.WHITE
var item_color: Color = Color.WHITE
var gamecolors: GameColors


func set_references():
	gamecolors = GameColors.new()
	lbl_amount = $Panel/mainPanel/MarginContainer/VBoxContainer/HBoxContainer/panelStat/MarginContainer/HBoxContainer/lblAmount
	lbl_info = $Panel/mainPanel/MarginContainer/VBoxContainer/lblInfo
	pic_item = $Panel/mainPanel/MarginContainer/VBoxContainer/HBoxContainer/picItem
	pic_stat = $Panel/mainPanel/MarginContainer/VBoxContainer/HBoxContainer/panelStat/MarginContainer/HBoxContainer/picStat
	panel_stat = $Panel/mainPanel/MarginContainer/VBoxContainer/HBoxContainer/panelStat
	anim_player = $AnimationPlayer

func set_info(_info: String):
	lbl_info.text = _info

func set_status_visuals(_status: Enums.StatusEffects):
	var status_acid: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_acid.tres")
	var status_blessing: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_blessing.tres")
	var status_blind: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_blind.tres")
	var status_burn: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_burn.tres")
	var status_poison: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_poison.tres")
	var status_regen: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_regen.tres")
	var status_stun: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_stun.tres")
	var status_thorns: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_thorns.tres")

	match _status:
		Enums.StatusEffects.POISON:
			stat_color = gamecolors.stats.poison
			pic_stat.texture = status_poison
		Enums.StatusEffects.THORNS:
			stat_color = gamecolors.stats.thorns
			pic_stat.texture = status_thorns
		Enums.StatusEffects.ACID:
			stat_color = gamecolors.stats.acid
			pic_stat.texture = status_acid
		Enums.StatusEffects.REGENERATION:
			stat_color = gamecolors.stats.regeneration
			pic_stat.texture = status_regen
		Enums.StatusEffects.BURN:
			stat_color = gamecolors.stats.burn
			pic_stat.texture = status_burn
		Enums.StatusEffects.STUN:
			stat_color = gamecolors.stats.stun
			pic_stat.texture = status_stun
		Enums.StatusEffects.BLIND:
			stat_color = gamecolors.stats.strikes
			pic_stat.texture = status_blind	
		Enums.StatusEffects.BLESSING:
			stat_color = gamecolors.stats.shield
			pic_stat.texture = status_blessing					
		_:
			pass

	panel_stat.self_modulate = stat_color
	pic_stat.self_modulate = stat_color

func set_status_as_item_visuals(_status: Enums.StatusEffects):
	var status_acid: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_acid.tres")
	var status_blessing: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_blessing.tres")
	var status_blind: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_blind.tres")
	var status_burn: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_burn.tres")
	var status_poison: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_poison.tres")
	var status_regen: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_regen.tres")
	var status_stun: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_stun.tres")
	var status_thorns: Texture2D = load("res://Resources/StatIcons/StatusIcons/status_thorns.tres")

	match _status:
		Enums.StatusEffects.POISON:
			pic_item.self_modulate = gamecolors.stats.poison
			pic_item.texture = status_poison
		Enums.StatusEffects.THORNS:
			pic_item.self_modulate = gamecolors.stats.thorns
			pic_item.texture = status_thorns
		Enums.StatusEffects.ACID:
			pic_item.self_modulate = gamecolors.stats.acid
			pic_item.texture = status_acid
		Enums.StatusEffects.REGENERATION:
			pic_item.self_modulate = gamecolors.stats.regeneration
			pic_item.texture = status_regen
		Enums.StatusEffects.BURN:
			pic_item.self_modulate = gamecolors.stats.burn
			pic_item.texture = status_burn
		Enums.StatusEffects.STUN:
			pic_item.self_modulate = gamecolors.stats.stun
			pic_item.texture = status_stun
		Enums.StatusEffects.BLIND:
			pic_item.self_modulate = gamecolors.stats.strikes
			pic_item.texture = status_blind	
		Enums.StatusEffects.BLESSING:
			pic_item.self_modulate = gamecolors.stats.shield
			pic_item.texture = status_blessing					
		_:
			pass

func set_stat_visuals(_stat: Enums.Stats):
	var stat_attack: Texture2D = load("res://Resources/StatIcons/icon_attack.tres")
	var stat_health: Texture2D = load("res://Resources/StatIcons/icon_health.tres")
	var stat_shield: Texture2D = load("res://Resources/StatIcons/icon_shield.tres")
	var stat_speed: Texture2D = load("res://Resources/StatIcons/icon_speed.tres")
	var stat_gold: Texture2D = load("res://Resources/StatIcons/stat_gold.tres")
	var stat_strikes: Texture2D = load("res://Resources/StatIcons/stat_strikes.tres")
	var stat_brokenshield: Texture2D = load("res://Resources/StatIcons/icon_broken_shield.tres")

	match _stat:
		Enums.Stats.DAMAGE:
			stat_color = gamecolors.stats.damage
			pic_stat.texture = stat_attack
		Enums.Stats.HITPOINTS:
			stat_color = gamecolors.stats.hit_points
			pic_stat.texture = stat_health
		Enums.Stats.AGILITY:
			stat_color = gamecolors.stats.agility
			pic_stat.texture = stat_speed
		Enums.Stats.SHIELD:
			stat_color = gamecolors.stats.shield
			pic_stat.texture = stat_shield
		Enums.Stats.GOLD:
			stat_color = gamecolors.stats.gold
			pic_stat.texture = stat_gold
		Enums.Stats.STRIKES:
			stat_color = gamecolors.stats.strikes
			pic_stat.texture = stat_strikes
		Enums.Stats.HP_AND_SHIELD:
			stat_color = gamecolors.stats.shield
			pic_stat.texture = stat_brokenshield

	panel_stat.self_modulate = stat_color
	pic_stat.self_modulate = stat_color

func set_item_visuals(_item_pic: Texture2D, _item_color: Color):
	pic_item.texture = _item_pic
	pic_item.self_modulate = _item_color

func set_label(value: int):
	var prefix: String = ""
	if value > 0:
		prefix = " + "
	else:
		value = value * -1 ### JMD: If it's negative just remove the extra -
		prefix = " - "
	lbl_amount.text = prefix + str(value) 


func _done():
	anim_player.play("hide")
	stat_animation_done.emit()

	await anim_player.animation_finished
	queue_free()

func run_animation(_party: Enums.Party):
	if _party == Enums.Party.PLAYER:
		anim_player.play("fade_upwards")
	else:
		anim_player.play("fade_downward")

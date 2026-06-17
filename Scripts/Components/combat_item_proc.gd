extends Control
class_name CombatItemProc

signal stat_animation_done()

@onready var lbl_amount: Label
@onready var lbl_info: Label 
@onready var pic_item: TextureRect
@onready var pic_stat: TextureRect 
@onready var panel_stat: PanelContainer
@onready var anim_player: AnimationPlayer

@export var item: Item = null

const ICON_POISON   	= preload("res://Resources/StatIcons/StatusIcons/status_poison.tres")
const ICON_BURN     	= preload("res://Resources/StatIcons/StatusIcons/status_burn.tres")
const ICON_ACID     	= preload("res://Resources/StatIcons/StatusIcons/status_acid.tres")
const ICON_THORNS    	= preload("res://Resources/StatIcons/StatusIcons/status_thorns.tres")
const ICON_REGEN     	= preload("res://Resources/StatIcons/StatusIcons/status_regen.tres")
const ICON_BLESSING   	= preload("res://Resources/StatIcons/StatusIcons/status_blessing.tres")
const ICON_BLIND   		= preload("res://Resources/StatIcons/StatusIcons/status_blind.tres")
const ICON_STUN   		= preload("res://Resources/StatIcons/StatusIcons/status_stun.tres")
const ICON_BLEED   		= preload("res://Resources/StatIcons/StatusIcons/status_poison.tres")

const ICON_ATTACK     = preload("res://Resources/StatIcons/icon_attack.tres")
const ICON_HEALTH     = preload("res://Resources/StatIcons/icon_health.tres")
const ICON_SHIELD     = preload("res://Resources/StatIcons/icon_shield.tres")
const ICON_SPEED      = preload("res://Resources/StatIcons/icon_speed.tres")
const ICON_GOLD       = preload("res://Resources/StatIcons/stat_gold.tres")
const ICON_STRIKES    = preload("res://Resources/StatIcons/stat_strikes.tres")
const ICON_BURN_DMG   = preload("res://Resources/StatIcons/stat_burn.tres")
const ICON_BLANK 	  = preload("res://Assets/Items/Blank.png")
const ICON_WOUNDED    = preload("res://Resources/StatIcons/stat_wounded.tres")
const ICON_EXPOSED    = preload("res://Resources/StatIcons/icon_broken_shield.tres")

var stat_color: Color = Color.WHITE
var item_color: Color = Color.WHITE
var gamecolors: GameColors
var _refs_set: bool = false

func set_references():
	if _refs_set:
		return
	_refs_set = true
	
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
	match _status:
		Enums.StatusEffects.POISON:
			stat_color = gamecolors.stats.poison
			pic_stat.texture = ICON_POISON
		Enums.StatusEffects.THORNS:
			stat_color = gamecolors.stats.thorns
			pic_stat.texture = ICON_THORNS
		Enums.StatusEffects.ACID:
			stat_color = gamecolors.stats.acid
			pic_stat.texture = ICON_ACID
		Enums.StatusEffects.REGENERATION:
			stat_color = gamecolors.stats.regeneration
			pic_stat.texture = ICON_REGEN
		Enums.StatusEffects.BURN:
			stat_color = gamecolors.stats.burn
			pic_stat.texture = ICON_BURN
		Enums.StatusEffects.STUN:
			stat_color = gamecolors.stats.stun
			pic_stat.texture = ICON_STUN
		Enums.StatusEffects.BLIND:
			stat_color = gamecolors.stats.strikes
			pic_stat.texture = ICON_BLIND	
		Enums.StatusEffects.BLESSING:
			stat_color = gamecolors.stats.shield
			pic_stat.texture = ICON_BLESSING
		Enums.StatusEffects.BLEED:
			stat_color = gamecolors.stats.damage
			pic_stat.texture = ICON_BLEED
		_:
			pass

	panel_stat.self_modulate = stat_color
	pic_stat.self_modulate = stat_color

func set_status_as_item_visuals(_status: Enums.StatusEffects):
	match _status:
		Enums.StatusEffects.POISON:
			pic_item.self_modulate = gamecolors.stats.poison
			pic_item.texture = ICON_POISON
		Enums.StatusEffects.THORNS:
			pic_item.self_modulate = gamecolors.stats.thorns
			pic_item.texture = ICON_THORNS
		Enums.StatusEffects.ACID:
			pic_item.self_modulate = gamecolors.stats.acid
			pic_item.texture = ICON_ACID
		Enums.StatusEffects.REGENERATION:
			pic_item.self_modulate = gamecolors.stats.regeneration
			pic_item.texture = ICON_REGEN
		Enums.StatusEffects.BURN:
			pic_item.self_modulate = gamecolors.stats.burn
			pic_item.texture = ICON_BURN
		Enums.StatusEffects.STUN:
			pic_item.self_modulate = gamecolors.stats.stun
			pic_item.texture = ICON_STUN
		Enums.StatusEffects.BLIND:
			pic_item.self_modulate = gamecolors.stats.strikes
			pic_item.texture = ICON_BLIND	
		Enums.StatusEffects.BLESSING:
			pic_item.self_modulate = gamecolors.stats.shield
			pic_item.texture = ICON_BLESSING
		Enums.StatusEffects.BLEED:
			pic_item.self_modulate = gamecolors.stats.damage
			pic_item.texture = ICON_BLEED	
		_:
			pass

func set_stat_visuals(_stat: Enums.Stats):
	match _stat:
		Enums.Stats.DAMAGE:
			stat_color = gamecolors.stats.damage
			pic_stat.texture = ICON_ATTACK
		Enums.Stats.HITPOINTS:
			stat_color = gamecolors.stats.hit_points
			pic_stat.texture = ICON_HEALTH
		Enums.Stats.AGILITY:
			stat_color = gamecolors.stats.agility
			pic_stat.texture = ICON_SPEED
		Enums.Stats.SHIELD:
			stat_color = gamecolors.stats.shield
			pic_stat.texture = ICON_SHIELD
		Enums.Stats.GOLD:
			stat_color = gamecolors.stats.gold
			pic_stat.texture = ICON_GOLD
		Enums.Stats.STRIKES:
			stat_color = gamecolors.stats.strikes
			pic_stat.texture = ICON_STRIKES
		Enums.Stats.EXPOSED:
			stat_color = gamecolors.stats.shield
			pic_stat.texture = ICON_EXPOSED
		Enums.Stats.WOUNDED:
			stat_color = gamecolors.stats.hit_points
			pic_stat.texture = ICON_WOUNDED
		Enums.Stats.BURN_DAMAGE:
			stat_color = gamecolors.stats.burn
			pic_stat.texture = ICON_BURN_DMG
		Enums.Stats.NONE:
			pic_stat.texture = ICON_BLANK

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
	anim_player.speed_scale = 1.0
	anim_player.play("hide")
	stat_animation_done.emit()

	queue_free()

func run_animation(_party: Enums.Party):
	anim_player.speed_scale = 1.0
	var anim_name = ""
	if _party == Enums.Party.PLAYER:
		anim_name = CombatSpeed.get_animation_variant("fade_upwards")
	else:
		anim_name = CombatSpeed.get_animation_variant("fade_downward")
	
	anim_player.play(anim_name)

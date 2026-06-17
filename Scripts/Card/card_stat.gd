extends Control
class_name CardStat

@onready var lbl_stat: Label 
@onready var pic_icon: TextureRect 

var gamecolors: GameColors

const ICON_ATTACK     = preload("res://Resources/StatIcons/icon_attack.tres")
const ICON_HEALTH     = preload("res://Resources/StatIcons/icon_health.tres")
const ICON_SHIELD     = preload("res://Resources/StatIcons/icon_shield.tres")
const ICON_SPEED      = preload("res://Resources/StatIcons/icon_speed.tres")
const ICON_GOLD       = preload("res://Resources/StatIcons/stat_gold.tres")
const ICON_STRIKES    = preload("res://Resources/StatIcons/stat_strikes.tres")
const ICON_BURN       = preload("res://Resources/StatIcons/stat_burn.tres")

var _refs_set: bool = false

func _ready() -> void:
	set_references()

func set_references():
	if _refs_set:
		return
	_refs_set = true
	
	lbl_stat = $PanelContainer/MarginContainer/VBoxContainer/lblStat
	pic_icon = $picIcon
	gamecolors = GameColors.new()

func update_stat(stat_name: String, stat_value: int):
	set_references()
	lbl_stat.text = str(stat_value)

	if stat_name == "damage" || stat_name == "attack":
		pic_icon.texture = ICON_ATTACK
		pic_icon.modulate = gamecolors.stats.damage
		lbl_stat.modulate = gamecolors.stats.damage
	elif stat_name == "shield" || stat_name == "armor":
		pic_icon.texture = ICON_SHIELD
		pic_icon.modulate = gamecolors.stats.shield
		lbl_stat.modulate = gamecolors.stats.shield
	elif stat_name == "health" || stat_name == "hitpoints":
		pic_icon.texture = ICON_HEALTH
		pic_icon.modulate = gamecolors.stats.hit_points
		lbl_stat.modulate = gamecolors.stats.hit_points
	elif stat_name == "speed" || stat_name == "agility":
		pic_icon.texture = ICON_SPEED
		pic_icon.modulate = gamecolors.stats.agility
		lbl_stat.modulate = gamecolors.stats.agility
	elif stat_name == "strikes" || stat_name == "hits":
		pic_icon.texture = ICON_STRIKES
		pic_icon.modulate = gamecolors.stats.strikes
		lbl_stat.modulate = gamecolors.stats.strikes
	elif stat_name == "gold":
		pic_icon.texture = ICON_GOLD
		pic_icon.modulate = gamecolors.stats.gold
		lbl_stat.modulate = gamecolors.stats.gold
	elif stat_name == "burn" || stat_name == "burn_damage":
		pic_icon.texture = ICON_BURN
		pic_icon.modulate = gamecolors.stats.burn
		lbl_stat.modulate = gamecolors.stats.burn

func update_value(value: String):
	lbl_stat.text = value

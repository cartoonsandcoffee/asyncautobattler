extends Control
class_name StatItem

@onready var lbl_stat: Label 
@onready var pic_icon: TextureRect 
@onready var panel_color: Panel

var gamecolors: GameColors

const ICON_ATTACK     = preload("res://Resources/StatIcons/icon_attack.tres")
const ICON_HEALTH     = preload("res://Resources/StatIcons/icon_health.tres")
const ICON_SHIELD     = preload("res://Resources/StatIcons/icon_shield.tres")
const ICON_SPEED      = preload("res://Resources/StatIcons/icon_speed.tres")
const ICON_GOLD       = preload("res://Resources/StatIcons/stat_gold.tres")
const ICON_STRIKES    = preload("res://Resources/StatIcons/stat_strikes.tres")
const ICON_BURN       = preload("res://Resources/StatIcons/stat_burn.tres")

func _ready() -> void:
	set_references()

func set_references():
	lbl_stat = $Panel/BorderPanel/MarginContainer/FillerPanel/MarginContainer/HBoxContainer/lblStat
	pic_icon = $Panel/BorderPanel/MarginContainer/FillerPanel/MarginContainer/HBoxContainer/picIcon
	panel_color = $Panel
	gamecolors = GameColors.new()

func update_stat(stat_name: String, stat_value: String):
	set_references()
	lbl_stat.text = stat_value

	if stat_name == "damage" || stat_name == "attack":
		pic_icon.texture = ICON_ATTACK
		panel_color.modulate = gamecolors.stats.damage
	elif stat_name == "shield" || stat_name == "armor":
		pic_icon.texture = ICON_SHIELD
		panel_color.modulate = gamecolors.stats.shield
	elif stat_name == "health" || stat_name == "hitpoints":
		pic_icon.texture = ICON_HEALTH
		panel_color.modulate = gamecolors.stats.hit_points
	elif stat_name == "speed" || stat_name == "agility":
		pic_icon.texture = ICON_SPEED
		panel_color.modulate = gamecolors.stats.agility
	elif stat_name == "strikes" || stat_name == "hits":
		pic_icon.texture = ICON_STRIKES
		panel_color.modulate = gamecolors.stats.strikes
	elif stat_name == "gold":
		pic_icon.texture = ICON_GOLD
		panel_color.modulate = gamecolors.stats.gold
	elif stat_name == "burn" || stat_name == "burn_damage":
		pic_icon.texture = ICON_BURN
		panel_color.modulate = gamecolors.stats.burn

func update_value(value: String):
	lbl_stat.text = value
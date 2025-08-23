extends Control
class_name StatItem

@onready var lbl_stat: Label 
@onready var pic_icon: TextureRect 
@onready var panel_color: Panel

enum Stat {
	DAMAGE,
	HITPOINTS,
	AGILITY,
	SHIELD,
	GOLD
}

var gamecolors: GameColors

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

	var stat_attack: Texture2D = load("res://Resources/StatIcons/icon_attack.tres")
	var stat_health: Texture2D = load("res://Resources/StatIcons/icon_health.tres")
	var stat_shield: Texture2D = load("res://Resources/StatIcons/icon_shield.tres")
	var stat_speed: Texture2D = load("res://Resources/StatIcons/icon_speed.tres")

	if stat_name == "damage" || stat_name == "attack":
		pic_icon.texture = stat_attack
		panel_color.modulate = gamecolors.stats.damage
	elif stat_name == "shield" || stat_name == "armor":
		pic_icon.texture = stat_shield
		panel_color.modulate = gamecolors.stats.shield
	elif stat_name == "health" || stat_name == "hitpoints":
		pic_icon.texture = stat_health
		panel_color.modulate = gamecolors.stats.hit_points
	elif stat_name == "speed" || stat_name == "agility":
		pic_icon.texture = stat_speed
		panel_color.modulate = gamecolors.stats.agility

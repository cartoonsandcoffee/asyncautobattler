extends Control
class_name CardStat

@onready var lbl_stat: Label 
@onready var pic_icon: TextureRect 

var gamecolors: GameColors

func _ready() -> void:
	set_references()

func set_references():
	lbl_stat = $PanelContainer/MarginContainer/VBoxContainer/lblStat
	pic_icon = $picIcon
	gamecolors = GameColors.new()

func update_stat(stat_name: String, stat_value: String):
	set_references()
	lbl_stat.text = stat_value

	var stat_attack: Texture2D = load("res://Resources/StatIcons/icon_attack.tres")
	var stat_health: Texture2D = load("res://Resources/StatIcons/icon_health.tres")
	var stat_shield: Texture2D = load("res://Resources/StatIcons/icon_shield.tres")
	var stat_speed: Texture2D = load("res://Resources/StatIcons/icon_speed.tres")
	var stat_strikes: Texture2D = load("res://Resources/StatIcons/stat_strikes.tres")
	var stat_burn: Texture2D = load("res://Resources/StatIcons/stat_burn.tres")
	var stat_gold: Texture2D = load("res://Resources/StatIcons/stat_gold.tres")

	if stat_name == "damage" || stat_name == "attack":
		pic_icon.texture = stat_attack
		pic_icon.modulate = gamecolors.stats.damage
		lbl_stat.modulate = gamecolors.stats.damage
	elif stat_name == "shield" || stat_name == "armor":
		pic_icon.texture = stat_shield
		pic_icon.modulate = gamecolors.stats.shield
		lbl_stat.modulate = gamecolors.stats.shield
	elif stat_name == "health" || stat_name == "hitpoints":
		pic_icon.texture = stat_health
		pic_icon.modulate = gamecolors.stats.hit_points
		lbl_stat.modulate = gamecolors.stats.hit_points
	elif stat_name == "speed" || stat_name == "agility":
		pic_icon.texture = stat_speed
		pic_icon.modulate = gamecolors.stats.agility
		lbl_stat.modulate = gamecolors.stats.agility
	elif stat_name == "strikes" || stat_name == "hits":
		pic_icon.texture = stat_strikes
		pic_icon.modulate = gamecolors.stats.strikes
		lbl_stat.modulate = gamecolors.stats.strikes
	elif stat_name == "gold":
		pic_icon.texture = stat_gold
		pic_icon.modulate = gamecolors.stats.gold
		lbl_stat.modulate = gamecolors.stats.gold
	elif stat_name == "burn" || stat_name == "burn_damage":
		pic_icon.texture = stat_burn
		pic_icon.modulate = gamecolors.stats.burn
		lbl_stat.modulate = gamecolors.stats.burn

func update_value(value: String):
	lbl_stat.text = value

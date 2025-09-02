extends Control
class_name CombatItemProc

signal stat_animation_done()

@onready var lbl_amount: Label = $Panel/mainPanel/MarginContainer/HBoxContainer/lblAmount
@onready var pic_item: TextureRect = $Panel/mainPanel/MarginContainer/HBoxContainer/picItem
@onready var pic_stat: TextureRect = $Panel/mainPanel/MarginContainer/HBoxContainer/panelStat/picStat
@onready var panel_stat: PanelContainer = $Panel/mainPanel/MarginContainer/HBoxContainer/panelStat
@onready var anim_player: AnimationPlayer = $AnimationPlayer


@export var item: Item = null
@export var stat: Enums.Stats = Enums.Stats.HITPOINTS
@export var party: Enums.Party = Enums.Party.PLAYER

var stat_color: Color = Color.WHITE
var item_color: Color = Color.WHITE
var gamecolors: GameColors


func set_references():
	gamecolors = GameColors.new()
	lbl_amount = $Panel/mainPanel/MarginContainer/HBoxContainer/lblAmount
	pic_item = $Panel/mainPanel/MarginContainer/HBoxContainer/picItem
	pic_stat = $Panel/mainPanel/MarginContainer/HBoxContainer/panelStat/picStat
	panel_stat = $Panel/mainPanel/MarginContainer/HBoxContainer/panelStat
	anim_player = $AnimationPlayer


func set_stat_visuals(_stat: Enums.Stats):
	var stat_attack: Texture2D = load("res://Resources/StatIcons/icon_attack.tres")
	var stat_health: Texture2D = load("res://Resources/StatIcons/icon_health.tres")
	var stat_shield: Texture2D = load("res://Resources/StatIcons/icon_shield.tres")
	var stat_speed: Texture2D = load("res://Resources/StatIcons/icon_speed.tres")
	var stat_gold: Texture2D = load("res://Resources/StatIcons/stat_gold.tres")
	var stat_strikes: Texture2D = load("res://Resources/StatIcons/stat_strikes.tres")

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

	panel_stat.self_modulate = stat_color
	pic_stat.self_modulate = stat_color

func set_item_visuals(_item_pic: Texture2D, _item_color: Color):
	pic_item.texture = _item_pic
	pic_item.self_modulate = _item_color

func set_label(value: int):
	var prefix: String = ""
	if value < 0:
		prefix = " + "
	else:
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
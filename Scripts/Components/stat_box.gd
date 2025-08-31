extends Control
class_name StatBoxDisplay

@onready var lbl_name: Label = $Tooltip/NinePatchRect/MarginContainer/VBoxContainer/lbl_name
@onready var lbl_tooltip: RichTextLabel = $Tooltip/NinePatchRect/MarginContainer/VBoxContainer/lbl_tooltip
@onready var stat_holder: NinePatchRect = $Panel/stat_holder
@onready var tooltip: Panel = $Tooltip
@onready var lbl_stat: Label = $Panel/stat_holder/MarginContainer/HBoxContainer/lbl_stat
@onready var icon: TextureRect = $Panel/stat_holder/MarginContainer/HBoxContainer/icon


@export var stat: Enums.Stats = Enums.Stats.HITPOINTS
@export var stat_color: Color
@export var stat_icon: Texture2D

var stat_value: int = 0
var stat_value_base: int = 0
var stat_name: String = ""
var stat_tooltip: String = ""
var gamecolors: GameColors

func _ready() -> void:
	gamecolors = GameColors.new()

func update_stat(_stat: Enums.Stats, value: int, base_value: int):
	set_visuals(_stat)	
	stat_value = value
	stat_value_base = base_value	
	_set_labels()

func set_visuals(_stat: Enums.Stats):
	var stat_attack: Texture2D = load("res://Resources/StatIcons/icon_attack.tres")
	var stat_health: Texture2D = load("res://Resources/StatIcons/icon_health.tres")
	var stat_shield: Texture2D = load("res://Resources/StatIcons/icon_shield.tres")
	var stat_speed: Texture2D = load("res://Resources/StatIcons/icon_speed.tres")
	var stat_gold: Texture2D = load("res://Resources/StatIcons/stat_gold.tres")

	match _stat:
		Enums.Stats.DAMAGE:
			stat_name = "Damage"
			stat_color = gamecolors.stats.damage
			icon.texture = stat_attack
			stat_tooltip = "The amount you take away from the enemy's shield or hit points each turn in combat."
		Enums.Stats.HITPOINTS:
			stat_name = "Hit Points"
			stat_color = gamecolors.stats.hit_points
			icon.texture = stat_health
			stat_tooltip = "Your life force, when it reaches zero you die."
		Enums.Stats.AGILITY:
			stat_name = "Agility"
			stat_color = gamecolors.stats.agility
			icon.texture = stat_speed
			stat_tooltip = "The party with higher agility goes first in combat."
		Enums.Stats.SHIELD:
			stat_name = "Shield"
			stat_color = gamecolors.stats.shield
			icon.texture = stat_shield
			stat_tooltip = "How much damage you can withstand before you begin to lose hit points. Replenishes between battles."
		Enums.Stats.GOLD:
			stat_name = "Gold"
			stat_color = gamecolors.stats.gold
			icon.texture = stat_gold
			stat_tooltip = "The currency of the dungeon, spend it to buy items and weapons."
		Enums.Stats.STRIKES:
			stat_name = "Strikes"
			stat_color = gamecolors.stats.strikes
			stat_tooltip = "How many strikes a weapon makes each turn."

func _set_labels() -> void:
	lbl_name.text = stat_name
	lbl_name.self_modulate = stat_color
	lbl_tooltip.text = stat_tooltip
	stat_holder.modulate = stat_color
	lbl_stat.text = str(stat_value)
	icon.texture = stat_icon
	if (stat_value_base > -1):
		lbl_stat.text = str(stat_value) + "/" + str(stat_value_base)

func _on_button_mouse_entered() -> void:
	tooltip.visible = true


func _on_button_mouse_exited() -> void:
	tooltip.visible = false

extends Control

@onready var lbl_name: Label = $Tooltip/NinePatchRect/MarginContainer/VBoxContainer/lbl_name
@onready var lbl_tooltip: RichTextLabel = $Tooltip/NinePatchRect/MarginContainer/VBoxContainer/lbl_tooltip
@onready var stat_holder: NinePatchRect = $Panel/stat_holder
@onready var tooltip: Panel = $Tooltip
@onready var lbl_stat: Label = $Panel/stat_holder/MarginContainer/HBoxContainer/lbl_stat
@onready var icon: TextureRect = $Panel/stat_holder/MarginContainer/HBoxContainer/icon

enum Stat {
	DAMAGE,
	HITPOINTS,
	AGILITY,
	SHIELD,
	GOLD
}

@export var stat: Stat = Stat.HITPOINTS
@export var stat_color: Color
@export var stat_icon: Texture2D

var stat_value: int = 0
var stat_value_base: int = 0
var stat_name: String = ""
var stat_tooltip: String = ""

func _ready() -> void:
	pass

func update_stuff():
	match stat:
		Stat.DAMAGE:
			stat_name = "Damage"
			stat_color = Color.RED
			stat_value = Player.stats.damage
			stat_tooltip = "The amount you take away from the enemy's shield or hit points each turn in combat."
		Stat.HITPOINTS:
			stat_name = "Hit Points"
			stat_color = Color.LIME_GREEN
			stat_value = Player.stats.hit_points_current
			stat_value_base = Player.stats.hit_points
			stat_tooltip = "Your life force, when it reaches zero you die."
		Stat.AGILITY:
			stat_name = "Agility"
			stat_color = Color.YELLOW
			stat_value = Player.stats.agility
			stat_tooltip = "The party with higher agility goes first in combat."
		Stat.SHIELD:
			stat_name = "Shield"
			stat_color = Color.DODGER_BLUE
			stat_value = Player.stats.shield
			stat_tooltip = "How much damage you can withstand before you begin to lose hit points. Replenishes between battles."
		Stat.GOLD:
			stat_name = "Gold"
			stat_color = Color.GOLDENROD
			stat_value = Player.stats.gold
			stat_tooltip = "The currency of the dungeon, spend it to buy items and weapons."
	_set_labels()

func _set_labels() -> void:
	lbl_name.text = stat_name
	lbl_name.self_modulate = stat_color
	lbl_tooltip.text = stat_tooltip
	stat_holder.modulate = stat_color
	lbl_stat.text = str(stat_value)
	icon.texture = stat_icon
	if (stat_value_base > 0):
		lbl_stat.text = str(stat_value) + "/" + str(stat_value_base)

func _on_button_mouse_entered() -> void:
	tooltip.visible = true


func _on_button_mouse_exited() -> void:
	tooltip.visible = false

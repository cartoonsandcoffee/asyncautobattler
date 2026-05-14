extends Control
class_name StatBoxDisplay

@onready var lbl_name: Label = $Tooltip/NinePatchRect/MarginContainer/VBoxContainer/lbl_name
@onready var lbl_tooltip: RichTextLabel = $Tooltip/NinePatchRect/MarginContainer/VBoxContainer/lbl_tooltip
@onready var stat_holder: Control = $Panel/statContainer
@onready var tooltip: Panel = $Tooltip
@onready var lbl_stat: Label = $Panel/statContainer/HBoxContainer/lbl_stat
@onready var icon: TextureRect = $Panel/statContainer/HBoxContainer/icon
@onready var anim_wounded: AnimationPlayer = $animWounded 
@onready var progress_bar: ProgressBar = $Panel/ProgressBar

@export var stat: Enums.Stats = Enums.Stats.HITPOINTS
@export var show_tooltip: bool = true
@export var show_progress_bar: bool = false

var stat_color: Color
var stat_icon: Texture2D

var stat_value: int = 0
var stat_value_base: int = 0
var stat_name: String = ""
var stat_tooltip: String = ""
var shield_max_seen: int = 0

var gamecolors: GameColors

func _ready() -> void:
	gamecolors = GameColors.new()

func update_stat(_stat: Enums.Stats, value: int, base_value: int, _display: bool = true):
	stat = _stat
	stat_value = value
	stat_value_base = base_value	
	set_visuals(stat)
	_set_labels()
	if _stat == Enums.Stats.STRIKES:
		visible = _display
	elif _stat == Enums.Stats.BURN_DAMAGE:
		visible = _display
	elif _stat == Enums.Stats.SHIELD:
		progress_bar.visible = base_value > 0
		progress_bar.modulate = stat_color
		progress_bar.size.x = progress_bar.get_parent().size.x * 0.5
		if CombatManager.combat_active:
			if value > shield_max_seen:
				shield_max_seen = value
			progress_bar.max_value = max(shield_max_seen, 1)
		else:
			shield_max_seen = base_value
			progress_bar.max_value = max(base_value, 1)
		progress_bar.value = value
	elif _stat == Enums.Stats.HITPOINTS:
		progress_bar.visible = true
		progress_bar.max_value = max(base_value, 1)
		progress_bar.value = value
		progress_bar.modulate = stat_color
	progress_bar.visible = show_progress_bar

func set_visuals(_stat: Enums.Stats):
	var stat_attack: Texture2D = load("res://Resources/StatIcons/icon_attack.tres")
	var stat_health: Texture2D = load("res://Resources/StatIcons/icon_health.tres")
	var stat_shield: Texture2D = load("res://Resources/StatIcons/icon_shield.tres")
	var stat_speed: Texture2D = load("res://Resources/StatIcons/icon_speed.tres")
	var stat_gold: Texture2D = load("res://Resources/StatIcons/stat_gold.tres")
	var stat_strikes: Texture2D = load("res://Resources/StatIcons/stat_strikes.tres")
	var stat_burn_damage: Texture2D = load("res://Resources/StatIcons/stat_burn.tres")
	var stat_wounded: Texture2D = load("res://Resources/StatIcons/stat_wounded.tres")
	var stat_exposed: Texture2D = load("res://Resources/StatIcons/icon_broken_shield.tres")
	var stat_turns_left: Texture2D = load("res://Resources/StatIcons/turns_left.tres")

	match _stat:
		Enums.Stats.DAMAGE:
			stat_name = "Attack Damage"
			stat_color = gamecolors.stats.damage
			icon.texture = stat_attack
			stat_tooltip = "The amount you take away from the enemy's shield or hit points each turn in combat."
		Enums.Stats.HITPOINTS:
			stat_name = "Hit Points"
			stat_color = gamecolors.stats.hit_points
			icon.texture = stat_health
			if stat_value <= (stat_value_base / 2):
				icon.texture = stat_wounded
			stat_tooltip = "Your life force, when it reaches zero you die."
		Enums.Stats.AGILITY:
			stat_name = "Agility"
			stat_color = gamecolors.stats.agility
			icon.texture = stat_speed
			stat_tooltip = "The party with higher agility goes first in combat. Also determines if you can run away from an enemy."
		Enums.Stats.SHIELD:
			stat_name = "Shield"
			stat_color = gamecolors.stats.shield
			icon.texture = stat_shield
			if stat_value == 0:
				icon.texture = stat_exposed
			stat_tooltip = "How much damage you can withstand before you begin to lose hit points. Replenishes between battles."
		Enums.Stats.GOLD:
			stat_name = "Gold"
			stat_color = gamecolors.stats.gold
			icon.texture = stat_gold
			stat_tooltip = "The currency of the dungeon, spend it to buy items and weapons."
		Enums.Stats.STRIKES:
			stat_name = "Strikes"
			stat_color = gamecolors.stats.strikes
			icon.texture = stat_strikes
			stat_tooltip = "How many times you hit with your weapon in a single turn. Resets between turns."
		Enums.Stats.BURN_DAMAGE:
			stat_name = "Burn Damage"
			stat_color = gamecolors.stats.burn
			icon.texture = stat_burn_damage
			stat_tooltip = "How much damage 1 stack of burn deals to the enemy."
		Enums.Stats.TURNS_LEFT:
			stat_name = "Turns Left"
			stat_color = Color.WHITE
			icon.texture = stat_turns_left
			stat_tooltip = "How much you can venture in the dungeon before fighting the rank boss."

func _set_labels() -> void:
	lbl_name.text = stat_name
	lbl_name.self_modulate = stat_color
	lbl_tooltip.text = stat_tooltip
	stat_holder.modulate = stat_color
	lbl_stat.text = str(stat_value)
	
	# Determine display format based on context
	if stat == Enums.Stats.HITPOINTS:
		# HP always shows current/max format
		lbl_stat.text = str(stat_value) + "/" + str(stat_value_base)
		lbl_stat.add_theme_font_size_override("font_size", 34)
		if stat_value <= ((stat_value_base/2)-1):
			anim_wounded.play("show_wounded")
		else:
			anim_wounded.play("RESET")
	elif stat == Enums.Stats.STRIKES:
		if CombatManager.combat_active and CombatManager.attack_sequence_active and stat_value_base > 1:
			lbl_stat.text = str(stat_value) + " (Next: " + str(stat_value_base) + ")"
		elif CombatManager.combat_active and not CombatManager.attack_sequence_active:
			lbl_stat.text = str(stat_value_base)
		else:
			lbl_stat.text = str(stat_value)	
	elif stat == Enums.Stats.BURN_DAMAGE:
		if CombatManager.combat_active:
			lbl_stat.text = str(stat_value)
		else:
			lbl_stat.text = str(stat_value_base) 
	elif CombatManager.combat_active:
		# In combat: show only current value for non-HP stats
		lbl_stat.text = str(stat_value)
		lbl_stat.add_theme_font_size_override("font_size", 40)
	else:
		# Outside combat: show only base value
		lbl_stat.text = str(stat_value_base)
		lbl_stat.add_theme_font_size_override("font_size", 40)	

	#if (stat_value_base > -1):
	#	lbl_stat.text = str(stat_value) + "/" + str(stat_value_base)

func _on_button_mouse_entered() -> void:
	if show_tooltip:
		tooltip.visible = true


func _on_button_mouse_exited() -> void:
	tooltip.visible = false

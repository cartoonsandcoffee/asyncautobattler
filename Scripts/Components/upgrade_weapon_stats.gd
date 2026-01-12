class_name UpgradeWeaponStats
extends Control

signal bonus_completed()

@onready var lbl_bonus: Label = $panelBack/panelBlack/MarginContainer/panelBox/VBoxContainer/lblBonus
@onready var btn_damage: Button = $panelBack/panelBlack/MarginContainer/panelBox/VBoxContainer/gridButtons/btnDamage
@onready var btn_shield: Button =$panelBack/panelBlack/MarginContainer/panelBox/VBoxContainer/gridButtons/btnShield
@onready var btn_agility: Button =$panelBack/panelBlack/MarginContainer/panelBox/VBoxContainer/gridButtons/btnAgility
@onready var anim_popup: AnimationPlayer = $animPopup

func _ready() -> void:
	if Player.current_weapon_stat_upgrades["damage"] >= 1:
		btn_damage.disabled = true
	if Player.current_weapon_stat_upgrades["shield"] >= 1:
		btn_shield.disabled = true
	if Player.current_weapon_stat_upgrades["agility"] >= 1:
		btn_agility.disabled = true
	

func show_popup():
	AudioManager.play_ui_sound("popup_open")
	anim_popup.play("show_popup")
	var anim_length = anim_popup.get_animation("show_popup").length
	await CombatSpeed.create_timer(anim_length)

func hide_popup():
	Player.update_stats_from_items()
	AudioManager.play_ui_sound("popup_close")
	anim_popup.play("hide_popup")
	var anim_length = anim_popup.get_animation("hide_popup").length
	await CombatSpeed.create_timer(anim_length)	
	bonus_completed.emit()


func _on_btn_agility_pressed() -> void:
	Player.current_weapon_stat_upgrades["agility"] = 1
	hide_popup()

func _on_btn_damage_pressed() -> void:
	Player.current_weapon_stat_upgrades["damage"] = 1
	hide_popup()

func _on_btn_shield_pressed() -> void:
	Player.current_weapon_stat_upgrades["shield"] = 1
	hide_popup()

func _on_btn_damage_mouse_exited() -> void:
	deselect_button()

func _on_btn_damage_mouse_entered() -> void:
	lbl_bonus.text = "Your weapon gains +1 Damage."
	CursorManager.set_interact_cursor()

func _on_btn_shield_mouse_exited() -> void:
	deselect_button()

func _on_btn_shield_mouse_entered() -> void:
	lbl_bonus.text = "Your weapon gains +1 Shield."
	CursorManager.set_interact_cursor()

func _on_btn_agility_mouse_exited() -> void:
	deselect_button()

func _on_btn_agility_mouse_entered() -> void:
	lbl_bonus.text = "Your weapon gains +1 Agility."
	CursorManager.set_interact_cursor()

func deselect_button():
	CursorManager.reset_cursor()
	lbl_bonus.text = ""



func _on_btn_skip_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func _on_btn_skip_pressed() -> void:
	hide_popup()

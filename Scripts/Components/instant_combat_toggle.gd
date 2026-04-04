extends Control

@onready var panel_tooltip: PanelContainer = $panelTooltip
@onready var pic_button: TextureRect = $Button/picButton
@onready var lbl_toggle: Label = $panelTooltip/PanelContainer/VBoxContainer/lblToggle

var toggled: bool = false

func _on_button_toggled(toggled_on:bool) -> void:
	toggled = toggled_on

	if toggled_on:
		pic_button.modulate = "#ffffff"
		pic_button.modulate.a = 1.0
		lbl_toggle.text = "Instant NPC Fights  (ON)"
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.INSTANT)
	else:
		pic_button.modulate = "#ffffff"
		pic_button.modulate.a = 0.5
		lbl_toggle.text = "Instant NPC Fights  (OFF)"
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL)

func show_me():
	visible = true
	if toggled:
		lbl_toggle.text = "Instant NPC Fights  (ON)"
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.INSTANT)
	else:
		lbl_toggle.text = "Instant NPC Fights  (OFF)"
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL)		


func _on_button_mouse_exited() -> void:
	panel_tooltip.visible = false
	if !toggled:
		pic_button.modulate = "#ffffff"
		pic_button.modulate.a = 0.5

func _on_button_mouse_entered() -> void:
	panel_tooltip.visible = true
	if !toggled:
		pic_button.modulate = "#c90000"
		pic_button.modulate.a = 1.0
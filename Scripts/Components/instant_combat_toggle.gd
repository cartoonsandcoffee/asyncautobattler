extends Control

@onready var panel_tooltip: PanelContainer = $panelTooltip
@onready var pic_button: TextureRect = $Button/picButton
@onready var pic_selected: TextureRect = $Button/picSelected

@onready var lbl_toggle: Label = $panelTooltip/PanelContainer/VBoxContainer/lblToggle
@onready var anim_button: AnimationPlayer = $animButton
var toggled: bool = false

func _on_button_toggled(toggled_on:bool) -> void:
	toggled = toggled_on

	if toggled_on:
		pic_button.visible = false
		pic_selected.visible = true
		lbl_toggle.text = "Instant NPC Fights  (ON)"
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.INSTANT)
	else:
		pic_button.visible = true
		pic_selected.visible = false
		lbl_toggle.text = "Instant NPC Fights  (OFF)"
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL)

func show_me():
	visible = true

	if CombatSpeed.current_mode == CombatSpeed.CombatSpeedMode.INSTANT:
		toggled = true
		
	if toggled:
		pic_button.visible = false
		pic_selected.visible = true		
		lbl_toggle.text = "Instant NPC Fights  (ON)"
		pic_button.modulate.a = 1.0
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.INSTANT)
	else:
		pic_button.visible = true
		pic_selected.visible = false		
		lbl_toggle.text = "Instant NPC Fights  (OFF)"
		pic_button.modulate.a = 0.6
		CombatSpeed.set_speed(CombatSpeed.CombatSpeedMode.NORMAL)		


func _on_button_mouse_exited() -> void:
	panel_tooltip.visible = false
	CursorManager.reset_cursor()
	pic_button.modulate.a = 0.6


func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	panel_tooltip.visible = true
	pic_button.modulate.a = 1.0

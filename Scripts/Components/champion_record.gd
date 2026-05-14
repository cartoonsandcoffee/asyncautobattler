extends Control
class_name ChampionRecord

signal record_clicked()
signal record_mouse_entered()
signal record_mouse_exited()

@onready var lbl_date: Label
@onready var lbl_wins: Label
@onready var lbl_active: Label
@onready var lbl_class: Label
@onready var lbl_defeated: Label
@onready var btn_main: Button
@onready var anim_player: AnimationPlayer

@onready var pnl_motive1: PanelContainer
@onready var pnl_motive2: PanelContainer
@onready var pnl_motive3: PanelContainer

@onready var lbl_motive1: Label
@onready var lbl_motive2: Label
@onready var lbl_motive3: Label


func set_references():
	lbl_date = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblDate
	lbl_wins = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblWins
	lbl_active = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblActive
	lbl_defeated = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblDefeated
	lbl_class = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblClass
	btn_main = $Panel/PanelContainer/MarginContainer/Button
	anim_player = $AnimationPlayer

	pnl_motive1 = $Panel/PanelContainer/MarginContainer/HBoxContainer/classBox/pnlMotive1
	pnl_motive2 = $Panel/PanelContainer/MarginContainer/HBoxContainer/classBox/pnlMotive2
	pnl_motive3 = $Panel/PanelContainer/MarginContainer/HBoxContainer/classBox/pnlMotive3

	lbl_motive1 = $Panel/PanelContainer/MarginContainer/HBoxContainer/classBox/pnlMotive1/lblMotive1
	lbl_motive2 = $Panel/PanelContainer/MarginContainer/HBoxContainer/classBox/pnlMotive2/lblMotive2
	lbl_motive3 = $Panel/PanelContainer/MarginContainer/HBoxContainer/classBox/pnlMotive3/lblMotive3
	btn_main = $Panel/PanelContainer/MarginContainer/Button
	btn_main.focus_mode = Control.FOCUS_NONE   # ← ADD THIS

func set_active(is_active: bool):
	lbl_active.visible = is_active
	lbl_defeated.visible = !is_active

func set_fields_my_champions(strDate: String, strWins: String):
	lbl_date.text = strDate
	lbl_wins.text = "Wins:  " + strWins

func set_fields_hall_of_fame(strdate1: String, strdate2: String):
	lbl_date.text = strdate1 + " - " + strdate2
	lbl_wins.visible = false
	lbl_active.visible = false
	lbl_defeated.visible = false

func set_fields_global_hall(strdate1:String, strdate2:String, username:String):
	lbl_date.text = strdate1 + " - " + strdate2
	lbl_wins.visible = false
	lbl_active.visible = true
	lbl_active.text = username
	lbl_defeated.visible = false

func set_fields_current_champs(strdate1:String, wins: int, username:String):
	lbl_date.text = strdate1 
	lbl_wins.visible = true
	lbl_wins.text = str(wins)
	lbl_active.visible = true
	lbl_active.text = username
	lbl_defeated.visible = false

func set_bundle(_bundle: Array[Enums.ItemBundles]):
	lbl_class.text = get_bundle_strings(_bundle)

	if !_bundle:
		return

	lbl_motive1.text = Enums.get_bundle_string(_bundle[0])
	lbl_motive2.text = Enums.get_bundle_string(_bundle[1])
	lbl_motive3.text = Enums.get_bundle_string(_bundle[2])

	var gc = GameColors.new()
	pnl_motive1.modulate = gc.get_bundle_color(_bundle[0])
	pnl_motive2.modulate = gc.get_bundle_color(_bundle[1])
	pnl_motive3.modulate = gc.get_bundle_color(_bundle[2])

func get_bundle_strings(_bundles: Array[Enums.ItemBundles]) -> String:
	var final_string: String = ""
	var cnt: int = 0

	for bundle in _bundles:
		final_string += Enums.get_bundle_string(bundle)
		cnt += 1

		if cnt <= 2:
			final_string += ", "

	return final_string

func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_player.play("RESET")
	record_mouse_exited.emit()


func _on_button_pressed() -> void:
	record_clicked.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_player.play("hover_start")
	record_mouse_entered.emit()

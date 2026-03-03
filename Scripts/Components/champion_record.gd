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

func set_references():
	lbl_date = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblDate
	lbl_wins = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblWins
	lbl_active = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblActive
	lbl_defeated = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblDefeated
	lbl_class = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblClass
	btn_main = $Panel/PanelContainer/MarginContainer/Button
	anim_player = $AnimationPlayer

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

func set_bundle(_bundle: Enums.ItemBundles):
	lbl_class.text = Enums.get_bundle_string(_bundle)

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

extends Control
class_name PlayerRecord

signal player_clicked()
signal player_mouse_entered()
signal player_mouse_exited()

@onready var lbl_name: Label
@onready var lbl_champions: Label
@onready var lbl_active: Label
@onready var lbl_killed: Label
@onready var lbl_rank: Label
@onready var btn_main: Button
@onready var anim_player: AnimationPlayer
@onready var main_box: PanelContainer

func set_references():
	lbl_name = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblName
	lbl_champions = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblChampions
	lbl_active = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblActive
	lbl_killed = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblKilled
	lbl_rank = $Panel/PanelContainer/MarginContainer/HBoxContainer/lblRank	
	btn_main = $Panel/PanelContainer/MarginContainer/Button
	anim_player = $AnimationPlayer
	main_box = $Panel/PanelContainer

func set_fields(strName, champs, actives, killed, rank):
	lbl_name.text = strName
	lbl_rank.text = "#" + str(rank)
	lbl_champions.text = "Hall of Famers:  " + str(champs)
	lbl_active.text = "Active Champions:  " + str(actives)
	lbl_killed.text = "Players Killed:  " + str(killed)

func its_me():
	main_box.self_modulate = Color.SLATE_BLUE

func _on_button_mouse_exited() -> void:
	CursorManager.reset_cursor()
	anim_player.play("RESET")
	player_mouse_exited.emit()

func _on_button_mouse_entered() -> void:
	CursorManager.set_interact_cursor()
	anim_player.play("hover_start")
	player_mouse_entered.emit()

func _on_button_pressed() -> void:
	player_clicked.emit()


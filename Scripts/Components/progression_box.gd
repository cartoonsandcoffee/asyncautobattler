class_name ProgressionBox
extends Control

enum ChallengerType {
	UPCOMING,
	CURRENT,
	DEFEATED
}

@onready var lbl_challenger: Label = $PanelContainer/MarginContainer/VBoxContainer/lblChallenger
@onready var lbl_wins: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ratioBox/lblWins
@onready var lbl_losses: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ratioBox/lblLosses

@onready var box_ratio: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ratioBox
@onready var pic_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/picIcon

@export var challenger_type: ChallengerType = ChallengerType.UPCOMING
@export_range(1, 6) var rank: int = 1

var question: Texture2D = load("res://Resources/Icons/icon_question.tres")
var crown: Texture2D = load("res://Resources/Icons/icon_crown.tres")
var skull: Texture2D = load("res://Resources/Icons/minimap_enemy.tres")
var done: Texture2D = load("res://Resources/Icons/minimap_x.tres")


func update_display() -> void:
	if rank == Player.current_rank:
		challenger_type = ChallengerType.CURRENT
	elif rank < Player.current_rank:
		challenger_type = ChallengerType.DEFEATED
	elif rank > Player.current_rank:
		challenger_type = ChallengerType.UPCOMING

	match challenger_type:
		ChallengerType.UPCOMING:
			box_ratio.visible = false
			lbl_challenger. text = "Upcoming Rank " + str(rank) + " Challenger"
			pic_icon.texture = question
		ChallengerType.CURRENT:
			box_ratio.visible = true
			lbl_challenger.text = "Rank " + str(rank) + " Challenger"
			pic_icon.texture = skull
		ChallengerType.DEFEATED:
			box_ratio.visible = true
			lbl_challenger.text = "(Defeated) Rank " + str(rank)
			pic_icon.texture = done

	if rank == 6 && Player.current_rank < 6:
		visible = false
	else:
		visible = true
		pic_icon.texture = crown


func update_record(wins: int, losses: int):
	lbl_losses.text = "Losses:  " + str(losses)
	lbl_wins.text = "Wins:  " + str(wins)
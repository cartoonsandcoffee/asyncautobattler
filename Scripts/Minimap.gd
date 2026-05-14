class_name Minimap
extends VBoxContainer

signal room_icon_clicked(room_index: int)
signal zoom_out_requested()

const QUESTION_MARK_ICON = preload("res://Resources/Icons/icon_question.tres") 
const CROWN_ICON = preload("res://Resources/Icons/icon_crown.tres") 

var room_icons: Array[RoomIconSlot] = []
var room_box = preload("res://Scenes/Elements/room_icon_slot.tscn")

func _ready():
	_initialize_room_slots()

func _initialize_room_slots():
	pass

func _on_room_icon_clicked(room_index: int):
	room_icon_clicked.emit(room_index)

func _on_zoom_out_pressed():
	if Player.is_in_town:
		zoom_out_requested.emit()
	elif !Player.popup_open && !Player.is_in_town:
		zoom_out_requested.emit()

@tool
class_name PopupMerchantSelector
extends Control

signal event_skipped()
signal store_selected(store_string: String)

@onready var anim_main: AnimationPlayer = $AnimationPlayer

@onready var store_bugs: CustomStoreButton = $CanvasLayer/Control/centerArea/PanelContainer/GridContainer/storeBugs
@onready var store_weapons: CustomStoreButton = $CanvasLayer/Control/centerArea/PanelContainer/GridContainer/storeWeapons
@onready var store_potions: CustomStoreButton = $CanvasLayer/Control/centerArea/PanelContainer/GridContainer/storePotions

func _init() -> void:
	pass

func _ready() -> void:
	add_to_group("item_selection_events") 

	store_bugs.button_clicked.connect(_button_pressed)
	store_weapons.button_clicked.connect(_button_pressed)
	store_potions.button_clicked.connect(_button_pressed)

func _button_pressed(_store_string: String):
	store_selected.emit(_store_string)

func _on_btn_skip_pressed() -> void:
	event_skipped.emit()

func _on_btn_skip_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func show_popup():
	AudioManager.play_ui_sound("popup_open")
	anim_main.play("show_popup")
	await anim_main.animation_finished
	store_bugs.show_button()
	store_weapons.show_button()
	store_potions.show_button()	


func hide_popup():
	AudioManager.play_ui_sound("popup_close")
	anim_main.play("hide_popup")
	await anim_main.animation_finished

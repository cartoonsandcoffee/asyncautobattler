extends Control

signal dismissed

@onready var lbl_name: Label = $Panel/PanelContainer/MarginContainer/VBoxContainer/lblMain
@onready var lbl_desc: RichTextLabel = $Panel/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/txtDesc
@onready var btn_dismiss: Button = $Panel/PanelContainer/Button
@onready var pic_skin: TextureRect = $Panel/PanelContainer/MarginContainer/Panel/picChar
@onready var anim: AnimationPlayer = $animChar

func show_unlock(path_name: String, path_desc: String) -> void:
	lbl_name.text = "You have unlocked... " + path_name + "!"
	lbl_desc.text = path_desc
	visible = true
	anim.play("show_unlock")
	AudioManager.play_ui_sound("cheer_long")

func _on_btn_dismiss_pressed() -> void:
	anim.play("hide")
	await anim.animation_finished
	visible = false
	dismissed.emit()

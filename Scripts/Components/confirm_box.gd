extends Control

signal confirmed
signal cancelled

@onready var btn_proceed: Button = $blackBox/panelBorder/MarginContainer/VBoxContainer/HBoxContainer/btnProceed
@onready var btn_cancel: Button = $blackBox/panelBorder/MarginContainer/VBoxContainer/HBoxContainer/btnCancel
@onready var lbl_message: RichTextLabel = $blackBox/panelBorder/MarginContainer/VBoxContainer/RichTextLabel
@onready var lbl_header: Label = $blackBox/panelBorder/MarginContainer/VBoxContainer/Label

func _ready():
	visible = false
	btn_proceed.pressed.connect(_on_proceed)
	btn_cancel.pressed.connect(_on_cancel)
	
	btn_proceed.mouse_entered.connect(_on_button_hover_on)
	btn_cancel.mouse_entered.connect(_on_button_hover_on)
	btn_proceed.mouse_exited.connect(_on_button_hover_exit)
	btn_cancel.mouse_exited.connect(_on_button_hover_exit)

func show_confirm(message: String) -> void:
	lbl_message.text = message
	visible = true

func _on_proceed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	visible = false
	confirmed.emit()

func _on_cancel() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	visible = false
	cancelled.emit()

func _on_button_hover_on():
	CursorManager.set_interact_cursor()
	AudioManager.play_ui_sound("button_hover")

func _on_button_hover_exit():
	CursorManager.reset_cursor()
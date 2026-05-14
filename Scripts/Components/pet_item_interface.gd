extends Control

@onready var btn_close: Button = $controlMain/panelClose/MarginContainer/btnClose
@onready var lbl_title: Label = $controlMain/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/lblTitle
@onready var lbl_desc: RichTextLabel = $controlMain/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/lblMessage
@onready var item_slot: ItemSlot = $controlMain/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/MarginContainer/picHolder/MarginContainer/Item

@onready var anim_player: AnimationPlayer = $controlMain/AnimationPlayer

@onready var main_game: Node = get_tree().get_first_node_in_group("main_game")

func _ready() -> void:
	btn_close.pressed.connect(_close_popup)
	btn_close.mouse_entered.connect(_hover_button)
	btn_close.mouse_exited.connect(_unhover_button)

	item_slot.drag_started.connect(_on_pet_slot_drag_started)
	item_slot.drag_ended.connect(_on_pet_slot_drag_ended)

func _close_popup():
	AudioManager.play_ui_sound("popup_close")
	anim_player.play("hide_popup")

func open_popup():
	refresh()
	AudioManager.play_ui_sound("popup_open")
	anim_player.play("show_popup")

func refresh():
	item_slot.set_item(Player.pet_carrying_item)
	if Player.is_in_town:
		if Player.pet_carrying_item == null:
			set_town_text_empty()
		else:
			set_town_text_full()
	else:
		if Player.pet_carrying_item == null:
			set_dungeon_text_empty()
		else:
			set_dungeon_text_full()

func _on_pet_slot_drag_started(slot: ItemSlot):
	# Delegate to main_game drag system
	get_tree().get_first_node_in_group("main_game")._on_drag_started(slot)

func _on_pet_slot_drag_ended(slot: ItemSlot):
	get_tree().get_first_node_in_group("main_game")._on_pet_slot_drag_ended(slot)

func _hover_button():
	CursorManager.set_interact_cursor()

func _unhover_button():
	CursorManager.reset_cursor()

func set_dungeon_text_full():
	lbl_desc.text = "'Dinglemeyer will bring this back to camp for you, master!'"

func set_town_text_full():
	lbl_desc.text = "'Dinglemeyer is holding this for you, master!'"

func set_town_text_empty():
	lbl_desc.text = "'What would you like Dinglemeyer to hold for you, master?'"

func set_dungeon_text_empty():
	lbl_desc.text = "'What shall Dinglemeyer run back to camp for you, master?'"

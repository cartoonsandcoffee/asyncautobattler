class_name DoorChoice
extends Control

## Individual door choice button that displays room type info

signal door_selected(room_data: RoomData)

@onready var door_button: Button = $btnPickDoor
@onready var room_label: Label = $tooltipPanel/PanelContainer/MarginContainer/VBoxContainer/lblName
@onready var room_desc: RichTextLabel = $tooltipPanel/PanelContainer/MarginContainer/VBoxContainer/txtDesc
@onready var pic_door: TextureRect = $picDoor
@onready var tooltip_panel: Panel = $tooltipPanel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var room_data: RoomData

func set_references():
	door_button = $btnPickDoor
	room_label = $tooltipPanel/PanelContainer/MarginContainer/VBoxContainer/lblName
	room_desc = $tooltipPanel/PanelContainer/MarginContainer/VBoxContainer/txtDesc
	pic_door = $picDoor
	tooltip_panel = $tooltipPanel
	anim_player = $AnimationPlayer

func setup_door(data: RoomData):
	set_references()
	room_data = data
	
	# Set up the visual display using RoomDefinition
	if room_data.room_definition:
		room_label.text = room_data.room_definition.room_name
		room_desc.text = room_data.room_definition.room_desc
		room_desc.visible = true

		if room_data.room_definition.door_texture:
			pic_door.texture = room_data.room_definition.door_texture
		else:
			pic_door.hide()
	else:
		# Fallback for rooms without definitions
		room_label.text = "Unknown Room"
		pic_door.hide()
	
	# Set colors based on room rarity
	set_door_appearance()

func set_door_appearance():
	if not room_data.room_definition:
		return

	pic_door.modulate = room_data.room_definition.room_color	
	var gamecolors = GameColors.new()
	
	# Color based on rarity instead of room type
	match room_data.room_definition.rarity:
		Enums.Rarity.COMMON:
			room_label.modulate = gamecolors.rarity.common
		Enums.Rarity.UNCOMMON:
			room_label.modulate = gamecolors.rarity.uncommon
		Enums.Rarity.RARE:
			room_label.modulate = gamecolors.rarity.rare
		Enums.Rarity.UNIQUE:
			room_label.modulate = gamecolors.rarity.unique
		Enums.Rarity.LEGENDARY:
			room_label.modulate = gamecolors.rarity.legendary

func _on_btn_pick_door_mouse_exited() -> void:
	tooltip_panel.visible = false


func _on_btn_pick_door_mouse_entered() -> void:
	tooltip_panel.visible = true
			
func on_room_completed():
	anim_player.play("show_door")

func _on_btn_pick_door_pressed() -> void:
	door_selected.emit(room_data)

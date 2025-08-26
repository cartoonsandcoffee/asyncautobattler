extends Node

signal show_minimap()

enum RoomType {
	STARTER,
	HALLWAY,
	TOMB,
	CHAMBERS,
	FORGE, 
	LIBRARY,
	COVEN,
	LARDER,
	GALLERY,
	BOSS,
	SPECIAL
}

func get_background_for_room_type(type: RoomType) -> Texture2D:
	match type:
		RoomType.STARTER:
			return preload("res://Assets/Art/Room_02_Background.png")
		RoomType.HALLWAY:
			return preload("res://Assets/Art/Room_01_Background.png")
		_:
			return preload("res://Assets/Art/Room_02_Background.png")

func slide_in_menus():
	show_minimap.emit()
class_name PopupMapMaker
extends Control

signal event_skipped()
signal destination_selected(room_id: String)

@onready var anim_main: AnimationPlayer = $AnimationPlayer
@onready var button_holder: GridContainer = $CanvasLayer/Control/centerArea/PanelContainer/GridContainer

const DESTINATION_POOL: Array[Dictionary] = [
	{ "id": "uncommon_treasure_bugs", "label": "Bug Mound", "icon": preload("res://Resources/DestinationButtons/bug_mound.tres"), "weight": 5, "min_rank": 1  },
	{ "id": "uncommon_merchant", "label": "Variety Merchant", "icon": preload("res://Resources/DestinationButtons/variety_merchant.tres"), "weight": 5, "min_rank": 1  },
	{ "id": "common_treasure_gold", "label": "Gold Cache", "icon": preload("res://Resources/DestinationButtons/gold_cache.tres"), "weight": 5, "min_rank": 1  },
	{ "id": "uncommon_treasure_weapons", "label": "Weapon Pile", "icon": preload("res://Resources/DestinationButtons/weapon_pile.tres"), "weight": 5, "min_rank": 1  },
	{ "id": "uncommon_treasure_sarcophagus", "label": "Sarcophagus", "icon": preload("res://Resources/DestinationButtons/sarcophagus.tres"), "weight": 5, "min_rank": 1  },
	{ "id": "common_utility_upgrade", "label": "Weapon Upgrade", "icon": preload("res://Resources/DestinationButtons/weapon_upgrade.tres"), "weight": 5, "min_rank": 1  },
	{ "id": "uncommon_utility_imbue", "label": "Weapon Enchantment", "icon": preload("res://Resources/DestinationButtons/weapon_enchantment.tres"), "weight": 5, "min_rank": 2  },
	{ "id": "common_camp", "label": "Camp File", "icon": preload("res://Resources/DestinationButtons/camp_fire.tres"), "weight": 5, "min_rank": 2  },
	{ "id": "rare_merchant", "label": "Rare Merchant", "icon": preload("res://Resources/DestinationButtons/rare_merchant.tres"), "weight": 1, "min_rank": 3  },
	{ "id": "rare_utility_fountain", "label": "Mystical Fountain", "icon": preload("res://Resources/DestinationButtons/fountain.tres"), "weight": 1, "min_rank": 3  },
	{ "id": "rare_treasure_crystal", "label": "Crystal Cave", "icon": preload("res://Resources/DestinationButtons/crystal_cave.tres"), "weight": 1, "min_rank": 3  },
	{ "id": "rare_tinker_room", "label": "Old Tinkers Workshop", "icon": preload("res://Resources/DestinationButtons/tinkers_workshop.tres"), "weight": 1, "min_rank": 3  },
	{ "id": "rare_elite_bug", "label": "Infested Hall", "icon": preload("res://Resources/DestinationButtons/scorpion.tres"), "weight": 1, "min_rank": 3  },
	{ "id": "rare_utility_superupgrade", "label": "Lounging Figure", "icon": preload("res://Resources/DestinationButtons/super_upgrade.tres"), "weight": 1, "min_rank": 3  },
	{ "id": "rare_encampment", "label": "Rumored Encampment", "icon": preload("res://Resources/DestinationButtons/encampment.tres"), "weight": 1, "min_rank": 3  },	
]

const PICK_COUNT: int = 3
const DEST_BUTTON_SCENE := preload("res://Scenes/Elements/Buttons/custom_destination_button.tscn")
var _rolled_destinations: Array = []

func _init() -> void:
	pass

func _ready() -> void:
	add_to_group("item_selection_events") 

func _populate_destinations() -> void:
	for child in button_holder.get_children():
		child.free()

	for data in _rolled_destinations:
		var btn: CustomDestinationButton = DEST_BUTTON_SCENE.instantiate()
		button_holder.add_child(btn)
		btn.setup(data["id"], data["label"], data["icon"])
		btn.destination_chosen.connect(_button_pressed)

func roll_destinations() -> void:
	var current_rank := DungeonManager.current_rank

	var available := DESTINATION_POOL.filter(func(entry: Dictionary) -> bool:
		if entry.get("min_rank", 1) > current_rank:
			return false
		return DungeonManager.is_room_available_for_map_maker(entry["id"])
	)

	var weighted: Array = []
	for entry in available:
		for i in entry.get("weight", 1):
			weighted.append(entry)
	weighted.shuffle()

	_rolled_destinations.clear()
	var seen: Dictionary = {}
	for entry in weighted:
		if not seen.has(entry["id"]):
			seen[entry["id"]] = true
			_rolled_destinations.append(entry)
		if _rolled_destinations.size() >= PICK_COUNT:
			break

## ----------------------------------------------------------------------------------------------------------------
##  Basic form and button stuff
## ----------------------------------------------------------------------------------------------------------------

func _button_pressed(_dest_string: String):
	await hide_popup()
	destination_selected.emit(_dest_string)

func _on_btn_skip_pressed() -> void:
	event_skipped.emit()
	hide_popup()


func _on_btn_skip_mouse_exited() -> void:
	pass # Replace with function body.

func _on_btn_skip_mouse_entered() -> void:
	AudioManager.play_ui_sound("woosh")

func show_popup():
	_populate_destinations()
	AudioManager.play_ui_sound("popup_open")
	Player.popup_open = true
	anim_main.play("show_popup")
	await anim_main.animation_finished

func hide_popup():
	AudioManager.play_ui_sound("popup_close")
	Player.popup_open = false
	anim_main.play("hide_popup")
	await anim_main.animation_finished

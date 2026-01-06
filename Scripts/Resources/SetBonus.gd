class_name SetBonus
extends Resource

@export var setbonus_name: String = ""
@export var unlocked: bool = true

@export_group("recipe")
# Required items (drag .tres files into this array)
@export var required_items: Array[Item] = []

@export_group("bonus")
## Set bonuses are stored as Item resources.
@export var setbonus_item: Item
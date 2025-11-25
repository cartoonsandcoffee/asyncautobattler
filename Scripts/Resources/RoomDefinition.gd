@tool
class_name RoomDefinition
extends Resource

@export_group("Room Identity")
@export var room_type: Enums.RoomType
@export var rarity: Enums.Rarity  = Enums.Rarity.COMMON:
	set(value):
		rarity = value
		notify_property_list_changed()
@export var room_name: String = "Unknown Room"
@export_multiline var room_desc: String = "Unknown Room"

@export_group("Visuals")
@export var background_texture: Texture2D
@export var door_texture: Texture2D
@export var room_icon: Texture2D  # abstract icon type for minimap
@export var room_color: Color = Color.WHITE

@export_group("Combat")
@export var can_have_random_combat: bool = false:
	set(value):
		can_have_random_combat = value
		notify_property_list_changed()
@export var random_combat_chance: float = 0.0  # 0.0-1.0
@export var specific_enemy: Enemy = null  # If set, ALWAYS spawns (overrides random)
## Will pick variants of possible enemies with "_easy", "_medium", "_hard" suffixes as player increases rank
@export var random_enemy_pool: Array[Enemy] = []  # Pick from this if combat rolls true

@export_group("Shortcuts")
# Navigation (for future shortcut system)
@export var can_spawn_shortcuts: bool = false
@export var shortcut_chance: float = 0.0  # 0.0-1.0

@export_group("Events")
# The events that can happen in this room type
@export var possible_events: Array[PackedScene] = []

@export_group("Generation Rules")
# Generation Rules
@export var spawn_weight: int = 1	# RNG weight for door generation (higher = more likely)
@export var min_rank: int = 1		# Lowest rank this room can appear in
@export var max_rank: int = 5		# highest rank this room can appear in

# This function controls which properties are visible in the inspector
func _validate_property(property: Dictionary) -> void:
	var prop_name = property.name
	
	if prop_name in ["random_combat_chance", "specific_enemy", "random_enemy_pool"]:
		if not can_have_random_combat:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return

	if prop_name == "can_spawn_shortcuts" || prop_name == "shortcut_chance":
		if rarity not in [Enums.Rarity.UNCOMMON, Enums.Rarity.RARE]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

func get_random_event() -> PackedScene:
	if possible_events.size() > 0:
		return possible_events.pick_random()
	else:
		push_warning("No events defined for room: " + room_name)
		return null

func can_appear_at_rank(rank: int) -> bool:
	return rank >= min_rank and rank <= max_rank


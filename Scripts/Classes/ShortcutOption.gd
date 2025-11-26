class_name ShortcutOption
extends Resource

## Represents one shortcut destination choice

var destination_room: RoomDefinition  # Where shortcut leads
var skip_count: int                    # How many rooms skipped
var has_combat: bool                   # Does destination have combat?
var display_name: String               # Room name for UI

func _init(dest: RoomDefinition = null, skips: int = 1, combat: bool = false):
	destination_room = dest
	skip_count = skips
	has_combat = combat
	display_name = dest.room_name if dest else "Unknown"

func get_destination_index(current_index: int) -> int:
	# Calculate which room slot this targets
	return current_index + 1 + skip_count
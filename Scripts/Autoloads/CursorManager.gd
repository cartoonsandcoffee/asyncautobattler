extends Node

enum CursorType {
	NONE,			# used at the beginnign
	DEFAULT,           # Normal pointer
	INTERACT,          # Hovering over buttons/doors (hand/pointer)
	TALK,			   # interacting with people
	ITEM_HOVER,        # Hovering over items (magnifying glass)
	ITEM_GRAB,         # Dragging an item (closed hand)
	COMBAT,            # During combat (crosshair/sword)
	DISABLED,          # Can't interact (X or blocked)
	NAVIGATION,		   # For moving between rooms
	LOADING            # Processing (hourglass)
}

# Store cursor textures
var cursors: Dictionary = {}
var current_cursor: CursorType = CursorType.NONE

# Hotspot positions (where the click point is on the cursor image)
var cursor_hotspots: Dictionary = {
	CursorType.DEFAULT: Vector2(0, 0),          # Top-left
	CursorType.INTERACT: Vector2(8, 0),         # Finger tip
	CursorType.ITEM_HOVER: Vector2(12, 12),     # Center
	CursorType.ITEM_GRAB: Vector2(16, 16),      # Center of hand
	CursorType.TALK: Vector2(16, 16),           # Center of bubble	
	CursorType.COMBAT: Vector2(16, 16),         # Center of crosshair
	CursorType.DISABLED: Vector2(16, 16),       # Center
	CursorType.NAVIGATION: Vector2(16, 16),     # Center	
	CursorType.LOADING: Vector2(16, 16)         # Center
}

func _ready():
	_load_cursors()
	set_cursor(CursorType.DEFAULT)

func _load_cursors():
	"""Load all cursor textures from Resources/Cursors/"""
	# Map cursor types to file paths
	var cursor_paths = {
		CursorType.DEFAULT: "res://Assets/UI/Cursors/pointer_c_shaded.png",
		CursorType.INTERACT: "res://Assets/UI/Cursors/gauntlet_default.png",
		CursorType.TALK: "res://Assets/UI/Cursors/message_dots_round.png",		
		CursorType.ITEM_HOVER: "res://Assets/UI/Cursors/hand_open.png",
		CursorType.ITEM_GRAB: "res://Assets/UI/Cursors/hand_closed.png",
		CursorType.COMBAT: "res://Assets/UI/Cursors/tool_sword_b.png",
		CursorType.DISABLED: "res://Assets/UI/Cursors/disabled.png",
		CursorType.NAVIGATION: "res://Assets/UI/Cursors/door_enter.png",
		CursorType.LOADING: "res://Assets/UI/Cursors/busy_hourglass_outline_detail.png"
	}
	
	# Load each cursor
	for cursor_type in cursor_paths:
		var path = cursor_paths[cursor_type]
		
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				cursors[cursor_type] = texture
		else:
			push_warning("[CursorManager] Cursor not found: %s" % path)
			# Use default Godot cursor as fallback
			cursors[cursor_type] = null

func set_cursor(cursor_type: CursorType):
	"""Change the active cursor."""
	if cursor_type == current_cursor:
		return  # Already using this cursor
	
	current_cursor = cursor_type
	
	# Get cursor texture
	var texture = cursors.get(cursor_type)
	
	if texture:
		# Custom cursor
		var hotspot = cursor_hotspots.get(cursor_type, Vector2.ZERO)
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)
	else:
		# Fallback to Godot's built-in cursors
		match cursor_type:
			CursorType.INTERACT:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			CursorType.ITEM_GRAB:
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			CursorType.DISABLED:
				Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
			CursorType.LOADING:
				Input.set_default_cursor_shape(Input.CURSOR_WAIT)
			_:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func reset_cursor():
	"""Return to default cursor."""
	set_cursor(CursorType.DEFAULT)

# Convenience functions for common cursor changes
func set_interact_cursor():
	set_cursor(CursorType.INTERACT)

func set_item_hover_cursor():
	set_cursor(CursorType.ITEM_HOVER)

func set_item_grab_cursor():
	set_cursor(CursorType.ITEM_GRAB)

func set_combat_cursor():
	set_cursor(CursorType.COMBAT)

func set_disabled_cursor():
	set_cursor(CursorType.DISABLED)

func set_loading_cursor():
	set_cursor(CursorType.LOADING)

func set_navigation_cursor():
	set_cursor(CursorType.NAVIGATION)

func set_talk_cursor():
	set_cursor(CursorType.TALK)	

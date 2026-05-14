class_name DungeonBag
extends Node

## Weighted bag system for dungeon room generation.
## Guarantees rare rooms appear within a cycle while respecting filter rules.
## Exhausted rooms (once-per-run) are permanently removed.
## Temp-skipped rooms (state-dependent) are re-evaluated each reshuffle.

var _active_bag: Array[RoomDefinition] = []
var _temp_skipped: Array[RoomDefinition] = []
var _exhausted_ids: Array[String] = []
var _current_rank: int = 1
var _last_drawn: RoomDefinition = null
var _reshuffle_count: int = 0

# ============================================================================
# EXHAUSTIBLE ROOMS
# Add new once-per-run room names here as the game grows.
# These are automatically exhausted when the encounter completes
# by calling exhaust_room() from the relevant event script.
# ============================================================================
const EXHAUSTIBLE_ROOMS: Array[String] = [
	"An Insect Nest",
	"Ancient Hall",
	"Tinker's Workshop",
	"Mysterious Fountain",
	"An Improvised Encampment",
	"Crystal Cave",
	# "New Room Name Here",
]

# ============================================================================
# ADJACENCY RULES
# Defines which room types cannot appear back-to-back.
# Add new rules here as new room types are introduced.
# ============================================================================
const BLOCKED_AFTER: Dictionary = {
	# Key: RoomType that was just drawn
	# Value: Array of RoomTypes that cannot appear next
	Enums.RoomType.UTILITY: [Enums.RoomType.UTILITY],
	Enums.RoomType.MERCHANT: [Enums.RoomType.MERCHANT],
}

# ============================================================================
# PUBLIC API
# ============================================================================

func build_for_rank(rank: int) -> void:
	_current_rank = rank
	_last_drawn = null
	_active_bag.clear()
	_temp_skipped.clear()
	_fill_and_shuffle()

func advance_rank(new_rank: int) -> void:
	_current_rank = new_rank
	_last_drawn = null
	_active_bag.clear()
	_temp_skipped.clear()
	# _exhausted_ids intentionally kept — run-scoped not rank-scoped
	_fill_and_shuffle()

func reset_for_new_run() -> void:
	_active_bag.clear()
	_temp_skipped.clear()
	_exhausted_ids.clear()
	_last_drawn = null
	_current_rank = 1
	_fill_and_shuffle()
	
func exhaust_room(room_name: String) -> void:
	"""Permanently remove a room from this run. Call from the room's event script on completion."""
	if not _exhausted_ids.has(room_name):
		_exhausted_ids.append(room_name)
	_active_bag = _active_bag.filter(func(rd): return rd.room_name != room_name)
	_temp_skipped = _temp_skipped.filter(func(rd): return rd.room_name != room_name)

func draw() -> RoomDefinition:
	"""Draw next valid room. Returns null only if truly nothing is available."""
	var attempts = 0
	var bag_size = _active_bag.size()

	while _active_bag.size() > 0:
		var candidate = _active_bag.pop_front()
		if _passes_filters(candidate):
			_last_drawn = candidate
			return candidate
		else:
			_temp_skipped.append(candidate)
		attempts += 1
		if attempts >= bag_size:
			break

	# Active bag exhausted or all skipped — reshuffle and try once more
	_fill_and_shuffle()

	for i in range(_active_bag.size()):
		var candidate = _active_bag.pop_front()
		if _passes_filters(candidate):
			_last_drawn = candidate
			return candidate
		_temp_skipped.append(candidate)

	return null

# ============================================================================
# PRIVATE
# ============================================================================

func _fill_and_shuffle() -> void:
	_reshuffle_count += 1
	print("[DungeonBag] Reshuffle #%d (rank %d)" % [_reshuffle_count, _current_rank])

	_active_bag.clear()
	var all_rooms = RoomRegistry.get_available_rooms_for_rank(_current_rank)
	for room_def in all_rooms:
		if _exhausted_ids.has(room_def.room_name):
			continue
		var weight = room_def.get_weight_for_rank(_current_rank)
		for i in range(weight):
			_active_bag.append(room_def)
	_active_bag.shuffle()

func _passes_filters(room_def: RoomDefinition) -> bool:
	# -----------------------------------------------------------------------
	# ADJACENCY RULES
	# Prevent certain room types from appearing back-to-back.
	# Edit BLOCKED_AFTER const above to add new rules.
	# -----------------------------------------------------------------------
	if _last_drawn != null and BLOCKED_AFTER.has(_last_drawn.room_type):
		var blocked_types: Array = BLOCKED_AFTER[_last_drawn.room_type]
		if room_def.room_type in blocked_types:
			return false

	# -----------------------------------------------------------------------
	# PLAYER STATE RULES
	# Rooms that are temporarily unavailable based on current player state.
	# These rooms stay in temp_skipped and re-enter the bag on next reshuffle.
	# -----------------------------------------------------------------------
	if room_def.room_type == Enums.RoomType.MERCHANT:
		if Player.stats.gold < 3:
			return false

	if room_def.room_name == "Weapon Upgrade":
		if Player.all_weapon_upgrades_maxed():
			return false

	if room_def.room_name == "A camp":
		if Player.campfires_left_this_rank <= 0:
			return false

	# -----------------------------------------------------------------------
	# EXHAUSTIBLE ROOM RULES
	# Rooms blocked by per-run usage limits.
	# Add new conditions here as new exhaustible rooms are introduced.
	# Cross-reference with EXHAUSTIBLE_ROOMS const above.
	# -----------------------------------------------------------------------
	if room_def.room_name == "Ancient Hall":
		if Player.super_upgrades_left <= 0:
			return false

	if room_def.room_name == "An Insect Nest":
		if Player.scorpion_encounters_left <= 0:
			return false

	if room_def.room_name == "An Improvised Encampment":
		if Player.rare_camp_events_left <= 0:
			return false

	if room_def.room_name == "Tinker's Workshop":
		if Player.tinker_events_left <= 0:
			return false

	if room_def.room_name == "Crystal Cave":
		if Player.crystal_events_left <= 0:
			return false

	if room_def.room_name == "Mysterious Fountain":
		if Player.potion_makers_left <= 0:
			return false

	return true

## ---------------------------------------------------------------
## -- For Loading Saved Games
## ---------------------------------------------------------------
func restore_from_save(rank: int, exhausted_ids: Array, last_drawn_name: String) -> void:
	# Rebuild bag state from a save. Called by Player.from_dict after rank is restored.

	_current_rank = rank
	_exhausted_ids.clear()
	for id in exhausted_ids:
		_exhausted_ids.append(str(id))
	_last_drawn = null
	_active_bag.clear()
	_temp_skipped.clear()
	_fill_and_shuffle()  # rebuilds active bag respecting exhausted list
	if last_drawn_name != "":
		for rd in RoomRegistry.get_available_rooms_for_rank(_current_rank):
			if rd.room_name == last_drawn_name:
				_last_drawn = rd
				break

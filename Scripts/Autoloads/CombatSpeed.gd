extends Node

signal speed_changed(new_speed: CombatSpeedMode)

enum CombatSpeedMode {
	PAUSE = 0,
	NORMAL = 1,
	FAST = 2,
	VERY_FAST = 3
}

var current_mode: CombatSpeedMode = CombatSpeedMode.NORMAL
var is_paused: bool = false

# Speed multipliers for different modes
const SPEED_MULTIPLIERS = {
	CombatSpeedMode.PAUSE: 0.0,
	CombatSpeedMode.NORMAL: 1.0,
	CombatSpeedMode.FAST: 1.5,
	CombatSpeedMode.VERY_FAST: 2.0
}

# Duration settings for different animation types (in seconds at NORMAL speed)
const BASE_DURATIONS = {
	"milestone_sign": 1.5,        # Battle Start, Turn Start signs
	"item_highlight": 0.8,         # Item slot highlighting
	"item_proc": 1.0,              # Item effect proc animation
	"proc_overlap": 0.6,           # Time before starting next proc (for overlap)
	"attack_slide": 1,           # Attack slide animation
	"damage_number": 0.8,          # Damage indicator animation
	"status_effect": 0.6,          # Status effect visual
	"turn_gap": 0.6,               # Brief pause between major phases
}

func get_multiplier() -> float:
	return SPEED_MULTIPLIERS[current_mode]

func get_duration(animation_type: String) -> float:
	"""Get the adjusted duration for an animation type"""
	if not animation_type in BASE_DURATIONS:
		push_warning("Unknown animation type: " + animation_type)
		return 1.0
	
	var base = BASE_DURATIONS[animation_type]
	var multiplier = get_multiplier()
	
	if multiplier == 0.0:
		return INF  # Paused
	
	return base / multiplier

func get_overlap_duration() -> float:
	"""Get the overlap time for sequential animations at current speed"""
	var multiplier = get_multiplier()
	if multiplier == 0.0:
		return INF
	
	# At normal speed, wait full duration. At faster speeds, allow more overlap
	match current_mode:
		CombatSpeedMode.NORMAL:
			return get_duration("item_proc") * 0.9  # 90% wait before next
		CombatSpeedMode.FAST:
			return get_duration("item_proc") * 0.6  # 60% wait before next
		CombatSpeedMode.VERY_FAST:
			return get_duration("item_proc") * 0.4  # 40% wait before next
		_:
			return INF

func set_speed(mode: CombatSpeedMode):
	"""Set the combat speed mode"""
	var was_paused = is_paused
	current_mode = mode
	is_paused = (mode == CombatSpeedMode.PAUSE)
	
	# Emit signal for all listeners
	speed_changed.emit(mode)
	
	# Log the change
	print("Combat speed set to: ", CombatSpeedMode.keys()[mode])

func pause_combat():
	set_speed(CombatSpeedMode.PAUSE)

func resume_combat():
	if is_paused:
		set_speed(CombatSpeedMode.NORMAL)

func cycle_speed():
	"""Cycle through speed modes (excluding pause)"""
	match current_mode:
		CombatSpeedMode.PAUSE, CombatSpeedMode.NORMAL:
			set_speed(CombatSpeedMode.FAST)
		CombatSpeedMode.FAST:
			set_speed(CombatSpeedMode.VERY_FAST)
		CombatSpeedMode.VERY_FAST:
			set_speed(CombatSpeedMode.NORMAL)

func wait_if_paused():
	"""Await function that waits while paused"""
	while is_paused:
		await get_tree().process_frame

func create_timer(duration: float) -> SceneTreeTimer:
	"""Create a timer that respects pause state"""
	if is_paused:
		await wait_if_paused()
	
	await get_tree().create_timer(duration).timeout
	return null #get_tree().create_timer(duration)

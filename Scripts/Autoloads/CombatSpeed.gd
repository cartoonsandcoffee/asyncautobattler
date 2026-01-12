extends Node

signal speed_changed(new_speed: CombatSpeedMode)

enum CombatSpeedMode {
	PAUSE = 0,
	NORMAL = 1,
	FAST = 2,
	VERY_FAST = 3,
	INSTANT = 4
}

var current_mode: CombatSpeedMode = CombatSpeedMode.NORMAL
var is_paused: bool = false
var in_combat: bool = false

const SPEED_CONFIGS = {
	CombatSpeedMode.PAUSE: {
		"timer_multiplier": 0.0,
		"anim_speed": 0.0
	},
	CombatSpeedMode.NORMAL: {
		"timer_multiplier": 1.0,
		"anim_speed": 1.0
	},
	CombatSpeedMode.FAST: {
		"timer_multiplier": 2.0,    # Waits are half as long
		"anim_speed": 1.0           
	},
	CombatSpeedMode.VERY_FAST: {
		"timer_multiplier": 4.0,    # Waits are 1/4 as long
		"anim_speed": 1.0           
	},
	CombatSpeedMode.INSTANT: {
		"timer_multiplier": 999.0,   # effectively instant
		"anim_speed": 1.0            # anims won't play or play special QUICK combat flash
	}
}

# Duration settings for different animation types (in seconds at NORMAL speed)
const BASE_DURATIONS = {
	"milestone_sign": 1.3,        # Battle Start, Turn Start signs

	# ITEM PROCESSING
	"item_highlight": 1.2,         # Item slot highlighting     --- REMOVE ME 
	"item_highlight_brief": 0.6,   # brief flash                --- REMOVE ME
	"item_proc": 0.8,              # Item effect proc animation
	"proc_overlap": 0.66,           # Time before starting next proc (for overlap)
	
	# COMBAT PACING
	"attack_slide": 1.2,           # Attack slide animation
	"attack_gap": 0.2,             # between multiple strikes

	# VISUAL FEEDBACK
	"damage_number": 1.0,          # Damage indicator animation
	"exposed_wounded": 1.0,        # Timing for these effects
	"status_effect": 0.8,          # Status effect visual

	"turn_gap": 0.4,               # Brief pause between turns
	"phase_transition": 0.3,       # between major sections
}

func get_animation_variant(base_name: String) -> String:
	"""Get the correct animation variant based on current speed"""
	match CombatSpeed.current_mode:
		CombatSpeed.CombatSpeedMode.NORMAL:
			return base_name
		CombatSpeed.CombatSpeedMode.FAST:
			return base_name + "_fast"
		CombatSpeed.CombatSpeedMode.VERY_FAST:
			return base_name + "_very_fast"
		CombatSpeed.CombatSpeedMode.INSTANT:
			return base_name + "_instant"  # Doesn't matter, won't play
		_:
			return base_name

func get_multiplier() -> float:
	if not in_combat:
		return 1.0
	return SPEED_CONFIGS[current_mode]["timer_multiplier"]

func is_instant_mode() -> bool:
	return in_combat and current_mode == CombatSpeedMode.INSTANT

func get_duration(animation_type: String) -> float:
	if not animation_type in BASE_DURATIONS:
		push_warning("Unknown animation type: " + animation_type)
		return 1.0
	
	var base = BASE_DURATIONS[animation_type]
	var multiplier = get_multiplier()
	
	if multiplier == 0.0:
		return INF  # Paused
	
	return base / multiplier

func set_speed(mode: CombatSpeedMode):
	var was_paused = is_paused
	current_mode = mode
	is_paused = (mode == CombatSpeedMode.PAUSE)
	
	if is_paused and not was_paused:
		get_tree().paused = true
	elif not is_paused and was_paused:
		get_tree().paused = false
	
	# Emit signal for all listeners
	speed_changed.emit(mode)
	
	# Log the change
	print("Combat speed set to: ", CombatSpeedMode.keys()[mode])

func cycle_speed():
	"""Cycle through speed modes (excluding pause)"""
	match current_mode:
		CombatSpeedMode.PAUSE, CombatSpeedMode.NORMAL:
			set_speed(CombatSpeedMode.FAST)
		CombatSpeedMode.FAST:
			set_speed(CombatSpeedMode.VERY_FAST)
		CombatSpeedMode.VERY_FAST:
			set_speed(CombatSpeedMode.NORMAL)
		CombatSpeedMode.INSTANT:
			set_speed(CombatSpeedMode.NORMAL)


func enter_combat():
	in_combat = true

func exit_combat():
	in_combat = false
	get_tree().paused = false
	set_speed(CombatSpeedMode.NORMAL)

func create_timer(duration: float) -> SceneTreeTimer:
	# Then create the actual timer
	var mod_duration: float = 1.0

	match current_mode:
		CombatSpeedMode.PAUSE, CombatSpeedMode.NORMAL:
			mod_duration = 1.0
		CombatSpeedMode.FAST:
			mod_duration = 0.75
		CombatSpeedMode.VERY_FAST:
			mod_duration = 0.66
		CombatSpeedMode.INSTANT:
			mod_duration = 0.5

	if duration > 0:
		await get_tree().create_timer(duration).timeout
	
	return null

extends Node

var shake_strength: float = 0.0
var shake_time: float = 0.0

var rng = RandomNumberGenerator.new()

var camera: Camera2D

func _ready():
	# Set process to always run (autoload behavior)
	set_process(true)
	
	# Try to find camera immediately
	call_deferred("_initial_camera_check")

func _initial_camera_check():
	refresh_camera()

func _process(delta: float):
	# Get current camera if we don't have one or if scene changed
	if not is_instance_valid(camera):
		refresh_camera()
	
	if shake_strength > 0:
		# Reduce trauma over time
		shake_strength = lerpf(shake_strength, 0, shake_time * delta)
		camera.offset = random_offset()

func random_offset() -> Vector2:
	return Vector2(rng.randf_range(-shake_strength,shake_strength),rng.randf_range(-shake_strength,shake_strength))


## Preset shake intensities for common use cases
func shake_light():
	shake_strength = 30.0
	shake_time = 5.0

func shake_medium():
	shake_strength = 60.0
	shake_time = 4.0

func shake_heavy():
	shake_strength = 120.0
	shake_time = 3.0

func shake_extreme():
	shake_strength = 150.0
	shake_time = 2.0

## Custom shake with specific parameters
func shake_custom(intensity: float, duration: float = 1.0):
	shake_strength = intensity
	shake_time = duration


## Refresh camera reference (useful after scene changes)
func refresh_camera():
	camera = get_viewport().get_camera_2d()

	if camera:
		var viewport_size = get_viewport().size
		
		# Center the camera on the viewport
		# Position the camera at half the viewport size
		camera.global_position = viewport_size / 2
		
		# Reset offset to zero (screen shake will use this)
		camera.offset = Vector2.ZERO

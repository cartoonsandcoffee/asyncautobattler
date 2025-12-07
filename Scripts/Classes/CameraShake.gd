extends Node

var trauma: float = 0.0
var trauma_power: int = 2
var decay: float = 1.0  # Trauma reduction per second
var max_offset: float = 100.0
var max_rotation: float = 10.0

var noise: FastNoiseLite
var noise_speed: float = 50.0
var time: float = 0.0

@onready var ui_root: Control  # Assign in _ready()

func _ready():
	# Get reference to main UI container
	#ui_root = get_tree().root.get_node(".")
	# Or however your scene is structured
	
	# Setup noise for smooth shake
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.5

func _process(delta):
	if trauma > 0:
		time += delta
		trauma = max(trauma - decay * delta, 0)
		_apply_shake()
	elif ui_root and ui_root.position != Vector2.ZERO:
		# Reset position when shake ends
		ui_root.position = Vector2.ZERO
		ui_root.rotation = 0

func add_trauma(amount: float):
	"""Add trauma for screen shake. Value from 0-1."""
	trauma = min(trauma + amount, 1.0)

func _apply_shake():
	if not ui_root:
		return
	
	var shake_amount = pow(trauma, trauma_power)
	
	# Get noise values for smooth shake
	var offset_x = noise.get_noise_2d(time * noise_speed, 0) * max_offset * shake_amount
	var offset_y = noise.get_noise_2d(0, time * noise_speed) * max_offset * shake_amount
	var rotation = noise.get_noise_2d(time * noise_speed, time * noise_speed) * max_rotation * shake_amount
	
	# Apply to UI root
	ui_root.position = Vector2(offset_x, offset_y)
	ui_root.rotation_degrees = rotation

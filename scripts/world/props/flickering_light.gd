## flickering_light.gd - Flickering torch/fire light effect
## Creates realistic flame flicker using noise-based intensity variation
## PS1 aesthetic: warm orange light, subtle movement
class_name FlickeringLight
extends OmniLight3D


## Flicker intensity settings
@export var base_energy: float = 1.0
@export var flicker_amount: float = 0.3  # How much energy varies
@export var flicker_speed: float = 8.0   # Speed of flicker

## Color variation
@export var base_color: Color = Color(1.0, 0.7, 0.3)  # Warm orange
@export var color_variation: float = 0.1  # Subtle color shift

## Range variation
@export var base_range: float = 8.0
@export var range_variation: float = 0.5

## Internal state
var _time: float = 0.0
var _noise: FastNoiseLite
var _noise_offset: float = 0.0


func _ready() -> void:
	# Initialize noise for organic flicker
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.5
	_noise.fractal_octaves = 2

	# Random offset so multiple lights don't sync
	_noise_offset = randf() * 1000.0

	# Set initial values
	light_energy = base_energy
	light_color = base_color
	omni_range = base_range

	# PS1 style: no shadows from torches (performance)
	shadow_enabled = false


func _process(delta: float) -> void:
	_time += delta * flicker_speed

	# Get noise values for organic variation
	var noise_val: float = _noise.get_noise_1d(_time + _noise_offset)
	var noise_val2: float = _noise.get_noise_1d(_time * 1.3 + _noise_offset + 100.0)

	# Energy flicker
	var energy_mult: float = 1.0 + noise_val * flicker_amount
	light_energy = base_energy * energy_mult

	# Subtle color variation (shift between orange and yellow)
	var color_shift: float = noise_val2 * color_variation
	light_color = Color(
		base_color.r + color_shift * 0.1,
		base_color.g + color_shift * 0.2,
		base_color.b - color_shift * 0.1
	)

	# Range variation
	omni_range = base_range + noise_val * range_variation


## Create a flickering torch light at position
static func spawn_torch_light(parent: Node, pos: Vector3, energy: float = 1.0, light_range: float = 8.0) -> FlickeringLight:
	var light := FlickeringLight.new()
	light.name = "TorchLight"
	light.position = pos
	light.base_energy = energy
	light.base_range = light_range
	light.base_color = Color(1.0, 0.7, 0.3)  # Warm torch
	light.flicker_amount = 0.3
	light.flicker_speed = 8.0

	parent.add_child(light)
	return light


## Create a campfire light (bigger, more intense flicker)
static func spawn_campfire_light(parent: Node, pos: Vector3) -> FlickeringLight:
	var light := FlickeringLight.new()
	light.name = "CampfireLight"
	light.position = pos
	light.base_energy = 1.5
	light.base_range = 12.0
	light.base_color = Color(1.0, 0.6, 0.2)  # Deeper orange
	light.flicker_amount = 0.4
	light.flicker_speed = 6.0
	light.range_variation = 1.0

	parent.add_child(light)
	return light


## Create a brazier light (steady, less flicker)
static func spawn_brazier_light(parent: Node, pos: Vector3) -> FlickeringLight:
	var light := FlickeringLight.new()
	light.name = "BrazierLight"
	light.position = pos
	light.base_energy = 1.2
	light.base_range = 10.0
	light.base_color = Color(1.0, 0.75, 0.4)  # Slightly yellow
	light.flicker_amount = 0.15
	light.flicker_speed = 5.0

	parent.add_child(light)
	return light


## Create eerie green light (for dungeons, magic)
static func spawn_eerie_light(parent: Node, pos: Vector3) -> FlickeringLight:
	var light := FlickeringLight.new()
	light.name = "EerieLight"
	light.position = pos
	light.base_energy = 0.8
	light.base_range = 6.0
	light.base_color = Color(0.3, 0.9, 0.4)  # Sickly green
	light.flicker_amount = 0.2
	light.flicker_speed = 3.0
	light.color_variation = 0.15

	parent.add_child(light)
	return light

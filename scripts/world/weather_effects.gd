## weather_effects.gd - Visual weather effects node spawned by WeatherManager
## Handles rain particles, fog density, and lighting adjustments
## PS1-style aesthetics: limited particles, chunky rain drops
class_name WeatherEffects
extends Node3D

## Reference to the player node (effects follow player)
var _player: Node3D = null

## Current weather state being displayed
var _current_weather: Enums.Weather = Enums.Weather.CLEAR

## Rain particle system
var _rain_particles: GPUParticles3D = null

## Reference to the world environment for fog adjustment
var _world_environment: WorldEnvironment = null

## Cached original fog values for restoration
var _original_fog_density: float = 0.015
var _original_fog_color: Color = Color(0.45, 0.42, 0.4)

## Current interpolated values
var _current_fog_density: float = 0.015
var _current_light_energy_modifier: float = 1.0

## ============================================================================
## FOG SETTINGS (PS1-style tight visibility)
## ============================================================================

## Fog density for each weather type
const FOG_DENSITY_CLEAR: float = 0.015
const FOG_DENSITY_CLOUDY: float = 0.018
const FOG_DENSITY_RAIN: float = 0.025
const FOG_DENSITY_FOG: float = 0.06  # Heavy fog, very limited visibility

## Fog color tints
const FOG_COLOR_CLEAR: Color = Color(0.45, 0.42, 0.4)
const FOG_COLOR_CLOUDY: Color = Color(0.35, 0.35, 0.38)
const FOG_COLOR_RAIN: Color = Color(0.32, 0.32, 0.35)
const FOG_COLOR_FOG: Color = Color(0.4, 0.4, 0.42)

## Light energy modifiers (relative to day/night cycle)
const LIGHT_MOD_CLEAR: float = 1.0
const LIGHT_MOD_CLOUDY: float = 0.7  # Overcast = darker
const LIGHT_MOD_RAIN: float = 0.65
const LIGHT_MOD_FOG: float = 0.8

## Transition lerp speed (lower = smoother but slower)
const TRANSITION_LERP_SPEED: float = 0.5

## ============================================================================
## RAIN SETTINGS (PS1-style chunky rain)
## ============================================================================

## Max particles for PS1 aesthetic (keep low)
const RAIN_PARTICLE_COUNT: int = 150

## Rain spawn area around player
const RAIN_SPAWN_RADIUS: float = 15.0
const RAIN_SPAWN_HEIGHT: float = 20.0
const RAIN_FALL_SPEED: float = 25.0

## Rain drop appearance
const RAIN_DROP_SIZE: float = 0.08


## ============================================================================
## LIFECYCLE
## ============================================================================

func _ready() -> void:
	_setup_rain_particles()


func _exit_tree() -> void:
	# Restore original fog settings when effects are removed
	_restore_original_fog()


## Initialize with current weather and player reference
func initialize(weather: Enums.Weather, player: Node3D) -> void:
	_player = player
	_current_weather = weather

	# Cache the world environment
	_cache_world_environment()

	# Apply weather immediately on init
	apply_weather_immediate(weather)


## ============================================================================
## UPDATE METHODS
## ============================================================================

## Called every frame by WeatherManager
func update_effects(delta: float, transition_progress: float) -> void:
	# Follow player
	_follow_player()

	# Get target values based on current/transitioning weather
	var target_fog_density: float = _get_fog_density_for_weather(_current_weather)
	var target_fog_color: Color = _get_fog_color_for_weather(_current_weather)
	var target_light_mod: float = _get_light_modifier_for_weather(_current_weather)

	# If WeatherManager is transitioning, interpolate based on progress
	if WeatherManager and WeatherManager._transitioning:
		var from_density: float = _get_fog_density_for_weather(WeatherManager.current_weather)
		var to_density: float = _get_fog_density_for_weather(WeatherManager._target_weather)
		var from_color: Color = _get_fog_color_for_weather(WeatherManager.current_weather)
		var to_color: Color = _get_fog_color_for_weather(WeatherManager._target_weather)
		var from_light: float = _get_light_modifier_for_weather(WeatherManager.current_weather)
		var to_light: float = _get_light_modifier_for_weather(WeatherManager._target_weather)

		target_fog_density = lerpf(from_density, to_density, transition_progress)
		target_fog_color = from_color.lerp(to_color, transition_progress)
		target_light_mod = lerpf(from_light, to_light, transition_progress)

		# Update current weather for effects
		_current_weather = WeatherManager._target_weather if transition_progress > 0.5 else WeatherManager.current_weather

	# Smoothly interpolate current values
	_current_fog_density = lerpf(_current_fog_density, target_fog_density, delta * TRANSITION_LERP_SPEED)
	_current_light_energy_modifier = lerpf(_current_light_energy_modifier, target_light_mod, delta * TRANSITION_LERP_SPEED)

	# Apply to environment
	_apply_fog_settings(_current_fog_density, target_fog_color)
	_apply_light_modifier(_current_light_energy_modifier)

	# Update rain visibility
	_update_rain_visibility()


## Apply weather state immediately (no interpolation)
func apply_weather_immediate(weather: Enums.Weather) -> void:
	_current_weather = weather
	_current_fog_density = _get_fog_density_for_weather(weather)
	_current_light_energy_modifier = _get_light_modifier_for_weather(weather)

	var fog_color: Color = _get_fog_color_for_weather(weather)

	_apply_fog_settings(_current_fog_density, fog_color)
	_apply_light_modifier(_current_light_energy_modifier)
	_update_rain_visibility()


## ============================================================================
## RAIN PARTICLE SETUP
## ============================================================================

func _setup_rain_particles() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "RainParticles"

	# PS1-style low particle count
	_rain_particles.amount = RAIN_PARTICLE_COUNT
	_rain_particles.lifetime = RAIN_SPAWN_HEIGHT / RAIN_FALL_SPEED
	_rain_particles.explosiveness = 0.0
	_rain_particles.randomness = 0.2
	_rain_particles.fixed_fps = 30  # PS1-style lower framerate
	_rain_particles.visibility_aabb = AABB(
		Vector3(-RAIN_SPAWN_RADIUS, -5, -RAIN_SPAWN_RADIUS),
		Vector3(RAIN_SPAWN_RADIUS * 2, RAIN_SPAWN_HEIGHT + 10, RAIN_SPAWN_RADIUS * 2)
	)

	# Create particle material
	var material := ParticleProcessMaterial.new()

	# Emission shape - box above player
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(RAIN_SPAWN_RADIUS, 0.5, RAIN_SPAWN_RADIUS)

	# Rain falls down
	material.direction = Vector3(0, -1, 0)
	material.spread = 5.0  # Slight spread for natural look
	material.initial_velocity_min = RAIN_FALL_SPEED * 0.9
	material.initial_velocity_max = RAIN_FALL_SPEED * 1.1

	# No gravity needed (constant velocity)
	material.gravity = Vector3.ZERO

	# Slight random rotation for variety
	material.angle_min = -10.0
	material.angle_max = 10.0

	_rain_particles.process_material = material

	# Create visual mesh for rain drops (simple quad stretched vertically)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(RAIN_DROP_SIZE, RAIN_DROP_SIZE * 8)  # Stretched for rain streak

	# Rain material - semi-transparent white/blue
	var rain_mat := StandardMaterial3D.new()
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.7, 0.75, 0.85, 0.4)
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = rain_mat

	_rain_particles.draw_pass_1 = mesh

	# Position above player
	_rain_particles.position = Vector3(0, RAIN_SPAWN_HEIGHT, 0)

	# Start disabled (will enable when raining)
	_rain_particles.emitting = false

	add_child(_rain_particles)


## ============================================================================
## WEATHER-SPECIFIC GETTERS
## ============================================================================

func _get_fog_density_for_weather(weather: Enums.Weather) -> float:
	match weather:
		Enums.Weather.CLEAR:
			return FOG_DENSITY_CLEAR
		Enums.Weather.CLOUDY:
			return FOG_DENSITY_CLOUDY
		Enums.Weather.RAIN:
			return FOG_DENSITY_RAIN
		Enums.Weather.FOG:
			return FOG_DENSITY_FOG
		_:
			return FOG_DENSITY_CLEAR


func _get_fog_color_for_weather(weather: Enums.Weather) -> Color:
	match weather:
		Enums.Weather.CLEAR:
			return FOG_COLOR_CLEAR
		Enums.Weather.CLOUDY:
			return FOG_COLOR_CLOUDY
		Enums.Weather.RAIN:
			return FOG_COLOR_RAIN
		Enums.Weather.FOG:
			return FOG_COLOR_FOG
		_:
			return FOG_COLOR_CLEAR


func _get_light_modifier_for_weather(weather: Enums.Weather) -> float:
	match weather:
		Enums.Weather.CLEAR:
			return LIGHT_MOD_CLEAR
		Enums.Weather.CLOUDY:
			return LIGHT_MOD_CLOUDY
		Enums.Weather.RAIN:
			return LIGHT_MOD_RAIN
		Enums.Weather.FOG:
			return LIGHT_MOD_FOG
		_:
			return LIGHT_MOD_CLEAR


## ============================================================================
## ENVIRONMENT MODIFICATION
## ============================================================================

func _cache_world_environment() -> void:
	# Find the world environment in the scene
	_world_environment = get_tree().get_first_node_in_group("world_environment")

	if not _world_environment:
		# Try to find any WorldEnvironment node
		var envs: Array[Node] = get_tree().get_nodes_in_group("world_environment")
		if envs.size() > 0 and envs[0] is WorldEnvironment:
			_world_environment = envs[0]

	# Cache original values
	if _world_environment and _world_environment.environment:
		_original_fog_density = _world_environment.environment.fog_density
		_original_fog_color = _world_environment.environment.fog_light_color


func _apply_fog_settings(density: float, color: Color) -> void:
	if not _world_environment:
		_cache_world_environment()

	if _world_environment and _world_environment.environment:
		var env: Environment = _world_environment.environment
		env.fog_density = density
		# Blend fog color with the current time-of-day fog color
		# This preserves day/night cycle color while tinting for weather
		var current_fog: Color = env.fog_light_color
		env.fog_light_color = current_fog.lerp(color, 0.3)  # Subtle weather tint


func _apply_light_modifier(modifier: float) -> void:
	# Find the directional light (sun/moon from DayNightCycle)
	var sun_light: DirectionalLight3D = null

	# DayNightCycle adds itself to "day_night_cycle" group
	var day_night: Node = get_tree().get_first_node_in_group("day_night_cycle")
	if day_night:
		sun_light = day_night.get_node_or_null("SunMoonLight")

	if not sun_light:
		# Fallback: search by iterating level children
		var level: Node = get_tree().current_scene
		if level:
			for child in level.get_children():
				if child is DayNightCycle:
					sun_light = child.get_node_or_null("SunMoonLight")
					break

			if not sun_light:
				# Last fallback: find any DirectionalLight3D in scene
				var lights: Array[Node] = []
				_find_nodes_of_type(level, DirectionalLight3D, lights)
				if lights.size() > 0:
					sun_light = lights[0] as DirectionalLight3D

	if sun_light:
		# Store base energy if not stored, then apply modifier
		if not sun_light.has_meta("base_energy"):
			sun_light.set_meta("base_energy", sun_light.light_energy)

		var base_energy: float = sun_light.get_meta("base_energy")
		sun_light.light_energy = base_energy * modifier


## Helper to find nodes of a specific type recursively
func _find_nodes_of_type(node: Node, type: Variant, results: Array[Node]) -> void:
	if node == null:
		return
	if is_instance_of(node, type):
		results.append(node)
	for child in node.get_children():
		_find_nodes_of_type(child, type, results)


func _restore_original_fog() -> void:
	if _world_environment and _world_environment.environment:
		_world_environment.environment.fog_density = _original_fog_density
		# Don't restore fog color - let day/night cycle handle it


## ============================================================================
## PLAYER FOLLOWING
## ============================================================================

func _follow_player() -> void:
	if _player and is_instance_valid(_player):
		global_position = _player.global_position


## ============================================================================
## RAIN CONTROL
## ============================================================================

func _update_rain_visibility() -> void:
	if not _rain_particles:
		return

	# Rain is only visible during RAIN weather
	var should_rain: bool = _current_weather == Enums.Weather.RAIN

	if should_rain and not _rain_particles.emitting:
		_rain_particles.emitting = true
	elif not should_rain and _rain_particles.emitting:
		_rain_particles.emitting = false

## weather_manager.gd - Visual weather system for cosmetic effects
## Cycles between weather states randomly, manages weather effects outdoors only
extends Node

signal weather_changed(old_state: Enums.Weather, new_state: Enums.Weather)
signal weather_transition_started(from_state: Enums.Weather, to_state: Enums.Weather)
signal weather_transition_completed(new_state: Enums.Weather)

## Current weather state
var current_weather: Enums.Weather = Enums.Weather.CLEAR

## Target weather state (for transitions)
var _target_weather: Enums.Weather = Enums.Weather.CLEAR

## Whether player is currently outdoors (effects only active outdoors)
var _is_outdoor: bool = false

## Time until next weather change (in seconds)
var _time_until_change: float = 0.0

## Whether a transition is in progress
var _transitioning: bool = false

## Transition progress (0.0 to 1.0)
var _transition_progress: float = 0.0

## Weather effects node instance
var _weather_effects: Node3D = null

## ============================================================================
## CONFIGURATION
## ============================================================================

## Minimum duration for a weather state (in real seconds)
@export var min_weather_duration: float = 120.0  # 2 minutes

## Maximum duration for a weather state (in real seconds)
@export var max_weather_duration: float = 300.0  # 5 minutes

## Duration of weather transitions (in seconds)
@export var transition_duration: float = 8.0

## Probability weights for each weather type (higher = more common)
## Only CLEAR, CLOUDY, RAIN, FOG are used for visual weather
const WEATHER_WEIGHTS: Dictionary = {
	Enums.Weather.CLEAR: 40,    # Most common
	Enums.Weather.CLOUDY: 30,   # Overcast (darker lighting)
	Enums.Weather.RAIN: 20,     # Rain particles
	Enums.Weather.FOG: 10       # Thick fog
}

## ============================================================================
## LIFECYCLE
## ============================================================================

func _ready() -> void:
	# Set initial weather timer
	_time_until_change = randf_range(min_weather_duration, max_weather_duration)

	# Connect to scene changes to handle indoor/outdoor transitions
	if SceneManager:
		SceneManager.scene_load_completed.connect(_on_scene_load_completed)


func _exit_tree() -> void:
	# Cleanup weather effects if they exist
	_destroy_weather_effects()

	# Disconnect signals
	if SceneManager and SceneManager.scene_load_completed.is_connected(_on_scene_load_completed):
		SceneManager.scene_load_completed.disconnect(_on_scene_load_completed)


func _process(delta: float) -> void:
	# Don't process if game is paused
	if GameManager and (GameManager.is_paused or GameManager.is_in_menu):
		return

	# Handle transitions
	if _transitioning:
		_process_transition(delta)

	# Update weather timer
	_time_until_change -= delta
	if _time_until_change <= 0.0:
		_pick_next_weather()

	# Update weather effects if outdoors
	if _is_outdoor and _weather_effects and is_instance_valid(_weather_effects):
		_weather_effects.update_effects(delta, _transition_progress if _transitioning else 1.0)


## ============================================================================
## PUBLIC API
## ============================================================================

## Set whether the current scene is outdoors
## Call this in _ready() of exterior levels with set_outdoor(true)
## Call with set_outdoor(false) for interiors/dungeons
func set_outdoor(is_outdoor: bool) -> void:
	var was_outdoor: bool = _is_outdoor
	_is_outdoor = is_outdoor

	if is_outdoor and not was_outdoor:
		# Entering outdoor area - spawn effects
		_spawn_weather_effects()
	elif not is_outdoor and was_outdoor:
		# Entering indoor area - remove effects
		_destroy_weather_effects()


## Check if currently outdoors
func is_outdoor() -> bool:
	return _is_outdoor


## Get current weather state
func get_current_weather() -> Enums.Weather:
	return current_weather


## Get weather state name as string
func get_weather_name(weather: Enums.Weather = current_weather) -> String:
	match weather:
		Enums.Weather.CLEAR:
			return "Clear"
		Enums.Weather.CLOUDY:
			return "Overcast"
		Enums.Weather.RAIN:
			return "Rain"
		Enums.Weather.FOG:
			return "Fog"
		_:
			return "Unknown"


## Force a specific weather state (for events/quests)
func force_weather(weather: Enums.Weather, immediate: bool = false) -> void:
	if immediate:
		_apply_weather_immediate(weather)
	else:
		_start_transition(weather)

	# Reset timer for this forced weather
	_time_until_change = randf_range(min_weather_duration, max_weather_duration)


## Get save data for persistence
func get_save_data() -> Dictionary:
	return {
		"current_weather": current_weather,
		"target_weather": _target_weather,
		"time_until_change": _time_until_change,
		"transitioning": _transitioning,
		"transition_progress": _transition_progress
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	current_weather = data.get("current_weather", Enums.Weather.CLEAR)
	_target_weather = data.get("target_weather", current_weather)
	_time_until_change = data.get("time_until_change", randf_range(min_weather_duration, max_weather_duration))
	_transitioning = data.get("transitioning", false)
	_transition_progress = data.get("transition_progress", 0.0)

	# Sync with GameManager
	if GameManager:
		GameManager.set_weather(current_weather)

	# Update effects if outdoors
	if _is_outdoor:
		_spawn_weather_effects()


## Reset for new game
func reset_for_new_game() -> void:
	current_weather = Enums.Weather.CLEAR
	_target_weather = Enums.Weather.CLEAR
	_time_until_change = randf_range(min_weather_duration, max_weather_duration)
	_transitioning = false
	_transition_progress = 0.0

	if GameManager:
		GameManager.set_weather(current_weather)


## ============================================================================
## INTERNAL METHODS
## ============================================================================

## Pick the next random weather state
func _pick_next_weather() -> void:
	var new_weather: Enums.Weather = _weighted_random_weather()

	# Avoid picking the same weather twice in a row (unless it's clear)
	var attempts: int = 0
	while new_weather == current_weather and attempts < 5:
		new_weather = _weighted_random_weather()
		attempts += 1

	_start_transition(new_weather)
	_time_until_change = randf_range(min_weather_duration, max_weather_duration)


## Select a random weather based on weights
func _weighted_random_weather() -> Enums.Weather:
	var total_weight: int = 0
	for w in WEATHER_WEIGHTS:
		total_weight += WEATHER_WEIGHTS[w]

	var roll: int = randi() % total_weight
	var cumulative: int = 0

	for w in WEATHER_WEIGHTS:
		cumulative += WEATHER_WEIGHTS[w]
		if roll < cumulative:
			return w

	return Enums.Weather.CLEAR


## Start a weather transition
func _start_transition(new_weather: Enums.Weather) -> void:
	if new_weather == current_weather:
		return

	_target_weather = new_weather
	_transitioning = true
	_transition_progress = 0.0

	weather_transition_started.emit(current_weather, _target_weather)


## Process ongoing weather transition
func _process_transition(delta: float) -> void:
	_transition_progress += delta / transition_duration

	if _transition_progress >= 1.0:
		_transition_progress = 1.0
		_transitioning = false

		var old_weather: Enums.Weather = current_weather
		current_weather = _target_weather

		# Sync with GameManager
		if GameManager:
			GameManager.set_weather(current_weather)

		weather_changed.emit(old_weather, current_weather)
		weather_transition_completed.emit(current_weather)


## Apply weather immediately without transition
func _apply_weather_immediate(weather: Enums.Weather) -> void:
	var old_weather: Enums.Weather = current_weather
	current_weather = weather
	_target_weather = weather
	_transitioning = false
	_transition_progress = 1.0

	# Sync with GameManager
	if GameManager:
		GameManager.set_weather(current_weather)

	weather_changed.emit(old_weather, current_weather)

	# Update effects immediately
	if _is_outdoor and _weather_effects and is_instance_valid(_weather_effects):
		_weather_effects.apply_weather_immediate(current_weather)


## Spawn weather effects node
func _spawn_weather_effects() -> void:
	if _weather_effects and is_instance_valid(_weather_effects):
		return  # Already exists

	# Create weather effects node
	var WeatherEffectsScript: GDScript = load("res://scripts/world/weather_effects.gd")
	if not WeatherEffectsScript:
		push_warning("[WeatherManager] Could not load weather_effects.gd")
		return

	_weather_effects = WeatherEffectsScript.new()
	_weather_effects.name = "WeatherEffects"

	# Add to scene tree (will follow player)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		get_tree().current_scene.add_child(_weather_effects)
		_weather_effects.initialize(current_weather, player)
	else:
		# No player yet, defer spawn
		call_deferred("_spawn_weather_effects")
		return


## Destroy weather effects node
func _destroy_weather_effects() -> void:
	if _weather_effects and is_instance_valid(_weather_effects):
		_weather_effects.queue_free()
		_weather_effects = null


## Handle scene load completion
func _on_scene_load_completed(_scene_path: String) -> void:
	# Re-spawn effects if outdoors
	if _is_outdoor:
		# Wait a frame for player to initialize
		await get_tree().process_frame
		_spawn_weather_effects()


## ============================================================================
## SAVE/LOAD INTEGRATION
## ============================================================================

## to_dict for SaveManager compatibility
func to_dict() -> Dictionary:
	return get_save_data()

## from_dict for SaveManager compatibility
func from_dict(data: Dictionary) -> void:
	load_save_data(data)

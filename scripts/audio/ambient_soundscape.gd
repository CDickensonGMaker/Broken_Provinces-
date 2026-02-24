## ambient_soundscape.gd - Layered ambient audio system with biome and time-of-day variations
## Respects performance budget of 4 max audio sources
## Integrates with AudioManager, GameManager (time), and biome system
class_name AmbientSoundscape
extends Node

## Signals
signal biome_changed(new_biome: int)
signal soundscape_changed(biome: int, is_night: bool)

## Biome enum - matches WorldGrid terrain types
enum Biome { FOREST, HIGHLANDS, SWAMP, COAST, ROAD, DESERT, CAVES }

## Audio layer types
enum Layer { BASE, ACCENT_1, ACCENT_2, WEATHER }

## Performance budget: 4 max audio sources
const MAX_AUDIO_SOURCES: int = 4
const CROSSFADE_DURATION: float = 2.0
const LAYER_COUNT: int = 4

## Audio players for each layer
var layer_players: Array[AudioStreamPlayer] = []

## Current state
var current_biome: Biome = Biome.FOREST
var is_night: bool = false
var is_interior: bool = false

## Target volumes for each layer (for crossfading)
var target_volumes: Array[float] = [0.0, 0.0, 0.0, 0.0]
var current_volumes: Array[float] = [0.0, 0.0, 0.0, 0.0]

## Volume settings
const BASE_VOLUME: float = 0.0  # dB
const ACCENT_VOLUME: float = -6.0  # dB (quieter than base)
const WEATHER_VOLUME: float = -3.0  # dB

## Soundscape definitions per biome
## Each biome has day and night variants with up to 4 layers
## Paths are placeholders - replace with actual audio assets
const SOUNDSCAPES: Dictionary = {
	Biome.FOREST: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/forest_day_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/forest_birds.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/forest_wind_leaves.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambient/forest_night_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/forest_crickets.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/forest_owls.ogg",
		}
	},
	Biome.HIGHLANDS: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/hills_day_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/hills_wind.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/hills_birds.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambient/hills_night_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/hills_night_wind.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/hills_wolves.ogg",
		}
	},
	Biome.SWAMP: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/swamp_day_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/swamp_frogs.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/swamp_insects.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambient/swamp_night_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/swamp_night_frogs.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/swamp_night_creatures.ogg",
		}
	},
	Biome.COAST: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/coast_waves.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/coast_seagulls.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/coast_wind.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambient/coast_waves_night.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/coast_night_wind.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/coast_night_creatures.ogg",
		}
	},
	Biome.ROAD: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/plains_day_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/plains_wind.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/plains_grasshoppers.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambient/plains_night_base.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/plains_crickets.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/plains_night_wind.ogg",
		}
	},
	Biome.DESERT: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/desert_wind.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/desert_sand.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/desert_heat.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambient/desert_night_wind.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/desert_night_cold.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/desert_coyotes.ogg",
		}
	},
	Biome.CAVES: {
		"day": {
			Layer.BASE: "res://assets/audio/ambient/cave_drips.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/cave_echo.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/cave_wind.ogg",
		},
		"night": {
			# Caves sound the same day and night
			Layer.BASE: "res://assets/audio/ambient/cave_drips.ogg",
			Layer.ACCENT_1: "res://assets/audio/ambient/cave_echo.ogg",
			Layer.ACCENT_2: "res://assets/audio/ambient/cave_wind.ogg",
		}
	}
}

## Fallback soundscape when audio files are missing
const FALLBACK_SOUNDSCAPE: Dictionary = {
	"day": {},
	"night": {}
}

## Sound cache for loaded audio streams
var sound_cache: Dictionary = {}


func _ready() -> void:
	_create_audio_players()
	_connect_signals()

	# Initialize based on current game state
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager:
		if game_manager.has_method("is_night"):
			is_night = game_manager.is_night()
		if game_manager.has_method("get_current_time_of_day"):
			_on_time_of_day_changed(game_manager.get_current_time_of_day())


func _process(delta: float) -> void:
	_update_crossfades(delta)


func _create_audio_players() -> void:
	# Create exactly MAX_AUDIO_SOURCES players
	for i in range(MAX_AUDIO_SOURCES):
		var player := AudioStreamPlayer.new()
		# Try to use ambient bus if AudioManager exists
		var audio_manager: Node = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.get("AMBIENT_BUS"):
			player.bus = audio_manager.AMBIENT_BUS
		else:
			player.bus = "Master"
		player.volume_db = -80.0  # Start silent
		add_child(player)
		layer_players.append(player)
		current_volumes.append(-80.0)
		target_volumes.append(-80.0)


func _connect_signals() -> void:
	# Connect to GameManager time changes
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_signal("time_of_day_changed"):
		if not game_manager.time_of_day_changed.is_connected(_on_time_of_day_changed):
			game_manager.time_of_day_changed.connect(_on_time_of_day_changed)


## Set the current biome and update soundscape
func set_biome(biome: int) -> void:
	if biome < 0 or biome >= Biome.size():
		push_warning("[AmbientSoundscape] Invalid biome index: %d" % biome)
		return

	var new_biome: Biome = biome as Biome
	if new_biome == current_biome:
		return

	current_biome = new_biome
	biome_changed.emit(biome)
	_update_soundscape()


## Set biome from WorldGrid.Terrain enum value
func set_biome_from_terrain(terrain: int) -> void:
	# WorldGrid.Terrain: BLOCKED=0, HIGHLANDS=1, FOREST=2, WATER=3, COAST=4, SWAMP=5, ROAD=6, POI=7, DESERT=8
	var biome_map: Dictionary = {
		1: Biome.HIGHLANDS,  # HIGHLANDS
		2: Biome.FOREST,     # FOREST
		4: Biome.COAST,      # COAST
		5: Biome.SWAMP,      # SWAMP
		6: Biome.ROAD,       # ROAD
		8: Biome.DESERT,     # DESERT
	}

	var local_biome: int = biome_map.get(terrain, Biome.FOREST)
	set_biome(local_biome)


## Set whether we're in an interior space (like caves/dungeons)
func set_interior(interior: bool) -> void:
	if interior == is_interior:
		return

	is_interior = interior

	if is_interior:
		# Switch to cave soundscape for interiors
		set_biome(Biome.CAVES)
	else:
		# Restore previous outdoor biome - caller should set biome after this
		pass


## Stop all ambient sounds (for menus, cutscenes, etc.)
func stop_all() -> void:
	for i in range(layer_players.size()):
		target_volumes[i] = -80.0


## Resume ambient sounds
func resume() -> void:
	_update_soundscape()


## Handle time of day changes from GameManager
func _on_time_of_day_changed(time_of_day: int) -> void:
	var was_night: bool = is_night

	# Determine if it's night based on time of day
	# Enums.TimeOfDay: DAWN=0, MORNING=1, NOON=2, AFTERNOON=3, DUSK=4, NIGHT=5, MIDNIGHT=6
	is_night = (time_of_day == 5 or time_of_day == 6)

	# Only update if night status changed
	if was_night != is_night:
		_update_soundscape()


## Update the soundscape based on current biome and time
func _update_soundscape() -> void:
	var soundscape: Dictionary = SOUNDSCAPES.get(current_biome, FALLBACK_SOUNDSCAPE)
	var time_key: String = "night" if is_night else "day"
	var layers: Dictionary = soundscape.get(time_key, {})

	# Update each layer
	for i in range(MAX_AUDIO_SOURCES):
		var layer_enum: Layer = i as Layer
		if layers.has(layer_enum):
			var sound_path: String = layers[layer_enum]
			_set_layer_sound(i, sound_path)

			# Set target volume based on layer type
			match layer_enum:
				Layer.BASE:
					target_volumes[i] = BASE_VOLUME
				Layer.ACCENT_1, Layer.ACCENT_2:
					target_volumes[i] = ACCENT_VOLUME
				Layer.WEATHER:
					target_volumes[i] = WEATHER_VOLUME
		else:
			# No sound for this layer - fade out
			target_volumes[i] = -80.0

	soundscape_changed.emit(current_biome, is_night)


## Set the sound for a specific layer
func _set_layer_sound(layer_index: int, sound_path: String) -> void:
	if layer_index < 0 or layer_index >= layer_players.size():
		return

	var player: AudioStreamPlayer = layer_players[layer_index]
	var stream: AudioStream = _load_sound(sound_path)

	if not stream:
		# Sound not found - fade out this layer
		target_volumes[layer_index] = -80.0
		return

	# Check if we need to change the stream
	if player.stream != stream:
		# If currently playing, we'll crossfade
		if player.playing and player.volume_db > -60.0:
			# Start at low volume for crossfade
			player.stream = stream
			player.play()
		else:
			# Not playing or very quiet - just switch
			player.stream = stream
			player.play()


## Update crossfades each frame
func _update_crossfades(delta: float) -> void:
	var fade_speed: float = 80.0 / CROSSFADE_DURATION  # dB per second

	for i in range(layer_players.size()):
		var player: AudioStreamPlayer = layer_players[i]
		var current: float = current_volumes[i]
		var target: float = target_volumes[i]

		if absf(current - target) < 0.1:
			# Close enough - snap to target
			current_volumes[i] = target
			player.volume_db = target

			# Stop player if faded out completely
			if target <= -79.0 and player.playing:
				player.stop()
		else:
			# Interpolate
			if current < target:
				current_volumes[i] = minf(current + fade_speed * delta, target)
			else:
				current_volumes[i] = maxf(current - fade_speed * delta, target)

			player.volume_db = current_volumes[i]

			# Ensure player is playing if we're fading in
			if target > -79.0 and not player.playing and player.stream:
				player.play()


## Load and cache a sound
func _load_sound(path: String) -> AudioStream:
	if sound_cache.has(path):
		return sound_cache[path]

	if not ResourceLoader.exists(path):
		# Don't spam warnings for missing ambient sounds during development
		return null

	var stream: AudioStream = load(path)
	if stream:
		sound_cache[path] = stream
	return stream


## Get current biome name for debugging
func get_current_biome_name() -> String:
	match current_biome:
		Biome.FOREST: return "Forest"
		Biome.HIGHLANDS: return "Highlands"
		Biome.SWAMP: return "Swamp"
		Biome.COAST: return "Coast"
		Biome.ROAD: return "Road"
		Biome.DESERT: return "Desert"
		Biome.CAVES: return "Caves"
		_: return "Unknown"


## Get debug info
func get_debug_info() -> Dictionary:
	var playing_layers: Array[String] = []
	for i in range(layer_players.size()):
		var player: AudioStreamPlayer = layer_players[i]
		if player.playing and player.volume_db > -60.0:
			var layer_name: String = Layer.keys()[i]
			playing_layers.append("%s (%.1f dB)" % [layer_name, player.volume_db])

	return {
		"biome": get_current_biome_name(),
		"is_night": is_night,
		"is_interior": is_interior,
		"playing_layers": playing_layers
	}


## Static helper to add to a scene
static func add_to_scene(parent: Node) -> AmbientSoundscape:
	var soundscape := AmbientSoundscape.new()
	soundscape.name = "AmbientSoundscape"
	parent.add_child(soundscape)
	return soundscape

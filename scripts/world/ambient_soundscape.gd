## ambient_soundscape.gd - Layered ambient audio system with biome and time-of-day variations
##
## **Wired 8/2.** It was instantiated by nothing at all: `AmbientSoundscape`
## and `add_to_scene()` were named by no script, scene or data file, and the
## reason was honest - there were no biome beds to play, so wiring it would
## have bought silence with extra steps. There are beds now (synthesised, see
## docs/audits/art_replacement_manifest.md), and `AudioManager` owns the one
## instance: it creates the node, feeds it the player's cell biome from
## PlayerGPS and the hour from GameManager, and stands it down whenever a
## scene claims the ambient player for itself.
##
## Respects performance budget of 4 max audio sources.
class_name AmbientSoundscape
extends Node

## Signals
signal biome_changed(new_biome: int)
signal soundscape_changed(biome: int, is_night: bool)

## Biome enum - the soundscape's own vocabulary, coarser than WorldGrid's
## fifteen. WINTER was appended 8/2 (never inserted: these values are stored
## in `current_biome` and compared by number).
enum Biome { FOREST, HIGHLANDS, SWAMP, COAST, ROAD, DESERT, CAVES, WINTER }

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

## Soundscape definitions per biome.
##
## MEASURED 8/1: this table used to name 36 loops under
## `res://assets/audio/ambient/`. That directory does not exist. The real one
## is `assets/audio/Ambiance/` and holds four files, none of them a biome bed -
## so every layer of every biome resolved to null, and the loader suppressed
## its own warning on the way past. Biome ambience had never made a sound.
##
## FILLED 8/2 with synthesised beds - 62-second loops, seam-crossfaded, RMS
## matched to -33 dBFS so no biome is louder than another. Every path under
## `assets/audio/generated/` is PLACEHOLDER-CLASS with a row in
## docs/audits/art_replacement_manifest.md; replacing one is editing one line
## here, and the layer scheme takes accents whenever there are accents.
##
## CAVES keeps the real ruins recording as its BASE. The synthesised drip bed
## sits UNDER it as an accent - a hand-made file is never displaced by a
## generated one.
const GEN := "res://assets/audio/generated/ambience/"

const SOUNDSCAPES: Dictionary = {
	Biome.FOREST: {
		"day": {Layer.BASE: GEN + "forest_day.ogg"},
		"night": {Layer.BASE: GEN + "forest_night.ogg"},
	},
	Biome.HIGHLANDS: {
		"day": {Layer.BASE: GEN + "highlands_day.ogg"},
		"night": {Layer.BASE: GEN + "highlands_night.ogg"},
	},
	Biome.SWAMP: {
		"day": {Layer.BASE: GEN + "swamp_day.ogg"},
		"night": {Layer.BASE: GEN + "swamp_night.ogg"},
	},
	Biome.COAST: {
		"day": {Layer.BASE: GEN + "coast_day.ogg"},
		"night": {Layer.BASE: GEN + "coast_night.ogg"},
	},
	Biome.ROAD: {
		"day": {Layer.BASE: GEN + "road_day.ogg"},
		"night": {Layer.BASE: GEN + "road_night.ogg"},
	},
	Biome.DESERT: {
		"day": {Layer.BASE: GEN + "desert_day.ogg"},
		"night": {Layer.BASE: GEN + "desert_night.ogg"},
	},
	Biome.WINTER: {
		"day": {Layer.BASE: GEN + "winter_day.ogg"},
		"night": {Layer.BASE: GEN + "winter_night.ogg"},
	},
	Biome.CAVES: {
		# Caves sound the same day and night
		"day": {
			Layer.BASE: "res://assets/audio/ambience/ruins/ruins_creepy_ambience.wav",
			Layer.ACCENT_1: GEN + "caves_drips.ogg",
		},
		"night": {
			Layer.BASE: "res://assets/audio/ambience/ruins/ruins_creepy_ambience.wav",
			Layer.ACCENT_1: GEN + "caves_drips.ogg",
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

## Paths already warned about, so a missing loop says so once
var _warned_missing: Dictionary = {}


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
		# The two volume arrays are already MAX_AUDIO_SOURCES long. Appending
		# here grew them to eight, and the four extra entries were written by
		# nothing and read by nothing.
		current_volumes[i] = -80.0
		target_volumes[i] = -80.0


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


## Set biome from a `WorldGrid.Biome` value - the cell's biome, which is what
## PlayerGPS can actually tell us, and finer-grained than its terrain.
## WorldGrid.Biome: FOREST=0, PLAINS=1, SWAMP=2, HILLS=3, ROCKY=4, MOUNTAINS=5,
## COAST=6, UNDEAD=7, HORDE=8, DESERT=9, WINTER=10, ROCKY_FOREST=11,
## ROCKY_PLAINS=12, ROCKY_WINTER=13, ROCKY_DESERT=14.
func set_biome_from_world_biome(world_biome: int) -> void:
	set_biome(WORLD_BIOME_MAP.get(world_biome, Biome.FOREST))


## Fifteen world biomes onto eight beds. The rocky variants take their parent's
## bed rather than a stony one, because what you hear in a rocky forest is
## still a forest; UNDEAD and HORDE take the bleak highland wind.
const WORLD_BIOME_MAP: Dictionary = {
	0: Biome.FOREST,      # FOREST
	1: Biome.ROAD,        # PLAINS - grassland, the open-road bed
	2: Biome.SWAMP,       # SWAMP
	3: Biome.HIGHLANDS,   # HILLS
	4: Biome.HIGHLANDS,   # ROCKY
	5: Biome.HIGHLANDS,   # MOUNTAINS
	6: Biome.COAST,       # COAST
	7: Biome.HIGHLANDS,   # UNDEAD
	8: Biome.HIGHLANDS,   # HORDE
	9: Biome.DESERT,      # DESERT
	10: Biome.WINTER,     # WINTER
	11: Biome.FOREST,     # ROCKY_FOREST
	12: Biome.ROAD,       # ROCKY_PLAINS
	13: Biome.WINTER,     # ROCKY_WINTER
	14: Biome.DESERT,     # ROCKY_DESERT
}


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
		# The suppression that used to live here is why nobody noticed this
		# system had never made a sound. Warn once per path instead.
		if not _warned_missing.has(path):
			_warned_missing[path] = true
			push_warning("[AmbientSoundscape] no such ambient loop: %s - see docs/audits/art_replacement_manifest.md" % path)
		return null

	var stream: AudioStream = load(path)
	if stream:
		# A bed that does not loop is a bed that plays once and leaves the
		# world silent, which is indistinguishable from having no bed at all.
		# Godot's Ogg and WAV importers both default `loop` to false.
		if "loop" in stream:
			stream.set("loop", true)
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
		Biome.WINTER: return "Winter"
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

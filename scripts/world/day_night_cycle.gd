## day_night_cycle.gd - Visual day/night cycle based on GameManager time
## Add this to any level that should have dynamic lighting
## GRIM DARK / DARK FANTASY aesthetic - muted colors, heavy atmosphere
class_name DayNightCycle
extends Node3D

## The directional light (sun/moon)
var sun_light: DirectionalLight3D

## The world environment
var world_environment: WorldEnvironment

## Sky material for visible sun
var sky_material: ProceduralSkyMaterial

## Moon billboard (visible at night)
var moon_sprite: Sprite3D

## Cloud dome for atmosphere
var cloud_dome: MeshInstance3D
var cloud_material: ShaderMaterial

## PS1-style distance fog settings (tight visibility for retro feel)
const FOG_START := 8.0     # Distance where fog begins (units) - closer for heavier fog
const FOG_END := 35.0      # Distance where fog is fully opaque (units) - tighter visibility

## ============================================================================
## GRIM DARK COLOR PALETTE - Muted, desaturated, atmospheric
## ============================================================================

## Light colors for different times of day (desaturated, muted tones)
const DAWN_COLOR := Color(0.75, 0.55, 0.45)     # Muted rust/amber sunrise
const MORNING_COLOR := Color(0.85, 0.8, 0.7)    # Pale overcast white
const NOON_COLOR := Color(0.9, 0.88, 0.82)      # Slightly warm grey-white (not pure white)
const AFTERNOON_COLOR := Color(0.8, 0.75, 0.65) # Dusty amber
const DUSK_COLOR := Color(0.7, 0.4, 0.3)        # Blood red sunset
const NIGHT_COLOR := Color(0.25, 0.28, 0.4)     # Cold blue moonlight
const MIDNIGHT_COLOR := Color(0.12, 0.14, 0.22) # Deep oppressive darkness

## Light intensities - balanced for visibility while maintaining atmosphere
const DAWN_ENERGY := 0.7
const MORNING_ENERGY := 1.1    # Bright morning light
const NOON_ENERGY := 1.5       # Strong midday sun
const AFTERNOON_ENERGY := 1.4  # Still strong until ~5pm
const DUSK_ENERGY := 0.6
const NIGHT_ENERGY := 0.15     # Dark but visible at night
const MIDNIGHT_ENERGY := 0.08  # Very dark at midnight but not pitch black

## Ambient light colors - balanced for visibility
const DAWN_AMBIENT := Color(0.4, 0.38, 0.35)
const MORNING_AMBIENT := Color(0.55, 0.52, 0.48)   # Brighter morning fill
const NOON_AMBIENT := Color(0.7, 0.68, 0.62)       # Strong warm ambient
const AFTERNOON_AMBIENT := Color(0.65, 0.6, 0.55)  # Strong afternoon fill
const DUSK_AMBIENT := Color(0.35, 0.3, 0.32)
const NIGHT_AMBIENT := Color(0.1, 0.1, 0.14)    # Visible blue-tinted night
const MIDNIGHT_AMBIENT := Color(0.06, 0.06, 0.08)  # Very dark but not pitch black

## PS1-style fog colors - lighter during day for better visibility
const DAWN_FOG := Color(0.35, 0.32, 0.3)        # Grey with slight warmth
const MORNING_FOG := Color(0.45, 0.42, 0.4)     # Lighter morning mist
const NOON_FOG := Color(0.5, 0.48, 0.45)        # Light haze, good visibility
const AFTERNOON_FOG := Color(0.48, 0.45, 0.42)  # Light afternoon haze
const DUSK_FOG := Color(0.28, 0.25, 0.25)       # Darkening grey
const NIGHT_FOG := Color(0.06, 0.06, 0.1)       # Deep blue-grey
const MIDNIGHT_FOG := Color(0.03, 0.03, 0.05)   # Near black

## Sun rotation angles (degrees from horizon)
const DAWN_ANGLE := -10.0       # Just below horizon
const MORNING_ANGLE := 30.0     # Rising
const NOON_ANGLE := 70.0        # High in sky
const AFTERNOON_ANGLE := 45.0   # Descending
const DUSK_ANGLE := 5.0         # Near horizon
const NIGHT_ANGLE := -30.0      # Below horizon (moonlight from opposite)
const MIDNIGHT_ANGLE := -45.0   # Deep below

## Transition speed (how fast lighting changes)
@export var transition_speed: float = 2.0

## Ambient light energy values for each time period - increased for visibility
const DAWN_AMBIENT_ENERGY := 0.5
const MORNING_AMBIENT_ENERGY := 0.75   # Strong morning ambient
const NOON_AMBIENT_ENERGY := 1.0       # Full ambient at midday
const AFTERNOON_AMBIENT_ENERGY := 0.95 # Strong afternoon ambient
const DUSK_AMBIENT_ENERGY := 0.45
const NIGHT_AMBIENT_ENERGY := 0.2    # Visible ambient at night
const MIDNIGHT_AMBIENT_ENERGY := 0.1  # Low but not pitch black

## Current target values
var target_color: Color = MORNING_COLOR
var target_energy: float = MORNING_ENERGY
var target_ambient: Color = MORNING_AMBIENT
var target_ambient_energy: float = MORNING_AMBIENT_ENERGY
var target_angle: float = MORNING_ANGLE
var target_fog: Color = MORNING_FOG

func _ready() -> void:
	_setup_lighting()

	# Connect to time changes
	GameManager.time_of_day_changed.connect(_on_time_of_day_changed)

	# Set initial state based on current time
	_on_time_of_day_changed(GameManager.current_time_of_day)

	# Apply immediately on start
	_apply_lighting_instant()


func _exit_tree() -> void:
	# Disconnect from GameManager signals to prevent stale callbacks
	if GameManager and GameManager.time_of_day_changed.is_connected(_on_time_of_day_changed):
		GameManager.time_of_day_changed.disconnect(_on_time_of_day_changed)


func _setup_lighting() -> void:
	# Remove any existing static DirectionalLight3D in the parent scene to avoid conflicts
	# Static lights override dynamic day/night cycle
	var parent_node: Node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is DirectionalLight3D and child != self:
				child.queue_free()

	# Create our dynamic directional light (sun/moon)
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunMoonLight"
	sun_light.light_color = MORNING_COLOR
	sun_light.light_energy = MORNING_ENERGY
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.1
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.rotation_degrees = Vector3(-30, -45, 0)
	add_child(sun_light)

	# CRITICAL FIX: ALWAYS remove any existing WorldEnvironment and create our own
	# This ensures consistent lighting across ALL scenes (hand-crafted and procedural)
	# Previously, hand-crafted scenes with custom WorldEnvironments would have different
	# lighting settings (fog, sky, ambient) causing visual mismatches when streaming cells

	# Remove any WorldEnvironment in the "world_environment" group
	var existing_env := get_tree().get_first_node_in_group("world_environment")
	if existing_env and existing_env is WorldEnvironment:
		existing_env.queue_free()

	# Also remove any WorldEnvironment in the parent scene (even if not in group)
	if parent_node:
		for child in parent_node.get_children():
			if child is WorldEnvironment:
				child.queue_free()

	# Create our own WorldEnvironment with consistent settings for ALL scenes
	world_environment = WorldEnvironment.new()
	world_environment.name = "DayNightEnvironment"
	world_environment.add_to_group("world_environment")

	var env := Environment.new()

	# ====================================================================
	# PROCEDURAL SKY WITH VISIBLE SUN DISC
	# ====================================================================
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()

	# Sky colors - grim dark aesthetic
	sky_material.sky_top_color = Color(0.25, 0.28, 0.35)      # Dark grey-blue
	sky_material.sky_horizon_color = Color(0.4, 0.38, 0.35)   # Murky horizon
	sky_material.ground_bottom_color = Color(0.1, 0.08, 0.06) # Dark ground
	sky_material.ground_horizon_color = Color(0.25, 0.22, 0.2) # Dark horizon

	# Sun disc - visible and follows DirectionalLight3D automatically
	sky_material.sun_angle_max = 5.0  # Size of sun disc (degrees)
	sky_material.sun_curve = 0.1      # Sun falloff sharpness

	sky.sky_material = sky_material
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = MORNING_AMBIENT
	env.ambient_light_energy = 0.3  # Low ambient for darker, moodier feel

	# ====================================================================
	# TONEMAPPING - Balanced for visibility
	# ====================================================================
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0  # Neutral exposure
	env.tonemap_white = 1.2  # Compress highlights

	# ====================================================================
	# PS1-STYLE ATMOSPHERIC FOG - Oppressive but not blinding
	# ====================================================================
	env.fog_enabled = true
	env.fog_light_color = MORNING_FOG
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0  # No sun scattering for cleaner PS1 look
	env.fog_density = 0.015  # Slightly less fog for better visibility
	env.fog_aerial_perspective = 0.0  # No aerial perspective
	env.fog_sky_affect = 1.0  # Fog affects sky too
	env.fog_depth_curve = 1.2  # Slightly curved for more gradual falloff
	env.fog_depth_begin = FOG_START
	env.fog_depth_end = FOG_END
	env.volumetric_fog_enabled = false

	# ====================================================================
	# COLOR GRADING - Grim dark but visible
	# ====================================================================
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0  # Neutral brightness
	env.adjustment_contrast = 1.1  # Moderate contrast
	env.adjustment_saturation = 0.75  # Slightly desaturated for grim feel

	# ====================================================================
	# GLOW - Subtle, for atmosphere (not bright bloom)
	# ====================================================================
	env.glow_enabled = true
	env.glow_intensity = 0.3  # Subtle glow
	env.glow_strength = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2  # Only very bright things glow
	env.glow_hdr_scale = 1.5

	world_environment.environment = env
	add_child(world_environment)

	# ====================================================================
	# MOON BILLBOARD - Visible at night
	# ====================================================================
	_create_moon()

	# ====================================================================
	# CLOUD DOME - Atmospheric clouds that drift slowly
	# ====================================================================
	_create_cloud_dome()


## Create moon sprite that appears at night
func _create_moon() -> void:
	moon_sprite = Sprite3D.new()
	moon_sprite.name = "Moon"

	# Try to load moon texture, fallback to white circle
	var moon_tex: Texture2D = load("res://assets/textures/sky/moon.png")
	if moon_tex:
		moon_sprite.texture = moon_tex
	else:
		# Create a simple white gradient texture as fallback
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var center := Vector2(32, 32)
		for x in range(64):
			for y in range(64):
				var dist: float = Vector2(x, y).distance_to(center)
				var alpha: float = clampf(1.0 - (dist / 28.0), 0.0, 1.0)
				var brightness: float = clampf(1.0 - (dist / 32.0), 0.6, 1.0)
				img.set_pixel(x, y, Color(brightness, brightness * 0.95, brightness * 0.85, alpha))
		moon_sprite.texture = ImageTexture.create_from_image(img)

	moon_sprite.pixel_size = 0.5  # Large in the sky
	moon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_sprite.no_depth_test = true  # Always render on top of sky
	moon_sprite.modulate = Color(0.9, 0.92, 1.0, 0.0)  # Start invisible (fades in at night)

	# Position far away in sky (will be updated in _process)
	moon_sprite.position = Vector3(0, 50, -100)

	add_child(moon_sprite)


## Create cloud dome with drifting clouds
func _create_cloud_dome() -> void:
	cloud_dome = MeshInstance3D.new()
	cloud_dome.name = "CloudDome"

	# Create a large inverted sphere for the sky dome
	var sphere := SphereMesh.new()
	sphere.radius = 200.0
	sphere.height = 400.0
	sphere.radial_segments = 16
	sphere.rings = 8
	cloud_dome.mesh = sphere

	# Create cloud shader material
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.002;
uniform float cloud_density : hint_range(0.0, 2.0) = 0.8;
uniform float cloud_alpha : hint_range(0.0, 1.0) = 0.5;
uniform vec4 cloud_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float time_scale : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// Sample cloud texture with UV scrolling for drift effect
	vec2 uv = UV * 2.0;  // Tile the texture
	uv.x += TIME * cloud_speed * time_scale;
	uv.y += TIME * cloud_speed * 0.3 * time_scale;  // Slower vertical drift

	vec4 cloud = texture(cloud_texture, uv);

	// Only show clouds above horizon (upper hemisphere)
	float horizon_mask = smoothstep(0.4, 0.6, UV.y);

	// Apply density and alpha
	float alpha = cloud.r * cloud_density * cloud_alpha * horizon_mask;

	ALBEDO = cloud_color.rgb;
	ALPHA = alpha;
}
"""

	cloud_material = ShaderMaterial.new()
	cloud_material.shader = shader

	# Try to load cloud texture, or create procedural one
	var cloud_tex: Texture2D
	if ResourceLoader.exists("res://assets/textures/sky/clouds.png"):
		cloud_tex = load("res://assets/textures/sky/clouds.png")
	if not cloud_tex:
		cloud_tex = _create_procedural_cloud_texture()
	cloud_material.set_shader_parameter("cloud_texture", cloud_tex)
	cloud_material.set_shader_parameter("cloud_speed", 0.003)
	cloud_material.set_shader_parameter("cloud_density", 1.0)
	cloud_material.set_shader_parameter("cloud_alpha", 0.4)
	cloud_material.set_shader_parameter("cloud_color", Color(0.85, 0.85, 0.85, 1.0))

	cloud_dome.material_override = cloud_material
	cloud_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(cloud_dome)


## Create procedural cloud texture if none exists
func _create_procedural_cloud_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	# Simple noise-based cloud pattern
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	for x in range(size):
		for y in range(size):
			var value: float = noise.get_noise_2d(x, y) * 0.5 + 0.5
			value = clampf(value * 1.5 - 0.3, 0.0, 1.0)  # Contrast boost
			img.set_pixel(x, y, Color(value, value, value, 1.0))

	return ImageTexture.create_from_image(img)


## Apply grim dark post-processing to an existing environment
func _apply_grim_dark_postprocess(env: Environment) -> void:
	if not env:
		return

	# Tonemapping - balanced exposure
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0  # Neutral exposure
	env.tonemap_white = 1.2

	# Color grading - keep grim aesthetic but don't crush brightness
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0  # Neutral brightness (was 0.92)
	env.adjustment_contrast = 1.1    # Slightly reduced contrast
	env.adjustment_saturation = 0.75 # Slightly more saturated than before

	# Subtle glow
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 1.5

func _process(delta: float) -> void:
	if not sun_light:
		return

	# Calculate sun angle based on actual game time (continuous movement)
	var sun_angle: float = _calculate_sun_angle_from_time(GameManager.game_time)

	# Smoothly interpolate to target values
	sun_light.light_color = sun_light.light_color.lerp(target_color, delta * transition_speed)
	sun_light.light_energy = lerpf(sun_light.light_energy, target_energy, delta * transition_speed)

	# Interpolate sun angle toward calculated position
	var current_angle := sun_light.rotation_degrees.x
	sun_light.rotation_degrees.x = lerpf(current_angle, sun_angle, delta * transition_speed)

	# Update environment ambient
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_color = env.ambient_light_color.lerp(target_ambient, delta * transition_speed)

		# Update ambient light ENERGY - this is critical for dark nights!
		env.ambient_light_energy = lerpf(env.ambient_light_energy, target_ambient_energy, delta * transition_speed)

		# Update PS1-style fog color
		env.fog_light_color = env.fog_light_color.lerp(target_fog, delta * transition_speed)

	# Update sky colors based on time of day
	_update_sky_colors(delta)

	# Update moon position and visibility
	_update_moon(delta)

	# Update cloud appearance
	_update_clouds(delta)

	# Update sky positions to follow player
	_update_sky_position_to_follow_player()


## Update procedural sky colors based on time
func _update_sky_colors(delta: float) -> void:
	if not sky_material:
		return

	var time: float = fmod(GameManager.game_time, 24.0)

	# Sky top color (zenith) - changes dramatically with time
	var sky_top: Color
	var sky_horizon: Color

	if time < 5.0:  # Night/Midnight
		sky_top = Color(0.05, 0.06, 0.12)       # Deep dark blue
		sky_horizon = Color(0.08, 0.08, 0.1)    # Slightly lighter
	elif time < 7.0:  # Dawn
		var t: float = (time - 5.0) / 2.0
		sky_top = Color(0.05, 0.06, 0.12).lerp(Color(0.4, 0.35, 0.5), t)     # Purple dawn
		sky_horizon = Color(0.08, 0.08, 0.1).lerp(Color(0.7, 0.45, 0.35), t) # Orange horizon
	elif time < 10.0:  # Morning
		var t: float = (time - 7.0) / 3.0
		sky_top = Color(0.4, 0.35, 0.5).lerp(Color(0.35, 0.4, 0.5), t)       # Clearing to grey-blue
		sky_horizon = Color(0.7, 0.45, 0.35).lerp(Color(0.55, 0.52, 0.5), t) # Fading orange
	elif time < 17.0:  # Day
		sky_top = Color(0.35, 0.4, 0.5)         # Muted grey-blue sky
		sky_horizon = Color(0.55, 0.52, 0.5)    # Hazy horizon
	elif time < 19.0:  # Dusk
		var t: float = (time - 17.0) / 2.0
		sky_top = Color(0.35, 0.4, 0.5).lerp(Color(0.3, 0.2, 0.35), t)       # Darkening purple
		sky_horizon = Color(0.55, 0.52, 0.5).lerp(Color(0.6, 0.35, 0.25), t) # Blood red sunset
	elif time < 21.0:  # Evening
		var t: float = (time - 19.0) / 2.0
		sky_top = Color(0.3, 0.2, 0.35).lerp(Color(0.08, 0.08, 0.15), t)     # Deep twilight
		sky_horizon = Color(0.6, 0.35, 0.25).lerp(Color(0.15, 0.1, 0.12), t) # Fading red
	else:  # Night
		var t: float = (time - 21.0) / 3.0
		sky_top = Color(0.08, 0.08, 0.15).lerp(Color(0.05, 0.06, 0.12), t)
		sky_horizon = Color(0.15, 0.1, 0.12).lerp(Color(0.08, 0.08, 0.1), t)

	# Smoothly interpolate sky colors
	var current_top: Color = sky_material.sky_top_color
	var current_horizon: Color = sky_material.sky_horizon_color
	sky_material.sky_top_color = current_top.lerp(sky_top, delta * transition_speed)
	sky_material.sky_horizon_color = current_horizon.lerp(sky_horizon, delta * transition_speed)
	sky_material.ground_horizon_color = current_horizon.lerp(sky_horizon * 0.6, delta * transition_speed)


## Get the player's current position for sky element tracking
func _get_player_position() -> Vector3:
	# Try to get player from scene tree
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		return player.global_position
	return Vector3.ZERO


## Update sky element positions to follow the player
func _update_sky_position_to_follow_player() -> void:
	var player_pos: Vector3 = _get_player_position()

	# Cloud dome follows player exactly
	if cloud_dome:
		cloud_dome.global_position = player_pos

	# Note: Moon position is updated in _update_moon() with player offset


## Update moon visibility and position
func _update_moon(delta: float) -> void:
	if not moon_sprite:
		return

	var time: float = fmod(GameManager.game_time, 24.0)

	# Moon is visible from dusk (18:00) to dawn (6:00)
	var target_alpha: float = 0.0
	if time >= 19.0 or time < 6.0:
		# Full moon visibility at night
		if time >= 21.0 or time < 5.0:
			target_alpha = 0.9
		else:
			# Fade in/out during twilight
			if time >= 19.0:
				target_alpha = (time - 19.0) / 2.0 * 0.9
			else:
				target_alpha = (6.0 - time) / 1.0 * 0.9

	# Smooth fade
	var current_alpha: float = moon_sprite.modulate.a
	moon_sprite.modulate.a = lerpf(current_alpha, target_alpha, delta * 2.0)

	# Position moon opposite to sun (roughly)
	# Moon rises in the east as sun sets in the west
	var moon_angle: float = 0.0
	if time >= 18.0:
		# Evening to midnight: moon rises
		moon_angle = (time - 18.0) / 6.0 * 70.0 - 10.0  # -10 to 60 degrees
	elif time < 6.0:
		# Midnight to dawn: moon sets
		moon_angle = 60.0 - (time / 6.0) * 70.0  # 60 to -10 degrees

	# Position moon in sky dome relative to player
	var moon_distance: float = 150.0
	var moon_y: float = sin(deg_to_rad(moon_angle)) * moon_distance
	var moon_z: float = -cos(deg_to_rad(moon_angle)) * moon_distance
	var player_pos: Vector3 = _get_player_position()
	moon_sprite.global_position = player_pos + Vector3(30, moon_y, moon_z)  # Offset X so it's not directly opposite


## Update cloud color and density based on time
func _update_clouds(delta: float) -> void:
	if not cloud_material:
		return

	var time: float = fmod(GameManager.game_time, 24.0)

	# Cloud color changes with time of day
	var cloud_color: Color
	var cloud_alpha: float

	if time < 5.0:  # Night
		cloud_color = Color(0.15, 0.15, 0.2)  # Dark blue-grey
		cloud_alpha = 0.25  # Subtle at night
	elif time < 7.0:  # Dawn
		var t: float = (time - 5.0) / 2.0
		cloud_color = Color(0.15, 0.15, 0.2).lerp(Color(0.85, 0.65, 0.55), t)  # Pink/orange dawn clouds
		cloud_alpha = lerpf(0.25, 0.5, t)
	elif time < 10.0:  # Morning
		cloud_color = Color(0.85, 0.82, 0.78)  # Bright white-ish
		cloud_alpha = 0.45
	elif time < 17.0:  # Day
		cloud_color = Color(0.9, 0.88, 0.85)   # White clouds
		cloud_alpha = 0.4
	elif time < 19.0:  # Dusk
		var t: float = (time - 17.0) / 2.0
		cloud_color = Color(0.9, 0.88, 0.85).lerp(Color(0.9, 0.5, 0.35), t)  # Orange/red sunset clouds
		cloud_alpha = lerpf(0.4, 0.55, t)
	elif time < 21.0:  # Evening
		var t: float = (time - 19.0) / 2.0
		cloud_color = Color(0.9, 0.5, 0.35).lerp(Color(0.25, 0.2, 0.25), t)
		cloud_alpha = lerpf(0.55, 0.3, t)
	else:  # Night
		cloud_color = Color(0.15, 0.15, 0.2)
		cloud_alpha = 0.25

	# Apply smoothly
	var current_color: Color = cloud_material.get_shader_parameter("cloud_color")
	var current_alpha: float = cloud_material.get_shader_parameter("cloud_alpha")
	cloud_material.set_shader_parameter("cloud_color", current_color.lerp(cloud_color, delta * transition_speed))
	cloud_material.set_shader_parameter("cloud_alpha", lerpf(current_alpha, cloud_alpha, delta * transition_speed))


## Calculate sun angle based on actual game time (0-24 hours)
## Returns continuous angle from below horizon at night to peak at noon
func _calculate_sun_angle_from_time(game_time: float) -> float:
	# Time periods and their sun angles
	# Dawn: 5-7, Morning: 7-10, Noon: 10-14, Afternoon: 14-17, Dusk: 17-20, Night: 20-5
	var time := fmod(game_time, 24.0)

	# Define keyframes: [time, angle]
	# Noon brightness extended to last until ~5pm
	var keyframes: Array[Array] = [
		[0.0, MIDNIGHT_ANGLE],   # Midnight
		[5.0, DAWN_ANGLE],       # Dawn start
		[7.0, MORNING_ANGLE],    # Morning start
		[10.0, NOON_ANGLE],      # Approaching noon
		[12.0, NOON_ANGLE],      # Solar noon (peak)
		[16.0, NOON_ANGLE],      # Extended noon until 4pm
		[17.0, AFTERNOON_ANGLE], # Afternoon starts at 5pm
		[19.0, DUSK_ANGLE],      # Dusk start
		[21.0, NIGHT_ANGLE],     # Night start
		[24.0, MIDNIGHT_ANGLE],  # Back to midnight
	]

	# Find which two keyframes we're between and interpolate
	for i in range(keyframes.size() - 1):
		var kf1: Array = keyframes[i]
		var kf2: Array = keyframes[i + 1]
		var t1: float = kf1[0]
		var t2: float = kf2[0]
		var a1: float = kf1[1]
		var a2: float = kf2[1]

		if time >= t1 and time < t2:
			var t: float = (time - t1) / (t2 - t1)
			return lerpf(a1, a2, t)

	# Fallback (should not reach)
	return MIDNIGHT_ANGLE

func _apply_lighting_instant() -> void:
	if sun_light:
		sun_light.light_color = target_color
		sun_light.light_energy = target_energy
		# Use actual time-based sun angle instead of period target
		sun_light.rotation_degrees.x = _calculate_sun_angle_from_time(GameManager.game_time)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_color = target_ambient
		env.ambient_light_energy = target_ambient_energy
		env.background_color = target_ambient * 0.8
		env.fog_light_color = target_fog

func _on_time_of_day_changed(time_of_day: Enums.TimeOfDay) -> void:
	match time_of_day:
		Enums.TimeOfDay.DAWN:
			target_color = DAWN_COLOR
			target_energy = DAWN_ENERGY
			target_ambient = DAWN_AMBIENT
			target_ambient_energy = DAWN_AMBIENT_ENERGY
			target_angle = DAWN_ANGLE
			target_fog = DAWN_FOG
		Enums.TimeOfDay.MORNING:
			target_color = MORNING_COLOR
			target_energy = MORNING_ENERGY
			target_ambient = MORNING_AMBIENT
			target_ambient_energy = MORNING_AMBIENT_ENERGY
			target_angle = MORNING_ANGLE
			target_fog = MORNING_FOG
		Enums.TimeOfDay.NOON:
			target_color = NOON_COLOR
			target_energy = NOON_ENERGY
			target_ambient = NOON_AMBIENT
			target_ambient_energy = NOON_AMBIENT_ENERGY
			target_angle = NOON_ANGLE
			target_fog = NOON_FOG
		Enums.TimeOfDay.AFTERNOON:
			target_color = AFTERNOON_COLOR
			target_energy = AFTERNOON_ENERGY
			target_ambient = AFTERNOON_AMBIENT
			target_ambient_energy = AFTERNOON_AMBIENT_ENERGY
			target_angle = AFTERNOON_ANGLE
			target_fog = AFTERNOON_FOG
		Enums.TimeOfDay.DUSK:
			target_color = DUSK_COLOR
			target_energy = DUSK_ENERGY
			target_ambient = DUSK_AMBIENT
			target_ambient_energy = DUSK_AMBIENT_ENERGY
			target_angle = DUSK_ANGLE
			target_fog = DUSK_FOG
		Enums.TimeOfDay.NIGHT:
			target_color = NIGHT_COLOR
			target_energy = NIGHT_ENERGY
			target_ambient = NIGHT_AMBIENT
			target_ambient_energy = NIGHT_AMBIENT_ENERGY
			target_angle = NIGHT_ANGLE
			target_fog = NIGHT_FOG
		Enums.TimeOfDay.MIDNIGHT:
			target_color = MIDNIGHT_COLOR
			target_energy = MIDNIGHT_ENERGY
			target_ambient = MIDNIGHT_AMBIENT
			target_ambient_energy = MIDNIGHT_AMBIENT_ENERGY
			target_angle = MIDNIGHT_ANGLE
			target_fog = MIDNIGHT_FOG

## Static spawner for adding to levels
## Returns null if called from a streaming cell context (lighting should come from main scene only)
static func add_to_level(parent: Node3D) -> DayNightCycle:
	# Don't add lighting if this scene is loaded as a streaming cell
	# Check if we're a child of the cell container (means we're streamed, not main scene)
	var node: Node = parent
	while node:
		# CellStreamer names its container "_CellContainer" or "CellContainer"
		if node.name == "_CellContainer" or node.name == "CellContainer":
			# We're inside a streamed cell - don't add lighting
			return null
		node = node.get_parent()

	# Normal creation for main scene
	var cycle := DayNightCycle.new()
	cycle.name = "DayNightCycle"
	parent.add_child(cycle)
	return cycle


## Force DayNightCycle to take over lighting (removes existing lights)
## Use this when entering hand-crafted areas that may have their own static lighting
static func force_takeover(parent: Node) -> DayNightCycle:
	# Remove any existing WorldEnvironment and DirectionalLight3D
	for child in parent.get_children():
		if child is WorldEnvironment:
			child.queue_free()
		elif child is DirectionalLight3D:
			child.queue_free()

	# Also check for existing DayNightCycle and remove it
	var existing_cycle: Node = parent.get_node_or_null("DayNightCycle")
	if existing_cycle:
		existing_cycle.queue_free()

	# Create fresh DayNightCycle
	var cycle := DayNightCycle.new()
	cycle.name = "DayNightCycle"
	parent.add_child(cycle)
	return cycle

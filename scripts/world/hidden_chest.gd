## hidden_chest.gd - Container that is invisible until detected by the player
## Hidden chests require the player's hidden detection bonus to beat the DC
## Once revealed, they behave like normal chests with enhanced loot
class_name HiddenChest
extends Chest

## Self-reference for static method instantiation
const _Self = preload("res://scripts/world/hidden_chest.gd")

signal chest_revealed(chest: HiddenChest)

## Detection configuration
@export var detection_dc: int = 15
@export var detection_radius: float = 6.0
@export var loot_tier: LootTables.LootTier = LootTables.LootTier.UNCOMMON

## Hidden state
var is_revealed: bool = false
var has_checked: bool = false
var check_at_bonus: int = -1

## Detection area
var detection_area: Area3D

## Reveal VFX
var reveal_particles: GPUParticles3D
var reveal_text: Label3D

## High-value guaranteed items for hidden chests
## These items have base_value >= 2000g or are extremely rare magical items
const HIGH_VALUE_ITEMS: Array[String] = [
	"soulstone_grand_filled",       # 5000g - Best soulstone
	"soulstone_greater_filled",     # 2000g - Great soulstone
	"soulstone_grand_empty",        # 2500g - Valuable empty stone
	"scroll_chain_lightning",       # Legendary spell
	"scroll_cone_of_cold",          # Legendary spell
	"scroll_iron_guard",            # Legendary spell
	"gem_diamond",                  # Legendary gem
	"flamebrand",                   # Legendary weapon
]

## Rare magical items that work with game systems
const RARE_MAGICAL_ITEMS: Array[String] = [
	"scroll_fireball",
	"scroll_fire_gate",
	"scroll_ice_storm",
	"scroll_soul_drain",
	"scroll_haste",
	"amulet_of_vitality",
	"amulet_of_wisdom",
	"ring_of_protection",
	"ring_of_strength",
]


func _ready() -> void:
	# Create the mesh but start hidden
	_create_chest_mesh()
	_create_interaction_area()
	_create_detection_area()

	# Start hidden - do NOT add to interactable group yet
	add_to_group("chests")
	add_to_group("hidden_chests")

	# Hide the mesh
	if mesh_root:
		mesh_root.visible = false

	# Disable interaction area until revealed
	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false


func _create_detection_area() -> void:
	## Create Area3D sphere for player detection
	detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0  # Don't block anything
	detection_area.collision_mask = 2   # Player layer (layer 2)
	add_child(detection_area)

	var sphere_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	sphere_shape.shape = sphere
	sphere_shape.name = "DetectionShape"
	detection_area.add_child(sphere_shape)

	# Connect signals
	detection_area.body_entered.connect(_on_body_entered_detection)


func _on_body_entered_detection(body: Node3D) -> void:
	## Player entered detection range - attempt detection
	if is_revealed:
		return

	if body.is_in_group("player"):
		_attempt_detection()


func _attempt_detection() -> void:
	## Try to detect the hidden chest using player's hidden detection bonus
	if not GameManager.player_data:
		return

	var player_bonus: int = GameManager.player_data.get_hidden_detection_bonus()

	# Allow re-check if skill improved by 3+ points
	if has_checked and (player_bonus < check_at_bonus + 3):
		return

	has_checked = true
	check_at_bonus = player_bonus

	# Make the passive check
	var result: Dictionary = DiceManager.passive_check("Secret Detection", player_bonus, detection_dc)

	if result.success:
		_reveal_chest()


func _reveal_chest() -> void:
	## Make the chest visible and interactable
	if is_revealed:
		return

	is_revealed = true

	# Play reveal VFX
	_play_reveal_effect()

	# Play gold sparkly text notification
	_show_gold_reveal_text()

	# Play sound
	AudioManager.play_sfx("chest_revealed")

	# Emit signal
	chest_revealed.emit(self)


func _play_reveal_effect() -> void:
	## Gold shimmer particles + mesh fade-in

	# Create reveal particles (gold shimmer)
	reveal_particles = GPUParticles3D.new()
	reveal_particles.name = "RevealParticles"
	reveal_particles.amount = 30
	reveal_particles.one_shot = true
	reveal_particles.explosiveness = 0.8
	reveal_particles.lifetime = 1.0
	reveal_particles.position = Vector3(0, 0.4, 0)  # Center of chest
	add_child(reveal_particles)

	# Create particle material
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(0.5, 0.3, 0.3)
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 45.0
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 2.0
	particle_material.gravity = Vector3(0, -2, 0)
	particle_material.scale_min = 0.05
	particle_material.scale_max = 0.1
	particle_material.color = Color(1.0, 0.85, 0.3, 1.0)  # Gold color
	reveal_particles.process_material = particle_material

	# Create particle mesh (small quad)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	reveal_particles.draw_pass_1 = quad

	# Start particles
	reveal_particles.emitting = true

	# Fade in mesh
	if mesh_root:
		mesh_root.visible = true

		# Start with transparent materials
		_set_mesh_transparency(0.0)

		# Create tween for fade-in
		var tween := create_tween()
		tween.tween_method(_set_mesh_transparency, 0.0, 1.0, 0.8)
		tween.tween_callback(_on_reveal_complete)


func _show_gold_reveal_text() -> void:
	## Create a floating gold text that says "Hidden Chest Revealed!" with sparkle effect
	reveal_text = Label3D.new()
	reveal_text.name = "RevealText"
	reveal_text.text = "Hidden Treasure Found!"
	reveal_text.font_size = 48
	reveal_text.pixel_size = 0.008
	reveal_text.position = Vector3(0, 1.5, 0)  # Above chest
	reveal_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reveal_text.modulate = Color(1.0, 0.85, 0.2, 1.0)  # Gold color
	reveal_text.outline_size = 8
	reveal_text.outline_modulate = Color(0.8, 0.5, 0.0, 1.0)  # Darker gold outline
	add_child(reveal_text)

	# Create sparkle particles around the text
	var sparkle := GPUParticles3D.new()
	sparkle.name = "TextSparkles"
	sparkle.amount = 20
	sparkle.lifetime = 1.5
	sparkle.one_shot = false
	sparkle.explosiveness = 0.0
	sparkle.position = Vector3(0, 1.5, 0)
	add_child(sparkle)

	# Sparkle particle material
	var sparkle_mat := ParticleProcessMaterial.new()
	sparkle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sparkle_mat.emission_box_extents = Vector3(0.8, 0.2, 0.1)
	sparkle_mat.direction = Vector3(0, 0.5, 0)
	sparkle_mat.spread = 180.0
	sparkle_mat.initial_velocity_min = 0.3
	sparkle_mat.initial_velocity_max = 0.8
	sparkle_mat.gravity = Vector3(0, -0.5, 0)
	sparkle_mat.scale_min = 0.02
	sparkle_mat.scale_max = 0.05
	sparkle_mat.color = Color(1.0, 0.9, 0.3, 1.0)  # Bright gold sparkles
	sparkle.process_material = sparkle_mat

	# Small quad mesh for sparkles
	var sparkle_mesh := QuadMesh.new()
	sparkle_mesh.size = Vector2(0.08, 0.08)
	sparkle.draw_pass_1 = sparkle_mesh

	sparkle.emitting = true

	# Animate text: float up and fade out after 3 seconds
	var tween := create_tween()
	tween.set_parallel(true)

	# Float up
	tween.tween_property(reveal_text, "position:y", 2.5, 3.0).set_ease(Tween.EASE_OUT)

	# Pulse scale for sparkle effect
	tween.tween_property(reveal_text, "pixel_size", 0.01, 0.5).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(reveal_text, "pixel_size", 0.008, 0.5).set_ease(Tween.EASE_IN)

	# Fade out after 2 seconds
	tween.tween_property(reveal_text, "modulate:a", 0.0, 1.0).set_delay(2.0)
	tween.tween_property(sparkle, "emitting", false, 0.0).set_delay(2.5)

	# Cleanup after animation
	tween.chain().tween_callback(func():
		if is_instance_valid(reveal_text):
			reveal_text.queue_free()
			reveal_text = null
		if is_instance_valid(sparkle):
			sparkle.queue_free()
	)


func _set_mesh_transparency(alpha: float) -> void:
	## Set transparency on all mesh materials
	if not mesh_root:
		return

	for child in mesh_root.get_children():
		if child is MeshInstance3D:
			var mat = child.material_override
			if mat and mat is StandardMaterial3D:
				if alpha < 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = alpha
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.albedo_color.a = 1.0


func _on_reveal_complete() -> void:
	## Called when reveal animation finishes
	# Add to interactable group so player can interact
	add_to_group("interactable")

	# Enable interaction area
	if interaction_area:
		interaction_area.monitoring = true
		interaction_area.monitorable = true

	# Disable detection area (no longer needed)
	if detection_area:
		detection_area.queue_free()
		detection_area = null

	# Clean up particles after they finish
	if reveal_particles:
		# Wait for particles to finish
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(reveal_particles):
			reveal_particles.queue_free()
			reveal_particles = null


## Override interaction prompt to indicate hidden status before reveal
func get_interaction_prompt() -> String:
	if not is_revealed:
		return ""  # Hidden chests shouldn't show prompts
	return super.get_interaction_prompt()


## Override interact to prevent interaction if not revealed
func interact(interactor: Node) -> void:
	if not is_revealed:
		return
	super.interact(interactor)


## Static factory method for spawning hidden chests
static func spawn_hidden_chest(
	parent: Node,
	pos: Vector3,
	p_chest_name: String = "Hidden Cache",
	p_detection_dc: int = 15,
	p_loot_tier: LootTables.LootTier = LootTables.LootTier.UNCOMMON,
	p_locked: bool = false,
	p_lock_dc: int = 10
) -> HiddenChest:
	var instance := _Self.new()
	instance.position = pos
	instance.chest_name = p_chest_name
	instance.detection_dc = p_detection_dc
	instance.loot_tier = p_loot_tier
	instance.is_locked = p_locked
	instance.lock_difficulty = p_lock_dc

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.5, 0.5)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.25, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)

	# Setup guaranteed high-value loot for hidden chests
	instance._setup_hidden_chest_loot(p_loot_tier)

	return instance


## Setup loot specific to hidden chests - guarantees high-value or rare magical items
func _setup_hidden_chest_loot(base_tier: LootTables.LootTier) -> void:
	# Clear any existing loot
	contents.clear()

	# GUARANTEED: One high-value item (2000g+) OR rare magical item
	var guaranteed_item: String = _get_guaranteed_valuable_item(base_tier)
	if not guaranteed_item.is_empty():
		var quality: Enums.ItemQuality = LootTables.roll_quality_for_tier(LootTables.LootTier.EPIC)
		add_item(guaranteed_item, 1, quality)

	# Enhanced tier for additional loot
	var enhanced_tier: LootTables.LootTier = _get_enhanced_tier(base_tier)

	# Add 2-3 more items from enhanced tier
	var extra_items: int = randi_range(2, 3)
	for i in range(extra_items):
		var drop: Dictionary = LootTables._generate_single_drop(enhanced_tier)
		if not drop.is_empty():
			var item_id: String = drop.get("item_id", "")
			var quantity: int = drop.get("quantity", 1)
			var quality: Enums.ItemQuality = drop.get("quality", Enums.ItemQuality.AVERAGE)
			if not item_id.is_empty():
				add_item(item_id, quantity, quality)

	# Generous gold bonus (hidden chests reward exploration)
	var gold_amount: int = randi_range(200, 500) * (int(enhanced_tier) + 1)
	add_item("_gold", gold_amount, Enums.ItemQuality.AVERAGE)


## Get a guaranteed valuable item based on chest tier
static func _get_guaranteed_valuable_item(tier: LootTables.LootTier) -> String:
	# Higher tiers get better guaranteed items
	var item_pool: Array[String] = []

	match tier:
		LootTables.LootTier.JUNK, LootTables.LootTier.COMMON:
			# Lower tier hidden chests: rare magical items
			item_pool = [
				"scroll_fireball",
				"scroll_soul_drain",
				"scroll_haste",
				"ring_of_protection",
				"ring_of_strength",
				"soulstone_greater_empty",  # Worth 1000g but useful
			]
		LootTables.LootTier.UNCOMMON:
			# Mid tier: epic magical items or lower high-value
			item_pool = [
				"scroll_ice_storm",
				"scroll_fire_gate",
				"amulet_of_vitality",
				"amulet_of_wisdom",
				"soulstone_greater_filled",  # 2000g
				"gem_emerald",
				"gem_sapphire",
			]
		LootTables.LootTier.RARE:
			# Higher tier: legendary scrolls or high-value soulstones
			item_pool = [
				"scroll_chain_lightning",
				"scroll_cone_of_cold",
				"scroll_iron_guard",
				"soulstone_grand_empty",     # 2500g
				"soulstone_greater_filled",  # 2000g
				"gem_diamond",
			]
		LootTables.LootTier.EPIC, LootTables.LootTier.LEGENDARY:
			# Best tier: guaranteed extremely valuable items
			item_pool = [
				"soulstone_grand_filled",    # 5000g
				"scroll_chain_lightning",
				"flamebrand",                # Legendary weapon
				"gem_diamond",
				"soulstone_grand_empty",     # 2500g
			]

	if item_pool.is_empty():
		return ""

	# Verify item exists before returning
	var shuffled: Array[String] = item_pool.duplicate()
	shuffled.shuffle()

	for item_id: String in shuffled:
		if InventoryManager.item_database.has(item_id) or \
		   InventoryManager.weapon_database.has(item_id) or \
		   InventoryManager.armor_database.has(item_id):
			return item_id

	# Fallback to a guaranteed existing item
	return "gem_diamond"


## Get enhanced loot tier (one tier better)
static func _get_enhanced_tier(base_tier: LootTables.LootTier) -> LootTables.LootTier:
	match base_tier:
		LootTables.LootTier.JUNK:
			return LootTables.LootTier.COMMON
		LootTables.LootTier.COMMON:
			return LootTables.LootTier.UNCOMMON
		LootTables.LootTier.UNCOMMON:
			return LootTables.LootTier.RARE
		LootTables.LootTier.RARE:
			return LootTables.LootTier.EPIC
		LootTables.LootTier.EPIC:
			return LootTables.LootTier.LEGENDARY
		LootTables.LootTier.LEGENDARY:
			return LootTables.LootTier.LEGENDARY  # Can't go higher
	return base_tier


## Parse loot tier from string metadata
static func parse_tier(tier_string: String) -> LootTables.LootTier:
	match tier_string.to_lower():
		"junk":
			return LootTables.LootTier.JUNK
		"common":
			return LootTables.LootTier.COMMON
		"uncommon":
			return LootTables.LootTier.UNCOMMON
		"rare":
			return LootTables.LootTier.RARE
		"epic":
			return LootTables.LootTier.EPIC
		"legendary":
			return LootTables.LootTier.LEGENDARY
	return LootTables.LootTier.COMMON

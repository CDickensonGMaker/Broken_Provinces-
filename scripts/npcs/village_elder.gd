## village_elder.gd - Village authority figure who accepts tributes to improve faction standing
## Players can pay gold to increase their reputation with the town faction
## Tribute only works when UNFRIENDLY or NEUTRAL (-49 to 20 rep), and caps at NEUTRAL (20 rep)
class_name VillageElderNPC
extends StaticBody3D

## NPC identification
@export var npc_id: String = "village_elder"
@export var display_name: String = "Village Elder"

## Alias for ConversationSystem compatibility
var npc_name: String:
	get: return display_name
	set(value): display_name = value

## NPC type for compass/minimap POI
var npc_type: String = "village_elder"

## Region this elder represents (matched to town faction)
@export var region_id: String = ""

## Faction ID for this town (e.g., "elder_moor", "dalhurst", "thornfield")
## If empty, will try to get from FactionManager based on current location
@export var town_faction_id: String = ""

## NPC knowledge profile for ConversationSystem
@export var npc_profile: NPCKnowledgeProfile

## Sprite configuration
@export var sprite_texture: Texture2D
@export var is_female: bool = false
var sprite_h_frames: int = 1
var sprite_v_frames: int = 1
var sprite_pixel_size: float = 0.0256  # Standard NPC height

## Visual components
var billboard: BillboardSprite
var interaction_area: Area3D

## Tribute system constants
const TRIBUTE_COST: int = 100       # Gold per tribute payment
const TRIBUTE_REP_GAIN: int = 5     # Reputation gained per tribute
const MAX_TRIBUTE_REP: int = 20     # Max rep achievable via tribute (NEUTRAL threshold)
const MIN_TRIBUTE_REP: int = -49    # Minimum rep to use tribute (UNFRIENDLY)

## Health and combat (NPCs can be attacked)
var max_health: int = 30
var current_health: int = 30
var _is_dead: bool = false

## Interaction guard
var _is_interacting: bool = false

## Pending tribute flag - set when player confirms tribute
var _pending_tribute: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	add_to_group("attackable")
	add_to_group("village_elders")

	current_health = max_health

	# Create visual components if not already present
	if not get_node_or_null("Billboard"):
		_create_visual()
	else:
		billboard = get_node_or_null("Billboard")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	if not get_node_or_null("Collision"):
		_create_collision()

	_register_compass_poi()
	_register_with_world_data()


## Create billboard sprite visual
func _create_visual() -> void:
	var tex: Texture2D = sprite_texture
	var h_frames: int = sprite_h_frames
	var v_frames: int = sprite_v_frames
	var pixel_size: float = sprite_pixel_size

	# Check ActorRegistry for sprite configuration
	if ActorRegistry and not npc_id.is_empty() and ActorRegistry.has_actor(npc_id):
		var config: Dictionary = ActorRegistry.get_sprite_config(npc_id)
		if not config.is_empty():
			var registry_path: String = config.get("sprite_path", "")
			if not registry_path.is_empty() and ResourceLoader.exists(registry_path):
				tex = load(registry_path) as Texture2D
				h_frames = config.get("h_frames", h_frames)
				v_frames = config.get("v_frames", v_frames)
				pixel_size = config.get("pixel_size", pixel_size)

	# Fallback to default sprite if none assigned
	if not tex:
		if is_female:
			tex = load("res://assets/sprites/npcs/civilians/lady_in_red.png") as Texture2D
			h_frames = 8
			pixel_size = 0.0256
		else:
			tex = load("res://assets/sprites/npcs/civilians/man_civilian.png") as Texture2D
			h_frames = 1
			pixel_size = 0.0256

	if not tex:
		push_warning("[VillageElderNPC] No sprite texture available for " + display_name)
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	billboard.h_frames = h_frames
	billboard.v_frames = v_frames
	billboard.pixel_size = pixel_size
	billboard.idle_frames = h_frames
	billboard.walk_frames = h_frames
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
	billboard.name = "Billboard"
	add_child(billboard)


## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	collision.shape = shape
	collision.position.y = 1.0
	interaction_area.add_child(collision)

	add_child(interaction_area)


## Create collision shape
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	add_child(collision)


## Register as compass POI
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	set_meta("poi_id", "npc_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(0.8, 0.6, 0.2))  # Gold color for authority figure


## Register with WorldData for tracking
func _register_with_world_data() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	var zone_id: String = ""

	# Try to get zone_id from parent scene
	var parent: Node = get_parent()
	while parent:
		if "zone_id" in parent:
			zone_id = parent.zone_id
			break
		parent = parent.get_parent()

	if zone_id.is_empty():
		zone_id = region_id if not region_id.is_empty() else "town_unknown"

	PlayerGPS.register_npc(self, effective_id, npc_type, zone_id)


## Get the town faction ID for this elder
func _get_town_faction_id() -> String:
	# Use explicit faction ID if set
	if not town_faction_id.is_empty():
		return town_faction_id

	# Otherwise get from current location via FactionManager
	if FactionManager:
		return FactionManager.get_town_faction()

	return ""


## Check if player can make a tribute (reputation is in valid range)
func can_make_tribute() -> bool:
	var faction_id: String = _get_town_faction_id()
	if faction_id.is_empty():
		return false

	var current_rep: int = FactionManager.get_reputation(faction_id)

	# Can't tribute if hostile/hated (they won't speak to you)
	if current_rep < MIN_TRIBUTE_REP:
		return false

	# Can't tribute if already at or above max tribute rep
	if current_rep >= MAX_TRIBUTE_REP:
		return false

	# Can't tribute if don't have enough gold
	if InventoryManager.gold < TRIBUTE_COST:
		return false

	return true


## Calculate how much rep can still be gained via tribute
func get_remaining_tribute_rep() -> int:
	var faction_id: String = _get_town_faction_id()
	if faction_id.is_empty():
		return 0

	var current_rep: int = FactionManager.get_reputation(faction_id)
	return maxi(0, MAX_TRIBUTE_REP - current_rep)


## Make a tribute payment - called from dialogue callback
## Returns true if successful
func make_tribute() -> bool:
	var faction_id: String = _get_town_faction_id()
	if faction_id.is_empty():
		return false

	# Verify player can still afford it
	if InventoryManager.gold < TRIBUTE_COST:
		return false

	# Check rep limits
	var current_rep: int = FactionManager.get_reputation(faction_id)
	if current_rep >= MAX_TRIBUTE_REP:
		return false

	# Remove gold
	if not InventoryManager.remove_gold(TRIBUTE_COST):
		return false

	# Calculate actual rep gain (don't exceed max)
	var actual_gain: int = mini(TRIBUTE_REP_GAIN, MAX_TRIBUTE_REP - current_rep)

	# Apply reputation gain (no cascade - tribute is local to this town)
	FactionManager.modify_reputation(faction_id, actual_gain, "tribute to " + display_name, false)

	# Play confirmation sound
	if AudioManager:
		AudioManager.play_ui_confirm()

	# Show notification
	var new_rep: int = FactionManager.get_reputation(faction_id)
	var new_status: String = FactionManager.get_status_name(faction_id)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Reputation improved! Standing: %s (%d)" % [new_status, new_rep])

	return true


## Interaction entry point
func interact(_interactor: Node) -> void:
	if _is_interacting:
		return
	_is_interacting = true

	# Block if already in conversation
	if ConversationSystem.is_active or ConversationSystem.is_scripted_mode:
		_is_interacting = false
		return

	# Check faction standing first
	var faction_id: String = _get_town_faction_id()
	if not faction_id.is_empty():
		var status: FactionData.ReputationStatus = FactionManager.get_reputation_status(faction_id)

		# If hostile or hated, refuse to speak
		if status == FactionData.ReputationStatus.HOSTILE or status == FactionData.ReputationStatus.HATED:
			_show_hostile_response()
			_is_interacting = false
			return

	# Open tribute dialogue
	_open_tribute_dialogue()
	_is_interacting = false


## Show response when player is hostile/hated
func _show_hostile_response() -> void:
	var lines: Array = []

	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"I have nothing to say to you, criminal. Leave this place before the guards are called.",
		[],
		true  # is_end
	))

	ConversationSystem.start_scripted_dialogue(lines)


## Open the tribute dialogue
func _open_tribute_dialogue() -> void:
	var faction_id: String = _get_town_faction_id()
	var current_rep: int = 0
	var status_name: String = "Unknown"
	var faction_name: String = "this town"

	if not faction_id.is_empty():
		current_rep = FactionManager.get_reputation(faction_id)
		status_name = FactionManager.get_status_name(faction_id)
		var faction_data: FactionData = FactionManager.get_faction(faction_id)
		if faction_data:
			faction_name = faction_data.display_name

	var lines: Array = []
	_pending_tribute = false

	# Check various states and build appropriate dialogue
	if current_rep >= MAX_TRIBUTE_REP:
		# Already at neutral or better - no tribute needed
		lines.append(ConversationSystem.create_scripted_line(
			display_name,
			"Greetings, traveler. Your standing with %s is satisfactory. There is no need for tribute." % faction_name,
			[ConversationSystem.create_scripted_choice("Farewell.", -1)],
			false
		))
		ConversationSystem.start_scripted_dialogue(lines)
		return

	var can_afford: bool = InventoryManager.gold >= TRIBUTE_COST

	# Build greeting based on reputation
	var greeting: String
	if current_rep >= 0:
		greeting = "Welcome. Your standing with %s is passable, though tribute would be appreciated." % faction_name
	else:
		greeting = "Hmph. Your reputation precedes you. The people of %s do not trust you." % faction_name

	# Add status info
	var status_info: String = "\n\nCurrent standing: %s (%d)\nTribute cost: %d gold for +%d reputation" % [
		status_name, current_rep, TRIBUTE_COST, TRIBUTE_REP_GAIN
	]

	if current_rep < 0:
		status_info = "\n\nHowever... a tribute to the town might help restore some faith." + status_info

	# Line 0: Initial greeting with options
	var choices: Array = []
	if can_afford:
		# Player can afford tribute - give them the option
		choices.append(ConversationSystem.create_scripted_choice(
			"Make a tribute (%d gold)" % TRIBUTE_COST,
			1  # Jump to tribute confirmation line
		))
	else:
		# Player cannot afford - show disabled option text
		choices.append(ConversationSystem.create_scripted_choice(
			"[Not enough gold - need %d]" % TRIBUTE_COST,
			2  # Jump to "cannot afford" line
		))

	choices.append(ConversationSystem.create_scripted_choice(
		"Perhaps later." if current_rep >= 0 else "I'll earn my standing another way.",
		-1  # End dialogue
	))

	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		greeting + status_info,
		choices,
		false
	))

	# Line 1: Tribute accepted - process the payment
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"Your generosity is noted. The town will remember this kindness.",
		[],
		true  # is_end - dialogue ends, callback handles tribute
	))

	# Line 2: Cannot afford response
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"You don't seem to have enough gold for a tribute. Return when you can afford it.",
		[ConversationSystem.create_scripted_choice("I understand.", -1)],
		false
	))

	# Start dialogue with callback to process tribute
	ConversationSystem.start_scripted_dialogue(lines, _on_dialogue_ended)

	# Connect to track which choice was made
	if not ConversationSystem.scripted_line_shown.is_connected(_on_line_shown):
		ConversationSystem.scripted_line_shown.connect(_on_line_shown)


## Track which line is shown to know if tribute was selected
func _on_line_shown(line: Dictionary, index: int) -> void:
	# Line 1 means player selected "Make a tribute" and we showed the acceptance text
	if index == 1:
		_pending_tribute = true

	# Disconnect after we've tracked what we need
	# We don't disconnect here because dialogue might show more lines
	pass


## Dialogue ended callback - process tribute if player confirmed
func _on_dialogue_ended() -> void:
	# Disconnect line tracking signal
	if ConversationSystem.scripted_line_shown.is_connected(_on_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_line_shown)

	# Process tribute if player confirmed
	if _pending_tribute:
		make_tribute()
		_pending_tribute = false


## Get interaction prompt
func get_interaction_prompt() -> String:
	var faction_id: String = _get_town_faction_id()
	if not faction_id.is_empty():
		var status: FactionData.ReputationStatus = FactionManager.get_reputation_status(faction_id)
		if status == FactionData.ReputationStatus.HOSTILE or status == FactionData.ReputationStatus.HATED:
			return "Press [E] to speak to " + display_name + " (Hostile)"
	return "Press [E] to speak to " + display_name


## Take damage from attacks
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	var actual_damage: int = mini(amount, current_health)
	current_health -= actual_damage

	# Visual feedback
	if billboard and billboard.sprite:
		var original_color: Color = billboard.sprite.modulate
		billboard.sprite.modulate = Color(1.0, 0.3, 0.3)
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard and billboard.sprite and not _is_dead:
				billboard.sprite.modulate = original_color
		)

	if AudioManager:
		AudioManager.play_sfx("player_hit")

	if current_health <= 0:
		_die(attacker)

	return actual_damage


## Check if dead
func is_dead() -> bool:
	return _is_dead


## Get armor value
func get_armor_value() -> int:
	return 5


## Handle death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	# Report crime - killing an elder is murder AND causes huge rep loss
	if killer and killer.is_in_group("player"):
		var crime_region: String = region_id if not region_id.is_empty() else "unknown"
		CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, crime_region, [])

		# Additional reputation penalty for killing authority figure
		var faction_id: String = _get_town_faction_id()
		if not faction_id.is_empty():
			FactionManager.modify_reputation(faction_id, -50, "murdered village elder", true)

	# Spawn corpse
	_spawn_corpse()

	CombatManager.entity_killed.emit(self, killer)

	if AudioManager:
		AudioManager.play_sfx("enemy_death")

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("village_elders")
	remove_from_group("attackable")
	remove_from_group("compass_poi")

	var effective_id: String = npc_id if not npc_id.is_empty() else name
	PlayerGPS.unregister_npc(effective_id)

	queue_free()


## Spawn lootable corpse
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		display_name,
		npc_id,
		10  # Higher level for authority figure
	)

	# Elders carry some gold and potentially valuable items
	corpse.gold = randi_range(50, 150)

	if randf() < 0.3:
		corpse.add_item("health_potion", 1, Enums.ItemQuality.ABOVE_AVERAGE)


## Unregister when removed
func _exit_tree() -> void:
	# Disconnect signal if connected
	if ConversationSystem.scripted_line_shown.is_connected(_on_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_line_shown)

	var effective_id: String = npc_id if not npc_id.is_empty() else name
	PlayerGPS.unregister_npc(effective_id)


## Static factory method to spawn a village elder
static func spawn_village_elder(parent: Node, pos: Vector3, elder_name: String = "Village Elder", id: String = "", faction_id: String = "", custom_sprite: Texture2D = null, h_frames: int = 1, v_frames: int = 1, pixel_size: float = 0.0384) -> VillageElderNPC:
	var elder := VillageElderNPC.new()
	elder.display_name = elder_name

	if id.is_empty():
		elder.npc_id = elder_name.to_lower().replace(" ", "_")
	else:
		elder.npc_id = id

	elder.town_faction_id = faction_id

	# Set sprite if provided
	if custom_sprite:
		elder.sprite_texture = custom_sprite
		elder.sprite_h_frames = h_frames
		elder.sprite_v_frames = v_frames
		elder.sprite_pixel_size = pixel_size

	elder.position = pos
	parent.add_child(elder)

	return elder

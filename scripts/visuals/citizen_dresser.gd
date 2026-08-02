## citizen_dresser.gd - one master GLB, the whole townsfolk population.
##
## Port of RECON's `scripts/visuals/grunt_dresser.gd`, which is the piece that
## makes 3D cheaper than 2D ever was: the dresser runs at RUNTIME in Godot, so
## two masters carry ~55 characters with no per-character export.
##
## FIVE LAWS, all of them bought with a bug:
##
## 1. EVERY VARIANT MESH SHIPS VISIBLE. glTF has no visibility flag - a mesh
##    hidden in Blender either exports visible or does not export at all
##    (docs/design/citizen_review/REVIEW.md). An undressed citizen therefore
##    wears all thirteen pieces at once. The dresser is not a nicety; it is the
##    first thing that must run.
## 2. DUPLICATE THE MATERIAL PER INSTANCE. `uv1_offset` is a MATERIAL property.
##    Share it and every citizen on screen rerolls to the same face together -
##    "a fireteam of octuplets". Do not optimise this away.
## 3. MATCH MATERIALS BY TEXTURE IDENTITY, NOT NAME. RECON's 2026-07-29
##    black-head bug: a face material matched by name slid alone and left the
##    body behind. Whatever a material is called, if it samples the face atlas
##    it is skin and it moves with the face.
## 4. DETERMINISTIC PER-NPC SEED. Grom is the same Grom in every session, in
##    every save, forever. The seed is his npc_id and nothing else - not the
##    spawn order, not the world seed, not the clock.
## 5. WARN WHEN A CAPABILITY DEGRADES, ONCE PER MODEL. Fifteen authored helmet
##    variants sat unused through RECON's playtests because a silent `false`
##    told nobody. A capability that degrades quietly is the same bug again.
class_name CitizenDresser
extends RefCounted

## The face atlas grid, per REVIEW.md "THE ATLAS CONVENTION": 8 columns x 4 rows
## of 32x64 px cells, the top three-quarters face and the bottom quarter a flat
## skin swatch. Resolution-independent - a 512² atlas needs no change here.
const FACE_COLS: int = 8
const FACE_ROWS: int = 4
const CELL_STRIDE: Vector2 = Vector2(0.125, 0.25)

## The merged head+skin material. Matched by texture first (law 3); this list is
## only the fallback for a material carrying no texture at all.
const FACE_MATERIALS: Array[String] = ["face_atlas_mat", "face_atlas", "grunt_face_skin"]

## The textures the exporter left unbound. The GLBs ship with three named
## materials and no albedo on any of them, so a citizen renders as three flat
## colours and `uv1_offset` moves nothing anybody can see. Binding them here is
## what makes the atlas contract mean something on screen; when Caleb paints the
## real atlas it replaces the file at this path and nothing else changes.
const FACE_ATLAS_PATH: String = "res://assets/models/citizens/textures/citizen_face_atlas.png"
const GARB_PALETTE_PATH: String = "res://assets/models/citizens/textures/citizen_garb_palette.png"
const HAIR_PALETTE_PATH: String = "res://assets/models/citizens/textures/citizen_hair_palette.png"

## Mesh-name prefixes the dresser owns. Everything under them is hidden first
## and only the chosen pieces are shown, so a re-dress cannot leave a stray
## sleeve on from the last one.
const GARB_PREFIX: String = "garb_"
const HAIR_PREFIX: String = "hair_"

const VESTS: Array[String] = ["garb_vest_plain", "garb_vest_laced"]
const SLEEVES: Array[String] = ["garb_sleeve_long", "garb_sleeve_rolled", "garb_sleeve_none"]
const PANTS: String = "garb_pants"
const SKIRT: String = "garb_skirt"
const APRON: String = "garb_apron"
const HOOD: String = "garb_hood"

## Only these masters carry a skirt mesh at all, and only they may wear one.
## Asked of a model without one the choice silently becomes trousers, which is
## why the mesh inventory is consulted rather than this list alone.
const SKIRT_MODELS: Array[String] = ["citizen_woman", "citizen_girl"]
const SKIRT_CHANCE: float = 0.65

## Trades that stand at a bench or a counter all day. The apron is the one piece
## of garb the schedule's archetype decides rather than the seed.
const APRON_ARCHETYPES: Array[String] = [
	"shopkeeper", "innkeeper", "smith", "blacksmith", "cook", "merchant",
]

## Every hair style measured against the hood's inner radius and every one fits
## (REVIEW.md, "Hood compatibility holds": worst crown 0.136 m against 0.204 m).
## So hair is worn UNDER a hood rather than swapped for it. Whether a bun under
## a hood reads right to the eye is still Caleb's call.
const HOOD_FITS_HAIR: bool = true
const HOOD_CHANCE: float = 0.18

## Model id -> true, so a model missing a whole category says so once and not
## once per citizen.
static var _warned: Dictionary = {}

## The garb and hair palettes carry no per-instance state, so they are bound to
## one shared material each for the whole game rather than duplicated per body.
## The FACE material is duplicated per body and always will be - that is law 2.
static var _shared_garb: BaseMaterial3D = null
static var _shared_hair: BaseMaterial3D = null


## Dress one citizen. [param root] is the instanced GLB, [param model_id] the
## master it came from, [param npc_id] the seed, [param archetype] the schedule
## trade (may be empty).
##
## Returns the loadout actually applied - never what was asked for. A piece the
## model does not carry comes back absent, so nothing downstream can claim a
## citizen is wearing something that is not on him.
static func dress(root: Node3D, model_id: String, npc_id: String,
		archetype: String = "", opts: Dictionary = {}) -> Dictionary:
	if root == null:
		return {}

	var meshes: Array[MeshInstance3D] = all_meshes(root)
	if meshes.is_empty():
		_warn_once(model_id, "no meshes at all - nothing to dress")
		return {}

	var present: Dictionary = {}
	for mi: MeshInstance3D in meshes:
		present[String(mi.name)] = true

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(npc_id)

	var out: Dictionary = {}

	# Every piece off first. The GLB ships them all on (law 1), and a re-dress
	# must not leave the previous outfit underneath the new one.
	_set_visible_by_prefix(meshes, GARB_PREFIX, false)
	_set_visible_by_prefix(meshes, HAIR_PREFIX, false)

	# --- 1. VEST: exactly one, always ---
	var vest: String = _pick(VESTS, present, rng)
	if vest.is_empty():
		_warn_once(model_id, "carries no vest mesh - this citizen goes bare-chested")
	else:
		_set_visible_by_name(meshes, vest, true)
		out["vest"] = vest

	# --- 2. LEGS: pants XOR skirt, and a skirt only where there is one ---
	var wants_skirt: bool = SKIRT_MODELS.has(model_id) and rng.randf() < SKIRT_CHANCE
	var legs: String = SKIRT if (wants_skirt and present.has(SKIRT)) else PANTS
	if not present.has(legs):
		_warn_once(model_id, "carries neither '%s' nor '%s'" % [PANTS, SKIRT])
	else:
		_set_visible_by_name(meshes, legs, true)
		out["legs"] = legs

	# --- 3. SLEEVES: exactly one style ---
	var sleeve: String = _pick(SLEEVES, present, rng)
	if sleeve.is_empty():
		_warn_once(model_id, "carries no sleeve mesh")
	else:
		_set_visible_by_name(meshes, sleeve, true)
		out["sleeve"] = sleeve

	# --- 4. HAIR, and a hood over it ---
	var hair_styles: Array[String] = []
	for name: String in present.keys():
		if name.begins_with(HAIR_PREFIX):
			hair_styles.append(name)
	# Sorted, because the seed is a promise and dictionary order is not. Draw
	# from an unsorted list and a citizen's hair changes with the mesh order in
	# a re-export, which is the one thing law 4 exists to forbid.
	hair_styles.sort()
	if hair_styles.is_empty():
		_warn_once(model_id, "carries no hair mesh - every citizen on it is bald")
	else:
		var hair: String = hair_styles[rng.randi() % hair_styles.size()]
		_set_visible_by_name(meshes, hair, true)
		out["hair"] = hair

	var wants_hood: bool = bool(opts.get("hood", rng.randf() < HOOD_CHANCE))
	if wants_hood and present.has(HOOD):
		_set_visible_by_name(meshes, HOOD, true)
		out["hood"] = HOOD
		if not HOOD_FITS_HAIR and out.has("hair"):
			_set_visible_by_name(meshes, String(out["hair"]), false)
			out.erase("hair")

	# --- 5. APRON: the trade decides, not the seed ---
	var wants_apron: bool = bool(opts.get("apron",
		APRON_ARCHETYPES.has(archetype.to_lower())))
	if wants_apron:
		if present.has(APRON):
			_set_visible_by_name(meshes, APRON, true)
			out["apron"] = APRON
		else:
			_warn_once(model_id, "carries no '%s' - its tradesmen work in their shirts" % APRON)

	# --- 6. FACE + SKIN: one number, one material offset, they move together ---
	out["face"] = int(opts.get("face", rng.randi() % (FACE_COLS * FACE_ROWS)))
	_bind_palettes(meshes)
	out["face_offset"] = _set_face(meshes, int(out["face"]), model_id)

	return out


## The seed a citizen is dressed from. Public because the gates assert on it and
## because the same id must produce the same person in any process, forever.
static func seed_for(npc_id: String) -> int:
	return hash("citizen_dresser|" + npc_id)


## The atlas offset for a face index. Public so a test can compute the expected
## value without duplicating the arithmetic it is checking.
static func face_offset(index: int) -> Vector3:
	var cells: int = FACE_COLS * FACE_ROWS
	var i: int = posmod(index, cells)
	var col: int = i % FACE_COLS
	var row: int = (i / FACE_COLS) % FACE_ROWS
	return Vector3(col * CELL_STRIDE.x, row * CELL_STRIDE.y, 0.0)


## ============================================================================
## THE MATERIAL WORK
## ============================================================================

## Slide every surface that rides the face atlas to the same cell. Head, neck,
## hands and feet are all in that cell, so face and skin tone are the same
## pixels and cannot mismatch.
static func _set_face(meshes: Array[MeshInstance3D], index: int, model_id: String) -> Vector3:
	var offset: Vector3 = face_offset(index)
	var slid: int = 0
	var stranded: Array[String] = []

	for mi: MeshInstance3D in meshes:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var material: Material = mi.get_active_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			var base := material as BaseMaterial3D
			if base == null:
				continue
			if not _rides_face_atlas(base):
				if _is_face_material(base):
					stranded.append(base.resource_name)
				continue
			# DUPLICATE, or every citizen sharing this material rerolls with him.
			var mine := base.duplicate() as BaseMaterial3D
			mine.uv1_offset = offset
			mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.set_surface_override_material(surface, mine)
			slid += 1

	if not stranded.is_empty():
		_warn_once(model_id, ("%d skin material(s) do NOT sample the face atlas and cannot follow "
			+ "the face: %s. That body's skin tone will not match the head it was dealt.")
			% [stranded.size(), ", ".join(stranded)])
	elif slid == 0:
		_warn_once(model_id, "no atlas surface found to slide - every citizen on it keeps one face")

	return offset


## Does this material sample the face atlas? Texture identity, not resource
## name: the name is what drifts, and the pixels are what decide the skin.
static func _rides_face_atlas(material: BaseMaterial3D) -> bool:
	var texture: Texture2D = material.albedo_texture
	if texture != null:
		return texture.resource_path.contains("face_atlas")
	# Untextured: fall back to the authored name. This is the state the citizen
	# GLBs ship in, which is why _bind_palettes runs before this does.
	return _is_face_material(material)


static func _is_face_material(material: Material) -> bool:
	for prefix: String in FACE_MATERIALS:
		if material.resource_name.begins_with(prefix):
			return true
	return false


## Bind the three palettes the glTF export left off. Face gets its atlas so the
## per-instance offset has pixels to move; garb and hair share one material each
## because neither carries per-instance state in v1.
static func _bind_palettes(meshes: Array[MeshInstance3D]) -> void:
	for mi: MeshInstance3D in meshes:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var material: Material = mi.get_active_material(surface)
			if material == null:
				continue
			var base := material as BaseMaterial3D
			if base == null:
				continue
			var name: String = base.resource_name

			if name.begins_with("garb"):
				mi.set_surface_override_material(surface, _palette(base, GARB_PALETTE_PATH, true))
			elif name.begins_with("hair"):
				mi.set_surface_override_material(surface, _palette(base, HAIR_PALETTE_PATH, false))
			elif base.albedo_texture == null and _is_face_material(base):
				# Per-instance: _set_face duplicates again on top of this, which
				# is deliberate - the atlas must never be shared.
				var face_texture: Texture2D = _load_texture(FACE_ATLAS_PATH)
				if face_texture != null:
					var mine := base.duplicate() as BaseMaterial3D
					mine.albedo_texture = face_texture
					mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					mi.set_surface_override_material(surface, mine)


static func _palette(source: BaseMaterial3D, path: String, is_garb: bool) -> BaseMaterial3D:
	var cached: BaseMaterial3D = _shared_garb if is_garb else _shared_hair
	if cached != null:
		return cached
	if source.albedo_texture != null:
		return source
	var texture: Texture2D = _load_texture(path)
	if texture == null:
		return source
	var made := source.duplicate() as BaseMaterial3D
	made.albedo_texture = texture
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if is_garb:
		_shared_garb = made
	else:
		_shared_hair = made
	return made


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## ============================================================================
## MESH PLUMBING
## ============================================================================

static func _pick(pool: Array[String], present: Dictionary, rng: RandomNumberGenerator) -> String:
	var available: Array[String] = []
	for name: String in pool:
		if present.has(name):
			available.append(name)
	if available.is_empty():
		return ""
	return available[rng.randi() % available.size()]


static func _set_visible_by_name(meshes: Array[MeshInstance3D], needle: String, on: bool) -> void:
	for mi: MeshInstance3D in meshes:
		if String(mi.name) == needle:
			mi.visible = on


static func _set_visible_by_prefix(meshes: Array[MeshInstance3D], prefix: String, on: bool) -> void:
	for mi: MeshInstance3D in meshes:
		if String(mi.name).begins_with(prefix):
			mi.visible = on


## Every MeshInstance3D under a root, in a stable order.
static func all_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.push_back(child)
		if node is MeshInstance3D:
			out.append(node as MeshInstance3D)
	return out


## The mesh names currently drawn, sorted. What a citizen is actually wearing,
## measured off the tree rather than read off the loadout he was handed.
static func visible_meshes(root: Node) -> Array[String]:
	var out: Array[String] = []
	for mi: MeshInstance3D in all_meshes(root):
		if mi.visible:
			out.append(String(mi.name))
	out.sort()
	return out


static func _warn_once(model_id: String, message: String) -> void:
	var key: String = model_id + "|" + message
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("[DRESSER] %s %s" % [model_id, message])


## The gates re-dress the same model many times on purpose; without this the
## warn-once ledger would make the second assertion pass for the wrong reason.
static func reset_warnings() -> void:
	_warned.clear()

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

## The garb atlas grid, per EQ_TECHNIQUE sec 3.B and the GARB ATLAS CONTRACT in
## tools/citizens/citizen_common.py: 512², 4 columns x 4 rows of 128 px PAGES,
## four 64 px zones per page. Page 0 is the bottom-left, so page index maps to
## uv1_offset (col * 0.25, prow * 0.25) with prow counting UP - the same
## arithmetic garb_page_uv_offset() does on the Blender side. The two must
## agree; if they ever disagree, citizens wear the page nobody painted.
## Resolution-independent - a 1024² atlas needs no change here.
const GARB_COLS: int = 4
const GARB_ROWS: int = 4
const GARB_STRIDE: Vector2 = Vector2(0.25, 0.25)

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

## There is exactly ONE vest and there always will be. `garb_vest_laced` was
## deleted at the mesh level - against the sky it was the plain vest, so it was
## 68 tris buying nothing (EQ_TECHNIQUE Rule 3). Laces are a painted page now.
const VESTS: Array[String] = ["garb_vest_plain"]
const SLEEVES: Array[String] = ["garb_sleeve_long", "garb_sleeve_rolled", "garb_sleeve_none"]
const PANTS: String = "garb_pants"
const SKIRT: String = "garb_skirt"
const APRON: String = "garb_apron"
const HOOD: String = "garb_hood"

## The robe REPLACES vest and legs rather than layering over them - it is a
## single shoulder-to-shin tube, and the one silhouette paint cannot fake.
const ROBE: String = "garb_robe"

## Trades that wear a robe instead of a vest and trousers. Everyone else can
## have their cassock painted on; these are the outlines a page cannot make.
const ROBE_ARCHETYPES: Array[String] = ["priest", "acolyte", "mage", "revenant"]

## Which garb page a trade wears. This is EQEmu's `npc_types.texture` field
## restated in GDScript (EQ_TECHNIQUE sec 1.5): the archetype decides the PAGE,
## the seed decides the TINT. A smith's page is not random; his colour is.
##
## An archetype not named here draws a page from COMMONER_PAGES on its seed, so
## an unlisted trade is a varied townsman rather than a clone of page 0.
const ARCHETYPE_PAGE: Dictionary = {
	"townsfolk": 0,
	"laborer": 1, "farmer": 1, "shepherd": 1, "fisherman": 1, "sailor": 1, "hunter": 1,
	"shopkeeper": 2, "innkeeper": 2, "barmaid": 2, "merchant": 2, "official": 2,
	"guard": 3, "night_watch": 3,
	"priest": 8, "acolyte": 8,
	"healer": 9,
	"revenant": 10,
	"scholar": 11,
	"beggar": 12, "crook": 12,
	"bard": 13,
	"mage": 14, "noble": 14,
}

## Pages 8-10 are the three priesthoods, and a priest's page is his GOD's, not
## his trade's - the schedule record only says "priest". The deity is read off
## the npc_id, which is where the world actually records it
## (`priest_chronos_dalhurst`, `acolyte_morthane_dalhurst`).
const DEITY_PAGE: Dictionary = {"chronos": 8, "gaela": 9, "morthane": 10}

## The seeded fallback range: page 0 plus every neutral variant. Deliberately
## NOT pages 1-3 or 8-10, because those read as a trade and an unlisted NPC has
## not claimed one.
const COMMONER_PAGES: Array[int] = [0, 4, 5, 6, 7, 11, 12, 13, 15]

## Per-instance dye, multiplied over the page (`albedo_color`). This is EQEmu's
## `npc_types_tint`, and it is where N painted pages become N x 14 looks.
##
## Every one is a MULTIPLIER, so they are all near-white and mildly hued: the
## pages are already painted desaturated and mid-value precisely so a tint
## lands where intended. A saturated dye here would crush the painted light out
## of the page and put a neon townsman in a world of earth and stone.
const DYES: Array[Color] = [
	Color(1.00, 0.98, 0.94),  # undyed
	Color(1.00, 0.80, 0.76),  # madder red
	Color(1.02, 0.96, 0.74),  # weld yellow
	Color(0.78, 0.86, 1.00),  # woad blue
	Color(0.92, 0.82, 0.70),  # walnut
	Color(0.84, 0.94, 0.78),  # lichen
	Color(0.86, 0.86, 0.88),  # iron grey
	Color(1.00, 0.90, 0.72),  # onion gold
	Color(0.72, 0.70, 0.72),  # oak black
	Color(0.96, 0.88, 0.76),  # bark tan
	Color(0.90, 0.84, 0.94),  # heather
	Color(0.82, 0.90, 0.76),  # moss
	Color(0.98, 0.84, 0.72),  # rust
	Color(0.80, 0.84, 0.90),  # slate
]

## Garb is dyed in TWO slots, not one. EQ tinted per slot (sec 1.5), and one
## material means a citizen's shirt and trousers always tint together, which is
## the least convincing thing a crowd can do.
##
## MEASURED before adopting, because the tri-budget law says draw calls are what
## matter and this deserved a number: the split costs ZERO extra draw calls. The
## premise that it costs one was wrong - vest, pants, sleeves and apron are
## already separate MeshInstance3Ds and therefore already separate surfaces, so
## giving the upper and lower meshes different materials changes no surface
## count at all. It costs one extra duplicated material per citizen and nothing
## else. check_character_visual records the measurement.
const GARB_LOWER: Array[String] = ["garb_pants", "garb_skirt", "garb_apron"]

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

## The hair palette carries no per-instance state yet, so it is bound to one
## shared material for the whole game. THE GARB MATERIAL IS NOT - it was, and
## that is the bug this file was rewritten to kill: `_shared_garb` was one
## BaseMaterial3D for the entire game, so every citizen in Broken Provinces wore
## the same four colours and no page or dye could ever move independently. Law 2
## applies to garb exactly as it applies to the face, and for the same reason.
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

	# The trade an NPC keeps. Passed in where the caller knows it; otherwise read
	# off the schedule record, which is where the world actually records it, so
	# every citizen gets his archetype's page without a call site being touched.
	var trade: String = archetype.to_lower()
	if trade.is_empty():
		trade = String(NPCScheduler.archetype_of(npc_id)).to_lower()

	# --- 1-2. TORSO AND LEGS: a robe, or a vest and one leg garment ---
	# The robe is a single shoulder-to-shin tube and REPLACES both, so it is
	# decided before either of them.
	var wants_robe: bool = bool(opts.get("robe", ROBE_ARCHETYPES.has(trade)))
	if wants_robe and not present.has(ROBE):
		_warn_once(model_id, "carries no '%s' - its priests and mages work in shirtsleeves" % ROBE)
		wants_robe = false

	if wants_robe:
		_set_visible_by_name(meshes, ROBE, true)
		out["robe"] = ROBE
	else:
		var vest: String = _pick(VESTS, present, rng)
		if vest.is_empty():
			_warn_once(model_id, "carries no vest mesh - this citizen goes bare-chested")
		else:
			_set_visible_by_name(meshes, vest, true)
			out["vest"] = vest

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
	var wants_apron: bool = bool(opts.get("apron", APRON_ARCHETYPES.has(trade)))
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

	# --- 7. THE CLOTHES' COLOUR: archetype picks the page, seed picks the dye ---
	# Drawn from its OWN seeded stream rather than the outfit's, so an `opts`
	# override upstream (a forced face, a forced hood) cannot shift a citizen's
	# colour. His dye is his and does not move.
	var garb_rng := RandomNumberGenerator.new()
	garb_rng.seed = garb_seed_for(npc_id)

	out["garb_page"] = int(opts.get("garb_page", page_for(trade, npc_id)))
	out["garb_offset"] = garb_page_offset(int(out["garb_page"]))
	var upper: Color = DYES[garb_rng.randi() % DYES.size()]
	var lower: Color = DYES[garb_rng.randi() % DYES.size()]
	out["garb_tint"] = upper
	out["garb_tint_lower"] = lower
	_set_garb(meshes, int(out["garb_page"]), upper, lower, model_id)

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


## The seed a citizen's CLOTHES are coloured from. A separate stream from the
## outfit seed on purpose: an opts override that changes how many numbers the
## outfit draws must not repaint the man.
static func garb_seed_for(npc_id: String) -> int:
	return hash("citizen_dresser_garb|" + npc_id)


## The atlas offset for a garb page, mirroring face_offset(). Public so a gate
## can compute the expectation without duplicating the arithmetic it is
## checking. Page 0 is the bottom-left and the page row counts UP, which is the
## same convention garb_page_uv_offset() paints to in citizen_common.py.
static func garb_page_offset(index: int) -> Vector3:
	var pages: int = GARB_COLS * GARB_ROWS
	var i: int = posmod(index, pages)
	var col: int = i % GARB_COLS
	var row: int = (i / GARB_COLS) % GARB_ROWS
	return Vector3(col * GARB_STRIDE.x, row * GARB_STRIDE.y, 0.0)


## The page a trade wears. Public because it is a design statement, not an
## implementation detail: a guard is page 3 in every town, forever.
##
## A priest's page is his GOD's - the schedule record only ever says "priest",
## and the deity is recorded in the npc_id, which is the only place the world
## writes it down.
static func page_for(archetype: String, npc_id: String) -> int:
	var trade: String = archetype.to_lower()
	if trade == "priest" or trade == "acolyte":
		var lowered: String = npc_id.to_lower()
		for deity: String in DEITY_PAGE.keys():
			if lowered.contains(deity):
				return int(DEITY_PAGE[deity])
	if ARCHETYPE_PAGE.has(trade):
		return int(ARCHETYPE_PAGE[trade])
	# Unlisted: a varied townsman, not a clone of page 0.
	var rng := RandomNumberGenerator.new()
	rng.seed = garb_seed_for(npc_id)
	return COMMONER_PAGES[rng.randi() % COMMONER_PAGES.size()]


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


## Slide every garb surface to its page and dye it. Two materials per citizen,
## upper and lower, both duplicated per instance (law 2) - share them and the
## whole town changes clothes together, which is the state this file shipped in.
##
## The two materials are built lazily and reused across the meshes in each slot,
## so a citizen carries exactly two garb materials no matter how many garments
## he wears, and every upper piece is guaranteed the same dye as every other.
static func _set_garb(meshes: Array[MeshInstance3D], page: int, upper: Color,
		lower: Color, model_id: String) -> Vector3:
	var offset: Vector3 = garb_page_offset(page)
	var made: Dictionary = {}
	var slid: int = 0

	for mi: MeshInstance3D in meshes:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var material: Material = mi.get_active_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			var base := material as BaseMaterial3D
			if base == null or not _rides_garb_atlas(base):
				continue
			var slot: String = "lower" if GARB_LOWER.has(String(mi.name)) else "upper"
			if not made.has(slot):
				var mine := base.duplicate() as BaseMaterial3D
				mine.uv1_offset = offset
				mine.albedo_color = lower if slot == "lower" else upper
				mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				made[slot] = mine
			mi.set_surface_override_material(surface, made[slot] as BaseMaterial3D)
			slid += 1

	if slid == 0:
		_warn_once(model_id, "no garb surface found to slide - every citizen on it wears one page")
	return offset


## Does this material sample the garb atlas? Texture identity first, exactly as
## the face is matched, and for the same reason (law 3): the name drifts and the
## pixels decide.
static func _rides_garb_atlas(material: BaseMaterial3D) -> bool:
	var texture: Texture2D = material.albedo_texture
	if texture != null:
		return texture.resource_path.contains("garb")
	return material.resource_name.begins_with("garb")


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


## Bind the three palettes the glTF export left off, so the per-instance offsets
## have pixels to move. Garb is bound but NOT shared - `_set_garb` duplicates it
## per citizen straight afterwards, the same two-step the face already used.
static func _bind_palettes(meshes: Array[MeshInstance3D]) -> void:
	if _load_texture(GARB_PALETTE_PATH) == null:
		# THE CAPABILITY-DEGRADATION LAW. Sixteen painted pages and fourteen dyes
		# collapse to one flat colour with no atlas bound, and a citizen silently
		# wearing page 0 forever is the fifteen-unused-helmets bug again.
		_warn_once("garb_atlas", ("no garb atlas at %s - every citizen wears one flat "
			+ "colour and neither page nor dye can be seen") % GARB_PALETTE_PATH)

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
				mi.set_surface_override_material(surface, _garb_bound(base))
			elif name.begins_with("hair"):
				mi.set_surface_override_material(surface, _palette(base, HAIR_PALETTE_PATH))
			elif base.albedo_texture == null and _is_face_material(base):
				# Per-instance: _set_face duplicates again on top of this, which
				# is deliberate - the atlas must never be shared.
				var face_texture: Texture2D = _load_texture(FACE_ATLAS_PATH)
				if face_texture != null:
					var mine := base.duplicate() as BaseMaterial3D
					mine.albedo_texture = face_texture
					mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					mi.set_surface_override_material(surface, mine)


## Give the garb material its atlas. Per-instance, never cached: `_set_garb`
## duplicates on top of this to apply the page and the dye, and a shared
## material underneath would be one more chance for two citizens to end up
## holding the same one.
static func _garb_bound(source: BaseMaterial3D) -> BaseMaterial3D:
	if source.albedo_texture != null:
		return source
	var texture: Texture2D = _load_texture(GARB_PALETTE_PATH)
	if texture == null:
		return source
	var made := source.duplicate() as BaseMaterial3D
	made.albedo_texture = texture
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return made


## Hair still shares one material for the whole game. It carries no per-instance
## state yet; when hair colour becomes a roll it must follow garb, not stay here.
static func _palette(source: BaseMaterial3D, path: String) -> BaseMaterial3D:
	if _shared_hair != null:
		return _shared_hair
	if source.albedo_texture != null:
		return source
	var texture: Texture2D = _load_texture(path)
	if texture == null:
		return source
	var made := source.duplicate() as BaseMaterial3D
	made.albedo_texture = texture
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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

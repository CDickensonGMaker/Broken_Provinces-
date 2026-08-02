## world_lexicon.gd - Single source of truth for all world content
## Used by BountyManager and NPC dialogue for consistent world references
class_name WorldLexicon
extends RefCounted

# =============================================================================
# REGIONS - Tied to actual world map locations with specific directions
# =============================================================================

## Region data with creatures that spawn there and specific directions to real locations
const REGIONS := {
	"southern_swamps": {
		"name": "Southern Swamps",
		"creatures": ["giant_rat", "giant_spider", "drowned_dead"],
		"directions": [
			"Go south from Elder Moor - the swamps start after two cells",
			"Head toward Aberdeen, you'll find them in the marshes along the way",
			"The swamps between Elder Moor and Aberdeen are infested"
		]
	},
	"dalhurst_plains": {
		"name": "Dalhurst Coast",
		"creatures": ["wolf", "human_bandit", "dire_wolf"],
		"directions": [
			"Travel west toward Dalhurst - the plains start after three cells",
			"Check the roads between Elder Moor and Dalhurst",
			"The coastal plains near Dalhurst Bay are hunting grounds"
		]
	},
	"whaeler_hills": {
		"name": "Whaeler's Canyon",
		"creatures": ["goblin_soldier", "goblin_archer", "wolf", "ogre"],
		"directions": [
			"Head south to Aberdeen, then east toward Whaeler's Drake",
			"The hills east of Aberdeen, on the way to Whaeler's Drake",
			"Travel the eastern path past Aberdeen - takes about five cells"
		]
	},
	"undead_lands": {
		"name": "Undead Lands",
		"creatures": ["skeleton_warrior", "skeleton_shade", "drowned_dead", "cultist"],
		"directions": [
			"Far northwest of Elder Moor lies cursed territory",
			"Beyond the forests northwest of Elder Moor lies cursed territory",
			"Travel northwest from Elder Moor - dangerous territory"
		]
	},
	"mountain_pass": {
		"name": "Mountain Pass",
		"creatures": ["goblin_soldier", "goblin_leader", "troll", "ogre"],
		"directions": [
			"The Keerzhar Pass - go east to Whaeler's Drake, then north through the mountains",
			"Take the eastern route to the mountain pass - long journey via Aberdeen",
			"Mountains block the direct path north - must go east through Whaeler's first"
		]
	},
	"elven_woods": {
		"name": "Elven Lands",
		"creatures": ["wolf", "dire_wolf", "tree_ent"],
		"directions": [
			"Far east, past Whaeler's Drake - the Elven Woods",
			"Travel east through Whaeler's Canyon to reach the elven territory",
			"The forests east of Whaeler's Drake belong to the elves"
		]
	}
}

# =============================================================================
# CREATURES
# =============================================================================

## Creature display names and IDs (must match enemy .tres file IDs)
const CREATURES := {
	"wolf": {"display": "Wolves", "singular": "wolf", "tier": 1},
	"dire_wolf": {"display": "Dire Wolves", "singular": "dire wolf", "tier": 2},
	"deer": {"display": "Deer", "singular": "deer", "tier": 1},
	"boar": {"display": "Wild Boars", "singular": "wild boar", "tier": 1},
	"giant_rat": {"display": "Giant Rats", "singular": "giant rat", "tier": 1},
	"giant_spider": {"display": "Giant Spiders", "singular": "giant spider", "tier": 1},
	"goblin_soldier": {"display": "Goblin Soldiers", "singular": "goblin", "tier": 1},
	"goblin_archer": {"display": "Goblin Archers", "singular": "goblin archer", "tier": 1},
	"goblin_leader": {"display": "Goblin Leaders", "singular": "goblin leader", "tier": 2},
	"human_bandit": {"display": "Bandits", "singular": "bandit", "tier": 1},
	"drowned_dead": {"display": "Drowned Dead", "singular": "drowned corpse", "tier": 2},
	"skeleton_warrior": {"display": "Skeleton Warriors", "singular": "skeleton", "tier": 2},
	"skeleton_shade": {"display": "Skeleton Shades", "singular": "shade", "tier": 3},
	"ogre": {"display": "Ogres", "singular": "ogre", "tier": 3},
	"troll": {"display": "Trolls", "singular": "troll", "tier": 3},
	"tree_ent": {"display": "Tree Ents", "singular": "ent", "tier": 3},
	"cultist": {"display": "Cultists", "singular": "cultist", "tier": 2},
	"cult_leader": {"display": "Cult Leaders", "singular": "cult leader", "tier": 3},
	"abomination": {"display": "Abominations", "singular": "abomination", "tier": 4},
	"vampire_lord": {"display": "Vampire Lords", "singular": "vampire", "tier": 4},
	"wyvern": {"display": "Wyverns", "singular": "wyvern", "tier": 4},
	"basilisk": {"display": "Basilisks", "singular": "basilisk", "tier": 4},
	"pirate_seadog": {"display": "Pirate Seadogs", "singular": "pirate", "tier": 2},
	"pirate_captain": {"display": "Pirate Captains", "singular": "pirate captain", "tier": 3},
	"ghost_pirate_seadog": {"display": "Ghost Pirates", "singular": "ghost pirate", "tier": 3},
	"ghost_pirate_captain": {"display": "Ghost Captains", "singular": "ghost captain", "tier": 4}
}

# =============================================================================
# SETTLEMENTS - Matches actual world_data.gd locations
# =============================================================================

## Settlement data with region for bounty generation
const SETTLEMENTS := {
	"village_elder_moor": {
		"name": "Elder Moor",
		"region": "southern_swamps",
		"nearby_regions": ["southern_swamps", "dalhurst_plains"]
	},
	"city_dalhurst": {
		"name": "Dalhurst",
		"region": "dalhurst_plains",
		"nearby_regions": ["dalhurst_plains", "southern_swamps"]
	},
	"town_larton": {
		"name": "Larton",
		"region": "dalhurst_plains",
		"nearby_regions": ["dalhurst_plains", "southern_swamps"]
	},
	"town_aberdeen": {
		"name": "Aberdeen",
		"region": "southern_swamps",
		"nearby_regions": ["southern_swamps", "whaeler_hills"]
	},
	"town_east_hollow": {
		"name": "East Hollow",
		"region": "southern_swamps",
		"nearby_regions": ["southern_swamps", "whaeler_hills"]
	},
	"town_whalers_abyss": {
		"name": "Whalers Abyss",
		"region": "whaeler_hills",
		"nearby_regions": ["whaeler_hills", "mountain_pass", "elven_woods"]
	},
	"city_rotherhine": {
		"name": "Rotherhine",
		"region": "mountain_pass",
		"nearby_regions": ["mountain_pass"]
	},
	"capital_falkenhafen": {
		"name": "Falkenhafen",
		"region": "mountain_pass",
		"nearby_regions": ["mountain_pass"]
	},
	"village_elven_outpost": {
		"name": "Elven Outpost",
		"region": "elven_woods",
		"nearby_regions": ["elven_woods", "whaeler_hills"]
	}
}

# =============================================================================
# NPC NAMES
# =============================================================================

## Names for randomly generated NPCs (75 male, 75 female)
## NOTE: "Aleric" is RESERVED for story NPC (Aleric Vale in Dalhurst)
## "Aldric" removed - it is the missing king's name and belongs to nobody else
const MALE_NAMES := [
	# Original names (24 - Aldric removed; see above)
	"Borin", "Cedric", "Dunstan", "Edmund", "Gareth", "Harald", "Osric",
	"Godwin", "Leofric", "Wulfric", "Beorn", "Cynric", "Eadric", "Aelfric", "Thurstan",
	"Grimwald", "Roderick", "Sigurd", "Torsten", "Ulrich", "Viktor", "Werner", "Yorick",
	"Magnus",
	# New names - Norse/Germanic inspired (15)
	"Arnulf", "Baldric", "Bjorn", "Brandr", "Egil", "Eirik", "Fenris", "Gunnar",
	"Haldor", "Halvard", "Hrothgar", "Ivar", "Knut", "Leif", "Sten",
	# New names - Anglo-Saxon inspired (12)
	"Aethelstan", "Beowulf", "Cuthbert", "Edric", "Ealdred", "Oswine", "Penda",
	"Sigebert", "Swithun", "Wilfrid", "Wulfstan", "Wystan",
	# New names - Celtic/Gaelic inspired (10)
	"Brennan", "Cormac", "Dermot", "Diarmuid", "Fergus", "Fionn", "Lorcan",
	"Niall", "Oisin", "Ronan",
	# New names - General medieval fantasy (13)
	"Alaric", "Bertram", "Corwin", "Darian", "Emeric", "Florian", "Gideon",
	"Kelwin", "Lothar", "Marius", "Severin", "Theron", "Vance",
	# Expansion 2026-07 - Grim/Dark Age flavor (28)
	"Ansgar", "Bardolph", "Caddock", "Drogo", "Eberhard", "Falk", "Gerulf",
	"Hadmar", "Isenbard", "Jorund", "Kaspar", "Ludolf", "Meinhard", "Norbert",
	"Odo", "Percival", "Quentin", "Radulf", "Sunward", "Tancred", "Ulfgar",
	"Volkmar", "Waldemar", "Ansel", "Bram", "Colm", "Duncan", "Erwin",
	# Expansion 2026-07 - Common folk / laborer names (22)
	"Tam", "Ned", "Wat", "Hob", "Jack", "Piers", "Rolf", "Simkin", "Toby",
	"Aldous", "Bennet", "Clem", "Dob", "Gil", "Hamo", "Jenkin", "Lambert",
	"Miles", "Ranulf", "Symond", "Tobias", "Walter"
]

const FEMALE_NAMES := [
	# Original 25 names
	"Elara", "Mira", "Gwendolyn", "Isolde", "Rowena", "Thalia", "Wren", "Astrid",
	"Brunhild", "Cordelia", "Dagny", "Edith", "Freya", "Gunhild", "Helga", "Ingrid",
	"Sigrid", "Thyra", "Valdis", "Ylva", "Adelheid", "Britta", "Carina", "Dagmar",
	"Solveig",
	# New names - Norse/Germanic inspired
	"Agna", "Asta", "Bodil", "Eerika", "Embla", "Freja", "Gerda", "Greta",
	"Gudrun", "Hilda", "Inga", "Liv", "Ragna", "Runa", "Sif", "Sigyn",
	"Svea", "Thora", "Torhild", "Ulfhild",
	# New names - Anglo-Saxon inspired
	"Aelwen", "Alditha", "Cwenburh", "Eadburga", "Elfgifu", "Ethelflaed", "Godgifu",
	"Hildegyth", "Leofwynn", "Mildred", "Osburgh", "Sunniva", "Wynflaed",
	# New names - Celtic/Gaelic inspired
	"Aisling", "Branwen", "Catriona", "Deirdre", "Enid", "Fionnuala", "Grainne",
	"Maeve", "Niamh", "Orlaith", "Rhiannon", "Saoirse", "Siobhan",
	# New names - General medieval fantasy
	"Alys", "Beatrix", "Clarice", "Drusilla", "Elowen", "Jocelyn", "Margery",
	"Rosalind", "Seraphina", "Vivienne", "Yseult",
	# Expansion 2026-07 - Grim/Dark Age flavor (26)
	"Adela", "Bertrada", "Cunigunde", "Dietlinde", "Ermengard", "Frideswide",
	"Gisela", "Hedwig", "Irmgard", "Jutta", "Kunissa", "Lioba", "Mechtild",
	"Notburga", "Oda", "Petronilla", "Reinhild", "Swanhild", "Theodelinda",
	"Uta", "Walburga", "Ysolt", "Amalia", "Brigid", "Ciara", "Demelza",
	# Expansion 2026-07 - Common folk names (20)
	"Nell", "Tilda", "Mabel", "Joan", "Agnes", "Bess", "Cissy", "Dot",
	"Emma", "Fern", "Gytha", "Hild", "Ida", "Kate", "Lark", "Meg",
	"Peg", "Rose", "Sal", "Wynn"
]

## Tracks used names per zone to prevent duplicates
## Format: { "zone_id": { "male": ["Borin", "Merric"], "female": ["Rowena"] } }
static var _used_names_by_zone: Dictionary = {}

## How many zone-unique names have been handed out in each zone this session.
##
## RULING LW-1: the ambient crowd draws its names with a seeded slot generator,
## but it draws them out of whatever is *left* in the pool. Every hand-placed
## NPC ahead of them takes a name first - most of them throw it away a line
## later and set their own - so an unseeded draw there shifted the pool under
## the ambient slots and the same seed produced a different crowd. Naming is
## therefore a sequence: draw n in a zone is the same draw in every session.
## Cleared with the zone's used-name list.
static var _zone_draw_count: Dictionary = {}

const SURNAMES := [
	"Ironhand", "Blackwood", "Stonehelm", "Ashford", "Brightwater", "Coldstream",
	"Darkhollow", "Frostborn", "Goldsmith", "Hawkwind", "Longstride", "Moorwalker",
	"Northwind", "Oakenshield", "Ravencrest", "Silvermane", "Thornwood", "Whitehall",
	# Expansion 2026-07 - nature/place surnames (24)
	"Aldermoor", "Birchbank", "Cindermill", "Dampmarsh", "Eastbrook", "Fallowfield",
	"Greenbriar", "Hollowell", "Kettleford", "Larkspur", "Mirefoot", "Nettlebed",
	"Oxbridge", "Pinewatch", "Quickwater", "Reedmere", "Saltmarsh", "Tanglewood",
	"Underhill", "Vexley", "Wanderford", "Yarrow", "Fernbrake", "Gorsefield",
	# Expansion 2026-07 - trade/occupation surnames (18)
	"Cooper", "Fletcher", "Mason", "Tanner", "Wheeler", "Thatcher", "Sawyer",
	"Chandler", "Carter", "Webber", "Fowler", "Baker", "Miller", "Smith",
	"Turner", "Ward", "Draper", "Kellner",
	# Expansion 2026-07 - grim/dark flavor surnames (18)
	"Ashgrave", "Blackmarsh", "Crowfeather", "Dreadmoor", "Emberfall", "Gallowglass",
	"Grimsbane", "Hollowbone", "Ironmarch", "Mourncastle", "Nightfen", "Palegate",
	"Rookwood", "Sorrowfield", "Thistledown", "Veilwater", "Wolfsbane", "Wrathmere"
]

## Epithets for memorable common folk ("Old Tam", "Meg One-Eye").
## Applied instead of a surname for a small fraction of generated NPCs.
const EPITHETS_PREFIX := [
	"Old", "Young", "Big", "Little", "Mad", "Quiet", "Red", "Black", "Grey", "Lucky"
]
const EPITHETS_SUFFIX := [
	"One-Eye", "the Lame", "the Younger", "the Elder", "Two-Fingers", "the Quiet",
	"the Fair", "Ill-Luck", "the Wanderer", "Half-Hand", "the Pious", "Longshanks",
	"the Sour", "Crookback", "the Bold", "Ratcatcher", "the Widow", "Greycloak"
]

## Dwarf names (Kazan-Dun folk; avoid story dwarves Tharin, Grond, Finn, Greta, Gormund)
const DWARF_MALE_NAMES := [
	"Balgrim", "Dorin", "Farin", "Gimli", "Harek", "Kargan", "Lodur", "Morgrim",
	"Norri", "Orik", "Rurik", "Snorri", "Thorgar", "Ulfrik", "Vondal", "Brokk",
	"Dain", "Eberk", "Gruumsh", "Hjalmar", "Kildrak", "Ovar", "Rangrim", "Tordek"
]
const DWARF_FEMALE_NAMES := [
	"Amber", "Bardryn", "Dagnal", "Eldeth", "Falkrunn", "Gunnloda", "Helja",
	"Kathra", "Kristryd", "Ilde", "Mardred", "Riswynn", "Sannl", "Torbera",
	"Vistra", "Bruenhilde", "Dathla", "Grendel", "Hlin", "Torgga"
]
const DWARF_CLAN_NAMES := [
	"Ironbeard", "Stoneheart", "Deepdelve", "Ironpick", "Coalbrow", "Granitefist",
	"Hammerfall", "Orewatcher", "Rockmantle", "Steelvein", "Torchbearer", "Undermount",
	"Bronzebottom", "Cavehowl", "Deepforge", "Gemcutter", "Leadbelly", "Mithrilborn"
]

## Halfling names (river- and hearth-folk)
const HALFLING_MALE_NAMES := [
	"Alton", "Cade", "Eldon", "Finnan", "Garret", "Lindal", "Lyle", "Merric",
	"Milo", "Osborn", "Perrin", "Reed", "Roscoe", "Wellby", "Pippin", "Dell"
]
const HALFLING_FEMALE_NAMES := [
	"Andry", "Bree", "Callie", "Cora", "Euphemia", "Jillian", "Kithri", "Lavinia",
	"Lidda", "Merla", "Nedda", "Paela", "Portia", "Seraphina", "Shaena", "Trym"
]
const HALFLING_FAMILY_NAMES := [
	"Brushgather", "Goodbarrel", "Greenbottle", "Highhill", "Hilltopple", "Leagallow",
	"Tealeaf", "Thorngage", "Tosscobble", "Underbough", "Applethorn", "Cherrycheeks",
	"Honeypot", "Quickstep", "Riverbend", "Warmhearth"
]

## Elf names (Silvanost visitors; rare in Act I human lands)
const ELF_MALE_NAMES := [
	"Adran", "Aelar", "Beiro", "Carric", "Erdan", "Galinndan", "Hadarai", "Immeral",
	"Ivellios", "Laucian", "Mindartis", "Paelias", "Quarion", "Riardon", "Soveliss", "Thamior"
]
const ELF_FEMALE_NAMES := [
	"Adrie", "Althaea", "Anastrianna", "Andraste", "Antinua", "Bethrynna", "Caelynn",
	"Drusilia", "Enna", "Felosial", "Ielenia", "Keyleth", "Leshanna", "Meriele", "Naivara", "Quelenna"
]

# =============================================================================
# BOUNTY TEMPLATES
# =============================================================================

## Templates for bounty dialogue completion
const BOUNTY_TEMPLATES := {
	"completion": [
		"Well done. Here's your pay.",
		"Good work. The gold is yours.",
		"Impressive. Take your reward.",
		"That's the job done. Here you go.",
		"You've done well. Here's what I promised."
	]
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Get a random creature for a region
static func get_random_creature_for_region(region_id: String) -> String:
	if not REGIONS.has(region_id):
		return "wolf"

	var creatures: Array = REGIONS[region_id].creatures
	if creatures.is_empty():
		return "wolf"

	return creatures[randi() % creatures.size()]


## Get creature display name
static func get_creature_display(creature_id: String, plural: bool = true) -> String:
	if not CREATURES.has(creature_id):
		return creature_id.capitalize()

	if plural:
		return CREATURES[creature_id].display
	else:
		return CREATURES[creature_id].singular


## Get creature tier (1-4, higher = more dangerous)
static func get_creature_tier(creature_id: String) -> int:
	if not CREATURES.has(creature_id):
		return 1
	return CREATURES[creature_id].tier


## Get a random direction hint for a region
static func get_random_direction(region_id: String) -> String:
	if not REGIONS.has(region_id):
		return "out in the wilds"

	var directions: Array = REGIONS[region_id].directions
	if directions.is_empty():
		return "out in the wilds"

	return directions[randi() % directions.size()]


## Get region name for display
static func get_region_name(region_id: String) -> String:
	if not REGIONS.has(region_id):
		return region_id.replace("_", " ").capitalize()
	return REGIONS[region_id].name


## Get settlement's primary region
static func get_settlement_region(settlement_id: String) -> String:
	if not SETTLEMENTS.has(settlement_id):
		return "kreigstan_forest"
	return SETTLEMENTS[settlement_id].region


## Get a random nearby region for a settlement (for variety in bounties)
static func get_random_nearby_region(settlement_id: String) -> String:
	if not SETTLEMENTS.has(settlement_id):
		return "kreigstan_forest"

	var nearby: Array = SETTLEMENTS[settlement_id].nearby_regions
	if nearby.is_empty():
		return SETTLEMENTS[settlement_id].region

	return nearby[randi() % nearby.size()]


## Draw an index from [param pool] using [param rng] when one is supplied.
## A null rng means the global unseeded generator, which is what every caller
## outside the ambient-population path wants.
static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	if rng != null:
		return String(pool[rng.randi() % pool.size()])
	return String(pool[randi() % pool.size()])


## A 0..1 roll from [param rng], or the global generator when it is null.
static func _roll(rng: RandomNumberGenerator) -> float:
	if rng != null:
		return rng.randf()
	return randf()


## Get a random NPC name (not zone-aware, may produce duplicates)
## race: "human" (default), "dwarf", "halfling", "elf"
## rng: pass a seeded generator to make the draw reproducible (RULING LW-1)
static func get_random_name(is_female: bool = false, race: String = "human", rng: RandomNumberGenerator = null) -> String:
	var first_names: Array = FEMALE_NAMES if is_female else MALE_NAMES
	var last_names: Array = SURNAMES
	var surname_chance: float = 0.3

	match race:
		"dwarf":
			first_names = DWARF_FEMALE_NAMES if is_female else DWARF_MALE_NAMES
			last_names = DWARF_CLAN_NAMES
			surname_chance = 0.8  # dwarves almost always carry clan names
		"halfling":
			first_names = HALFLING_FEMALE_NAMES if is_female else HALFLING_MALE_NAMES
			last_names = HALFLING_FAMILY_NAMES
			surname_chance = 0.6
		"elf":
			first_names = ELF_FEMALE_NAMES if is_female else ELF_MALE_NAMES
			surname_chance = 0.0  # elves go by single names among humans

	var first: String = _pick(first_names, rng)

	if _roll(rng) < surname_chance:
		return first + " " + _pick(last_names, rng)

	# Humans without surnames: small chance of a memorable epithet instead
	if race == "human" and _roll(rng) < 0.15:
		if _roll(rng) < 0.5:
			return _pick(EPITHETS_PREFIX, rng) + " " + first
		return first + " " + _pick(EPITHETS_SUFFIX, rng)

	return first


## Get a unique NPC name for a specific zone (no duplicates within same zone)
## Returns empty string if all names for that sex are used in the zone
## rng: pass a seeded generator to make the draw reproducible (RULING LW-1)
enum Gender { UNKNOWN, MALE, FEMALE }

## Honorifics and role words that name a woman on their own, so "Widow Hild Marrow"
## and "Sister Rowena Ash" resolve even when the given name is not in a pool.
const FEMALE_TITLES: Array[String] = [
	"lady", "widow", "goodwife", "sister", "mother", "priestess", "matron",
	"madam", "madame", "mistress", "dame", "abbess", "wife", "daughter", "queen",
	"duchess", "baroness", "countess", "enchantress", "seeress", "witch", "nun",
]

## The same for men. Listed so a male title beats a female-sounding given name
## rather than the classifier having to guess.
const MALE_TITLES: Array[String] = [
	"lord", "sir", "brother", "father", "widower", "king", "duke", "baron",
	"count", "prince", "abbot", "monk", "friar", "husband", "son",
]


## Which pool a display name came out of, and therefore which body it should wear.
##
## The name pools are gendered and always were; nothing between the pool and the
## sprite carried the bit, so every quest giver whose name a level script wrote by
## hand fell through to the male fallback. This is the bit, recovered from the name.
##
## Returns UNKNOWN rather than guessing. Every caller treats UNKNOWN as "keep doing
## what you did before", so this can only ever fix a wrong answer, never invent one.
static func name_gender(display_name: String) -> int:
	if display_name.is_empty():
		return Gender.UNKNOWN

	var words: PackedStringArray = display_name.replace("-", " ").replace("'", " ").split(" ", false)
	if words.is_empty():
		return Gender.UNKNOWN

	# A title is a stronger signal than a given name, and it comes first.
	for word: String in words:
		var lower: String = word.to_lower().rstrip(".,")
		if lower in MALE_TITLES:
			return Gender.MALE
		if lower in FEMALE_TITLES:
			return Gender.FEMALE

	# Otherwise the given name decides, checked against every pool the game draws
	# from. Titles like "Master" and "Lector" are gender-neutral here on purpose,
	# so the word after them is what gets tested.
	var female_pools: Array[Array] = [
		FEMALE_NAMES, DWARF_FEMALE_NAMES, HALFLING_FEMALE_NAMES, ELF_FEMALE_NAMES
	]
	var male_pools: Array[Array] = [
		MALE_NAMES, DWARF_MALE_NAMES, HALFLING_MALE_NAMES, ELF_MALE_NAMES
	]

	for word: String in words:
		var candidate: String = word.rstrip(".,")
		for pool: Array in female_pools:
			if candidate in pool:
				return Gender.FEMALE
		for pool: Array in male_pools:
			if candidate in pool:
				return Gender.MALE

	return Gender.UNKNOWN


## Convenience: true only when the name is positively a woman's.
static func is_female_name(display_name: String) -> bool:
	return name_gender(display_name) == Gender.FEMALE


static func get_unique_name_for_zone(zone_id: String, is_female: bool = false, rng: RandomNumberGenerator = null) -> String:
	# Initialize zone tracking if needed
	if not _used_names_by_zone.has(zone_id):
		_used_names_by_zone[zone_id] = {"male": [], "female": []}

	# No seeded generator supplied: use this zone's draw sequence, so the pool
	# the ambient slots later index into is the same pool every session.
	var draw_index: int = int(_zone_draw_count.get(zone_id, 0))
	_zone_draw_count[zone_id] = draw_index + 1
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = hash("%s#%d" % [zone_id, draw_index])

	var sex_key: String = "female" if is_female else "male"
	var first_names: Array = FEMALE_NAMES if is_female else MALE_NAMES
	var used_in_zone: Array = _used_names_by_zone[zone_id][sex_key]

	# Find available names
	var available: Array[String] = []
	for name: String in first_names:
		if name not in used_in_zone:
			available.append(name)

	# If all names used, return empty (caller should handle this)
	if available.is_empty():
		push_warning("WorldLexicon: All %s names exhausted in zone '%s'" % [sex_key, zone_id])
		return ""

	# Pick a random available name
	var chosen: String = _pick(available, rng)

	# Mark as used
	used_in_zone.append(chosen)

	# 30% chance to include surname
	if _roll(rng) < 0.3:
		return chosen + " " + _pick(SURNAMES, rng)

	return chosen


## Check if a name is available in a zone
static func is_name_available_in_zone(zone_id: String, name: String, is_female: bool = false) -> bool:
	if not _used_names_by_zone.has(zone_id):
		return true

	var sex_key: String = "female" if is_female else "male"
	var used_in_zone: Array = _used_names_by_zone[zone_id][sex_key]

	# Extract first name (in case full name with surname was passed)
	var first_name: String = name.split(" ")[0]
	return first_name not in used_in_zone


## Reserve a specific name in a zone (for named NPCs that shouldn't be duplicated)
static func reserve_name_in_zone(zone_id: String, name: String, is_female: bool = false) -> void:
	if not _used_names_by_zone.has(zone_id):
		_used_names_by_zone[zone_id] = {"male": [], "female": []}

	var sex_key: String = "female" if is_female else "male"
	var used_in_zone: Array = _used_names_by_zone[zone_id][sex_key]

	# Extract first name
	var first_name: String = name.split(" ")[0]
	if first_name not in used_in_zone:
		used_in_zone.append(first_name)


## Clear all used names for a zone (call when zone is unloaded/reset)
static func clear_zone_names(zone_id: String) -> void:
	if _used_names_by_zone.has(zone_id):
		_used_names_by_zone.erase(zone_id)
	_zone_draw_count.erase(zone_id)


## Clear all used names across all zones (call on new game)
static func clear_all_zone_names() -> void:
	_used_names_by_zone.clear()
	_zone_draw_count.clear()


## Get count of available names remaining for a zone
static func get_available_name_count(zone_id: String, is_female: bool = false) -> int:
	if not _used_names_by_zone.has(zone_id):
		return FEMALE_NAMES.size() if is_female else MALE_NAMES.size()

	var sex_key: String = "female" if is_female else "male"
	var used_count: int = _used_names_by_zone[zone_id][sex_key].size()
	var total: int = FEMALE_NAMES.size() if is_female else MALE_NAMES.size()
	return total - used_count


## Get all regions as an array of IDs
static func get_all_region_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in REGIONS.keys():
		ids.append(key)
	return ids


## Get bounty template text
static func get_bounty_template(category: String) -> String:
	if not BOUNTY_TEMPLATES.has(category):
		return ""

	var templates: Array = BOUNTY_TEMPLATES[category]
	if templates.is_empty():
		return ""

	return templates[randi() % templates.size()]

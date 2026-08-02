"""Scratch generator for data/npc_schedules.json.

Reads a census of every NPC the Act I town scenes actually spawn (id, display
name, measured world position) and writes one schedule record per NPC. Trade is
inferred from the id and the display name, on word boundaries, first rule wins.
Anything the rules cannot place gets `townsfolk`, which is a schedule, not a
guess about their life.
"""
import json, collections, re, hashlib, math, sys

CELLS = {"elder_moor": (0, 0), "dalhurst": (-8, -2), "thornfield": (3, -2),
         "millbrook": (-7, 4), "willow_dale": (-5, -5)}
LEISURE = {
    "elder_moor":  (5.5, 0.0, 12.0),    # the camp cook fire
    "dalhurst":    (-9.0, 0.0, -39.0),  # the dockside tavern the barmaids work
    "thornfield":  (3.0, 0.0, 9.0),     # Godfrey Larke's inn
    "millbrook":   (4.0, 0.0, 16.0),    # Hamish Roke's inn
    "willow_dale": (6.0, 0.0, 44.0),    # the survivors' fire; there is nothing else
}
BOUNDS = {"elder_moor": (242, 219), "dalhurst": (160, 172),
          "thornfield": (100, 100), "millbrook": (100, 100), "willow_dale": (100, 100)}

RULES = [
    ("innkeeper",  ["innkeeper", "hamish roke", "godfrey larke"]),
    ("barmaid",    ["barmaid"]),
    ("priest",     ["priest", "priestess", "sister", "brother", "chronist",
                    "prophet", "seer", "acolyte of"]),
    ("acolyte",    ["acolyte", "monk"]),
    ("crook",      ["thief", "thieves", "fence", "informant", "shadowmaster",
                    "nightshade", "raven", "recruiter", "smuggler", "mara",
                    "traitor", "contact", "ferret", "quint", "vex"]),
    ("official",   ["magistrate", "guildmaster", "harbor master",
                    "harbor captain", "captain", "foreman", "officer",
                    "sergeant", "corporal", "guild clerk", "elder", "company",
                    "blades", "chief"]),
    ("guard",      ["guard", "watchman", "watch"]),
    ("scholar",    ["scholar", "lector", "loremaster", "librarian", "keeper", "tome"]),
    ("mage",       ["wizard", "mage", "enchantress", "sorcerer", "sorceress",
                    "helvant", "maelorn", "apprentice", "vayle", "wyke"]),
    ("healer",     ["healer", "sorcha", "nuala"]),
    ("shepherd",   ["shepherd"]),
    ("fisherman",  ["fisherman", "fisher", "finn", "ketch", "quist"]),
    ("sailor",     ["sailor", "deckhand", "dockhand", "drowned"]),
    ("farmer",     ["farmer", "goodwife", "widow", "edda", "mother"]),
    ("hunter",     ["hunter", "marek", "trapper"]),
    ("noble",      ["noble", "lord", "lady", "caddock", "sunniva", "sigyn"]),
    ("bard",       ["bard", "minstrel"]),
    ("beggar",     ["beggar", "hermit", "drifter", "survivor", "refugee",
                    "witness", "victim", "frightened", "shaken", "worried"]),
    ("shopkeeper", ["merchant", "trader", "store", "shop", "smith", "smithy",
                    "armory", "alchemist", "weapons", "supplies", "goods",
                    "grog", "bar", "curiosities", "lodge", "supplier", "stall",
                    "vendor", "halvard", "talbot", "hector", "greta"]),
    ("laborer",    ["woodcutter", "logger", "miller", "mason", "carter",
                    "stallhand", "labourer", "laborer", "worker", "porter"]),
    ("townsfolk",  ["adventurer", "gladiator", "villager", "clerk"]),
]
COMPILED = [(a, re.compile(r"\b(?:%s)\b" % "|".join(re.escape(k) for k in ks)))
            for a, ks in RULES]

# Hand rulings where the trade rules land on the wrong trade, or land on
# nothing and the name says otherwise. Each is a reading of a name the quest
# pass already wrote, never a new fact about the person.
OVERRIDES = {
    "elder_moor_old_woman": "townsfolk",       # "Goodwife Hester Crow" - not an elder
    "elder_moor_woodsmans_wife": "townsfolk",  # Bridget Hale, waiting on news
    "elder_moor_guard": "official",            # Watch-Captain, over the watchman
    "foreman_garvek": "official",              # runs the camp, keeps camp hours
    "borin_stonehammer": "beggar",             # a courier off his feet, no post
    "dying_merchant_ilsabet": "beggar",        # laid down beside the shrine
    "martha_cook": "innkeeper",                # the cook fire is her counter
    "varn_the_scarred": "laborer",             # retired, hangs about the camp
    "grom_the_smith": "shopkeeper",
    "sage_brennan": "scholar",
    "tharin_ironbeard": "shopkeeper",
    "restless_ghost": "beggar",                # The Drowned Man keeps no hours
    "temple_acolyte_dalhurst": "acolyte",
    "millbrook_healer": "healer",
    "thornfield_healer": "healer",
    "millbrook_shepherd": "shepherd",
    "millbrook_innkeeper": "innkeeper",
    "thornfield_innkeeper": "innkeeper",
    "innkeeper_dalhurst": "innkeeper",
    "millbrook_fisherman": "fisherman",
    "master_helvant_dalhurst": "mage",
    "wizard_dalhurst": "mage",
    "thornfield_wizard": "mage",
    "harbor_blacksmith": "shopkeeper",
    "aldric_vane": "scholar",
    "head_fisherman_millbrook": "fisherman",
    "old_fisherman_dalhurst": "fisherman",
    "thornfield_farmer": "farmer",
    "farmer_edda": "farmer",
    "miller_oswin": "laborer",
    "caravan_survivor": "beggar",
}

# One of these per town works the other half of the watch rota, so a town at
# 03:00 is not simply an empty one.
NIGHT_WATCH = {"guard_elder_moor_1", "guard_dalhurst_1", "marius_thornfield",
               "baldric_dalhurst", "marius_dalhurst"}


def classify(nid, name, cls, zone):
    if nid in OVERRIDES:
        return OVERRIDES[nid]
    # Anything the level script built as a Merchant keeps a counter, whatever
    # its name says. The class is ground truth; the name is a guess.
    if cls == "merchant.gd":
        return "shopkeeper"
    # The zone name is part of most ids ("mabel_elder_moor") and is not a trade.
    # Left in, every resident of Elder Moor read as an "elder".
    bare = nid
    for suffix in ("_" + zone, zone + "_", "_" + zone.replace("_", "")):
        if bare.endswith(suffix):
            bare = bare[: -len(suffix)]
        elif bare.startswith(suffix):
            bare = bare[len(suffix):]
    hay = (bare.replace("_", " ") + " " + name).lower()
    for arch, rx in COMPILED:
        if rx.search(hay):
            return arch
    return "townsfolk"


def jitter(seed, radius):
    h = int(hashlib.sha1(seed.encode()).hexdigest()[:8], 16)
    ang = (h % 360) * math.pi / 180.0
    r = radius * (0.35 + 0.65 * (((h >> 9) % 100) / 100.0))
    return round(math.cos(ang) * r, 2), round(math.sin(ang) * r, 2)


def face(seed):
    return (int(hashlib.sha1(seed.encode()).hexdigest()[:4], 16) % 8) * 45


def stable(path_a, path_b):
    """Only NPCs whose id AND position are identical across two cold boots.

    The rest are the ambient population: `spawn_random` draws their name out of
    a pool and their spot out of `randf()`, so both change every boot. A record
    keyed on one of those ids would be dead data. They get a schedule at
    runtime instead, off the archetype their spawner names.
    """
    a = json.loads(open(path_a, "rb").read().decode("utf-8-sig"))
    b = json.loads(open(path_b, "rb").read().decode("utf-8-sig"))
    out = {}
    for scene, rows in a.items():
        other = {r["id"]: tuple(r["pos"]) for r in b.get(scene, []) if r["id"]}
        keep = [r for r in rows
                if r["id"] and other.get(r["id"]) == tuple(r["pos"])]
        out[scene] = keep
        dropped = len(rows) - len(keep)
        if dropped:
            print("   ambient (unstable id or position): %-22s %d of %d" %
                  (scene.split("/")[-1], dropped, len(rows)))
    return out


def main(census_path, census_path_b):
    src = stable(census_path, census_path_b)
    out, skipped, dupes, seen = collections.OrderedDict(), [], [], {}
    counts = collections.Counter()
    oob = []

    for scene, rows in sorted(src.items()):
        zone = scene.split("/")[-1].replace(".tscn", "")
        if zone not in CELLS:
            continue
        cx, cz = CELLS[zone]
        ox, oz = cx * 100.0, cz * 100.0
        hw, hd = BOUNDS[zone][0] / 2.0, BOUNDS[zone][1] / 2.0
        lx, ly, lz = LEISURE[zone]
        for r in rows:
            nid = r["id"]
            if not nid:
                skipped.append((zone, r["name"], "no npc_id"))
                continue
            if re.match(r"^(thief|guard)_\d{6,}$", nid) or "@" in nid:
                skipped.append((zone, nid, "id not stable across boots"))
                continue
            if nid in seen:
                dupes.append((zone, nid, r["name"]))
                continue
            seen[nid] = zone
            px, py, pz = r["pos"]
            arch = "night_watch" if nid in NIGHT_WATCH else classify(
                nid, r["name"], r.get("cls", ""), zone)
            counts[arch] += 1
            jx, jz = jitter(nid, 3.0)
            st = collections.OrderedDict()
            st["work"] = collections.OrderedDict([
                ("cell", [cx, cz]),
                ("pos", [round(ox + px, 2), round(py, 2), round(oz + pz, 2)]),
                ("facing", face(nid + "f"))])
            st["home"] = collections.OrderedDict([
                ("cell", [cx, cz]),
                ("pos", [round(ox + px, 2), round(py, 2), round(oz + pz, 2)]),
                ("facing", 0), ("interior", True)])
            st["leisure"] = collections.OrderedDict([
                ("cell", [cx, cz]),
                ("pos", [round(ox + lx + jx, 2), round(ly, 2), round(oz + lz + jz, 2)]),
                ("facing", face(nid + "l")),
                ("sit", (int(hashlib.sha1((nid + "s").encode()).hexdigest()[:2], 16) % 2) == 0)])
            rec = collections.OrderedDict([("archetype", arch), ("zone", zone),
                                           ("stations", st)])
            if r["quests"]:
                rec["quest_giver"] = True
            out[nid] = rec
            for s in ("work", "leisure"):
                p = st[s]["pos"]
                if abs(p[0] - ox) > hw or abs(p[2] - oz) > hd:
                    oob.append((nid, s, zone, round(p[0] - ox, 1), round(p[2] - oz, 1), hw, hd))

    doc = collections.OrderedDict()
    doc["_README"] = (
        "Per-NPC schedule records. `archetype` names a file in "
        "data/schedules/archetypes/. Station `pos` is WORLD coordinates - the "
        "cell origin plus the position the level script actually spawns them "
        "at, measured by booting the scene rather than read off the source. "
        "`interior: true` means the room behind that door is not modelled, so "
        "the NPC is absent from the world while the schedule has them there. A "
        "missing station key falls back to the authored spawn and warns loudly; "
        "it is never quietly relocated. Generated by _gen_schedules.py from a "
        "headless census; hand edits here are fine and will not be regenerated "
        "away without someone choosing to.")
    doc["npcs"] = out
    with open("data/npc_schedules.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")

    print("scheduled:", len(out))
    for s in skipped:
        print("   skip", s)
    for d in dupes:
        print("   dup ", d)
    for o in oob:
        print("   oob ", o)
    for k, v in counts.most_common():
        print("  %-12s %d" % (k, v))
    return out


if __name__ == "__main__":
    res = main(sys.argv[1] if len(sys.argv) > 1 else "_census_tmp.json",
               sys.argv[2] if len(sys.argv) > 2 else "_census_tmp2.json")
    if "--list" in sys.argv:
        for k, v in sorted(res.items(), key=lambda kv: (kv[1]["zone"], kv[1]["archetype"], kv[0])):
            print("  %-12s %-14s %-34s %s" % (v["zone"], v["archetype"], k,
                                              "quest" if v.get("quest_giver") else ""))

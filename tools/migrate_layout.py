"""Apply tools/layout_rules.json to the working tree.

Two phases, run separately so each can be inspected before the next:

    python tools/migrate_layout.py plan     -> writes tools/layout_moves.tsv
    python tools/migrate_layout.py move     -> performs the moves and deletes
    python tools/migrate_layout.py remap    -> rewrites every res:// string

The sidecars are the whole reason this is a script and not a shell loop.
`*.uid` and `*.import` are gitignored, so `git mv` never sees them, and a .gd
that arrives at its new home without its .gd.uid gets a *fresh* uid on the next
import - silently breaking every `uid://` reference in every scene that loads
it. Sidecars travel with their file here, always.
"""

import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RULES = os.path.join(ROOT, "tools", "layout_rules.json")
MOVES = os.path.join(ROOT, "tools", "layout_moves.tsv")
DELETES = os.path.join(ROOT, "tools", "layout_deletes.tsv")

SIDECARS = (".uid", ".import")

# addons/ is never MOVED - plugin paths are fragile and already work - but its
# scripts reach into scripts/, data/, assets/ and scenes/ and must be rewritten
# like anything else. So it is skipped by the mover and scanned by the remapper.
SKIP_DIRS = {".git", ".godot", ".beads", "node_modules", "__pycache__"}
MOVE_SKIP_DIRS = SKIP_DIRS | {"addons"}

# Files whose text carries res:// paths. .import is included because its
# source_file= line names the asset, and a stale one forces a reimport that
# would mint a new uid.
TEXT_EXT = {
    ".gd", ".tscn", ".tres", ".json", ".cfg", ".import", ".md", ".ps1",
    ".py", ".godot", ".gdshader", ".sh", ".txt",
}

# Records of what the tree used to be. Rewriting these turns the map into a
# tautology - layout_rules.json would say new -> new, and the design doc's
# "Was | Is" table would say "Is | Is" - so the one artefact that explains the
# move would be the one artefact the move destroyed.
NEVER_REWRITE = {
    "tools/layout_rules.json",
    "tools/layout_moves.tsv",
    "tools/layout_deletes.tsv",
    "tools/fixtures/broken_paths_baseline.txt",
    "docs/audits/boot_sweep_baseline.txt",
    "docs/design/PROJECT_LAYOUT.md",
}


def load_rules():
    with open(RULES, encoding="utf-8") as f:
        doc = json.load(f)
    return [r for r in doc["rules"] if r["k"] != "c"]


def walk_files(skip=None):
    """Every file in the tree, repo-relative, forward slashes."""
    skip = SKIP_DIRS if skip is None else skip
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            if rel.split("/")[0] in skip:
                continue
            out.append(rel)
    return sorted(out)


def is_sidecar(rel):
    return any(rel.endswith(s) for s in SIDECARS)


def base_of(rel):
    """A sidecar's owning file: foo.gd.uid -> foo.gd."""
    for s in SIDECARS:
        if rel.endswith(s):
            return rel[: -len(s)]
    return rel


def plan():
    rules = load_rules()
    files = walk_files(MOVE_SKIP_DIRS)

    moves = []      # (old, new)
    deletes = []    # (path, why)
    seen = set()

    for rel in files:
        # A sidecar follows its owner; it is never matched on its own, so a
        # rule written for foo.gd automatically carries foo.gd.uid.
        key = base_of(rel) if is_sidecar(rel) else rel
        suffix = rel[len(key):] if is_sidecar(rel) else ""

        for r in rules:
            if r["k"] == "file":
                if key == r["from"]:
                    if r["to"] != r["from"]:
                        moves.append((rel, r["to"] + suffix))
                    seen.add(rel)
                    break
            elif r["k"] == "dir":
                if key.startswith(r["from"]):
                    new = r["to"] + key[len(r["from"]):] + suffix
                    if new != rel:
                        moves.append((rel, new))
                    seen.add(rel)
                    break
            elif r["k"] == "delete":
                frm = r["from"]
                if key == frm or (frm.endswith("/") and key.startswith(frm)):
                    deletes.append((rel, r.get("why", "")))
                    seen.add(rel)
                    break

    # A move whose destination already exists would silently clobber content.
    existing = set(files)
    dests = {}
    for old, new in moves:
        if new in dests:
            raise SystemExit("two files collide on %s: %s and %s" % (new, dests[new], old))
        dests[new] = old
        if new in existing and new not in {o for o, _ in moves}:
            raise SystemExit("move would clobber an existing file: %s -> %s" % (old, new))

    with open(MOVES, "w", encoding="utf-8", newline="\n") as f:
        for old, new in moves:
            f.write("%s\t%s\n" % (old, new))
    with open(DELETES, "w", encoding="utf-8", newline="\n") as f:
        for p, why in deletes:
            f.write("%s\t%s\n" % (p, why))

    print("moves:   %d" % len(moves))
    print("deletes: %d" % len(deletes))
    print("wrote %s and %s" % (MOVES, DELETES))


def tracked():
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True,
                         text=True, check=True).stdout
    return set(out.splitlines())


def move():
    trk = tracked()
    with open(MOVES, encoding="utf-8") as f:
        moves = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    with open(DELETES, encoding="utf-8") as f:
        deletes = [line.rstrip("\n").split("\t")[0] for line in f if line.strip()]

    for old, new in moves:
        src = os.path.join(ROOT, old)
        dst = os.path.join(ROOT, new)
        if not os.path.exists(src):
            print("  skip (gone): %s" % old)
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if old in trk:
            subprocess.run(["git", "mv", "-f", old, new], cwd=ROOT, check=True)
        else:
            shutil.move(src, dst)
    print("moved %d" % len(moves))

    for p in deletes:
        full = os.path.join(ROOT, p)
        if not os.path.exists(full):
            continue
        if p in trk:
            subprocess.run(["git", "rm", "-q", "-f", p], cwd=ROOT, check=True)
        else:
            os.remove(full)
    print("deleted %d" % len(deletes))

    # Directories the moves emptied.
    for dirpath, dirnames, filenames in os.walk(ROOT, topdown=False):
        if any(part in MOVE_SKIP_DIRS for part in dirpath.replace("\\", "/").split("/")):
            continue
        if dirpath == ROOT:
            continue
        try:
            if not os.listdir(dirpath):
                os.rmdir(dirpath)
        except OSError:
            pass


# A res:// literal ends at whitespace, a quote, a bracket, or the markdown
# characters that wrap paths in prose. Backticks and asterisks are excluded
# deliberately: `res://scripts/core/log.gd` in a document is a path plus two
# backticks, and a naive class would carry them into the lookup and miss.
RES_LITERAL = re.compile(r"""res://[^\s"'`*()\[\]{},;<>|]*""")

TRAILING = ".,:!?"


def _tables(pairs):
    """(exact file map, pinned set, directory prefix list).

    `pinned` is the set of files a rule names explicitly and leaves where they
    are. Without it a directory rule swallows them: scripts/world/ moves to
    scripts/world/interactables/, and day_night_cycle.gd - which a file rule
    deliberately holds in place - would follow it there.
    """
    exact = dict(pairs)
    rules = load_rules()
    pinned = {r["from"] for r in rules
              if r["k"] == "file" and r["from"] == r.get("to")}
    prefixes = [(r["from"], r["to"]) for r in rules if r["k"] == "dir"]
    prefixes.sort(key=lambda p: len(p[0]), reverse=True)
    return exact, pinned, prefixes


def _map(p, exact, pinned, prefixes):
    """Old repo-relative path -> new. Applied exactly once per literal."""
    tail = ""
    while p and p[-1] in TRAILING:
        tail = p[-1] + tail
        p = p[:-1]
    if p in exact:
        return exact[p] + tail
    if p in pinned:
        return p + tail
    for old, new in prefixes:
        if p.startswith(old):
            return new + p[len(old):] + tail
    return p + tail


def remap(scope=None):
    with open(MOVES, encoding="utf-8") as f:
        pairs = [line.rstrip("\n").split("\t") for line in f if line.strip()]

    exact, pinned, prefixes = _tables(pairs)

    def map_path(p):
        return _map(p, exact, pinned, prefixes)

    # Prose names paths without the scheme - CLAUDE.md's tables, the design
    # docs, the shell scripts. Only whole file paths are rewritten there, never
    # directory prefixes, because "scripts/world/" in a sentence is ambiguous
    # in a way "scripts/world/interactables/chest.gd" is not.
    bare_pairs = [(o, n) for o, n in pairs
                  if "/" in o and "." in os.path.basename(o)]
    bare_pairs.sort(key=lambda p: len(p[0]), reverse=True)
    bare_map = dict(bare_pairs)
    bare_re = re.compile("|".join(re.escape(o) for o, _ in bare_pairs)) \
        if bare_pairs else None

    changed = 0
    counts = [0, 0]

    def sub_res(m):
        literal = m.group()
        new = "res://" + map_path(literal[6:])
        if new != literal:
            counts[0] += 1
        return new

    def sub_bare(m):
        counts[1] += 1
        return bare_map[m.group()]

    for rel in walk_files():
        if rel in NEVER_REWRITE:
            continue
        if scope is not None and not rel.startswith(scope):
            continue
        ext = os.path.splitext(rel)[1].lower()
        if rel == "project.godot":
            ext = ".godot"
        if ext not in TEXT_EXT:
            continue
        full = os.path.join(ROOT, rel)
        try:
            with open(full, encoding="utf-8") as f:
                text = f.read()
        except (UnicodeDecodeError, OSError):
            print("  !! could not read as utf-8, skipped: %s" % rel)
            continue
        orig = text
        # One pass each, so a path can never be rewritten twice - which matters
        # because assets/sprites/ moves *inside itself*, to assets/sprites/
        # legacy/, and a second pass would nest it again.
        if "res://" in text:
            text = RES_LITERAL.sub(sub_res, text)
        if bare_re is not None:
            text = bare_re.sub(sub_bare, text)
        if text != orig:
            with open(full, "w", encoding="utf-8", newline="") as f:
                f.write(text)
            changed += 1
    print("rewrote %d res:// and %d bare references across %d files"
          % (counts[0], counts[1], changed))


def preflight():
    """Would every res:// literal that resolves today still resolve after?

    Run before `move`. It answers the only question that matters and it
    answers it in a second, where the real gate - check_no_broken_paths in a
    headless Godot - takes a minute and only runs once the tree is already
    torn apart.
    """
    with open(MOVES, encoding="utf-8") as f:
        pairs = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    with open(DELETES, encoding="utf-8") as f:
        deletes = {line.split("\t")[0] for line in f if line.strip()}

    exact, pinned, prefixes = _tables(pairs)

    def map_path(p):
        return _map(p, exact, pinned, prefixes)

    before = set(walk_files())
    dirs_before = set()
    for f in before:
        parts = f.split("/")
        for i in range(1, len(parts)):
            dirs_before.add("/".join(parts[:i]) + "/")

    after = set()
    moved = set(o for o, _ in pairs)
    for f in before:
        if f in deletes:
            continue
        after.add(exact[f] if f in moved else f)
    dirs_after = set()
    for f in after:
        parts = f.split("/")
        for i in range(1, len(parts)):
            dirs_after.add("/".join(parts[:i]) + "/")

    def resolves(p, files, dirs):
        p = p.rstrip("".join(TRAILING))
        if not p:
            return True
        if "%" in p or "{" in p:
            return True
        if p.endswith("/"):
            return p in dirs
        return p in files or (p + "/") in dirs or (p + ".import") in files

    broken = {}
    already = 0
    for rel in sorted(before):
        if rel in deletes:
            continue
        ext = os.path.splitext(rel)[1].lower()
        if rel == "project.godot":
            ext = ".godot"
        if ext not in TEXT_EXT:
            continue
        try:
            with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
                text = f.read()
        except (UnicodeDecodeError, OSError):
            continue
        if "res://" not in text:
            continue
        for m in set(x.group() for x in RES_LITERAL.finditer(text)):
            old = m[6:]
            if not resolves(old, before, dirs_before):
                already += 1
                continue
            new = map_path(old)
            if not resolves(new, after, dirs_after):
                broken.setdefault("res://" + old + "  ->  res://" + new,
                                  []).append(rel)

    print("literals already broken before the move: %d" % already)
    if not broken:
        print("PREFLIGHT OK: every literal that resolves today still resolves")
        return
    print("PREFLIGHT FAIL: %d literal(s) would rot:" % len(broken))
    for k in sorted(broken):
        print("  %s" % k)
        for site in sorted(set(broken[k]))[:4]:
            print("      %s" % site)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "plan"
    if cmd == "remap":
        remap(sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        {"plan": plan, "move": move, "preflight": preflight}[cmd]()

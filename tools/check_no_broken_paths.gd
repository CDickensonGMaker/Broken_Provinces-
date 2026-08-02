extends Node
## Every res:// string in the project points at something that exists.
##
## Usage: godot --headless --path . res://tools/check_no_broken_paths.tscn
##
## This gate exists because of the 2026-08-02 layout migration, which moved
## 2185 files and rewrote several thousand res:// references. A stale reference
## is the one failure mode that class of change produces, and it is close to
## invisible: Godot resolves scenes by uid first, so a .tscn whose `path=` rots
## keeps working right up until the uid cache is rebuilt, and a `load()` of a
## dead path in a branch nobody walked that session prints one line and returns
## null. Both survive a green check suite.
##
## So the scan is textual and total. It reads every file the project can carry a
## path in, pulls every res:// literal out of it, and demands the target exist
## on disk. Nothing is inferred from the engine's own resolution, because the
## engine's own resolution is what hides the rot.
##
## What it deliberately does NOT flag:
##   - literals that are the head of a runtime-built path ("res://data/quests/"
##     + id): a trailing slash means "directory", and the directory is checked
##   - literals carrying a format placeholder (%s, {0}), which are templates
##   - user:// and uid:// (a different question)
## Anything else that does not resolve is a defect, and the allowlist below is
## the only escape hatch. Every entry on it needs a reason.

## Extensions that can carry a res:// path and that gate the build.
const CODE_EXT: Array[String] = [
	".gd", ".tscn", ".tres", ".json", ".cfg", ".gdshader", ".import", ".godot",
]

## Prose. Scanned and reported, but a rotten link in a document is not a build
## failure, so these are warnings.
const DOC_EXT: Array[String] = [".md", ".txt"]

## Directories with their own rules. addons/ ships third-party and in-house
## editor plugins whose paths are checked, but .godot/ is the import cache and
## is regenerated, never authored.
const SKIP_DIRS: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://.beads",
]

## Files whose whole content is a list of paths that do not resolve - reading
## them as sources would report every line twice and make the check's own
## bookkeeping look like project rot.
const SKIP_FILES: Array[String] = [
	"res://tools/fixtures/broken_paths_baseline.txt",
	"res://tools/layout_moves.tsv",
	"res://tools/layout_deletes.tsv",
]

## Paths that do not resolve on disk and are correct anyway. One line of reason
## each; an entry with no reason is a bug being hidden.
const ALLOWED: Dictionary = {
	# Godot writes these; they are outputs, not inputs.
	"res://.godot/imported": "engine import cache, generated",
	"res://android/build": "gradle build template, only present after an Android export setup",
	"res://exports": "CSG export output directory, created by the exporter at run time",
}

## The ratchet.
##
## 227 paths were already broken the day this check was written, and every one
## of them is a missing ASSET - a sprite named in a blueprint that was never
## drawn, a cave GLB that was never modelled - not a mis-typed path. Fixing them
## is art work, not a rename, so the gate cannot demand zero without either
## lying or blocking every commit until the art lands.
##
## So it demands **no new ones**. The file is the committed list of what was
## already rotten; anything outside it fails. Regenerate with --write-baseline
## after a deliberate move, and read the diff: that diff is the damage report.
##
## A line in the baseline that now resolves also fails, with instructions to
## delete it. A list of excuses nobody prunes stops being a list of excuses and
## becomes a place to hide.
const BASELINE_PATH := "res://tools/fixtures/broken_paths_baseline.txt"

var _bad: Array[String] = []
var _doc_bad: Array[String] = []
var _scanned: int = 0
var _paths: int = 0


func _ready() -> void:
	# Two passes, because paths with spaces exist and are legal. A quoted
	# literal runs to its closing quote whatever is inside it; only after those
	# are lifted out can the rest be scanned on the assumption that whitespace
	# ends a path. Doing it the other way round truncates
	# "res://Sprite folders grab bag/rat.png" to "res://Sprite" and reports 100
	# imaginary breakages.
	var quoted := RegEx.new()
	quoted.compile("[\"'](res://[^\"'\\n]*)[\"']")
	var bare := RegEx.new()
	bare.compile("res://[^\"'\\s\\)\\]\\},;>|]*")

	_scan_dir("res://", quoted, bare)

	print("")
	print("scanned %d files, %d res:// literals" % [_scanned, _paths])
	print("%d rotten path(s) in code, %d in documentation" % [_bad.size(), _doc_bad.size()])

	_bad.sort()
	if "--write-baseline" in OS.get_cmdline_user_args():
		var out := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		for line: String in _bad:
			out.store_line(line)
		out.close()
		print("wrote %d lines to %s" % [_bad.size(), BASELINE_PATH])
		get_tree().quit(0)
		return

	var baseline: Dictionary = {}
	var bf := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if bf != null:
		while not bf.eof_reached():
			var line := bf.get_line().strip_edges()
			if line != "":
				baseline[line] = true
		bf.close()

	var current: Dictionary = {}
	for line: String in _bad:
		current[line] = true

	var new_breaks: Array[String] = []
	for line: String in _bad:
		if not baseline.has(line):
			new_breaks.append(line)
	var fixed: Array[String] = []
	for line: String in baseline:
		if not current.has(line):
			fixed.append(line)
	fixed.sort()

	print("")
	if new_breaks.is_empty() and fixed.is_empty():
		print("OK: no new broken res:// paths (%d known, all still known)" % baseline.size())
		get_tree().quit(0)
		return

	if not fixed.is_empty():
		printerr("FAIL: %d baseline line(s) now resolve and must be deleted from" % fixed.size())
		printerr("      %s - a stale excuse is a place to hide:" % BASELINE_PATH)
		for line: String in fixed:
			printerr("  fixed  %s" % line)

	if not new_breaks.is_empty():
		printerr("FAIL: %d NEW broken res:// path(s):" % new_breaks.size())
		for line: String in new_breaks:
			printerr("  - %s" % line)

	printerr("")
	printerr("Regenerate deliberately with:")
	printerr("  godot --headless --path . res://tools/check_no_broken_paths.tscn -- --write-baseline")
	get_tree().quit(1)


func _scan_dir(dir_path: String, quoted: RegEx, bare: RegEx) -> void:
	for skip: String in SKIP_DIRS:
		if dir_path.begins_with(skip):
			return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan_dir(full, quoted, bare)
		else:
			_scan_file(full, quoted, bare)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, quoted: RegEx, bare: RegEx) -> void:
	if path in SKIP_FILES:
		return
	var ext := "." + path.get_extension().to_lower()
	if path.get_file() == "project.godot":
		ext = ".godot"
	var is_doc := ext in DOC_EXT
	if not is_doc and ext not in CODE_EXT:
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	_scanned += 1
	if not text.contains("res://"):
		return

	var found_paths: Array[String] = []
	# Quoted first, then blank the quoted regions out so the bare pass cannot
	# re-read the same literal and truncate it at a space.
	var stripped := text
	for m: RegExMatch in quoted.search_all(text):
		found_paths.append(m.get_string(1))
		stripped = stripped.replace(m.get_string(), "\"\"")
	for m: RegExMatch in bare.search_all(stripped):
		found_paths.append(m.get_string())

	for raw: String in found_paths:
		var found := raw
		# Trailing punctuation the regex could not know about.
		while found.length() > 6 and found[-1] in ".,:`*":
			found = found.substr(0, found.length() - 1)
		if found == "res://":
			continue
		_paths += 1
		if _resolves(found):
			continue
		# One line per (file, path) pair. A script that names the same dead
		# directory three times is one defect, not three.
		var line := "%s -> %s" % [path.replace("res://", ""), found]
		if is_doc:
			if not _doc_bad.has(line):
				_doc_bad.append(line)
		elif not _bad.has(line):
			_bad.append(line)


func _resolves(p: String) -> bool:
	# A template, not a path.
	if p.contains("%") or p.contains("{") or p.contains("\\"):
		return true
	for allowed: String in ALLOWED:
		if p.begins_with(allowed):
			return true
	# A trailing slash is a directory head that runtime code appends to.
	if p.ends_with("/"):
		return DirAccess.dir_exists_absolute(p)
	if FileAccess.file_exists(p):
		return true
	if DirAccess.dir_exists_absolute(p):
		return true
	# An imported asset is addressed by its source path but only its .import
	# sidecar survives into an export; both count as present in the source tree.
	if FileAccess.file_exists(p + ".import"):
		return true
	# A .tscn/.tres/.gd inside a .pck answers to ResourceLoader when the file
	# scan cannot see it (the remapped path case).
	return ResourceLoader.exists(p)

extends Node
## Audio event check: every sound this game names either plays, or is written
## down as an asset it does not have.
##
## Usage: godot --headless --path . res://tools/check_audio_events.tscn
##
## The 8/1 audit found ~120 EVENTS entries pointing at res://assets/audio/sfx/
## root, which holds zero files - every real asset lives one directory down.
## `_load_sound` push_warning'd and returned null, and every caller did
## `if not stream: return`, so no hit, death, menu or item sound had ever
## played and nothing had ever crashed to say so.
##
## Four assertions:
##
##   1. Every EVENTS key resolves to a file on disk, through its own asset or
##      a declared substitute - or is named in MISSING_SFX.
##   2. Every MISSING_SFX entry is a real EVENTS key (no stale excuses) and
##      appears in docs/audits/art_replacement_manifest.md.
##   3. Every EVENT_SUBSTITUTES entry points at an event with a real file, so
##      a substitution can never itself be silent.
##   4. Every sound name written as a literal at a call site in scripts/
##      resolves: an event, an alias, or a res:// path that exists.

const MANIFEST_PATH := "res://docs/audits/art_replacement_manifest.md"
const SCRIPT_DIRS: Array[String] = ["res://scripts", "res://tools", "res://dev"]

## Call sites whose sound argument is a variable, an expression or data-driven.
## These cannot be checked statically and are not evidence of a bug.
const DYNAMIC_CALL_MARKERS: Array[String] = ["%"]

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	_check_events_resolve()
	_check_missing_declared()
	_check_substitutes_resolve()
	_check_call_sites()

	print("")
	print("Checks run: %d" % checks)
	if failures.is_empty():
		print("Audio event check: PASS")
		get_tree().quit(0)
	else:
		for f: String in failures:
			print("  FAIL  %s" % f)
		print("Audio event check: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _check_events_resolve() -> void:
	for event_name: String in AudioManager.EVENTS.keys():
		checks += 1
		var path: String = AudioManager.resolve_event_path(event_name)
		if path.is_empty() and not AudioManager.MISSING_SFX.has(event_name):
			failures.append("event '%s' resolves to nothing and is not in MISSING_SFX" % event_name)


func _check_missing_declared() -> void:
	var manifest: String = ""
	if FileAccess.file_exists(MANIFEST_PATH):
		manifest = FileAccess.get_file_as_string(MANIFEST_PATH)
	else:
		failures.append("art manifest not found at %s" % MANIFEST_PATH)

	for event_name: String in AudioManager.MISSING_SFX:
		checks += 1
		if not AudioManager.EVENTS.has(event_name):
			failures.append("MISSING_SFX names '%s', which is not an EVENTS key" % event_name)
			continue
		if not AudioManager.resolve_event_path(event_name).is_empty():
			failures.append("MISSING_SFX names '%s', which now resolves - drop the excuse" % event_name)
			continue
		if not manifest.contains(event_name):
			failures.append("MISSING_SFX names '%s' with no row in the art manifest" % event_name)


func _check_substitutes_resolve() -> void:
	for event_name: String in AudioManager.EVENT_SUBSTITUTES.keys():
		checks += 1
		if not AudioManager.EVENTS.has(event_name):
			failures.append("EVENT_SUBSTITUTES names '%s', which is not an EVENTS key" % event_name)
		var sub: Variant = AudioManager.EVENT_SUBSTITUTES[event_name]
		var candidates: Array = (sub as Array) if sub is Array else [sub]
		for candidate: Variant in candidates:
			var stand_in: String = str(candidate)
			var path: String = AudioManager.EVENTS.get(stand_in, "")
			if path.is_empty() or not ResourceLoader.exists(path):
				failures.append("substitute '%s' -> '%s' has no file on disk" % [event_name, stand_in])


func _check_call_sites() -> void:
	var regex := RegEx.new()
	regex.compile("(play_sfx|play_sfx_3d|play_event|play_event_3d|play_ui_sound)\\(\\s*\"([^\"]+)\"")

	for dir_path: String in SCRIPT_DIRS:
		for file_path: String in _gd_files(dir_path):
			var text: String = FileAccess.get_file_as_string(file_path)
			for m: RegExMatch in regex.search_all(text):
				var name: String = m.get_string(2)
				var skip: bool = false
				for marker: String in DYNAMIC_CALL_MARKERS:
					if name.contains(marker):
						skip = true
				if skip:
					continue
				checks += 1
				if name.begins_with("res://"):
					if not ResourceLoader.exists(name):
						failures.append("%s plays a file that does not exist: %s" % [file_path, name])
					continue
				var canonical: String = AudioManager.EVENT_ALIASES.get(name, name)
				if not AudioManager.EVENTS.has(canonical):
					failures.append("%s plays '%s', which is not an event, an alias or a path" % [file_path, name])


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out

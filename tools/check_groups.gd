extends Node
## Group-registry check: every scene group this project *reads* must be a group
## something *joins*.
##
## Usage: godot --headless --path . res://tools/check_groups.tscn
##
## Batch 5 tasks 69, 70 and 71 were nine instances of one bug: a lookup like
## `get_nodes_in_group("zone_doors")` against a name no `add_to_group` and no
## `.tscn` ever registers. It always returns an empty array. Nothing throws,
## nothing warns, and the feature it powers - minimap door icons, arena
## hazards hitting gladiators, guild NPC icons, day/night stealth - is simply
## absent. The audit found them by hand; this finds them by boot.
##
## It is deliberately a *source* scan rather than a runtime one, because a
## group only exists while the node holding it is in the tree, and no headless
## boot loads every scene in the game at once.
##
## Reads recognised:
##   get_nodes_in_group("x") / get_first_node_in_group("x") / is_in_group("x")
##   {"group": "x"}          - the table-driven form the minimap uses, which is
##                             where two of this batch's dead lookups lived
##
## Joins recognised:
##   add_to_group("x")       anywhere under scripts/ tools/ dev/ addons/
##   groups = [...]          in any .tscn
##
## A read whose group is joined by nothing is an ERROR. If a group is genuinely
## joined by something this scanner cannot see, add it to KNOWN_EXTERNAL_JOINS
## with the reason - the same discipline as the TRANSIENT_FIELDS whitelists.

const SCAN_DIRS: Array[String] = ["res://scripts", "res://tools", "res://dev", "res://addons"]
const SCENE_DIRS: Array[String] = ["res://scenes", "res://addons"]

## Directories whose `{"group": "x"}` dictionaries are quest/objective data,
## not scene-group lookups. `objective_groups` uses the same key name.
const TABLE_READ_EXCLUDE_PREFIXES: Array[String] = ["res://tools/", "res://dev/"]

## Groups joined somewhere this scanner cannot read, with the reason.
const KNOWN_EXTERNAL_JOINS: Dictionary = {}

var _reads: Dictionary = {}   # group -> Array[String] of "file:line"
var _joins: Dictionary = {}   # group -> Array[String]
var _files_scanned: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	for dir_path: String in SCAN_DIRS:
		_scan_scripts(dir_path)
	for dir_path: String in SCENE_DIRS:
		_scan_scenes(dir_path)

	print("")
	print("files scanned: %d" % _files_scanned)
	print("group names read: %d" % _reads.size())
	print("group names joined: %d" % _joins.size())

	var read_names: Array = _reads.keys()
	read_names.sort()
	for group_name: String in read_names:
		if _joins.has(group_name):
			continue
		if KNOWN_EXTERNAL_JOINS.has(group_name):
			continue
		var sites: Array = _reads[group_name]
		_failures.append('group "%s" is read at %s and joined by nothing' % [
			group_name, ", ".join(PackedStringArray(sites))
		])

	# A whitelist entry that is no longer needed is a stale excuse.
	for group_name: String in KNOWN_EXTERNAL_JOINS.keys():
		if _joins.has(group_name):
			_failures.append(
				'KNOWN_EXTERNAL_JOINS names "%s", but the scanner can see it joined now - remove the entry' % group_name
			)
		elif not _reads.has(group_name):
			_failures.append(
				'KNOWN_EXTERNAL_JOINS names "%s", which nothing reads - remove the entry' % group_name
			)

	print("")
	if _failures.is_empty():
		print("OK: every group read anywhere in the project is joined somewhere")
		get_tree().quit(0)
	else:
		for msg: String in _failures:
			printerr("FAIL: %s" % msg)
		printerr("check_groups: %d failure(s)" % _failures.size())
		get_tree().quit(1)


func _scan_scripts(dir_path: String) -> void:
	for path: String in _files_under(dir_path, ".gd"):
		var text := _read_text(path)
		if text.is_empty():
			continue
		_files_scanned += 1
		var allow_table_reads: bool = true
		for prefix: String in TABLE_READ_EXCLUDE_PREFIXES:
			if path.begins_with(prefix):
				allow_table_reads = false
				break

		var lines: PackedStringArray = text.split("\n")
		for i: int in lines.size():
			var line: String = lines[i]
			var site: String = "%s:%d" % [path.trim_prefix("res://"), i + 1]
			for group_name: String in _match_all(
				line, "(?:get_nodes_in_group|get_first_node_in_group|is_in_group)\\(\\s*\"([^\"]+)\""
			):
				_record(_reads, group_name, site)
			if allow_table_reads:
				for group_name: String in _match_all(line, "\"group\"\\s*:\\s*\"([^\"]+)\""):
					_record(_reads, group_name, site)
			for group_name: String in _match_all(line, "add_to_group\\(\\s*\"([^\"]+)\""):
				_record(_joins, group_name, site)


func _scan_scenes(dir_path: String) -> void:
	for path: String in _files_under(dir_path, ".tscn"):
		var text := _read_text(path)
		if text.is_empty():
			continue
		_files_scanned += 1
		var lines: PackedStringArray = text.split("\n")
		for i: int in lines.size():
			var line: String = lines[i]
			# `groups` appears both as its own property line and inline on a
			# [node ...] header. Pull just the array, not every quoted string on
			# the line - a [node] header also carries name, type and parent.
			var site: String = "%s:%d" % [path.trim_prefix("res://"), i + 1]
			for array_text: String in _match_all(
				line, "groups\\s*=\\s*(?:PackedStringArray)?\\(?(\\[[^\\]]*\\])"
			):
				for group_name: String in _match_all(array_text, "\"([^\"]+)\""):
					_record(_joins, group_name, site)


func _record(store: Dictionary, group_name: String, site: String) -> void:
	if not store.has(group_name):
		store[group_name] = []
	var sites: Array = store[group_name]
	if sites.size() < 4 and not sites.has(site):
		sites.append(site)


func _match_all(text: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		return out
	for m: RegExMatch in re.search_all(text):
		out.append(m.get_string(1))
	return out


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _files_under(dir_path: String, extension: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_files_under(full, extension))
		elif entry.ends_with(extension):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out

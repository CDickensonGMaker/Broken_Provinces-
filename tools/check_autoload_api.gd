extends Node
## Autoload API check: every `Autoload.thing` written in source actually exists.
##
## Usage: godot --headless --path . res://tools/check_autoload_api.tscn
##
## GDScript resolves a call on an autoload at RUNTIME. `InventoryManager.get_gold()`
## parses, exports, ships, and throws `Invalid call. Nonexistent function` the
## first time a player tries to buy a boat ticket. Nine such call sites across
## seven files reached a milestone build, several of them wrapped in an
## `if Autoload:` guard that reads as defensive and guards nothing - an autoload
## registered in project.godot is never null.
##
## This walks every .gd file, finds `<AutoloadName>.<identifier>`, and resolves
## the identifier against the live singleton: method, signal, property, or
## script constant. Anything that resolves to none of those is an error.
##
## When a call really is dynamic, add it to DYNAMIC_WHITELIST with a reason.
## Do not add anything there to make a red check quiet.

const SCAN_DIRS: Array[String] = ["res://scripts", "res://tools", "res://dev"]

## Identifiers reached on an autoload that cannot be resolved by reflection.
## Format: "<AutoloadName>.<identifier>": "why".
const DYNAMIC_WHITELIST: Dictionary = {}

## Members every Object/Node carries that has_method covers, listed only so a
## reader knows they are not special-cased.
const _NOTE := "Node's own API resolves through has_method/has_signal already."

var _failures: int = 0
var _resolved: int = 0
var _sites: int = 0


func _ready() -> void:
	var autoloads: Dictionary = _collect_autoloads()
	print("autoloads registered: %d" % autoloads.size())

	var files: Array[String] = []
	for dir_path: String in SCAN_DIRS:
		_collect_gd_files(dir_path, files)
	files.sort()
	print("gdscript files scanned: %d" % files.size())
	print("")

	for file_path: String in files:
		_scan_file(file_path, autoloads)

	print("")
	print("autoload member references: %d resolved, %d call sites read" % [_resolved, _sites])
	_finish()


## ---------------------------------------------------------------------------
## Autoload discovery
## ---------------------------------------------------------------------------
func _collect_autoloads() -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in ProjectSettings.get_property_list():
		var setting: String = prop.get("name", "")
		if not setting.begins_with("autoload/"):
			continue
		var singleton_name: String = setting.substr("autoload/".length())
		var node: Node = get_node_or_null("/root/" + singleton_name)
		if node == null:
			_fail("setup", "autoload %s is registered but not present at /root/%s" % [
				singleton_name, singleton_name])
			continue
		out[singleton_name] = node
	return out


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, file_name])
	for sub: String in dir.get_directories():
		_collect_gd_files("%s/%s" % [dir_path, sub], out)


## ---------------------------------------------------------------------------
## Scanning
## ---------------------------------------------------------------------------
func _scan_file(file_path: String, autoloads: Dictionary) -> void:
	var source: String = FileAccess.get_file_as_string(file_path)
	if source.is_empty():
		return

	# Members this file explicitly tests for before reaching them. That is the
	# correct idiom for a genuinely optional member, and it cannot throw - so
	# such a reference is out of scope here, dead or not.
	var guarded: Dictionary = _collect_guarded_members(source)

	var line_no: int = 0
	for raw_line: String in source.split("\n"):
		line_no += 1
		var line: String = _strip_noise(raw_line)
		if line.is_empty():
			continue

		for singleton_name: String in autoloads:
			var from: int = 0
			while true:
				var at: int = line.find(singleton_name + ".", from)
				if at < 0:
					break
				from = at + singleton_name.length() + 1

				# Must be a whole word - not the tail of another identifier
				if at > 0 and _is_ident_char(line[at - 1]):
					continue

				var member: String = _read_identifier(line, from)
				if member.is_empty():
					continue

				if guarded.has(member):
					continue

				_sites += 1
				_check_member(file_path, line_no, singleton_name,
					autoloads[singleton_name], member)


## Names this file tests for by reflection: has_method("x"), has_signal("x"),
## or `"x" in Something`. Read off the raw source, before string literals are
## stripped - the guard's evidence IS a string literal.
func _collect_guarded_members(source: String) -> Dictionary:
	var out: Dictionary = {}
	for prefix: String in ["has_method(\"", "has_signal(\""]:
		var from: int = 0
		while true:
			var at: int = source.find(prefix, from)
			if at < 0:
				break
			from = at + prefix.length()
			var close: int = source.find("\"", from)
			if close > from:
				out[source.substr(from, close - from)] = true

	# `"member" in Autoload`
	var regex := RegEx.new()
	regex.compile("\"([A-Za-z_][A-Za-z0-9_]*)\"\\s+in\\s+[A-Z]")
	for m: RegExMatch in regex.search_all(source):
		out[m.get_string(1)] = true

	return out


## Remove comments and string literals so their contents cannot be mistaken for
## code. Erring toward dropping too much only ever loses a check, never invents
## a failure.
func _strip_noise(line: String) -> String:
	var out: String = ""
	var i: int = 0
	var in_string: bool = false
	var quote: String = ""
	while i < line.length():
		var c: String = line[i]
		if in_string:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_string = false
			i += 1
			continue
		if c == "\"" or c == "'":
			in_string = true
			quote = c
			i += 1
			continue
		if c == "#":
			break
		out += c
		i += 1
	return out


func _is_ident_char(c: String) -> bool:
	return c == "_" or (c >= "0" and c <= "9") \
		or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


func _read_identifier(line: String, start: int) -> String:
	var i: int = start
	var out: String = ""
	while i < line.length() and _is_ident_char(line[i]):
		out += line[i]
		i += 1
	if out.is_empty():
		return ""
	# A leading digit is not an identifier
	if out[0] >= "0" and out[0] <= "9":
		return ""
	return out


## ---------------------------------------------------------------------------
## Resolution
## ---------------------------------------------------------------------------
func _check_member(file_path: String, line_no: int, singleton_name: String,
		node: Node, member: String) -> void:
	var key: String = "%s.%s" % [singleton_name, member]
	if DYNAMIC_WHITELIST.has(key):
		_resolved += 1
		return

	if node.has_method(member) or node.has_signal(member):
		_resolved += 1
		return

	if member in node:
		_resolved += 1
		return

	var script: Script = node.get_script() as Script
	if script != null:
		if script.get_script_constant_map().has(member):
			_resolved += 1
			return

	_fail(file_path.get_file(), "line %d: %s.%s does not exist on the %s singleton - this throws at runtime" % [
		line_no, singleton_name, member, singleton_name])


func _fail(context: String, message: String) -> void:
	_failures += 1
	printerr("FAIL [%s]: %s" % [context, message])


func _finish() -> void:
	if _failures > 0:
		print("FAIL: %d nonexistent autoload member(s)" % _failures)
		get_tree().quit(1)
		return
	print("OK: every autoload member reached from source exists on the singleton")
	get_tree().quit(0)

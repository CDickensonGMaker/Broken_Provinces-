extends Node
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	await get_tree().process_frame
	var unknown: Dictionary = {}
	var total: int = 0
	for dir: String in ["res://data/dialogue", "res://data/dialogues"]:
		_walk(dir, unknown)
	for k: String in unknown:
		print("UNPARSED CONDITION TYPE %-24s x%d" % [k, unknown[k]])
		total += unknown[k]
	print("total unparsed condition instances: %d" % total)
	get_tree().quit(0)

func _walk(path: String, unknown: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	var e: String = dir.get_next()
	while not e.is_empty():
		var full: String = path.path_join(e)
		if dir.current_is_dir(): _walk(full, unknown)
		elif e.ends_with(".json"):
			var f := FileAccess.open(full, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			_scan(parsed, false, unknown)
		e = dir.get_next()
	dir.list_dir_end()

func _scan(v: Variant, in_cond: bool, unknown: Dictionary) -> void:
	if v is Array:
		for e: Variant in (v as Array): _scan(e, in_cond, unknown)
	elif v is Dictionary:
		var d: Dictionary = v
		if in_cond and d.get("type", null) is String:
			var t: String = d["type"]
			if DialogueLoader._parse_condition_type(t) == DialogueData.ConditionType.INVALID:
				unknown[t] = unknown.get(t, 0) + 1
		for k: Variant in d: _scan(d[k], String(k) in ["conditions", "condition"], unknown)

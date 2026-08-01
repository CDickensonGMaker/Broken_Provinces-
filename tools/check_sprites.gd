extends Node
## Sprite frame and scale check.
##
## Usage: godot --headless --path . res://tools/check_sprites.tscn
##
## Two things about a billboard sprite are declared in code and checked by
## nothing: how many poses are on the sheet, and how tall one pose stands in the
## world. Both fail quietly. A wrong h_frames does not error, it just renders the
## whole strip as one frame - a wizard becomes four wizards smeared into a seven
## metre wide poster. A wrong pixel_size does not error either, it just makes an
## innkeeper three and a half metres tall behind her own counter.
##
## So measure. Transparent gutters between poses are readable straight off the
## image, and world height is pixel_size * frame_height, which is arithmetic.

## A person should stand between these, in metres. Generous on purpose - some
## characters are meant to be big - but a 3.7m villager is not a style choice.
const MIN_HEIGHT_M := 1.4
const MAX_HEIGHT_M := 3.2

## Outside this band it is not a style choice by any reading, and the run fails.
## Everything between this and the band above is reported and left to eyes.
const ABSURD_MIN_M := 1.0
const ABSURD_MAX_M := 4.0

## A boundary between two poses should be nearly empty. Fraction of the sheet's
## mean column coverage below which a column counts as a gutter.
const GUTTER_THRESHOLD := 0.30

## Hard failures: a scale nothing could have intended.
var _problems: Array[String] = []
## Worth a look, not worth a red run - deliberate big characters, art whose poses
## are unevenly spaced, registry entries for sprites nobody has drawn yet.
var _notes: Array[String] = []
var _checked: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	# NPCs, named characters and hostages. Enemies are excluded: their sizes are
	# a balance decision, not a human-scale one.
	for entry: Dictionary in ZooRegistry.NPCS:
		_check_entry(entry)
	for entry: Dictionary in ZooRegistry.NAMED_CHARACTERS:
		_check_entry(entry)
	for entry: Dictionary in ZooRegistry.HOSTAGES:
		_check_entry(entry)

	print("")
	print("Sprite configurations checked: %d" % _checked)
	if not _notes.is_empty():
		print("Worth a look (%d):" % _notes.size())
		for line: String in _notes:
			print("  - " + line)
	if _problems.is_empty():
		print("Sprite check: OK")
	else:
		print("Sprite check: %d PROBLEMS" % _problems.size())
		for line: String in _problems:
			print("  - " + line)

	get_tree().quit(0 if _problems.is_empty() else 1)


func _check_entry(entry: Dictionary) -> void:
	var sprite_path: String = entry.get("sprite_path", "")
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		if not sprite_path.is_empty():
			# Registry rows for art that has not been drawn yet. Listed, not failed.
			_notes.append("%s has no sprite drawn yet: %s" % [entry.get("id", "?"), sprite_path])
		return

	var texture: Texture2D = load(sprite_path) as Texture2D
	if texture == null:
		_problems.append("%s: %s would not load as a texture" % [entry.get("id", "?"), sprite_path])
		return

	_checked += 1
	var entry_id: String = entry.get("id", "?")
	var declared_h: int = int(entry.get("h_frames", 1))
	var declared_v: int = int(entry.get("v_frames", 1))
	var pixel_size: float = float(entry.get("pixel_size", 0.0))

	var frame_height: int = int(texture.get_height() / float(max(1, declared_v)))
	var world_height: float = pixel_size * frame_height
	if world_height < ABSURD_MIN_M or world_height > ABSURD_MAX_M:
		_problems.append("%s stands %.2fm tall (pixel_size %.4f on a %dpx frame)" % [
			entry_id, world_height, pixel_size, frame_height
		])
	elif world_height < MIN_HEIGHT_M or world_height > MAX_HEIGHT_M:
		_notes.append("%s stands %.2fm tall - deliberate, or a leftover?" % [entry_id, world_height])

	# Advisory only. This can only test EVEN division, and several of the older
	# sheets have poses at uneven widths - it reads those as fewer frames than
	# there are. A disagreement is a reason to open the png, not a failure.
	var measured: int = _measure_frame_count(texture)
	if measured > 0 and measured != declared_h:
		_notes.append("%s declares %d frames; even division of %s reads %d" % [
			entry_id, declared_h, sprite_path.get_file(), measured
		])


## Count poses by looking for the transparent gutters between them.
## Returns 0 when the sheet has no readable gutters and nothing can be claimed.
func _measure_frame_count(texture: Texture2D) -> int:
	var image: Image = texture.get_image()
	if image == null:
		return 0
	if image.is_compressed():
		return 0

	var width: int = image.get_width()
	var height: int = image.get_height()

	var coverage: PackedInt32Array = PackedInt32Array()
	coverage.resize(width)
	var total: int = 0
	for x: int in range(width):
		var filled: int = 0
		for y: int in range(height):
			if image.get_pixel(x, y).a > 0.03:
				filled += 1
		coverage[x] = filled
		total += filled

	if total == 0:
		return 0
	var mean: float = float(total) / float(width)

	# The most frames whose every internal boundary lands on a gutter
	var best: int = 1
	for n: int in range(2, 11):
		if float(width) / float(n) < 14.0:
			break
		var all_clear: bool = true
		for i: int in range(1, n):
			var boundary: int = int(round(float(width) * float(i) / float(n)))
			var lowest: int = coverage[clampi(boundary, 0, width - 1)]
			for offset: int in [-1, 1]:
				var sample: int = clampi(boundary + offset, 0, width - 1)
				lowest = mini(lowest, coverage[sample])
			if float(lowest) / mean > GUTTER_THRESHOLD:
				all_clear = false
				break
		if all_clear:
			best = n

	return best

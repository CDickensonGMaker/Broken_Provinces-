extends Node3D
## Streaming probe - the worst frame during a three-cell walk, measured.
##
## Usage: godot --headless --path . res://tools/probes/stream_probe.tscn
##
## Written for the 8/2 playtest report of hitching as cells load. It drives the
## real CellStreamer across a real run of wilderness cells and records the worst
## frame time seen, plus the cost of each individual cell build.
##
## Headless has no renderer, so these numbers are not frame times a player would
## see - they are the CPU spike the generator puts in front of one, which is the
## thing being fixed. Compare a run against a run, not against 16.6ms.

## A run of open wilderness south-west of Elder Moor: no hand-built scene, no
## road, so every cell is a full procedural build.
const WALK: Array[Vector2i] = [
	Vector2i(-3, 3), Vector2i(-3, 4), Vector2i(-3, 5), Vector2i(-2, 5)
]

var _worst_ms: float = 0.0
var _worst_at: int = -1
var _frames: int = 0
var _total_ms: float = 0.0
var _sampling: bool = false
var _current_step: int = 0


func _ready() -> void:
	call_deferred("_run")


func _process(_delta: float) -> void:
	if not _sampling:
		return
	var ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_frames += 1
	_total_ms += ms
	if ms > _worst_ms:
		_worst_ms = ms
		_worst_at = _current_step


func _run() -> void:
	if GameManager.player_data == null:
		GameManager.player_data = CharacterData.new()

	print("")
	print("== PER-CELL BUILD COST ==")
	for coords: Vector2i in WALK:
		var start: int = Time.get_ticks_usec()
		var room: Node3D = await _build_one(coords)
		var elapsed: float = float(Time.get_ticks_usec() - start) / 1000.0
		var nodes: int = _count(room)
		print("  cell %-9s %8.2f ms   %5d nodes" % [str(coords), elapsed, nodes])
		room.queue_free()
		await _settle(2)

	# The walk: the three cells a player crosses into, built through the real
	# streamer entry point, with frame time sampled throughout.
	print("")
	print("== WORST FRAME OVER A %d-CELL WALK ==" % (WALK.size() - 1))
	# The per-cell section above queue_free()s four cells; their deferred
	# destruction lands several frames later and is not a streaming cost. Let the
	# tree go quiet before anything is called a frame time.
	await _settle(90)
	WildernessRoom.profile_slices = true
	_sampling = true
	for i: int in range(1, WALK.size()):
		_current_step = i
		await CellStreamer._load_cell(WALK[i])
		await _settle(20)
	_sampling = false
	WildernessRoom.profile_slices = false

	print("  frames sampled       %d" % _frames)
	print("  mean frame           %.2f ms" % (_total_ms / maxf(float(_frames), 1.0)))
	print("  WORST frame          %.2f ms (on step %d, entering %s)" % [
		_worst_ms, _worst_at, str(WALK[maxi(_worst_at, 1)])
	])
	get_tree().quit(0)


## One wilderness cell, built exactly the way CellStreamer builds it.
## Total wall clock, awaiting the coroutine to completion - so this is the whole
## cost of a cell, not the first slice of it. The walk section below is where
## the per-FRAME number lives.
func _build_one(coords: Vector2i) -> Node3D:
	var scene: PackedScene = load("res://scenes/generation/wilderness/wilderness_room.tscn")
	var room: Node3D = scene.instantiate() as Node3D
	var info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	room.set("biome", WorldGrid.to_wilderness_biome(info.biome if info else 0))
	if room.has_method("set_seamless_mode"):
		room.call("set_seamless_mode", true)
	add_child(room)
	room.global_position = WorldGrid.cell_to_world(coords)
	if room.has_method("generate"):
		await room.call("generate", 4242 + coords.x * 10000 + coords.y, coords)
	return room


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _settle(frames: int) -> void:
	for _i: int in frames:
		await get_tree().process_frame

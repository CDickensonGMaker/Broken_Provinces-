extends Node
## Popup instantiation check.
##
## Usage: godot --headless --path . res://tools/check_popups.tscn
##
## Note it runs as a *scene*, not with --script. Every popup in this game reaches
## for GameManager, InventoryManager or CraftingManager while it builds itself,
## and --script starts an engine with no autoloads at all, so a --script run
## would only ever prove that the autoloads are missing.
##
## Every popup builds itself in code, in _ready(), out of a hundred hand-wired
## containers. A parse pass proves nothing about that - the crash is in the
## building. So this actually instantiates each one, puts it on a canvas, lets it
## run a frame and closes it again.
##
## It cannot tell you a popup looks right. It can tell you a popup no longer
## explodes on open, which is what a base-class migration is most likely to break.

const POPUPS: Array[String] = [
	"res://scripts/ui/shop_ui.gd",
	"res://scripts/ui/bounty_board_ui.gd",
	"res://scripts/ui/crafting_ui.gd",
	"res://scripts/ui/enchanting_ui.gd",
	"res://scripts/ui/repair_station_ui.gd",
	"res://scripts/ui/chest_ui.gd",
	"res://scripts/ui/corpse_loot_ui.gd",
	"res://scripts/ui/spell_maker_ui.gd",
	"res://scripts/ui/fast_travel_ui.gd",
	"res://scripts/ui/wait_ui.gd",
	"res://scripts/ui/companion_status_ui.gd",
	"res://scripts/ui/companion_command_ui.gd",
	"res://scripts/ui/dice_roll_ui.gd",
	"res://scripts/ui/humanoid_dialogue.gd",
	"res://scripts/ui/intro_dialogue_ui.gd",
	"res://scripts/ui/dialogue_box.gd",
	"res://scripts/ui/npc_dialogue_ui.gd",
	"res://scripts/ui/conversation_ui.gd",
]
## Not listed: the panels under scripts/ui/panels/. They are pages inside
## GameMenu, not popups - they have no chrome of their own and several build
## nothing until GameMenu shows them.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	var failures: Array[String] = []
	var built: int = 0

	for path: String in POPUPS:
		var script: Script = load(path) as Script
		if script == null:
			failures.append("%s - script would not load" % path)
			continue

		var node: Node = script.new() as Node
		if node == null:
			failures.append("%s - script.new() is not a Node" % path)
			continue

		add_child(node)
		await get_tree().process_frame

		if node.get_child_count() == 0:
			failures.append("%s - built no children in _ready()" % path)
		else:
			built += 1

		# Some popups free themselves inside close(); that is legal, so re-check.
		if node.has_method("close"):
			node.call("close")
		await get_tree().process_frame
		if is_instance_valid(node):
			node.queue_free()

	# Whatever the last popup did to the pause and the mouse is not our problem
	# to inherit, but it is the next popup's, so reset before reporting.
	get_tree().paused = false

	print("")
	print("Popups checked: %d" % POPUPS.size())
	print("Popups that built a tree: %d" % built)
	if failures.is_empty():
		print("Popup check: OK")
	else:
		print("Popup check: %d FAILED" % failures.size())
		for line: String in failures:
			print("  - " + line)

	get_tree().quit(0 if failures.is_empty() else 1)

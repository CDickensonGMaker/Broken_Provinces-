# data/world

## `world_forge_map.json`

The world's land, as painted in World Forge. **`WorldGrid.initialize()` reads
this exact path**, and if it is absent the land comes from `GRID_DATA` in
`scripts/data/world_grid.gd` instead. Either way the *places* - which cell is
Dalhurst, which scene streams there, how big it is, whether it is WIP - come
from `LOCATIONS` and `LOCATION_SCENES` in that same script, and never from the
map. The map owns the land; `world_grid.gd` owns the places.

Layers: `terrain`, `road`, `biome_override`, `poi`. Only the first three are
built. `poi` is drawn in the editor for orientation and, on load, checked: a POI
naming a `location_id` that `LOCATIONS` does not declare is reported, not
created, because a named cell with nothing behind it is exactly what THE
GROUNDING LAW forbids.

`biome_override` is empty in almost every cell, and should stay that way. An
empty cell's biome is decided by `WorldGrid.biome_for_cell()` - the climate
model, latitude and moisture and a mountain mask. Paint an override only where
the climate must be overruled.

## `world_forge_map.legacy.json`

**Nothing reads this file.** It is the map that lived in
`user://world_forge_map.json` until 8/2 - 4096 painted cells and 56 POIs of real
authored work that was outside the repository, invisible to git and to the
validator, and present on exactly one machine.

It is parked here so it cannot be lost, and it is not live because it cannot be
made live as it stands. Measured (docs/audits/tool_suite_audit.md §2):

- 3296 of its 4096 painted cells fall outside `GRID_MIN..GRID_MAX`;
- 23 of its 56 places are past the edge of the world, five of which have
  hand-built scenes already sitting in `scenes/levels/`;
- 28 of its POIs carry no `scene_path`, though `LOCATION_SCENES` has one for
  most of them - the old forge path never read that table;
- 27 of its 56 places sit at a different cell than `LOCATIONS` puts them;
- it puts Dalhurst at (-10,-2) while all forty of Dalhurst's scheduled residents
  stand in (-8,-2).

Making it the world is a design decision, not a merge: either the grid grows to
hold it, or the places past the edge move inside. World Forge's **Import legacy
map** button loads it into the editor and **Check map** counts all of the above,
so the decision can be made with the numbers in front of it.

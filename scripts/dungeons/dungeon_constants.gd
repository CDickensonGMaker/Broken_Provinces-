## dungeon_constants.gd - Centralized constants for dungeon generation
class_name DungeonConstants
extends RefCounted

## Grid cell size in world units
const CELL_SIZE := Vector3(8.0, 4.0, 8.0)

## Hidden room configuration
const MIN_HIDDEN_ROOM_DEPTH := 3
const HIDDEN_ROOM_CHANCE := 0.25

## Generation defaults
const MAX_ROOMS_DEFAULT := 20
const MIN_ROOMS_DEFAULT := 8
const MAX_CORRIDOR_LENGTH := 5
const MAX_PLACEMENT_ATTEMPTS := 50

## Room frequency limits (can be overridden per room in RoomData.max_count)
const MAX_TREASURE_ROOMS := 3
const MAX_SHRINE_ROOMS := 1
const MAX_TRAP_ROOMS := 4

## Distance thresholds
const MIN_BOSS_DEPTH := 4  ## Boss must be at least this deep
const BOSS_DEPTH_TARGET := 0.8  ## Target depth ratio (0.8 = 80% of max depth)

# ADR-004: Travel Systems Architecture

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** Technical Director, Game Designer

---

## Context

The game supports multiple travel methods with different gameplay implications. Each method serves a specific player need and has unique mechanics, costs, and risks.

### Travel Methods

| Method | Status | Purpose |
|--------|--------|---------|
| Walking | Implemented | Default exploration, cell streaming |
| Fast Travel | Implemented | Instant travel to discovered locations |
| Caravan | Not Implemented | Paid travel with encounters |
| Boat | Partially Implemented | Sea travel to distant locations |

---

## Decision

### 1. Walking (Cell Streaming)

**File:** `scripts/autoload/cell_streamer.gd`

Primary exploration method. Player walks freely across cell boundaries with seamless streaming.

| Aspect | Design |
|--------|--------|
| Speed | Base walking speed |
| Cost | None |
| Risk | Enemies, terrain hazards |
| Time | Real-time |

### 2. Fast Travel

**File:** `scripts/autoload/fast_travel_manager.gd`

Instant teleportation to discovered locations. Primary convenience feature.

| Aspect | Design |
|--------|--------|
| Speed | Instant (with time passage) |
| Cost | None |
| Risk | Blocked during combat/overencumbered |
| Restrictions | Must discover location first |

**Travel Speed Options:**
- CAUTIOUS: Slower, safer, restores HP
- NORMAL: Standard speed
- RECKLESS: Faster, higher encounter chance

**Travel Mode Options:**
- ROAD: Follow roads (safer, uses pathfinding)
- DIRECT: Straight line (faster, more dangerous)

### 3. Caravan Travel (Future)

**File:** `scripts/autoload/fast_travel_manager.gd` (lines 316-480)
**Status:** Not Implemented

Paid travel via NPC-operated caravans between settlements.

| Aspect | Design |
|--------|--------|
| Speed | Moderate (time passes) |
| Cost | Gold (2-5 per cell based on danger) |
| Risk | Random encounters during travel |
| Restrictions | Must use established routes |

**Designed Pricing:**
| Danger | Gold/Cell | Encounter Chance |
|--------|-----------|------------------|
| Low | 2 | 5% |
| Medium | 3 | 15% |
| High | 5 | 25% |

**Implementation Roadmap:**
1. Parse WorldGrid roads to build route connections
2. Populate `caravan_routes` dictionary in `_load_caravan_routes()`
3. Add caravan NPC dialogue (e.g., at stables, trading posts)
4. Wire up destination selection UI
5. Implement encounter interruption system

### 4. Boat Travel (Partial)

**File:** `scripts/autoload/boat_travel_manager.gd`
**Status:** Infrastructure exists, no active routes

Sea travel for crossing water to locations like the Elven City.

| Aspect | Design |
|--------|--------|
| Speed | Moderate (time passes) |
| Cost | Gold (passage fare) |
| Risk | Pirates, ghost pirates, sea monsters |
| Restrictions | Harbor access required |

**Implementation Status:**
- BoatTravelManager autoload exists
- Dialogue action `start_boat_voyage` exists
- Route data structure defined
- NO active routes configured
- NO UI integration for booking passage

**Implementation Roadmap:**
1. Define boat routes in data file (e.g., Dalhurst Harbor -> Elven City)
2. Create Harbor Master NPCs with dialogue
3. Implement sea encounter system
4. Add voyage visualization (optional)

---

## Consequences

### Positive

1. **Player Choice** - Multiple travel options for different situations
2. **Economy Integration** - Caravan/boat costs provide gold sinks
3. **Encounter Variety** - Sea and road encounters add content
4. **Immersion** - Time passage creates realistic world feel

### Negative

1. **Complexity** - Multiple systems to maintain
2. **Incomplete Systems** - Caravan and boat not fully implemented
3. **Balance Challenge** - Must balance convenience vs. gameplay

### Mitigations

- Clear status documentation in code
- Stub methods return gracefully (no crashes)
- Fast travel always available as fallback

---

## Implementation Priority

| Priority | System | Reason |
|----------|--------|--------|
| 1 | Fast Travel | Core convenience (DONE) |
| 2 | Walking | Core exploration (DONE) |
| 3 | Boat Travel | Access to Elven City content |
| 4 | Caravan | Nice-to-have, not blocking content |

---

## Files

| File | Purpose |
|------|---------|
| `scripts/autoload/fast_travel_manager.gd` | Fast travel + caravan stubs |
| `scripts/autoload/boat_travel_manager.gd` | Boat travel infrastructure |
| `scripts/autoload/cell_streamer.gd` | Walking/streaming |
| `scripts/data/world_grid.gd` | Road and location data |

---

## Ghost System Notes

**Caravan System (Dead Code):**
- All infrastructure exists but `caravan_routes` is always empty
- `_load_caravan_routes()` is a pass stub
- Methods like `travel_by_caravan()` will always fail gracefully
- Preserved for future implementation

**Boat System (Incomplete):**
- Infrastructure exists and is functional
- Needs route data and NPC integration
- Blocked on Elven City content development

**Investigation Skill (Partial):**
- Works for hidden chest/wall detection via `get_hidden_detection_bonus()`
- "Pressing NPCs for info" dialogue feature not implemented
- Documented in POST-RELEASE features

---

## References

- [ADR-001: Cell-Based World Streaming](001-cell-streaming.md)
- [World System GDD](../gdd/world-system.md)
- Daggerfall Unity travel system


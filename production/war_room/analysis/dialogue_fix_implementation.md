# Dialogue Architecture P0 Fixes — Implementation Log

Implements the three P0 items from `dialogue_quest_master.md` (HEADLINE FINDING + §1).
Scope: `scripts/autoload/conversation_system.gd` and `scripts/dialogue/conversation_response.gd` only.
No content files were edited (weather.tres loaded as-is; career_greetings.json / career_topics.json untouched).

## Files changed

- `scripts/autoload/conversation_system.gd`
- `scripts/dialogue/conversation_response.gd`

---

## Fix 1 — Persistent anti-repeat

**Problem:** `_filter_responses()` only excluded responses in `current_context.discussed_responses`
(reset every `start_conversation()`). The persistent `npc_memory` dict was written to but never
read back during filtering, so walking away and returning let the exact same line replay
immediately.

**Change:** `conversation_system.gd:2224` (`_filter_responses`), rewritten as a tiered fallback
instead of a single pass/fail filter:

1. **Eligibility pass** (unchanged criteria: disposition range, knowledge tags, scripted
   conditions) plus the new archetype hard-filter (Fix 2c) → `eligible`.
2. Exclude anything already said **this conversation** (`discussed_responses`) → `not_this_session`.
   If that empties the set (tiny pool, player asked the same topic repeatedly in one sitting),
   fall back to `eligible` rather than returning nothing.
3. **New:** from `not_this_session`, exclude anything present in `npc_memory` (told in *any* past
   conversation with this NPC) → `never_heard`. If non-empty, return it — this is the fix: brand
   new lines are now preferred across separate conversations, not just within one.
4. **Critical fallback:** if `never_heard` is empty (player has heard every eligible line before),
   return `_least_heard_subset(not_this_session, npc_id)` — the subset of `not_this_session` with
   the lowest `npc_memory_heard_count`. The pool is never empty as long as `eligible` was non-empty.

Supporting additions:
- New state dict `npc_memory_heard_count: Dictionary` (`"npc_id:response_id" -> int`), a **separate**
  dictionary from `npc_memory` — deliberately not folded into `npc_memory`'s value, so the existing
  save format (`npc_memory` maps to the last-said text, used by the reminder UI) is untouched.
  Incremented alongside the existing `npc_memory[memory_key] = injected_text` write in
  `select_topic()` (`conversation_system.gd:754-760`).
- `_least_heard_subset()`, `_get_heard_count()` — new small helpers.
- `to_dict()` / `from_dict()` / `reset_for_new_game()` updated to persist/clear
  `npc_memory_heard_count` as an **additive** save key. Old saves without this key load fine
  (`data.get("npc_memory_heard_count", {})`); `npc_memory`'s own shape is unchanged.

**Fallback semantics, precisely:** never-empty is guaranteed *provided at least one response in the
input array passes disposition/knowledge/condition/archetype gating*. If `eligible` itself is empty
(e.g. no response in the pool matches this NPC's disposition), `_filter_responses` still returns
empty — that pre-existing edge case is handled one layer up, where `select_response()` /
`get_greeting()` / `get_farewell()` already have hardcoded text fallbacks for an empty filtered list.
That upstream safety net was not touched.

**memory_reminder signal:** unchanged. `select_topic()` still checks `npc_memory.has(memory_key)`
*after* a response is chosen and fires `memory_reminder.emit(response_id, original_text)` with the
same payload as before. The practical effect of Fix 1 is that this now fires far less often (only
in the last-resort fallback tier), but the signal's firing condition and contract are identical.

---

## Fix 2 — Real archetype tier

**Problem:** `register_archetype_response()` / `register_unique_response()` were never called.
`career_greetings.json` / `career_topics.json` content (clearly archetype-authored, e.g.
`greeting_merchant_to_noble`, `topic_priest_temple_secrets`) was being parsed and dumped into
either the generic pool or — worse, for `career_greetings.json` specifically — into
`response_pools[GOODBYE]` (topic_type `7` in that file), a pool that `select_response()` never
actually queries, since `GOODBYE` is handled by `get_farewell()`/`farewell_pool` instead. That
content was **fully inert**, not merely unfiltered.

**(a) Routing at load time** — `conversation_system.gd:288` (`_load_responses_from_dict`):
- New `_resolve_archetype_for_response(pool_id, response_id)` (line ~404) computes an archetype
  from the response_id, gated on `pool_id`:
  - `career_greetings.json`: response_id format is `"greeting_<archetype>_to_<player_career>"`.
    `_parse_greeting_archetype_token()` extracts the token before `"_to_"` directly
    (e.g. `greeting_merchant_to_noble` → `"merchant"`). All 23 entries in the file follow this
    format and all resolve (verified against the live JSON — see note below).
  - `career_topics.json`: response_id format is `"topic_<player_career_token>_<label>"` — the
    career token doesn't always equal an NPC archetype name. `_parse_topic_archetype_token()`
    extracts the first token (checking a two-word token like `grave_digger` first) and looks it
    up in `ARCHETYPE_TOKEN_MAP` (line ~62). 23 of 27 entries resolve to a real archetype
    (`thief`→THIEF, `priest`→PRIEST, `merchant`→MERCHANT, `farmer`→FARMER, `noble`→NOBLE,
    `beggar`→BEGGAR, plus the career-token equivalents `soldier`→GUARD, `scout`→HUNTER,
    `apprentice`→SCHOLAR, `alchemist`→SCHOLAR). The 4 `cultist`/`grave_digger` entries have no
    corresponding NPC archetype in `NPCKnowledgeProfile.Archetype`, so they intentionally resolve
    to `-1` and stay in the generic pool — this matches the instruction that untagged responses
    remain generic/available to all, rather than guessing a wrong mapping.
  - Verified by replicating the exact parsing logic in a standalone script against the live JSON:
    `career_greetings.json` → 23/23 resolved; `career_topics.json` → 23/27 resolved, 4 generic
    (cultist ×2, grave_digger ×2). No other pool file's response_ids are touched by this logic —
    `_resolve_archetype_for_response` returns `-1` immediately unless `pool_id` is exactly
    `career_greetings` or `career_topics`.
- Routing decision (line ~348): `career_topics` entries that resolved an archetype go through
  `register_archetype_response(archetype, topic_type, response)` (the previously-dead API is now
  live). `career_greetings` entries — resolved or not — go into the existing flat `greeting_pool`,
  because greetings have no `TopicType` dimension to key an `archetype_pools` bucket by; they rely
  on the hard filter below instead (documented as a deliberate deviation, see "What I did NOT do").
  Everything else (unresolved career_topics tokens, and all other pool files) keeps going through
  `register_response()` into the generic pool exactly as before.

**(b) Tier preference order** — `select_response()` (`conversation_system.gd:778`) already tried
unique → archetype → generic in that order; this was correct, dead code notwithstanding. No change
needed there — it was inert only because the dictionaries it reads (`unique_responses`,
`archetype_pools`) were always empty. They are no longer empty for `career_topics`-sourced content.

**(c) Hard archetype filter** — new `ConversationResponse.required_archetype: int` field
(`conversation_response.gd:32`, default `-1` = "no restriction"), set at load time to the resolved
archetype (or `-1`). New `_check_archetype_match()` (`conversation_system.gd:2329`) is called inside
the eligibility pass of `_filter_responses()`, so it applies uniformly to the generic pool, the
archetype pool, and the shared `greeting_pool`/`farewell_pool` — a response tagged for one archetype
is hard-excluded for every other archetype (and for NPCs with no profile at all — fails closed
rather than assuming a match). Untagged responses (`-1`, i.e. everything that existed before this
change, plus the 4 unresolved career_topics entries) are unaffected and remain available to any NPC,
exactly as `calculate_personality_score()`'s weight-only bonus already worked for personality tags.

`calculate_personality_score()` in `conversation_response.gd` was **not** modified — it continues to
give a weight bonus for personality-trait overlap; `required_archetype` is a separate, harder gate
that answers "can this NPC say this at all," not "how likely is this NPC to pick it."

---

## Fix 3 — weather.tres

**Problem:** `data/conversation_pools/weather.tres` (21 authored responses) was never loaded — the
JSON-only loader never touched it, and `WEATHER` was never added to `get_available_topics()`.

**Change:**
- `_load_response_pools()` (`conversation_system.gd:265`): after the JSON pool loop, loads
  `weather.tres` via `load(...) as ConversationResponsePool` and passes it through the existing
  (already-correct, previously-unused) `_register_pool()` path. Falls back to a `push_warning` if
  the resource fails to load or the file is missing — nothing crashes either way.
- `get_available_topics()` (`conversation_system.gd:564`): appends `ConversationTopic.WEATHER` for
  all non-guard NPCs, right after the TRADE checks (a "low priority", always-available topic, per
  the instruction — no knowledge-tag gate, matching how the .tres content itself has no
  `required_knowledge` gate on most entries). Guards still return early with `[DIRECTIONS, GOODBYE]`
  only, unchanged.
- The `.tres` file loaded cleanly on inspection — well-formed `ConversationResponsePool` resource,
  21 sub-resources match the 21 entries in the pool's `responses` array, every field present and
  typed correctly against `ConversationResponse`'s exports. No JSON conversion was needed.
- Verified via a full headless project boot (`Godot_v4.6.2 --headless --path . --check-only`):
  zero compile/parse errors anywhere in the project, and specifically no errors referencing
  `conversation_system.gd`, `conversation_response.gd`, `ConversationResponse`, or
  `NPCKnowledgeProfile` (the pre-existing errors in that run are unrelated missing-imported-texture
  /audio-cache issues in `game_manager.gd`/`scene_manager.gd`/`audio_manager.gd`/`title_screen.gd`,
  present before this change and outside this task's scope).

---

## What I deliberately did NOT do

- **Did not add a parallel archetype-keyed greeting tier.** `career_greetings.json` content is
  gated via the `required_archetype` hard-filter on the shared `greeting_pool`/`_filter_responses`
  path rather than via `register_archetype_response()` into a new "greeting" bucket, because
  greetings have no `TopicType` to key such a bucket by and the hard filter achieves the same
  practical outcome (an archetype-mismatched greeting line can never be selected) with much less
  new surface area. Flagging this since it's a deviation from literally calling
  `register_archetype_response()` for *all* career content, though it satisfies the stated intent.
- **Did not touch `career_greetings.json`/`career_topics.json` content or `NPCKnowledgeProfile`
  archetype factory functions.** Per the task constraint, no new content authoring.
- **Did not fix a pre-existing content/design tension surfaced while tracing this:**
  `career_topics.json` has `soldier`-token entries (now correctly routed to the `GUARD` archetype
  pool) tagged with `topic_type: 0` (LOCAL_NEWS) and `topic_type: 1` (RUMORS). Guards, however,
  return early from `get_available_topics()` with only `[DIRECTIONS, GOODBYE]` (an existing,
  explicitly documented design rule in `CLAUDE.md`), so these specific lines are now correctly
  *wired* but still practically unreachable for pure GUARD-archetype NPCs — a content/topic-gating
  conflict between two already-documented systems, not something introduced by this pass. Worth a
  follow-up design decision (loosen guard topics for this content, or accept it stays dormant like
  weather.tres did until now).
- **Did not change `calculate_personality_score()`** — personality-trait weighting and the new
  hard archetype gate are independent, complementary mechanisms.
- **Did not change quest/bounty response construction** (`_handle_bounty_topic`,
  `_handle_quest_topic`, `select_custom_topic`) — those build `ConversationResponse` objects
  on the fly and emit them directly, bypassing `_filter_responses`/`select_response` entirely, so
  none of the three fixes touch that path (`required_archetype` defaults to `-1` for them, correct).

---

## Verification performed

- Read back every edited region for tab-indentation consistency (`cat -A` spot checks) and
  explicit-typing per `CLAUDE.md`'s GDScript pitfalls (typed loop vars, typed `Dictionary.get()`
  results, no `:=` on comparisons/enum casts).
  - `register_archetype_response()` expects `NPCKnowledgeProfile.Archetype`; the resolved value is
    computed as `int` (from `ARCHETYPE_TOKEN_MAP`) and explicitly cast
    (`resolved_archetype as NPCKnowledgeProfile.Archetype`) at the one call site that needs it.
- `git diff --stat` confirms only the two intended files changed.
- Full headless project boot (`--check-only`, no `--script` isolation) — all autoloads
  (including `ConversationSystem`) initialize with zero script compile/parse errors.
- Replicated `_parse_greeting_archetype_token`/`_parse_topic_archetype_token` logic in a standalone
  script against the live `career_greetings.json`/`career_topics.json` to confirm exact resolution
  counts (23/23 and 23/27 respectively) before trusting the in-engine behavior.
- Confirmed `_filter_responses`'s 5 call sites (`select_response` ×3 tiers, `get_greeting`,
  `get_farewell`) all still call it with the same `(candidates, profile, disposition) -> Array`
  shape — no caller assumed the old single-pass filtering behavior in a way that breaks.
- Confirmed `memory_reminder` signal's firing condition/payload in `select_topic()` is untouched.

## What a human should playtest

1. **Persistent anti-repeat (Fix 1):** Talk to any generic civilian (e.g. a Millbrook or Elder Moor
   villager), ask LOCAL_NEWS or PERSONAL 3-4 times in one sitting (should already not repeat —
   pre-existing behavior), say GOODBYE, walk away, come back, and ask the same topic again
   immediately. Confirm you get a **different** line than any you've already heard, not an instant
   repeat. Keep re-asking across several separate conversations until you've plausibly heard
   everything in that topic's eligible pool for that NPC/disposition — confirm the conversation
   never dead-ends with "I'm not sure what to say about that" and instead starts recycling lines
   (this is the least-heard fallback kicking in, which is expected/correct, not a bug).
2. **Archetype tier (Fix 2):** Start a new game as a Thief-career character, talk to a GUARD-
   archetype NPC (e.g. a town guard), and confirm the guard's greeting can now show
   `greeting_guard_to_thief` ("Hold there. You have the look of trouble about you.") — previously
   this line was dead. Then talk to a MERCHANT-archetype NPC as a Merchant-career character and ask
   RUMORS repeatedly to try to surface `topic_merchant_trade_secrets`/`topic_merchant_smuggling`/
   `topic_merchant_contacts` (requires disposition ≥60 and the `trade`/`prices` knowledge tags on
   that NPC's profile). Separately, confirm a FARMER-archetype NPC never produces a `merchant_to_*`
   or `guard_to_*` greeting line (the hard filter should exclude it outright, not just downweight
   it).
3. **Weather (Fix 3):** Talk to any non-guard NPC and confirm a "Weather" option now appears in the
   topic menu, and selecting it produces one of the 21 `weather.tres` lines (e.g. "Gray skies again
   today..."). Confirm guards still do NOT get a Weather option (only Directions/Goodbye).

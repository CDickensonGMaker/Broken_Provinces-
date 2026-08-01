# Per-NPC conversation pools (tier 1)

Drop a `.json` file in this folder and ConversationSystem loads it at startup.
Nothing needs to be registered in code.

A response in one of these files is offered **only** by the NPC(s) named on it,
and it is offered **before** anything from that NPC's archetype or from the
generic pool. That is the whole point of the tier: a named character answers in
his own words, and only falls back to his trade's stock line when he has nothing
of his own to say about the topic.

## Format

```json
{
  "pool_id": "unique_tharin",
  "npc_id": "tharin_holt",
  "responses": [
    {
      "response_id": "tharin_personal_mill",
      "topic_type": 2,
      "text": "The mill was my father's. I've not been able to look at it since.",
      "min_disposition": 40,
      "weight": 1.0
    }
  ]
}
```

| Field | Where | Meaning |
|---|---|---|
| `npc_id` | pool or response | The NPC this content belongs to. On the pool it applies to every response in the file. |
| `npc_ids` | pool or response | Several NPCs share the line (a pair of guards, a family). |
| `archetype` | pool or response | Only meaningful in the shared pools; a tier-1 response is already narrower than an archetype. Accepts a name (`"priest"`) or the raw enum int. |
| `response_id` | response | **Must be unique game-wide.** It is the anti-repeat key: the memory entry is `npc_id:response_id`, so a duplicate id makes two different lines share one memory. |
| `topic_type` | response | `ConversationTopic.TopicType` int. |

Everything else a response can carry - `min_disposition`, `max_disposition`,
`required_knowledge`, `personality_affinity`, `weight`, `conditions`, `actions`,
`unlock_topics` - works here exactly as it does in the shared pools.

## What `npc_id` has to match

Whatever `ConversationSystem._get_npc_id()` returns for that NPC: its
`get_npc_id()`, else its `npc_id` property, else its `unique_id`, else its node
name. Check the NPC before writing the file; a typo does not error, it just
makes the whole file dead content that nobody ever hears.

## Verify

```
_tools\godot45\Godot_v4.5-stable_win64_console.exe --headless --path . res://tools/check_conversation_tiers.tscn
```

It prints how many responses landed in each tier and how many files it found here.

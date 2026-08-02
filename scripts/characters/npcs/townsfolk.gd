## townsfolk.gd - One-call spawner for the province's ordinary residents.
##
## Roughly forty quest chains name a role rather than a person: "the merchant in
## Dalhurst", "the healer in Millbrook", "the shepherd on the pasture". Each of
## those needs the same six things - a name, an id, a place to stand, a faction,
## a conversation archetype and one line in their own voice - and nothing else.
## Writing that out longhand per resident is ninety per cent boilerplate, so it
## lives here once.
##
## The argument order matches QuestGiver.spawn_quest_giver deliberately: the id
## is argument index 3, which is where tools/validate_content.gd looks for it.
class_name Townsfolk
extends RefCounted


## Spawns a named resident who can hold quests, be a talk target, or both.
##
## [param traits] and [param knowledge_tags] feed the conversation tiers, so the
## resident answers RUMORS and LOCAL_NEWS in their trade's voice without anyone
## writing a dialogue tree for them.
##
## [param is_female] is only needed for a woman whose given name is not in the
## gendered name pools and who carries no female title - QuestGiver reads the name
## otherwise. Getting it wrong costs a sprite, not a crash.
static func spawn_townsfolk(
	parent: Node,
	pos: Vector3,
	display_name: String,
	npc_id: String,
	zone_id: String,
	faction_id: String,
	archetype: NPCKnowledgeProfile.Archetype,
	traits: Array[String],
	knowledge_tags: Array[String],
	line: String,
	quest_ids: Array[String] = [],
	is_talk_target: bool = false,
	disposition: int = 50,
	speech_style: String = "casual",
	is_female: bool = false
) -> QuestGiver:
	var npc: QuestGiver = QuestGiver.spawn_quest_giver(
		parent,
		pos,
		display_name,
		npc_id,
		null,
		8, 2,
		quest_ids,
		is_talk_target,
		0.0,
		"",
		is_female
	)
	if not npc:
		push_warning("[Townsfolk] Failed to spawn %s" % npc_id)
		return null

	npc.region_id = zone_id
	npc.faction_id = faction_id
	npc.no_quest_dialogue = line

	var profile := NPCKnowledgeProfile.new()
	profile.archetype = archetype
	profile.personality_traits = traits
	profile.knowledge_tags = knowledge_tags
	profile.base_disposition = disposition
	profile.speech_style = speech_style
	npc.npc_profile = profile
	return npc

class_name EnemyIntentExecutor
extends RefCounted

const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")


func execute(intent: RefCounted, battle: RefCounted) -> int:
	assert(intent != null and battle != null, "Intent execution requires intent and battle")
	battle.enemy_intent_delayed = false
	match intent.kind:
		EnemyIntentScript.Kind.ATTACK:
			return battle.hero.take_damage(intent.value)
		EnemyIntentScript.Kind.HEAL:
			return battle.enemy.heal(intent.value)
		EnemyIntentScript.Kind.SPECIAL, EnemyIntentScript.Kind.PREPARE:
			if (
				intent.kind == EnemyIntentScript.Kind.SPECIAL
				and battle.enemy.is_boss
				and battle.hero.has_relic(RelicDefinitionScript.Id.MIRROR_SHARD)
				and battle.hero.mirror_shard_available
			):
				battle.hero.mirror_shard_available = false
				battle.enemy_intent_delayed = true
				return 0
			if intent.action.is_valid():
				var action_result: Variant = intent.action.call(battle, intent.value)
				if action_result is int:
					return action_result
			return intent.value
	return 0

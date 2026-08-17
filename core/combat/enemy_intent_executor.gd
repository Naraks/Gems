class_name EnemyIntentExecutor
extends RefCounted

const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")


func execute(intent: RefCounted, battle: RefCounted) -> int:
	assert(intent != null and battle != null, "Intent execution requires intent and battle")
	match intent.kind:
		EnemyIntentScript.Kind.ATTACK:
			return battle.hero.take_damage(intent.value)
		EnemyIntentScript.Kind.HEAL:
			return battle.enemy.heal(intent.value)
		EnemyIntentScript.Kind.SPECIAL, EnemyIntentScript.Kind.PREPARE:
			if intent.action.is_valid():
				intent.action.call(battle, intent.value)
			return intent.value
	return 0

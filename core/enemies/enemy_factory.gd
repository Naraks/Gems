class_name EnemyFactory
extends RefCounted

const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")

var rules: Resource


func _init(economy_rules: Resource = null) -> void:
	rules = economy_rules if economy_rules != null else load("res://data/economy_rules.tres")


func create(definition: Resource, battle_number: int, weakness_multiplier := 1.5) -> RefCounted:
	assert(definition != null and definition.is_valid(), "Enemy factory requires valid definition")
	assert(battle_number >= 1, "Battle number starts at one")
	var enemy_health: int = ceili(rules.enemy_health(battle_number, definition.is_boss) * definition.health_multiplier)
	var enemy_damage: int = ceili(rules.enemy_damage(battle_number, definition.is_boss) * definition.damage_multiplier)
	var enemy = EnemyStateScript.new(enemy_health)
	enemy.definition = definition
	enemy.base_damage = enemy_damage
	enemy.experience_reward = ceili(rules.enemy_experience(battle_number) * definition.experience_multiplier)
	enemy.base_coin_reward = rules.enemy_coins(battle_number) + definition.coin_bonus
	enemy.is_boss = definition.is_boss
	enemy.configure_affinities(definition.weakness_type, definition.resistance_type, weakness_multiplier)
	return enemy

class_name EnemyFactory
extends RefCounted

const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")


func create(definition: Resource, battle_number: int, weakness_multiplier := 1.5) -> RefCounted:
	assert(definition != null and definition.is_valid(), "Enemy factory requires valid definition")
	assert(battle_number >= 1, "Battle number starts at one")
	var cycle := floori(float(battle_number - 1) / 30.0)
	var health_value := 45.0 * pow(1.075, battle_number - 1) * pow(1.025, cycle)
	var damage_value := 8.0 * pow(1.055, battle_number - 1) * pow(1.015, cycle)
	if definition.is_boss:
		health_value *= 2.4
		damage_value *= 1.15
	var enemy_health := ceili(health_value)
	var enemy_damage := ceili(damage_value)
	var enemy = EnemyStateScript.new(enemy_health)
	enemy.definition = definition
	enemy.base_damage = enemy_damage
	enemy.experience_reward = ceili(18.0 * pow(1.045, battle_number - 1))
	enemy.base_coin_reward = 5 + floori(float(battle_number) / 3.0)
	enemy.is_boss = definition.is_boss
	enemy.configure_affinities(definition.weakness_type, definition.resistance_type, weakness_multiplier)
	return enemy

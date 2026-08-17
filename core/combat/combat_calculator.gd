class_name CombatCalculator
extends RefCounted

const CalculatedEffectsScript = preload("res://core/combat/calculated_effects.gd")
const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")


func calculate(board_result: RefCounted, hero: RefCounted, enemy: RefCounted) -> RefCounted:
	assert(board_result != null and hero != null and enemy != null, "CombatCalculator requires effects and combatants")
	var calculated = CalculatedEffectsScript.new()
	calculated.physical_damage = _calculate_damage_components(
		board_result.physical_components,
		hero.sword_power * enemy.physical_damage_multiplier,
		hero,
		RelicDefinitionScript.Id.RUBY_HILT,
	)
	calculated.magic_damage = _calculate_damage_components(
		board_result.magic_components,
		hero.magic_power * enemy.magic_damage_multiplier,
		hero,
		RelicDefinitionScript.Id.SAPPHIRE_LENS,
	)
	calculated.healing = _calculate_components(board_result.healing_components, hero.healing_power)
	calculated.coins = _calculate_components(board_result.coin_components, hero.coin_multiplier)
	if hero.has_relic(RelicDefinitionScript.Id.PROSPECTOR_HAMMER):
		calculated.coins += board_result.enhanced_match_count * 2
	return calculated


func _calculate_damage_components(components: Array[float], multiplier: float, hero: RefCounted, relic_id: int) -> int:
	var total := 0
	for index in components.size():
		var relic_multiplier := 1.0
		if index == 0 and hero.has_relic(relic_id):
			if relic_id == RelicDefinitionScript.Id.RUBY_HILT and hero.first_sword_relic_available:
				relic_multiplier = 1.5
				hero.first_sword_relic_available = false
			elif relic_id == RelicDefinitionScript.Id.SAPPHIRE_LENS and hero.first_magic_relic_available:
				relic_multiplier = 1.5
				hero.first_magic_relic_available = false
		total += ceili(components[index] * multiplier * relic_multiplier)
	return total


func _calculate_components(components: Array[float], multiplier: float) -> int:
	var total := 0
	for component in components:
		total += ceili(component * multiplier)
	return total

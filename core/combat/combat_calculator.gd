class_name CombatCalculator
extends RefCounted

const CalculatedEffectsScript = preload("res://core/combat/calculated_effects.gd")


func calculate(board_result: RefCounted, hero: RefCounted, enemy: RefCounted) -> RefCounted:
	assert(board_result != null and hero != null and enemy != null, "CombatCalculator requires effects and combatants")
	var calculated = CalculatedEffectsScript.new()
	calculated.physical_damage = _calculate_components(
		board_result.physical_components,
		hero.sword_power * enemy.physical_damage_multiplier,
	)
	calculated.magic_damage = _calculate_components(
		board_result.magic_components,
		hero.magic_power * enemy.magic_damage_multiplier,
	)
	calculated.healing = _calculate_components(board_result.healing_components, hero.healing_power)
	calculated.coins = _calculate_components(board_result.coin_components, hero.coin_multiplier)
	return calculated


func _calculate_components(components: Array[float], multiplier: float) -> int:
	var total := 0
	for component in components:
		total += ceili(component * multiplier)
	return total

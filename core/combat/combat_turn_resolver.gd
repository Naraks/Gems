class_name CombatTurnResolver
extends RefCounted

const CombatTurnResultScript = preload("res://core/combat/combat_turn_result.gd")
const CombatCalculatorScript = preload("res://core/combat/combat_calculator.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")

var _calculator := CombatCalculatorScript.new()


func resolve(board_result: RefCounted, battle: RefCounted, enemy_action: Callable = Callable()) -> RefCounted:
	assert(board_result != null and battle != null, "Combat turn requires board result and battle")
	assert(not battle.is_over, "Cannot resolve a finished battle")
	var result = CombatTurnResultScript.new()
	var calculated = _calculator.calculate(board_result, battle.hero, battle.enemy)

	result.phase_order.append("damage")
	result.physical_damage_applied = battle.enemy.take_damage(calculated.physical_damage)
	result.magic_damage_applied = battle.enemy.take_damage(calculated.magic_damage)
	var attack_type := AttackTypeScript.Kind.NONE
	if not board_result.physical_components.is_empty():
		attack_type = AttackTypeScript.Kind.PHYSICAL
	elif not board_result.magic_components.is_empty():
		attack_type = AttackTypeScript.Kind.MAGIC
	var reveal: RefCounted = battle.enemy.reveal_weakness_from_attack(attack_type)
	result.weakness_revealed = reveal.revealed
	result.weakness_hit = reveal.hit_weakness
	result.weakness_inferred = reveal.inferred
	result.weakness_type = reveal.weakness_type

	result.phase_order.append("healing")
	result.healing_applied = battle.hero.heal(calculated.healing)

	result.phase_order.append("coins")
	battle.hero.add_coins(calculated.coins)
	result.coins_granted = calculated.coins

	if not battle.enemy.is_defeated() and enemy_action.is_valid():
		result.phase_order.append("enemy_response")
		result.enemy_intent = battle.enemy.current_intent
		enemy_action.call(battle)
		battle.enemy_actions_executed += 1
		result.enemy_responded = true

	result.phase_order.append("final_checks")
	_apply_final_checks(battle, result)
	return result


func _apply_final_checks(battle: RefCounted, result: RefCounted) -> void:
	if battle.hero.is_defeated():
		battle.finish_defeat()
	elif battle.enemy.is_defeated():
		battle.finish_victory()
	battle.level_up_pending = battle.hero.can_level_up()
	result.victory = battle.victory
	result.defeat = battle.defeat
	result.level_up_pending = battle.level_up_pending

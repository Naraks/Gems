class_name CombatTurnResolver
extends RefCounted

const CombatTurnResultScript = preload("res://core/combat/combat_turn_result.gd")


func resolve(board_result: RefCounted, battle: RefCounted, enemy_action: Callable = Callable()) -> RefCounted:
	assert(board_result != null and battle != null, "Combat turn requires board result and battle")
	assert(not battle.is_over, "Cannot resolve a finished battle")
	var result = CombatTurnResultScript.new()

	result.phase_order.append("damage")
	result.physical_damage_applied = battle.enemy.take_damage(board_result.total_physical_damage)
	result.magic_damage_applied = battle.enemy.take_damage(board_result.total_magic_damage)

	result.phase_order.append("healing")
	result.healing_applied = battle.hero.heal(board_result.total_healing)

	result.phase_order.append("coins")
	battle.hero.add_coins(board_result.total_coins)
	result.coins_granted = board_result.total_coins

	if not battle.enemy.is_defeated() and enemy_action.is_valid():
		result.phase_order.append("enemy_response")
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

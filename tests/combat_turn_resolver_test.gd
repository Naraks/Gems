extends SceneTree

const BattleStateScript = preload("res://core/combat/battle_state.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const CombatTurnResolverScript = preload("res://core/combat/combat_turn_resolver.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")


func _init() -> void:
	var failed := false
	var resolver = CombatTurnResolverScript.new()

	var killing_effects = _effects(30, 10, 20, 9)
	var victory_battle = BattleStateScript.new(HeroStateScript.new(100, 50), EnemyStateScript.new(40))
	var cancelled_responses: Array = []
	var victory_result = resolver.resolve(killing_effects, victory_battle, func(_battle: RefCounted) -> void: cancelled_responses.append(true))
	failed = _check(victory_result.phase_order == PackedStringArray(["damage", "healing", "coins", "final_checks"]), "Effects use damage, healing, coins order") or failed
	failed = _check(victory_battle.enemy.health == 0, "Damage defeats the enemy") or failed
	failed = _check(victory_battle.hero.health == 70 and victory_battle.hero.coins == 9, "Healing and coins apply before final checks") or failed
	failed = _check(cancelled_responses.is_empty() and not victory_result.enemy_responded, "Defeated enemy response is cancelled") or failed
	failed = _check(victory_result.victory and victory_battle.is_over, "Enemy defeat completes battle with victory") or failed

	var defeat_battle = BattleStateScript.new(HeroStateScript.new(100, 50), EnemyStateScript.new(100))
	var observed_before_response: Array = []
	var defeat_result = resolver.resolve(_effects(10, 0, 20, 3), defeat_battle, func(battle: RefCounted) -> void:
		observed_before_response.append([battle.enemy.health, battle.hero.health, battle.hero.coins])
		battle.hero.take_damage(80)
	)
	failed = _check(observed_before_response == [[90, 70, 3]], "Enemy responds after all player effects") or failed
	failed = _check(defeat_result.phase_order == PackedStringArray(["damage", "healing", "coins", "enemy_response", "final_checks"]), "Final checks happen after enemy response") or failed
	failed = _check(defeat_result.defeat and defeat_battle.is_over, "Hero defeat completes battle") or failed
	failed = _check(defeat_battle.enemy_actions_executed == 1, "Enemy action executes exactly once") or failed

	var level_hero = HeroStateScript.new(100)
	level_hero.experience = 40
	var level_battle = BattleStateScript.new(level_hero, EnemyStateScript.new(100))
	var level_result = resolver.resolve(_effects(0, 0, 0, 0), level_battle, func(_battle: RefCounted) -> void: pass)
	failed = _check(level_result.level_up_pending and level_battle.level_up_pending, "Level-up availability is checked after response") or failed

	var response_victory = BattleStateScript.new(HeroStateScript.new(100), EnemyStateScript.new(20))
	var response_result = resolver.resolve(_effects(0, 0, 0, 0), response_victory, func(battle: RefCounted) -> void: battle.enemy.take_damage(20))
	failed = _check(response_result.enemy_responded and response_result.victory, "Battle completion is checked after enemy action") or failed

	quit(1 if failed else 0)


func _effects(physical: int, magic: int, healing: int, coins: int) -> RefCounted:
	var result = BoardResolutionResultScript.new()
	result.total_physical_damage = physical
	result.total_magic_damage = magic
	result.total_healing = healing
	result.total_coins = coins
	return result


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

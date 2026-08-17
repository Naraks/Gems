extends SceneTree

const BattleStateScript = preload("res://core/combat/battle_state.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const CombatTurnResolverScript = preload("res://core/combat/combat_turn_resolver.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")


func _init() -> void:
	var failed := false
	var resolver = CombatTurnResolverScript.new()

	var weak_enemy = EnemyStateScript.new(100)
	weak_enemy.configure_affinities(AttackTypeScript.Kind.PHYSICAL)
	var weak_battle = BattleStateScript.new(HeroStateScript.new(100), weak_enemy)
	var physical = BoardResolutionResultScript.new()
	physical.physical_components.append(10.0)
	var weak_result = resolver.resolve(physical, weak_battle)
	failed = _check(weak_result.physical_damage_applied == 15, "Weakness multiplies damage by 1.50 before reveal") or failed
	failed = _check(weak_result.weakness_revealed and weak_result.weakness_hit and not weak_result.weakness_inferred, "Matching first attack reveals weakness directly") or failed
	failed = _check(weak_enemy.weakness_display() == "меч", "Revealed weakness is visible") or failed

	var inferred_enemy = EnemyStateScript.new(100)
	inferred_enemy.configure_affinities(AttackTypeScript.Kind.PHYSICAL)
	var inferred_battle = BattleStateScript.new(HeroStateScript.new(100), inferred_enemy)
	var magic = BoardResolutionResultScript.new()
	magic.magic_components.append(10.0)
	var inferred_result = resolver.resolve(magic, inferred_battle)
	failed = _check(inferred_result.magic_damage_applied == 10, "Non-weak attack keeps normal damage") or failed
	failed = _check(inferred_result.weakness_revealed and inferred_result.weakness_inferred and not inferred_result.weakness_hit, "Other first attack reveals weakness by exclusion") or failed

	var resistant_enemy = EnemyStateScript.new(100)
	resistant_enemy.configure_affinities(AttackTypeScript.Kind.PHYSICAL, AttackTypeScript.Kind.MAGIC)
	var resistant_battle = BattleStateScript.new(HeroStateScript.new(100), resistant_enemy)
	var resistant_result = resolver.resolve(magic, resistant_battle)
	failed = _check(resistant_result.magic_damage_applied == 7, "Boss resistance multiplies damage by 0.65 and rounds up") or failed

	var executor = EnemyIntentExecutorScript.new()
	var intent_enemy = EnemyStateScript.new(100, 60)
	var intent_battle = BattleStateScript.new(HeroStateScript.new(100), intent_enemy)
	var attack = EnemyIntentScript.new(EnemyIntentScript.Kind.ATTACK, 8)
	intent_enemy.current_intent = attack
	failed = _check(attack.display_text() == "Атака: 8", "Attack intent shows its exact value") or failed
	executor.execute(intent_enemy.current_intent, intent_battle)
	failed = _check(intent_battle.hero.health == 92, "Displayed attack intent is executed") or failed
	executor.execute(EnemyIntentScript.new(EnemyIntentScript.Kind.HEAL, 12), intent_battle)
	failed = _check(intent_enemy.health == 72, "Heal intent restores enemy health") or failed

	var calls: Array = []
	executor.execute(EnemyIntentScript.new(EnemyIntentScript.Kind.SPECIAL, 4, "Яд", func(_battle: RefCounted, value: int) -> void: calls.append(["special", value])), intent_battle)
	executor.execute(EnemyIntentScript.new(EnemyIntentScript.Kind.PREPARE, 2, "Заряд", func(_battle: RefCounted, value: int) -> void: calls.append(["prepare", value])), intent_battle)
	failed = _check(calls == [["special", 4], ["prepare", 2]], "Special and prepare intents invoke their actions with exact values") or failed

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

extends SceneTree

const RULES_PATH := "res://data/game_rules.tres"
const BATTLE_COUNT := 10
const MAX_TURNS_PER_BATTLE := 100

const AttackTypeScript = preload("res://core/combat/attack_type.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardShufflerScript = preload("res://core/board/board_shuffler.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")
const CombatTurnResolverScript = preload("res://core/combat/combat_turn_resolver.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")


func _init() -> void:
	var rules := load(RULES_PATH) as GameRules
	var failed := _check(rules != null and rules.is_valid(), "Battle run uses valid game rules")
	var victories := 0
	var defeats := 0
	var total_turns := 0
	if not failed:
		for battle_index in BATTLE_COUNT:
			var outcome := _run_battle(rules, battle_index)
			failed = _check(outcome.completed, "Battle %d completes within the turn limit" % [battle_index + 1]) or failed
			failed = _check(outcome.logical, "Battle %d preserves board and combat invariants" % [battle_index + 1]) or failed
			victories += int(outcome.victory)
			defeats += int(outcome.defeat)
			total_turns += outcome.turns
	failed = _check(victories + defeats == BATTLE_COUNT, "All 10 battles have exactly one final outcome") or failed
	if not failed:
		print("Battle run summary: %d victories, %d defeats, %d turns" % [victories, defeats, total_turns])
	quit(1 if failed else 0)


func _run_battle(rules: GameRules, battle_index: int) -> Dictionary:
	var seed := 12000 + battle_index * 101
	var board = BoardGeneratorScript.new(rules, seed).generate_starting_board()
	var board_resolver = BoardResolverScript.new(rules, seed + 1)
	var shuffler = BoardShufflerScript.new(seed + 2)
	var turn_controller = BoardTurnControllerScript.new(board, rules.minimum_match_size)
	var combat_resolver = CombatTurnResolverScript.new()
	var intent_executor = EnemyIntentExecutorScript.new()
	var enemy = EnemyStateScript.new(rules.enemy_base_health)
	var weakness: int = AttackTypeScript.Kind.PHYSICAL if battle_index % 2 == 0 else AttackTypeScript.Kind.MAGIC
	enemy.configure_affinities(weakness, AttackTypeScript.Kind.NONE, rules.weakness_multiplier, rules.boss_resistance_multiplier)
	enemy.current_intent = EnemyIntentScript.new(EnemyIntentScript.Kind.ATTACK, rules.enemy_base_damage)
	var battle = BattleStateScript.new(HeroStateScript.new(rules.hero_max_health), enemy)
	var logical := board != null
	var turns := 0

	while logical and not battle.is_over and turns < MAX_TURNS_PER_BATTLE:
		var moves: Array = board.find_valid_moves(rules.minimum_match_size)
		if moves.is_empty():
			logical = shuffler.reshuffle(board, rules.minimum_match_size)
			moves = board.find_valid_moves(rules.minimum_match_size)
		if not logical or moves.is_empty():
			break
		var move = moves[(turns + battle_index) % moves.size()]
		logical = turn_controller.begin_swap(move.first, move.second) and turn_controller.finish_swap()
		if not logical:
			break
		var board_result = board_resolver.resolve(board)
		var combat_result = combat_resolver.resolve(
			board_result,
			battle,
			func(current_battle: RefCounted) -> void:
				intent_executor.execute(current_battle.enemy.current_intent, current_battle),
		)
		turns += 1
		logical = (
			board_result.stable
			and not board.has_any_match(rules.minimum_match_size)
			and combat_result.phase_order[0] == "damage"
			and combat_result.phase_order[-1] == "final_checks"
			and battle.hero.health >= 0
			and battle.hero.health <= battle.hero.max_health
			and battle.enemy.health >= 0
			and battle.enemy.health <= battle.enemy.max_health
			and battle.enemy_actions_executed <= turns
		)
		if logical and not battle.is_over:
			logical = board.has_valid_move(rules.minimum_match_size) or shuffler.reshuffle(board, rules.minimum_match_size)

	return {
		"completed": battle.is_over and turns <= MAX_TURNS_PER_BATTLE,
		"logical": logical and battle.victory != battle.defeat and turn_controller.move_count == turns,
		"victory": battle.victory,
		"defeat": battle.defeat,
		"turns": turns,
	}


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

extends SceneTree

const BOSS_PATH := "res://data/enemies/stone_guardian.tres"
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const CombatCalculatorScript = preload("res://core/combat/combat_calculator.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var definition: Resource = load(BOSS_PATH)
	failed = _check(definition != null and definition.is_valid() and definition.is_boss, "Stone Guardian loads as valid boss data") or failed
	var boss = EnemyFactoryScript.new().create(definition, 10)
	var expected_health := ceili(45.0 * pow(1.075, 9) * 2.4)
	var expected_damage := ceili(8.0 * pow(1.055, 9) * 1.15)
	failed = _check(boss.max_health == expected_health and boss.base_damage == expected_damage, "Boss applies ×2.4 HP and ×1.15 damage") or failed
	failed = _check(boss.is_boss and boss.physical_damage_multiplier == 0.65 and boss.magic_damage_multiplier == 1.5, "Boss has explicit physical resistance and magic weakness") or failed

	var board = BoardModelScript.new(Vector2i(7, 7), _board_with_blockers(0))
	var controller = EnemyControllerScript.new(boss, board, 12, 1818)
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK, "Boss cycle starts with attack") or failed
	controller.advance_intent()
	failed = _check(
		boss.current_intent.kind == EnemyIntentScript.Kind.SPECIAL
		and boss.current_intent.value == 3
		and "Подготовка" in boss.current_intent.display_text(),
		"Boss clearly telegraphs preparation of three blockers",
	) or failed
	var battle = BattleStateScript.new(HeroStateScript.new(100), boss)
	EnemyIntentExecutorScript.new().execute(boss.current_intent, battle)
	failed = _check(_count_blockers(board) == 3, "Stonefall adds exactly three empty stones") or failed
	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK, "Boss returns to attack after blockers") or failed

	var limited_board = BoardModelScript.new(Vector2i(7, 7), _board_with_blockers(11))
	var limited_boss = EnemyFactoryScript.new().create(definition, 10)
	var limited_controller = EnemyControllerScript.new(limited_boss, limited_board, 12, 1919)
	limited_controller.advance_intent()
	EnemyIntentExecutorScript.new().execute(limited_boss.current_intent, BattleStateScript.new(HeroStateScript.new(100), limited_boss))
	failed = _check(_count_blockers(limited_board) == 12, "Stonefall respects the global empty-stone limit") or failed

	var effects = BoardResolutionResultScript.new()
	effects.physical_components.append(10.0)
	effects.magic_components.append(10.0)
	var calculated = CombatCalculatorScript.new().calculate(effects, HeroStateScript.new(100), boss)
	failed = _check(calculated.physical_damage == 7 and calculated.magic_damage == 15, "Boss resistance and weakness affect exact damage") or failed

	var main = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	main.battle_number = 10
	root.add_child(main)
	await process_frame
	failed = _check("Каменный страж" in main.enemy_title_label.text and "меч" in main.resistance_label.text, "Battle 10 HUD names boss and shows resistance") or failed
	var special = EnemyIntentScript.new(EnemyIntentScript.Kind.SPECIAL, 3, "Подготовка: Каменный обвал")
	await main._show_special_feedback(special)
	failed = _check(not main.special_feedback_label.visible and not main.board_flash.visible, "Stonefall has a dedicated completed flash and caption") or failed
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _board_with_blockers(blocker_count: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(49)
	cells.fill(TileTypeScript.Value.SWORD)
	for index in blocker_count:
		cells[index] = TileTypeScript.Value.EMPTY_STONE
	return cells


func _count_blockers(board: RefCounted) -> int:
	var count := 0
	for tile in board.cells():
		if tile == TileTypeScript.Value.EMPTY_STONE:
			count += 1
	return count


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

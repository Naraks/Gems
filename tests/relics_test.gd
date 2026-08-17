extends SceneTree

const RelicCatalogScript = preload("res://core/progression/relic_catalog.gd")
const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const CombatCalculatorScript = preload("res://core/combat/combat_calculator.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func _init() -> void:
	var failed := false
	var catalog = RelicCatalogScript.new().all()
	var expected_prices := {
		RelicDefinitionScript.Id.RUBY_HILT: 55,
		RelicDefinitionScript.Id.SAPPHIRE_LENS: 55,
		RelicDefinitionScript.Id.HEALER_FLASK: 70,
		RelicDefinitionScript.Id.PROSPECTOR_HAMMER: 65,
		RelicDefinitionScript.Id.MIRROR_SHARD: 95,
		RelicDefinitionScript.Id.CASCADE_CLOVER: 85,
	}
	failed = _check(catalog.size() == 6, "Catalog contains all six relics") or failed
	for relic in catalog:
		failed = _check(expected_prices.get(relic.id, -1) == relic.price and not relic.title.is_empty() and not relic.description.is_empty(), "%s has its GDD price and readable effect" % relic.title) or failed

	var hero = HeroStateScript.new(101, 40)
	for relic in catalog:
		failed = _check(hero.add_relic(relic.id), "%s can be acquired once" % relic.title) or failed
	failed = _check(not hero.add_relic(RelicDefinitionScript.Id.RUBY_HILT) and hero.relic_ids.size() == 6, "Duplicate relics are rejected") or failed

	var components = BoardResolutionResultScript.new()
	components.physical_components.append_array([10.0, 10.0])
	components.magic_components.append_array([10.0, 10.0])
	components.enhanced_match_count = 2
	var calculator = CombatCalculatorScript.new()
	var enemy = EnemyStateScript.new(100)
	var first = calculator.calculate(components, hero, enemy)
	failed = _check(first.physical_damage == 25 and first.magic_damage == 25, "Ruby Hilt and Sapphire Lens multiply only the first matching combination") or failed
	failed = _check(first.coins == 4, "Prospector Hammer grants two coins for every 4+ combination") or failed
	var second = calculator.calculate(components, hero, enemy)
	failed = _check(second.physical_damage == 20 and second.magic_damage == 20, "First-combination damage relics are consumed for the current battle") or failed

	hero.reset_battle_relics()
	var next_battle = calculator.calculate(components, hero, enemy)
	failed = _check(next_battle.physical_damage == 25 and next_battle.magic_damage == 25 and hero.relic_ids.size() == 6, "Battle reset restores first effects without removing run relics") or failed
	failed = _check(hero.apply_victory_relics() == 6 and hero.health == 46, "Healer Flask restores ceil(5% max HP) after victory") or failed

	var rules = load("res://data/game_rules.tres")
	var resolver = BoardResolverScript.new(rules, 22022)
	resolver.cascade_start_bonus = 0.10
	failed = _check(
		is_equal_approx(resolver.cascade_multiplier_for(1), 1.10)
		and is_equal_approx(resolver.cascade_multiplier_for(2), 1.35)
		and is_equal_approx(resolver.cascade_multiplier_for(5), 2.0),
		"Cascade Clover starts at ×1.10 and preserves the ×2.00 cap",
	) or failed

	var boss = EnemyFactoryScript.new().create(load("res://data/enemies/stone_guardian.tres"), 10)
	var board = BoardModelScript.new(Vector2i(7, 7), _filled_board())
	var controller = EnemyControllerScript.new(boss, board, 12, 22023)
	controller.advance_intent()
	var battle = BattleStateScript.new(hero, boss)
	var executor = EnemyIntentExecutorScript.new()
	var blockers_before := _count_blockers(board)
	executor.execute(boss.current_intent, battle)
	if not battle.enemy_intent_delayed:
		controller.advance_intent()
	failed = _check(battle.enemy_intent_delayed and _count_blockers(board) == blockers_before and boss.current_intent.kind == 2, "Mirror Shard postpones the first boss special for one turn") or failed
	executor.execute(boss.current_intent, battle)
	if not battle.enemy_intent_delayed:
		controller.advance_intent()
	failed = _check(_count_blockers(board) == blockers_before + 3 and boss.current_intent.kind == 0, "Delayed boss special executes on the following turn and the cycle continues") or failed

	quit(1 if failed else 0)


func _filled_board() -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(49)
	cells.fill(TileTypeScript.Value.SWORD)
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

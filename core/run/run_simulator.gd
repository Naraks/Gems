class_name RunSimulator
extends RefCounted

const MAX_TURNS_PER_BATTLE := 100
const MAX_ROUTE_NODES := 20
const BOSS_PATH := "res://data/enemies/stone_guardian.tres"

const RoutePlannerScript = preload("res://core/run/linear_route_planner.gd")
const RouteNodeScript = preload("res://core/run/route_node.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const CombatTurnResolverScript = preload("res://core/combat/combat_turn_resolver.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyCatalogScript = preload("res://core/enemies/enemy_catalog.gd")
const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const ShopStateScript = preload("res://core/shop/shop_state.gd")
const UpgradeCatalogScript = preload("res://core/progression/upgrade_catalog.gd")

var rules: Resource


func _init(game_rules: Resource = null) -> void:
	rules = game_rules if game_rules != null else load("res://data/game_rules.tres")
	assert(rules != null and rules.is_valid(), "Run simulator requires valid game rules")


func simulate(seed: int) -> Dictionary:
	assert(seed != 0, "Simulation seed must be explicit and non-zero")
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var hero = HeroStateScript.new(rules.hero_max_health)
	var route = RoutePlannerScript.new(seed).generate_block(0)
	var upgrades = UpgradeCatalogScript.new(seed + 1)
	var result := {
		"seed": seed,
		"cause": "route_exhausted",
		"depth": 0,
		"duration_seconds": 0,
		"turns": 0,
		"shops": 0,
		"levels": 0,
		"bosses_encountered": 0,
		"bosses_defeated": 0,
		"completed": false,
		"valid": true,
	}
	if route.size() > MAX_ROUTE_NODES:
		result.valid = false
		result.cause = "route_limit"
		return result

	for node in route:
		if node.kind == RouteNodeScript.Kind.SHOP:
			_visit_shop(hero, seed + node.battle_number * 101, result)
			result.duration_seconds += 15
			continue
		result.depth = node.battle_number
		if node.kind == RouteNodeScript.Kind.BOSS:
			result.bosses_encountered += 1
		var battle_result := _simulate_battle(hero, node.battle_number, seed, random)
		result.turns += battle_result.turns
		result.duration_seconds += battle_result.duration_seconds
		if not battle_result.valid:
			result.valid = false
			result.cause = battle_result.cause
			return result
		if battle_result.defeat:
			result.cause = "defeat"
			return result
		if node.kind == RouteNodeScript.Kind.BOSS:
			result.bosses_defeated += 1
		_grant_rewards_and_levels(hero, battle_result.enemy, upgrades, result)

	result.cause = "completed"
	result.completed = true
	return result


func simulate_many(count: int, first_seed: int = 24001) -> Dictionary:
	assert(count > 0 and first_seed != 0, "Simulation batch requires count and seed")
	var runs: Array[Dictionary] = []
	var depth_distribution := {}
	var duration_distribution := {}
	var cause_distribution := {}
	var total_shops := 0
	var total_levels := 0
	var total_bosses := 0
	for offset in count:
		var run := simulate(first_seed + offset)
		runs.append(run)
		_increment(depth_distribution, str(run.depth))
		_increment(duration_distribution, _duration_bucket(run.duration_seconds))
		_increment(cause_distribution, run.cause)
		total_shops += run.shops
		total_levels += run.levels
		total_bosses += run.bosses_encountered
	return {
		"first_seed": first_seed,
		"runs": runs,
		"depth_distribution": depth_distribution,
		"duration_distribution": duration_distribution,
		"cause_distribution": cause_distribution,
		"total_shops": total_shops,
		"total_levels": total_levels,
		"total_bosses_encountered": total_bosses,
	}


func _simulate_battle(hero: RefCounted, battle_number: int, seed: int, random: RandomNumberGenerator) -> Dictionary:
	hero.reset_battle_relics()
	var definition: Resource = (
		load(BOSS_PATH)
		if battle_number % rules.boss_interval == 0
		else EnemyCatalogScript.new().for_battle(battle_number)
	)
	var enemy = EnemyFactoryScript.new().create(definition, battle_number, hero.weakness_multiplier)
	var board = BoardGeneratorScript.new(rules, seed + battle_number * 17).generate_starting_board()
	var controller = EnemyControllerScript.new(enemy, board, rules.maximum_empty_stones, seed + battle_number * 31)
	var battle = BattleStateScript.new(hero, enemy)
	var resolver = CombatTurnResolverScript.new()
	var executor = EnemyIntentExecutorScript.new()
	var turns := 0
	while not battle.is_over and turns < MAX_TURNS_PER_BATTLE:
		var effects = _simulated_match(random, turns)
		resolver.resolve(effects, battle, func(current: RefCounted) -> void:
			executor.execute(current.enemy.current_intent, current)
			if not current.enemy_intent_delayed:
				controller.advance_intent()
		)
		turns += 1
		if hero.health < 0 or hero.health > hero.max_health or enemy.health < 0 or enemy.health > enemy.max_health:
			return {"valid": false, "cause": "invalid_health", "turns": turns, "duration_seconds": 0, "defeat": false, "enemy": enemy}
	return {
		"valid": battle.is_over,
		"cause": "turn_limit" if not battle.is_over else ("defeat" if battle.defeat else "victory"),
		"turns": turns,
		"duration_seconds": turns * random.randi_range(32, 55),
		"defeat": battle.defeat,
		"enemy": enemy,
	}


func _simulated_match(random: RandomNumberGenerator, _turn: int) -> RefCounted:
	var effects = BoardResolutionResultScript.new()
	var strength := float(random.randi_range(3, 5))
	var move_kind := random.randf()
	if move_kind < 0.08:
		effects.healing_components.append(float(rules.base_healing) * strength)
	elif move_kind < 0.25:
		effects.coin_components.append(float(rules.base_coins) * strength)
	elif random.randi() % 2 == 0:
		effects.physical_components.append(float(rules.base_physical_damage) * strength)
	else:
		effects.magic_components.append(float(rules.base_magic_damage) * strength)
	if move_kind >= 0.25 and random.randf() < 0.45:
		effects.coin_components.append(float(rules.base_coins) * float(random.randi_range(1, 3)))
	if move_kind >= 0.25 and strength >= 4.0:
		effects.enhanced_match_count = 1
	return effects


func _grant_rewards_and_levels(hero: RefCounted, enemy: RefCounted, upgrades: RefCounted, result: Dictionary) -> void:
	hero.add_experience(enemy.experience_reward)
	hero.add_coins(enemy.base_coin_reward)
	hero.apply_victory_relics()
	while hero.can_level_up():
		var choices: Array[RefCounted] = upgrades.draw_three()
		upgrades.apply(choices[0], hero)
		hero.level_up()
		result.levels += 1


func _visit_shop(hero: RefCounted, seed: int, result: Dictionary) -> void:
	var shop = ShopStateScript.new(hero, seed, floori(float(result.depth) / 10.0))
	result.shops += 1
	var best_index := -1
	var best_price := 1_000_000
	for index in shop.items.size():
		if shop.can_purchase(index) and shop.items[index].price < best_price:
			best_index = index
			best_price = shop.items[index].price
	if best_index >= 0:
		shop.purchase(best_index)


func _duration_bucket(seconds: int) -> String:
	var start := floori(float(seconds) / 60.0)
	return "%d-%d min" % [start, start + 1]


func _increment(distribution: Dictionary, key: String) -> void:
	distribution[key] = int(distribution.get(key, 0)) + 1

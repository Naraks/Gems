extends SceneTree

const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const CombatCalculatorScript = preload("res://core/combat/combat_calculator.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const RULES_PATH := "res://data/game_rules.tres"


func _init() -> void:
	var failed := false
	var rules := load(RULES_PATH) as GameRules
	var hero = HeroStateScript.new(
		rules.hero_max_health,
		-1,
		rules.hero_sword_power,
		rules.hero_magic_power,
		rules.hero_healing_power,
		rules.hero_coin_multiplier,
	)
	failed = _check(hero.max_health == 100 and hero.health == 100, "Hero starts with 100/100 HP") or failed
	failed = _check(hero.sword_power == 1.0 and hero.magic_power == 1.0 and hero.healing_power == 1.0, "Hero powers start at x1.00") or failed
	failed = _check(hero.coin_multiplier == 1.0 and hero.coins == 0 and hero.level == 1, "Hero starts with x1.00 coins, zero coins and level 1") or failed

	var scaled_hero = HeroStateScript.new(100, 50, 1.15, 1.15, 1.18, 1.20)
	var enemy = EnemyStateScript.new(200)
	enemy.physical_damage_multiplier = 1.5
	enemy.magic_damage_multiplier = 0.65
	var components = BoardResolutionResultScript.new()
	components.physical_components.append(30.0)
	components.magic_components.append(30.0)
	components.healing_components.append(24.0)
	components.coin_components.append(9.0)
	var calculated = CombatCalculatorScript.new().calculate(components, scaled_hero, enemy)
	failed = _check(calculated.physical_damage == 52, "Physical formula rounds 30 x 1.15 x 1.50 up to 52") or failed
	failed = _check(calculated.magic_damage == 23, "Magic formula rounds 30 x 1.15 x 0.65 up to 23") or failed
	failed = _check(calculated.healing == 29, "Healing formula rounds 24 x 1.18 up to 29") or failed
	failed = _check(calculated.coins == 11, "Coin formula rounds 9 x 1.20 up to 11") or failed

	failed = _check(scaled_hero.heal(999) == 50 and scaled_hero.health == 100, "Hero HP never exceeds maximum") or failed
	failed = _check(scaled_hero.take_damage(999) == 100 and scaled_hero.health == 0, "Hero HP never drops below zero") or failed
	failed = _check(enemy.take_damage(999) == 200 and enemy.health == 0, "Enemy HP never drops below zero") or failed
	failed = _check(enemy.heal(999) == 200 and enemy.health == 200, "Enemy HP never exceeds maximum") or failed

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

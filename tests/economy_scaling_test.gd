extends SceneTree

const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const ShopStateScript = preload("res://core/shop/shop_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")


func _init() -> void:
	var failed := false
	var rules = load("res://data/economy_rules.tres")
	failed = _check(rules.enemy_health(1) == 45 and rules.enemy_damage(1) == 8, "Battle one uses base HP and damage") or failed
	failed = _check(rules.enemy_health(3) == 53 and rules.enemy_damage(3) == 9, "HP and damage follow battle growth formulas") or failed
	failed = _check(rules.enemy_experience(3) == 20 and rules.enemy_coins(3) == 6, "Experience and coins follow GDD formulas") or failed
	failed = _check(rules.enemy_health(31) == ceili(45.0 * pow(1.075, 30) * 1.025), "Full cycles add 2.5% enemy HP") or failed
	failed = _check(rules.enemy_damage(31) == ceili(8.0 * pow(1.055, 30) * 1.015), "Full cycles add 1.5% enemy damage") or failed
	failed = _check(rules.enemy_health(10, true) == ceili(45.0 * pow(1.075, 9) * 2.4), "Boss HP multiplier is applied after scaling") or failed
	failed = _check(rules.enemy_damage(10, true) == ceili(8.0 * pow(1.055, 9) * 1.15), "Boss damage multiplier is applied after scaling") or failed

	failed = _check(rules.scaled_price(20, 0) == 20, "Prices stay at base values before the first boss") or failed
	failed = _check(rules.scaled_price(20, 1) == 25 and rules.scaled_price(55, 1) == 60, "After one boss prices grow 8% and round up to five") or failed
	failed = _check(rules.scaled_price(55, 2) == 65, "Price growth compounds after each boss") or failed
	var hero = HeroStateScript.new(100, 50)
	hero.coins = 999
	var shop = ShopStateScript.new(hero, 21021, 1, rules)
	failed = _check(shop.refresh_cost == 20, "Refresh price uses the same boss scaling") or failed
	shop.refresh()
	failed = _check(shop.refresh_cost == 30, "Repeated refresh scales the full base price sequence") or failed
	for item in shop.items:
		failed = _check(item.price % 5 == 0, "Every generated shop price is rounded to five") or failed

	var custom_rules = rules.duplicate()
	custom_rules.enemy_base_health = 100
	custom_rules.health_growth_per_battle = 0.10
	custom_rules.small_heal_price = 33
	var definition = load("res://data/enemies/ruins_fighter.tres")
	var custom_enemy = EnemyFactoryScript.new(custom_rules).create(definition, 2)
	failed = _check(custom_enemy.max_health == 111, "Enemy balance can be changed through data") or failed
	var custom_shop = ShopStateScript.new(hero, 2, 0, custom_rules)
	var small_heal_found := false
	for item in custom_shop.items:
		if item.kind == 0:
			small_heal_found = item.price == 35
	failed = _check(small_heal_found, "Shop balance can be changed through data without code changes") or failed

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

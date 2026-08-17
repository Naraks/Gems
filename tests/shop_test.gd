extends SceneTree

const ShopStateScript = preload("res://core/shop/shop_state.gd")
const ShopItemScript = preload("res://core/shop/shop_item.gd")
const RelicCatalogScript = preload("res://core/progression/relic_catalog.gd")
const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const CombatCalculatorScript = preload("res://core/combat/combat_calculator.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var hero = HeroStateScript.new(100, 50)
	hero.coins = 500
	var shop = ShopStateScript.new(hero, 16016)
	failed = _check(shop.items.size() == 4, "Shop displays four items") or failed
	failed = _check(shop.items[0].kind in [ShopItemScript.Kind.SMALL_HEAL, ShopItemScript.Kind.FULL_HEAL], "First slot is healing") or failed
	failed = _check(shop.items[1].kind != shop.items[2].kind and shop.items[1].kind != ShopItemScript.Kind.RELIC and shop.items[2].kind != ShopItemScript.Kind.RELIC, "Middle slots are two different upgrades") or failed
	failed = _check(shop.items[3].kind == ShopItemScript.Kind.RELIC, "Last slot is a relic") or failed

	var coins_before: int = hero.coins
	failed = _check(shop.refresh() and hero.coins == coins_before - 15 and shop.refresh_cost == 25, "First refresh costs 15 and next costs 25") or failed
	coins_before = hero.coins
	failed = _check(shop.refresh() and hero.coins == coins_before - 25 and shop.refresh_cost == 35, "Refresh price increases by 10") or failed

	var effect_hero = HeroStateScript.new(100, 40)
	var effect_shop = ShopStateScript.new(effect_hero, 2)
	_apply(effect_shop, ShopItemScript.Kind.SMALL_HEAL, 20)
	failed = _check(effect_hero.health == 65, "Small heal restores 25 HP for 20") or failed
	effect_hero.health = 10
	_apply(effect_shop, ShopItemScript.Kind.FULL_HEAL, 55)
	failed = _check(effect_hero.health == 100, "Full heal restores all HP for 55") or failed
	_apply(effect_shop, ShopItemScript.Kind.FORTIFY, 60)
	failed = _check(effect_hero.max_health == 115 and effect_hero.health == 115, "Fortify adds and heals 15 HP for 60") or failed
	_apply(effect_shop, ShopItemScript.Kind.SWORD_POWER, 50)
	_apply(effect_shop, ShopItemScript.Kind.MAGIC_POWER, 50)
	_apply(effect_shop, ShopItemScript.Kind.HEALING_POWER, 45)
	failed = _check(is_equal_approx(effect_hero.sword_power, 1.12) and is_equal_approx(effect_hero.magic_power, 1.12) and is_equal_approx(effect_hero.healing_power, 1.15), "Power shop upgrades use GDD values and prices") or failed

	var relics := RelicCatalogScript.new().all()
	var relic_prices: Array[int] = []
	for relic in relics:
		relic_prices.append(relic.price)
	relic_prices.sort()
	failed = _check(relics.size() == 6 and relic_prices == [55, 55, 65, 70, 85, 95], "All six relics have GDD prices") or failed
	var relic = relics[0]
	effect_hero.add_relic(relic.id)
	var duplicate = ShopItemScript.new(ShopItemScript.Kind.RELIC, relic.title, relic.description, relic.price, relic)
	effect_shop.items.clear()
	effect_shop.items.append(duplicate)
	effect_hero.coins = 999
	failed = _check(not effect_shop.can_purchase(0) and not effect_shop.purchase(0), "Owned relic cannot be purchased again") or failed
	var sold_item = ShopItemScript.new(ShopItemScript.Kind.SWORD_POWER, "Усиление меча", "+12%", 50)
	effect_shop.items.clear()
	effect_shop.items.append(sold_item)
	effect_hero.coins = 50
	failed = _check(effect_shop.purchase(0) and sold_item.sold and not effect_shop.purchase(0), "Sold item cannot be purchased twice") or failed
	effect_shop.items.clear()
	effect_shop.items.append(ShopItemScript.new(ShopItemScript.Kind.MAGIC_POWER, "Усиление магии", "+12%", 50))
	effect_hero.coins = 49
	failed = _check(not effect_shop.purchase(0), "Unaffordable item cannot be purchased") or failed

	var relic_hero = HeroStateScript.new(100)
	relic_hero.add_relic(RelicDefinitionScript.Id.RUBY_HILT)
	relic_hero.add_relic(RelicDefinitionScript.Id.SAPPHIRE_LENS)
	relic_hero.add_relic(RelicDefinitionScript.Id.PROSPECTOR_HAMMER)
	var board_result = BoardResolutionResultScript.new()
	board_result.physical_components.append(10.0)
	board_result.magic_components.append(10.0)
	board_result.enhanced_match_count = 1
	var calculator = CombatCalculatorScript.new()
	var calculated = calculator.calculate(board_result, relic_hero, EnemyStateScript.new(100))
	failed = _check(calculated.physical_damage == 15 and calculated.magic_damage == 15 and calculated.coins == 2, "Sword, magic and 4+ relic effects modify combat") or failed
	calculated = calculator.calculate(board_result, relic_hero, EnemyStateScript.new(100))
	failed = _check(calculated.physical_damage == 10 and calculated.magic_damage == 10, "First-combination relic bonuses trigger once per battle") or failed
	var rules := load("res://data/game_rules.tres") as GameRules
	var resolver = BoardResolverScript.new(rules, 3)
	resolver.cascade_start_bonus = 0.10
	failed = _check(is_equal_approx(resolver.cascade_multiplier_for(1), 1.10), "Cascade Clover starts cascades at ×1.10") or failed
	var flask_hero = HeroStateScript.new(100, 50)
	flask_hero.add_relic(RelicDefinitionScript.Id.HEALER_FLASK)
	failed = _check(flask_hero.apply_victory_relics() == 5 and flask_hero.health == 55, "Healer Flask restores 5% max HP after victory") or failed
	var boss = EnemyStateScript.new(100)
	boss.is_boss = true
	var mirror_hero = HeroStateScript.new(100)
	mirror_hero.add_relic(RelicDefinitionScript.Id.MIRROR_SHARD)
	var boss_battle = BattleStateScript.new(mirror_hero, boss)
	var special_calls: Array = []
	var special = EnemyIntentScript.new(EnemyIntentScript.Kind.SPECIAL, 9, "Удар", func(_battle: RefCounted, value: int) -> void: special_calls.append(value))
	var executor = EnemyIntentExecutorScript.new()
	failed = _check(executor.execute(special, boss_battle) == 0 and special_calls.is_empty(), "Mirror Shard delays the first boss special") or failed
	executor.execute(special, boss_battle)
	failed = _check(special_calls == [9], "Mirror Shard is consumed after one boss special") or failed

	var screen = (load("res://ui/shop/shop_screen.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	var ui_hero = HeroStateScript.new(100, 50)
	ui_hero.coins = 100
	screen.setup(ui_hero, 4)
	failed = _check(screen.item_buttons.size() == 4 and "Обновить · 15" == screen.refresh_button.text, "Shop screen presents assortment and refresh price") or failed
	screen.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _apply(shop: RefCounted, kind: int, price: int) -> void:
	var item = ShopItemScript.new(kind, "Тест", "Тест", price)
	shop._apply(item)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

extends SceneTree

const MAIN_SCENE := "res://ui/main/main.tscn"
const UpgradeCatalogScript = preload("res://core/progression/upgrade_catalog.gd")
const UpgradeDefinitionScript = preload("res://core/progression/upgrade_definition.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var hero = HeroStateScript.new(100)
	hero.add_experience(105)
	failed = _check(hero.experience_for_next_level() == 40, "Level 1 requires 40 experience") or failed
	failed = _check(hero.level_up() and hero.level == 2 and hero.experience == 65, "First level carries excess experience") or failed
	failed = _check(hero.experience_for_next_level() == 60, "Level threshold follows 40 + 20 × (level − 1)") or failed
	failed = _check(hero.level_up() and hero.level == 3 and hero.experience == 5, "Multiple level-ups preserve the remaining excess") or failed

	var catalog = UpgradeCatalogScript.new(15015)
	var definitions: Array[RefCounted] = catalog.all()
	var common_count := 0
	var rare_count := 0
	for definition in definitions:
		if definition.rarity == UpgradeDefinitionScript.Rarity.COMMON:
			common_count += 1
		else:
			rare_count += 1
	failed = _check(definitions.size() == 8 and common_count == 5 and rare_count == 3, "Catalog contains all eight upgrades with GDD rarities") or failed
	var choices: Array[RefCounted] = catalog.draw_three()
	var choice_ids := {choices[0].id: true, choices[1].id: true, choices[2].id: true}
	failed = _check(choice_ids.size() == 3, "Level offer contains three non-repeating random upgrades") or failed

	var effect_hero = HeroStateScript.new(100, 50)
	for definition in definitions:
		catalog.apply(definition, effect_hero)
	failed = _check(is_equal_approx(effect_hero.sword_power, 1.15), "Tempered Blade adds 15% sword power") or failed
	failed = _check(is_equal_approx(effect_hero.magic_power, 1.15), "Mage Focus adds 15% magic power") or failed
	failed = _check(is_equal_approx(effect_hero.healing_power, 1.18), "Vital Blood adds 18% healing power") or failed
	failed = _check(effect_hero.max_health == 112 and effect_hero.health == 62, "Endurance adds and heals 12 HP") or failed
	failed = _check(is_equal_approx(effect_hero.coin_multiplier, 1.20), "Treasure Hunter adds 20% coin multiplier") or failed
	failed = _check(is_equal_approx(effect_hero.cascade_bonus, 0.10), "Combo Master adds 0.10 after the first cascade") or failed
	failed = _check(effect_hero.last_chance_available and is_equal_approx(effect_hero.weakness_multiplier, 1.70), "Rare defensive and weakness upgrades modify the run") or failed
	var damage_applied: int = effect_hero.take_damage(999)
	failed = _check(effect_hero.health == 1 and damage_applied == 61 and not effect_hero.last_chance_available, "Last Chance prevents one lethal hit at 1 HP") or failed
	effect_hero.take_damage(999)
	failed = _check(effect_hero.health == 0, "Last Chance is consumed after one lethal hit") or failed

	var rules := load("res://data/game_rules.tres") as GameRules
	var resolver = BoardResolverScript.new(rules, 1)
	resolver.cascade_bonus = 0.10
	failed = _check(is_equal_approx(resolver.cascade_multiplier_for(1), 1.0) and is_equal_approx(resolver.cascade_multiplier_for(2), 1.35), "Combo Master skips first match and affects later cascades") or failed
	resolver.cascade_bonus = 2.0
	failed = _check(is_equal_approx(resolver.cascade_multiplier_for(5), 2.0), "Cascade multiplier remains capped at ×2.00") or failed

	var main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main._grant_victory_experience()
	var visible_ids := {}
	for upgrade in main._upgrade_choices:
		visible_ids[upgrade.id] = true
	failed = _check(main._battle.hero.experience == 40 and main.level_up_overlay.visible and visible_ids.size() == 3, "Victory grants experience once and blocks play with three unique choices") or failed
	main._grant_victory_experience()
	failed = _check(main._battle.hero.experience == 40, "Victory experience cannot be granted twice") or failed
	main._choose_upgrade(0)
	failed = _check(main._battle.hero.level == 2 and main._battle.hero.experience == 0 and not main.level_up_overlay.visible, "Choosing one upgrade completes the level-up") or failed
	main.queue_free()
	await process_frame

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

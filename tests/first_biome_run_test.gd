extends SceneTree

const RunStateScript = preload("res://core/run/first_biome_run_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const UpgradeCatalogScript = preload("res://core/progression/upgrade_catalog.gd")

const REGULAR_PATHS := [
	"res://data/enemies/ruins_fighter.tres",
	"res://data/enemies/ruins_healer.tres",
	"res://data/enemies/ruins_curser.tres",
]
const BOSS_PATH := "res://data/enemies/stone_guardian.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var hero = HeroStateScript.new(100)
	var state = RunStateScript.new(hero)
	var first_block_shops: Array[int] = state.shop_after_battles.duplicate()
	var factory = EnemyFactoryScript.new()
	var upgrades = UpgradeCatalogScript.new(1919)
	var visited_battles: Array[int] = []
	var shop_after: Array[int] = []
	var boss_seen := false

	while state.completed_battles < 10:
		if state.current_kind == RunStateScript.NodeKind.SHOP:
			shop_after.append(state.battle_number)
			state.leave_shop()
			continue
		visited_battles.append(state.battle_number)
		var path: String = BOSS_PATH if state.current_kind == RunStateScript.NodeKind.BOSS else REGULAR_PATHS[(state.battle_number - 1) % 3]
		var enemy = factory.create(load(path), state.battle_number, hero.weakness_multiplier)
		boss_seen = boss_seen or enemy.is_boss
		hero.add_experience(enemy.experience_reward)
		hero.add_coins(enemy.base_coin_reward)
		while hero.can_level_up():
			upgrades.apply(upgrades.draw_three()[0], hero)
			hero.level_up()
		state.complete_battle()

	failed = _check(visited_battles == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "Run exposes battles 1 through 10 in order") or failed
	failed = _check(shop_after == first_block_shops and shop_after.size() <= 2, "Run places its generated shops as readable nodes") or failed
	failed = _check(boss_seen and state.completed_battles == 10, "Battle 10 is the Stone Guardian boss") or failed
	failed = _check(state.status == RunStateScript.Status.ACTIVE and state.battle_number == 11 and state.current_kind == RunStateScript.NodeKind.BATTLE, "Run continues into the Ashen Mines after the first boss") or failed
	failed = _check(hero.coins > 0 and hero.experience >= 0, "Hero rewards persist across the full biome") or failed

	var ui_hero = HeroStateScript.new(100)
	var ui_state = RunStateScript.new(ui_hero)
	var run_screen = (load("res://ui/run/first_biome_run.tscn") as PackedScene).instantiate()
	run_screen.run_state = ui_state
	root.add_child(run_screen)
	await process_frame
	var background := run_screen.get_node("RuinsBackground") as ColorRect
	failed = _check(background.color.g > background.color.r and run_screen.node_title_label.text == ui_state.node_title(), "Run screen uses a readable green ruins palette and node title") or failed
	failed = _check(run_screen.journey_hero.visible and run_screen.journey_stage.size.y > 0.0, "Hero remains visible on the persistent journey stage") or failed
	failed = _check(run_screen.encounter_avatar.visible and not run_screen.encounter_label.text.is_empty() and run_screen.is_travelling, "Enemy encounter appears on the journey screen while the hero advances") or failed
	var fixed_hero_x: float = run_screen.journey_hero.position.x
	var moving_background_x: float = run_screen.road_marks.position.x
	await create_timer(0.3).timeout
	failed = _check(is_equal_approx(run_screen.journey_hero.position.x, fixed_hero_x), "Hero stays fixed while travelling") or failed
	failed = _check(run_screen.road_marks.position.x < moving_background_x and run_screen.encounter_avatar.position.x < run_screen.journey_stage.size.x, "Background moves left while the encounter enters from the right") or failed
	failed = _check(run_screen.current_screen.run_hero == ui_hero and run_screen.current_screen.battle_number == 1, "Battle screen receives persistent hero and node number") or failed
	failed = _check(
		not run_screen.current_screen.battle_number_label.visible
		and not run_screen.current_screen.top_bar.visible,
		"Embedded battle relies on the run heading instead of repeating battle and biome titles",
	) or failed
	while ui_state.current_kind != RunStateScript.NodeKind.SHOP:
		run_screen._on_battle_completed()
		await process_frame
	var shop_after_battle: int = ui_state.battle_number
	failed = _check(run_screen.journey_hero.visible and ui_state.current_kind == RunStateScript.NodeKind.SHOP and not run_screen.encounter_label.text.is_empty(), "Merchant and goods share the persistent journey screen") or failed
	failed = _check(run_screen.current_screen.shop.hero == ui_hero, "Generated shop transition opens the real shop with the same hero") or failed
	await create_timer(2.2).timeout
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	failed = _check(not run_screen.journey_stage.visible and run_screen.current_screen.item_buttons[0].size.y >= 44.0, "Collapsed journey and merchant goods remain readable at mobile landscape size") or failed
	run_screen._on_shop_closed()
	await process_frame
	failed = _check(ui_state.battle_number == shop_after_battle + 1 and run_screen.current_screen.run_hero == ui_hero, "Leaving shop continues to the next battle without resetting the run") or failed
	run_screen.queue_free()
	await process_frame

	var battle_screen = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	root.add_child(battle_screen)
	await process_frame
	var automatic_transitions := [0]
	battle_screen.battle_completed.connect(func() -> void: automatic_transitions[0] += 1)
	var battle_hero_x: float = battle_screen.hero_portrait.position.x
	battle_screen._grant_victory_experience()
	var expected_reward_text: String = tr("+%d опыта · +%d монет") % [
		battle_screen._battle.enemy.experience_reward,
		battle_screen._battle.enemy.base_coin_reward,
	]
	failed = _check(
		battle_screen.battle_transition_overlay.visible
		and battle_screen.battle_reward_label.text == expected_reward_text
		and battle_screen.get_node("%TransitionBackdrop").color.a >= 0.9
		and not battle_screen.enemy_portrait.visible
		and not battle_screen.enemy_intent_icon.visible
		and not battle_screen.enemy_health_label.visible
		and "\n" in battle_screen.transition_title.text
		and battle_screen.transition_title.get_theme_font_size("font_size") <= 20,
		"Victory and its rewards remain readable on an opaque backing card",
	) or failed
	failed = _check(battle_screen.get_node_or_null("%ContinueRunButton") == null, "Victory has no manual next-node button") or failed
	await create_timer(0.5).timeout
	failed = _check(battle_screen.biome_background.travel_progress == 0.0, "Victory reward remains readable before travel starts") or failed
	await create_timer(0.85).timeout
	failed = _check(
		battle_screen.biome_background.travel_progress > 0.0
		and battle_screen.pixel_wipe.progress > 0.0,
		"Battle background scrolls behind a pixel wipe after the victory hold",
	) or failed
	failed = _check(battle_screen.hero_portrait.position.x > battle_hero_x, "Hero advances toward the next encounter") or failed
	await create_timer(0.65).timeout
	failed = _check(automatic_transitions[0] == 1, "Victory automatically continues to the next node") or failed
	battle_screen.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

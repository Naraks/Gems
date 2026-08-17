extends SceneTree

const RunStateScript = preload("res://core/run/first_biome_run_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var hero = HeroStateScript.new(130, 0, 1.3, 1.2, 1.1, 1.2)
	hero.coins = 87
	hero.experience = 19
	hero.level = 4
	hero.add_relic(RelicDefinitionScript.Id.RUBY_HILT)
	var state = RunStateScript.new(hero, 23023)
	state.completed_battles = 6
	state.battle_number = 7
	state.shops_visited = 2
	state.finish_defeat(125.0)
	failed = _check(state.status == RunStateScript.Status.DEFEAT_SUMMARY, "Defeat changes the run to summary state") or failed
	var summary := state.summary_text()
	failed = _check("бой 7" in summary and "Побед: 6" in summary and "02:05" in summary, "Summary contains depth, victories and duration") or failed
	failed = _check("Магазинов: 2" in summary and "Уровень: 4" in summary and "Монеты: 87" in summary and "Реликвии: 1" in summary, "Summary contains key run results") or failed

	var screen = (load("res://ui/run/first_biome_run.tscn") as PackedScene).instantiate()
	screen.setup(state)
	root.add_child(screen)
	await process_frame
	failed = _check(screen.defeat_panel.visible and summary == screen.defeat_summary.text, "Defeat opens the run summary screen") or failed
	screen._on_return_to_menu()
	await process_frame
	failed = _check(screen.menu_panel.visible and state.status == RunStateScript.Status.MENU, "Summary returns to the run menu") or failed
	screen._start_new_run()
	await process_frame
	var fresh = screen.run_state
	failed = _check(fresh.status == RunStateScript.Status.ACTIVE and fresh.battle_number == 1 and fresh.completed_battles == 0, "New run starts from battle one") or failed
	failed = _check(fresh.hero.max_health == 100 and fresh.hero.health == 100 and fresh.hero.coins == 0 and fresh.hero.experience == 0 and fresh.hero.level == 1, "Health, coins, experience and levels reset for a new run") or failed
	failed = _check(fresh.hero.relic_ids.is_empty() and is_equal_approx(fresh.hero.sword_power, 1.0) and is_equal_approx(fresh.hero.magic_power, 1.0), "Relics and upgrades do not carry into a new run") or failed
	screen.current_screen._notify_defeat()
	await process_frame
	await process_frame
	failed = _check(screen.run_state.status == RunStateScript.Status.DEFEAT_SUMMARY and screen.defeat_panel.visible, "Battle defeat signal automatically ends the active run") or failed
	screen.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

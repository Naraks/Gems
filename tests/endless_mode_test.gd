extends SceneTree

const EndlessCycleScript = preload("res://core/run/endless_cycle.gd")
const RunStateScript = preload("res://core/run/first_biome_run_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const EnemyCatalogScript = preload("res://core/enemies/enemy_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var catalog = EnemyCatalogScript.new()
	failed = _check(catalog.for_battle(31).id == catalog.for_battle(1).id and catalog.for_battle(61).id == catalog.for_battle(1).id, "Regular enemies repeat every 30 battles") or failed
	failed = _check(catalog.boss_for_battle(40).id == &"stone_guardian" and catalog.boss_for_battle(50).id == &"fire_golem" and catalog.boss_for_battle(60).id == &"void_archmage", "Boss cycle repeats after battle 30") or failed

	var state = RunStateScript.new(HeroStateScript.new(100), 29029)
	var bosses: Array[int] = []
	var shops_by_block := {}
	while state.battle_number < 65:
		if state.current_kind == RunStateScript.NodeKind.SHOP:
			var block_index: int = (state.battle_number - 1) / 10
			shops_by_block[block_index] = int(shops_by_block.get(block_index, 0)) + 1
			state.leave_shop()
			continue
		if state.current_kind == RunStateScript.NodeKind.BOSS:
			bosses.append(state.battle_number)
		state.complete_battle()
	failed = _check(state.status == RunStateScript.Status.ACTIVE and state.battle_number == 65, "Run continues beyond battle 30 without completion") or failed
	failed = _check(bosses == [10, 20, 30, 40, 50, 60], "Every tenth battle remains a boss at endless depth") or failed
	for count in shops_by_block.values():
		failed = _check(int(count) <= 2, "Every endless block keeps the two-shop limit") or failed
	failed = _check("Заросшие руины" in state.node_title() and "Цикл 3" in state.node_title(), "Large-depth title keeps biome and cycle numbering") or failed

	failed = _check(EndlessCycleScript.biome_id(1) == &"ruins" and EndlessCycleScript.biome_id(31) == &"ruins" and EndlessCycleScript.biome_id(51) == &"tower", "Biome sequence repeats cyclically") or failed
	failed = _check(EndlessCycleScript.blocker_limit_bonus(31) == 1 and EndlessCycleScript.blocker_limit_bonus(1000000) == EndlessCycleScript.MAX_BLOCKER_BONUS, "Endless modifier grows and remains capped at large depth") or failed

	var early = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	early.battle_number = 1
	root.add_child(early)
	await process_frame
	var early_color: Color = early.biome_background.accent_color()
	early.queue_free()
	await process_frame
	var endless = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	endless.battle_number = 31
	root.add_child(endless)
	await process_frame
	failed = _check(endless.biome_background.biome_id == &"ruins" and endless.biome_background.accent_color() != early_color, "Repeated biome receives a palette variation") or failed
	failed = _check(endless.cycle_modifier_label.visible and "+1" in endless.cycle_modifier_label.text and endless._enemy_controller.maximum_empty_stones == endless.rules.maximum_empty_stones + 1, "Cycle modifier is visible and applied to combat") or failed
	endless.queue_free()
	await process_frame

	var rules = load("res://data/economy_rules.tres")
	failed = _check(rules.enemy_health(31) == ceili(45.0 * pow(1.075, 30) * 1.025), "Second cycle adds exactly 2.5% HP") or failed
	failed = _check(rules.enemy_damage(31) == ceili(8.0 * pow(1.055, 30) * 1.015), "Second cycle adds exactly 1.5% damage") or failed
	failed = _check(rules.enemy_health(10000) == rules.MAX_SCALED_VALUE and rules.enemy_damage(10000) == rules.MAX_SCALED_VALUE, "Scaling saturates safely at large depth") or failed
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

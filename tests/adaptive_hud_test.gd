extends SceneTree

const MAIN_SCENE := "res://ui/main/main.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	root.size = Vector2i(1280, 720)
	var scene := load(MAIN_SCENE) as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	failed = _check(_has_required_hud(main), "HUD shows battle, HP, intent, weakness and coins") or failed
	failed = _check(
		main.get_node("%EnemyIntentIcon").visible
		and not main.get_node("%EnemyIntentLabel").visible
		and not main.get_node("%EnemyIntentIcon").tooltip_text.is_empty()
		and main.get_node("%EnemyIntentIcon").position.y < -40.0,
		"Enemy intent is shown as an icon above the enemy with detailed tooltip text",
	) or failed
	failed = _check(_has_target_composition(main), "Large match-3 board is centered between both combatants") or failed
	failed = _check(
		not main.get_node("%TurnResultArea").visible
		and main.get_node("%BoardView").size.y >= main.size.y * 0.75,
		"Board expands into the space freed by the removed instruction",
	) or failed
	failed = _check(
		not main.get_node("Layout/CombatArea/CombatMargin/Fighters/HeroSide/HeroPanel/HeroTitleLabel").visible
		and not main.get_node("%EnemyTitleLabel").visible,
		"Hero caption and enemy name are removed from the battlefield",
	) or failed
	failed = _check(
		main.get_node("%HeroHealthLabel").global_position.y < main.size.y * 0.88
		and main.get_node("%EnemyHealthLabel").global_position.y < main.size.y * 0.88
		and absf(main.get_node("%HeroHealthLabel").global_position.y - main.get_node("%EnemyHealthLabel").global_position.y) <= 2.0,
		"Both HP labels sit higher beneath the character art",
	) or failed
	failed = _check(
		main.get_node("%HeroPortrait").global_position.x < main.get_node("%BoardView").global_position.x
		and main.get_node("%EnemyPortrait").global_position.x > main.get_node("%BoardView").global_position.x + main.get_node("%BoardView").size.x,
		"Hero and enemy frame the board on the left and right",
	) or failed
	failed = _check(
		main.get_node("%HeroPortrait").size.y >= 120.0
		and main.get_node("%EnemyPortrait").size.y >= 120.0
		and main.get_node("%HeroPortrait").ART_SCALE >= 2.0
		and main.get_node("%EnemyPortrait").ART_SCALE >= 2.0,
		"Combatant portraits are visually prominent at desktop size",
	) or failed
	failed = _check(
		absf(main.get_node("%HeroPortrait").global_position.y - main.get_node("%EnemyPortrait").global_position.y) <= 2.0,
		"Hero and enemy portraits share the same vertical level",
	) or failed
	var board_view := main.get_node("%BoardView") as Control
	failed = _check(not board_view.tooltip_for_position(board_view.size * 0.5).is_empty(), "Gem meaning is available as an in-board hover tooltip") or failed
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	failed = _check(_has_target_composition(main), "HUD preserves the centered-board composition at mobile landscape size") or failed
	failed = _check(main.get_node("%BoardView").size.x > 0.0, "Board remains visible at mobile landscape size") or failed
	failed = _check(main.get_node("%EnemyIntentLabel").get_theme_font_size("font_size") >= 12, "Compact HUD text remains readable") or failed

	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _has_required_hud(main: Control) -> bool:
	return (
		not main.get_node("%BattleNumberLabel").text.is_empty()
		and "HP" in main.get_node("%HeroHealthLabel").text
		and "HP" in main.get_node("%EnemyHealthLabel").text
		and main.get_node("%EnemyIntentIcon").visible
		and not main.get_node("%EnemyIntentIcon").tooltip_text.is_empty()
		and not main.get_node("%WeaknessLabel").text.is_empty()
		and not main.get_node("%CoinsLabel").text.is_empty()
	)


func _has_target_composition(main: Control) -> bool:
	var board := main.get_node("%BoardView") as Control
	if board.size.x <= 0.0 or main.size.x <= 0.0:
		return false
	var board_center_x := board.global_position.x + board.size.x * 0.5
	return absf(board_center_x - main.size.x * 0.5) < main.size.x * 0.08 and board.size.x >= main.size.y * 0.6


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

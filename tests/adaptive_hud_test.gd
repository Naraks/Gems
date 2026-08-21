extends SceneTree

const MAIN_SCENE := "res://ui/main/main.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var scene := load(MAIN_SCENE) as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	failed = _check(_has_required_hud(main), "HUD shows battle, HP, intent, weakness, coins and pause") or failed
	failed = _check(_has_target_proportions(main), "HUD prioritizes the match-3 board with 71/7/22 proportions") or failed
	failed = _check(
		main.get_node("%HeroPortrait").global_position.x < main.size.x * 0.25
		and main.get_node("%EnemyPortrait").global_position.x > main.size.x * 0.75,
		"Hero and enemy occupy the upper-left and upper-right corners",
	) or failed
	var pause_button := main.get_node("%PauseButton") as Button
	failed = _check(pause_button.custom_minimum_size.y >= 44.0, "Pause touch target is at least 44 px high") or failed
	pause_button.pressed.emit()
	failed = _check(paused and main.get_node("%PauseOverlay").visible, "Pause control pauses the game and shows an overlay") or failed
	pause_button.pressed.emit()
	failed = _check(not paused and not main.get_node("%PauseOverlay").visible, "Pause control resumes the game") or failed

	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	failed = _check(_has_target_proportions(main), "HUD preserves proportions at mobile landscape size") or failed
	failed = _check(main.get_node("%BoardView").size.x > 0.0, "Board remains visible at mobile landscape size") or failed
	failed = _check(main.get_node("%EnemyIntentLabel").get_theme_font_size("font_size") >= 14, "Compact HUD text remains readable") or failed

	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _has_required_hud(main: Control) -> bool:
	return (
		"Бой" in main.get_node("%BattleNumberLabel").text
		and "HP" in main.get_node("%HeroHealthLabel").text
		and "HP" in main.get_node("%EnemyHealthLabel").text
		and "Намерение" in main.get_node("%EnemyIntentLabel").text
		and "Слабость" in main.get_node("%WeaknessLabel").text
		and "Монеты" in main.get_node("%CoinsLabel").text
		and not main.get_node("%PauseButton").text.is_empty()
	)


func _has_target_proportions(main: Control) -> bool:
	var layout := main.get_node("%Layout") as Control
	var total := layout.size.y
	if total <= 0.0:
		return false
	var board_ratio: float = main.get_node("%BoardArea").size.y / total
	var result_ratio: float = main.get_node("%TurnResultArea").size.y / total
	var combat_ratio: float = main.get_node("%CombatArea").size.y / total
	return absf(board_ratio - 0.71) < 0.03 and absf(result_ratio - 0.07) < 0.03 and absf(combat_ratio - 0.22) < 0.03


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

extends SceneTree

const MAIN_SCENE := "res://ui/main/main.tscn"
const CombatTurnResultScript = preload("res://core/combat/combat_turn_result.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame

	var result = CombatTurnResultScript.new()
	result.physical_damage_applied = 15
	result.healing_applied = 8
	result.coins_granted = 3
	result.weakness_revealed = true
	result.weakness_hit = true
	result.enemy_responded = true
	result.enemy_intent = main._battle.enemy.current_intent
	await main._play_combat_feedback(result, 2)
	failed = _check(
		main.feedback_events == PackedStringArray(["board", "enemy_damage", "hero_heal", "coins", "weakness", "intent", "enemy_attack"]),
		"Feedback follows player effects, weakness, intent and enemy response order",
	) or failed
	failed = _check(main.get_node("%WeaknessSound").stream != null, "Weakness has a dedicated sound") or failed
	failed = _check(not main.get_node("%WeaknessFlash").visible and not main.get_node("%WeaknessFeedbackLabel").visible, "Weakness flash and caption complete cleanly") or failed
	failed = _check(
		main.get_node("%HeroFeedbackLabel").anchor_left < 0.5
		and main.get_node("%EnemyFeedbackLabel").anchor_left > 0.5
		and main.get_node("%CoinFeedbackLabel").anchor_left < 0.5,
		"Damage, healing and coins are anchored to their own HUD targets",
	) or failed

	var speed_tween: Tween = main.create_tween()
	speed_tween.tween_interval(1.0)
	main._feedback_tweens.clear()
	main._feedback_tweens.append(speed_tween)
	main.tutorial_completed = false
	var events_before_skip: int = main.feedback_events.size()
	main.accelerate_feedback()
	failed = _check(main.feedback_events.size() == events_before_skip, "Animation skip is locked during tutorial") or failed
	main.tutorial_completed = true
	main.accelerate_feedback()
	failed = _check(main.feedback_events[-1] == "accelerated", "Touch acceleration is enabled after tutorial") or failed
	speed_tween.kill()

	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

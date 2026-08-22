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
		main.feedback_events == PackedStringArray(["enemy_damage", "weakness", "hero_heal", "coins", "intent", "enemy_attack"]),
		"Feedback follows player effects, weakness, intent and enemy response order",
	) or failed
	failed = _check(main.get_node("%WeaknessSound").stream != null, "Weakness has a dedicated sound") or failed
	failed = _check(main.get_node_or_null("%WeaknessFlash") == null and not main.get_node("%WeaknessFeedbackLabel").visible, "Weakness caption completes without a blocking background") or failed
	var hero_center_x: float = main.get_node("%HeroPortrait").get_global_rect().get_center().x
	var enemy_center_x: float = main.get_node("%EnemyPortrait").get_global_rect().get_center().x
	failed = _check(
		absf(main.get_node("%HeroFeedbackLabel").get_global_rect().get_center().x - hero_center_x) <= 2.0
		and absf(main.get_node("%CoinFeedbackLabel").get_global_rect().get_center().x - hero_center_x) <= 2.0
		and absf(main.get_node("%EnemyFeedbackLabel").get_global_rect().get_center().x - enemy_center_x) <= 2.0
		and absf(main.get_node("%WeaknessFeedbackLabel").get_global_rect().get_center().x - enemy_center_x) <= 2.0,
		"Damage, weakness, healing and coins are aligned to their own combatants",
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
	failed = _check(
		main.feedback_events[-1] == "accelerated"
		and main.hero_portrait._animation_speed == main.SKIP_SPEED
		and main.enemy_portrait._animation_speed == main.SKIP_SPEED,
		"Touch acceleration includes feedback and character animation",
	) or failed
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

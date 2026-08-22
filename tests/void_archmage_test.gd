extends SceneTree

const BOSS_PATH := "res://data/enemies/void_archmage.tres"
const EnemyCatalogScript = preload("res://core/enemies/enemy_catalog.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var definition: Resource = load(BOSS_PATH)
	failed = _check(definition != null and definition.is_valid() and definition.is_boss, "Void Archmage loads as valid boss data") or failed
	failed = _check(EnemyCatalogScript.new().boss_for_battle(30) == definition, "Battle 30 selects the Void Archmage") or failed

	var original := PackedInt32Array([
		0, 1, 0, 2,
		2, 0, 2, 1,
		1, 2, 1, 0,
		0, 1, 2, 1,
	])
	var board = BoardModelScript.new(Vector2i(4, 4), original)
	failed = _check(not board.has_any_match() and board.has_valid_move(), "Rotation fixture starts stable and playable") or failed
	var boss = EnemyFactoryScript.new().create(definition, 30)
	var controller = EnemyControllerScript.new(boss, board, 12, 3030)
	var battle = BattleStateScript.new(HeroStateScript.new(300), boss)
	var executor = EnemyIntentExecutorScript.new()

	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK and boss.current_intent.title == definition.attack_title, "Cycle starts with a telegraphed magic attack") or failed
	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.SPECIAL and boss.current_intent.title == definition.special_title, "Second action telegraphs the field shift") or failed
	executor.execute(boss.current_intent, battle)
	failed = _check(board.cells() == PackedInt32Array([0, 1, 2, 0, 1, 2, 0, 1, 2, 1, 2, 0, 1, 0, 1, 2]), "Shift rotates the board clockwise without losing tiles") or failed
	failed = _check(not board.has_any_match() and board.has_valid_move(), "Rotated field remains stable and playable") or failed

	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK and boss.current_intent.title == definition.attack_title, "Third action returns to empowered magic") or failed
	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.SPECIAL and boss.current_intent.title == definition.alternate_special_title, "Fourth action clearly telegraphs affinity change") or failed
	var old_weakness: int = boss.weakness_type
	var old_resistance: int = boss.resistance_type
	executor.execute(boss.current_intent, battle)
	failed = _check(boss.weakness_type == old_resistance and boss.resistance_type == old_weakness, "Every fourth action swaps weakness and resistance") or failed
	failed = _check(is_equal_approx(boss.magic_damage_multiplier, 1.5) and is_equal_approx(boss.physical_damage_multiplier, 0.65), "Damage multipliers follow the swapped affinities") or failed
	failed = _check(boss.weakness_display() == "?" and AttackTypeScript.display_name(boss.resistance_type) == AttackTypeScript.display_name(AttackTypeScript.Kind.PHYSICAL), "Changed affinities are reset and readable by the HUD") or failed
	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK, "Four-action cycle repeats from magic") or failed

	var main = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	main.battle_number = 30
	root.add_child(main)
	await process_frame
	failed = _check(tr(definition.display_name) in main.enemy_title_label.text and tr(definition.attack_title) in main.enemy_intent_label.text, "Battle 30 HUD names the boss and its magic intent") or failed
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

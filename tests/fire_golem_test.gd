extends SceneTree

const BOSS_PATH := "res://data/enemies/fire_golem.tres"
const EnemyCatalogScript = preload("res://core/enemies/enemy_catalog.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var definition: Resource = load(BOSS_PATH)
	failed = _check(definition != null and definition.is_valid() and definition.is_boss, "Fire Golem loads as valid boss data") or failed
	failed = _check(EnemyCatalogScript.new().boss_for_battle(20) == definition, "Battle 20 selects the Fire Golem") or failed

	var board = BoardModelScript.new(Vector2i(7, 7), _board_with_hearts(4, 0))
	var boss = EnemyFactoryScript.new().create(definition, 20)
	var controller = EnemyControllerScript.new(boss, board, 12, 2626)
	var hero = HeroStateScript.new(200)
	var battle = BattleStateScript.new(hero, boss)
	var executor = EnemyIntentExecutorScript.new()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK, "Fire Golem cycle starts with an attack") or failed
	controller.advance_intent()
	var prepared_damage: int = boss.base_damage * 2
	failed = _check(
		boss.current_intent.kind == EnemyIntentScript.Kind.PREPARE
		and boss.current_intent.value == prepared_damage
		and "Огненный удар" in boss.current_intent.display_text(),
		"Preparation clearly telegraphs the exact double-damage strike",
	) or failed
	var health_before_prepare: int = hero.health
	executor.execute(boss.current_intent, battle)
	failed = _check(hero.health == health_before_prepare, "Preparation does not deal damage") or failed

	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.SPECIAL and boss.current_intent.value == prepared_damage, "Prepared strike follows preparation with double damage") or failed
	var damage_dealt := executor.execute(boss.current_intent, battle)
	failed = _check(damage_dealt == prepared_damage and hero.health == health_before_prepare - prepared_damage, "Fire strike deals the telegraphed damage") or failed
	failed = _check(_count_tiles(board, TileTypeScript.Value.HEART) == 2 and _count_tiles(board, TileTypeScript.Value.EMPTY_STONE) == 2, "Fire strike turns exactly two hearts into empty stones") or failed
	controller.advance_intent()
	failed = _check(boss.current_intent.kind == EnemyIntentScript.Kind.ATTACK, "Fire Golem returns to attack after its strike") or failed

	var limited_board = BoardModelScript.new(Vector2i(7, 7), _board_with_hearts(2, 11))
	var limited_boss = EnemyFactoryScript.new().create(definition, 20)
	var limited_controller = EnemyControllerScript.new(limited_boss, limited_board, 12, 2727)
	limited_controller.advance_intent()
	limited_controller.advance_intent()
	executor.execute(limited_boss.current_intent, BattleStateScript.new(HeroStateScript.new(200), limited_boss))
	failed = _check(_count_tiles(limited_board, TileTypeScript.Value.EMPTY_STONE) == 12 and _count_tiles(limited_board, TileTypeScript.Value.HEART) == 1, "Fire strike respects the blocker limit") or failed

	var main = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	main.battle_number = 20
	root.add_child(main)
	await process_frame
	failed = _check("Огненный голем" in main.enemy_title_label.text, "Battle 20 HUD names the Fire Golem") or failed
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _board_with_hearts(heart_count: int, blocker_count: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(49)
	cells.fill(TileTypeScript.Value.SWORD)
	for index in blocker_count:
		cells[index] = TileTypeScript.Value.EMPTY_STONE
	for index in heart_count:
		cells[blocker_count + index] = TileTypeScript.Value.HEART
	return cells


func _count_tiles(board: RefCounted, tile_type: int) -> int:
	var count := 0
	for tile in board.cells():
		if tile == tile_type:
			count += 1
	return count


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

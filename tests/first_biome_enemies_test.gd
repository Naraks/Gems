extends SceneTree

const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")

const PATHS := [
	"res://data/enemies/ruins_fighter.tres",
	"res://data/enemies/ruins_healer.tres",
	"res://data/enemies/ruins_curser.tres",
]


func _init() -> void:
	var failed := false
	var definitions: Array[Resource] = []
	var ids := {}
	var cycles := {}
	for path in PATHS:
		var definition: Resource = load(path)
		definitions.append(definition)
		ids[definition.id] = true
		cycles[str(definition.intent_cycle)] = true
		failed = _check(definition != null and definition.is_valid(), "%s loads as valid enemy data" % path.get_file()) or failed
	failed = _check(ids.size() == 3 and cycles.size() == 3, "First biome has three distinct data-driven archetypes and cycles") or failed

	var factory = EnemyFactoryScript.new()
	var first_enemy = factory.create(definitions[0], 1)
	failed = _check(first_enemy.max_health == 45 and first_enemy.base_damage == 8 and first_enemy.experience_reward == 18 and first_enemy.base_coin_reward == 5, "Battle 1 uses GDD base parameters") or failed
	var third_enemy = factory.create(definitions[2], 3)
	failed = _check(third_enemy.max_health == 53 and third_enemy.base_damage == 9 and third_enemy.experience_reward == 20 and third_enemy.base_coin_reward == 6, "Enemy parameters scale from battle number data") or failed

	var board = BoardModelScript.new(Vector2i(7, 7), _filled_board())
	var fighter = factory.create(definitions[0], 1)
	var fighter_controller = EnemyControllerScript.new(fighter, board, 12, 1)
	failed = _check(fighter.current_intent.kind == EnemyIntentScript.Kind.ATTACK and fighter.current_intent.value == 8, "Fighter telegraphs exact normal attack") or failed
	fighter_controller.advance_intent()
	failed = _check(fighter.current_intent.kind == EnemyIntentScript.Kind.ATTACK and fighter.current_intent.value == 12, "Fighter alternates to exact empowered attack") or failed

	var healer = factory.create(definitions[1], 2)
	var healer_controller = EnemyControllerScript.new(healer, board, 12, 2)
	healer_controller.advance_intent()
	failed = _check(healer.current_intent.kind == EnemyIntentScript.Kind.HEAL and healer.current_intent.value > 0 and "Лечение" in healer.current_intent.display_text(), "Healer telegraphs healing with exact value") or failed

	var curser = factory.create(definitions[2], 3)
	var curser_controller = EnemyControllerScript.new(curser, board, 12, 3)
	curser_controller.advance_intent()
	failed = _check(curser.current_intent.kind == EnemyIntentScript.Kind.SPECIAL and "пустой камень" in curser.current_intent.display_text(), "Curser telegraphs blocker special by name and value") or failed
	var battle = BattleStateScript.new(HeroStateScript.new(100), curser)
	EnemyIntentExecutorScript.new().execute(curser.current_intent, battle)
	failed = _check(_count_blockers(board) == 1, "Curser special adds a visible empty stone") or failed

	quit(1 if failed else 0)


func _filled_board() -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(49)
	cells.fill(TileTypeScript.Value.SWORD)
	return cells


func _count_blockers(board: RefCounted) -> int:
	var count := 0
	for tile in board.cells():
		if tile == TileTypeScript.Value.EMPTY_STONE:
			count += 1
	return count


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

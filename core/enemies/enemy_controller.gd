class_name EnemyController
extends RefCounted

const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyDefinitionScript = preload("res://core/enemies/enemy_definition.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")

var enemy: RefCounted
var board: RefCounted
var maximum_empty_stones: int
var turn_index := 0
var _random := RandomNumberGenerator.new()


func _init(enemy_state: RefCounted, board_model: RefCounted, blocker_limit: int, seed: int = 0) -> void:
	assert(enemy_state != null and enemy_state.definition != null and board_model != null, "Enemy controller requires enemy data and board")
	enemy = enemy_state
	board = board_model
	maximum_empty_stones = blocker_limit
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed
	enemy.current_intent = _build_intent()


func advance_intent() -> void:
	turn_index = (turn_index + 1) % enemy.definition.intent_cycle.size()
	enemy.current_intent = _build_intent()


func _build_intent() -> RefCounted:
	var kind: int = enemy.definition.intent_cycle[turn_index]
	var multiplier: float = enemy.definition.intent_multipliers[turn_index]
	match kind:
		EnemyIntentScript.Kind.ATTACK:
			if enemy.definition.archetype == "Берсерк" and float(enemy.health) / float(enemy.max_health) <= enemy.definition.berserk_health_threshold:
				multiplier *= enemy.definition.berserk_damage_multiplier
			return EnemyIntentScript.new(kind, ceili(enemy.base_damage * multiplier))
		EnemyIntentScript.Kind.HEAL:
			return EnemyIntentScript.new(kind, ceili(enemy.base_damage * multiplier), "Лечение")
		EnemyIntentScript.Kind.SPECIAL:
			if enemy.definition.special_behavior == EnemyDefinitionScript.SpecialBehavior.FIRE_HEART_STRIKE:
				return EnemyIntentScript.new(kind, ceili(enemy.base_damage * multiplier), enemy.definition.special_title, _perform_special)
			return EnemyIntentScript.new(kind, enemy.definition.special_value, enemy.definition.special_title, _perform_special)
		EnemyIntentScript.Kind.PREPARE:
			return EnemyIntentScript.new(kind, ceili(enemy.base_damage * multiplier), enemy.definition.special_title)
	return EnemyIntentScript.new(EnemyIntentScript.Kind.ATTACK, enemy.base_damage)


func _perform_special(battle: RefCounted, amount: int) -> int:
	if enemy.definition.special_behavior == EnemyDefinitionScript.SpecialBehavior.FIRE_HEART_STRIKE:
		var damage_dealt: int = battle.hero.take_damage(amount)
		_replace_tiles_with_blockers(TileTypeScript.Value.HEART, enemy.definition.special_value)
		return damage_dealt
	if enemy.definition.special_behavior == EnemyDefinitionScript.SpecialBehavior.SHIELD_LAST_ATTACK:
		enemy.apply_temporary_resistance(enemy.last_attack_type)
		return 0
	if enemy.definition.special_behavior != EnemyDefinitionScript.SpecialBehavior.ADD_BLOCKERS:
		return 0
	return _replace_tiles_with_blockers(-1, amount)


func _replace_tiles_with_blockers(required_tile: int, amount: int) -> int:
	var candidates: Array[Vector2i] = []
	var empty_count := 0
	for y in board.size.y:
		for x in board.size.x:
			var position := Vector2i(x, y)
			if board.get_cell(position) == TileTypeScript.Value.EMPTY_STONE:
				empty_count += 1
			elif required_tile < 0 or board.get_cell(position) == required_tile:
				candidates.append(position)
	var allowed := mini(amount, mini(maxi(0, maximum_empty_stones - empty_count), candidates.size()))
	for _index in allowed:
		var picked := _random.randi_range(0, candidates.size() - 1)
		board.set_cell(candidates.pop_at(picked), TileTypeScript.Value.EMPTY_STONE)
	return allowed

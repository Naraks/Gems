extends SceneTree

const BoardModelScript = preload("res://core/board/board_model.gd")
const MatchFinderScript = preload("res://core/board/match_finder.gd")
const MatchShapeScript = preload("res://core/board/match_shape.gd")
const TileEffectResolverScript = preload("res://core/board/tile_effect_resolver.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const RULES_PATH := "res://data/game_rules.tres"

var _finder = MatchFinderScript.new()
var _resolver = TileEffectResolverScript.new()
var _rules: Resource


func _init() -> void:
	var failed := false
	_rules = load(RULES_PATH)

	failed = _check_base_effect(TileTypeScript.Value.SWORD, "physical_damage", 30, "Sword deals base physical damage") or failed
	failed = _check_base_effect(TileTypeScript.Value.MAGIC, "magic_damage", 30, "Magic deals base magic damage") or failed
	failed = _check_base_effect(TileTypeScript.Value.HEART, "healing", 24, "Heart restores base health") or failed
	failed = _check_base_effect(TileTypeScript.Value.COIN, "coins", 9, "Coin grants base currency") or failed

	var line4 = _board(7, 3, TileTypeScript.Value.MAGIC, TileTypeScript.Value.HEART)
	_set_many(line4, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)], TileTypeScript.Value.SWORD)
	_set_many(line4, [Vector2i(0, 1), Vector2i(5, 1), Vector2i(2, 0)], TileTypeScript.Value.EMPTY_STONE)
	var line4_effects = _resolver.evaluate(line4, _finder.find_matches(line4), 1.0, _rules)
	failed = _check(line4_effects.cleared_empty_stones == [Vector2i(0, 1), Vector2i(5, 1)], "Line 4 clears one blocker at each end only") or failed

	var line5 = _board(7, 5, TileTypeScript.Value.SWORD, TileTypeScript.Value.HEART)
	_set_many(line5, [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)], TileTypeScript.Value.MAGIC)
	_set_many(line5, [Vector2i(0, 1), Vector2i(3, 1), Vector2i(6, 3), Vector2i(0, 4)], TileTypeScript.Value.EMPTY_STONE)
	var line5_effects = _resolver.evaluate(line5, _finder.find_matches(line5), 1.0, _rules)
	failed = _check(line5_effects.cleared_empty_stones == [Vector2i(0, 1), Vector2i(3, 1), Vector2i(6, 3)], "Line 5+ clears every touching blocker") or failed

	var t_board = _board(5, 5, TileTypeScript.Value.SWORD, TileTypeScript.Value.MAGIC)
	_set_many(t_board, [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)], TileTypeScript.Value.HEART)
	_set_many(t_board, [Vector2i(1, 1), Vector2i(3, 3), Vector2i(0, 0)], TileTypeScript.Value.EMPTY_STONE)
	var t_matches := _finder.find_matches(t_board)
	failed = _check(t_matches[0].shape == MatchShapeScript.Value.T_OR_L, "Fixture is a T match") or failed
	var t_effects = _resolver.evaluate(t_board, t_matches, 1.0, _rules)
	failed = _check(t_effects.cleared_empty_stones == [Vector2i(1, 1), Vector2i(3, 3)], "T/L clears blockers in intersection 3x3") or failed

	var blockers = _board(5, 5, TileTypeScript.Value.SWORD, TileTypeScript.Value.MAGIC)
	_set_many(blockers, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], TileTypeScript.Value.EMPTY_STONE)
	failed = _check(_finder.find_matches(blockers).is_empty(), "Empty stones do not form matches") or failed

	quit(1 if failed else 0)


func _check_base_effect(tile: int, property: StringName, expected: int, description: String) -> bool:
	var first_filler := TileTypeScript.Value.SWORD
	var second_filler := TileTypeScript.Value.MAGIC
	if tile == first_filler or tile == second_filler:
		first_filler = TileTypeScript.Value.HEART
		second_filler = TileTypeScript.Value.COIN
	var board = _board(3, 3, first_filler, second_filler)
	_set_many(board, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], tile)
	var effects = _resolver.evaluate(board, _finder.find_matches(board), 1.0, _rules)
	return _check(effects.get(property) == expected, description)


func _board(width: int, height: int, first_tile: int, second_tile: int) -> RefCounted:
	var cells := PackedInt32Array()
	cells.resize(width * height)
	for y in height:
		for x in width:
			cells[y * width + x] = first_tile if (x + y) % 2 == 0 else second_tile
	return BoardModelScript.new(Vector2i(width, height), cells)


func _set_many(board: RefCounted, positions: Array[Vector2i], tile: int) -> void:
	for position in positions:
		board.set_cell(position, tile)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

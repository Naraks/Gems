class_name BoardResolver
extends RefCounted

const BoardCollapserScript = preload("res://core/board/board_collapser.gd")
const BoardResolutionResultScript = preload("res://core/board/board_resolution_result.gd")
const CascadeStepScript = preload("res://core/board/cascade_step.gd")
const MatchFinderScript = preload("res://core/board/match_finder.gd")
const TileEffectResolverScript = preload("res://core/board/tile_effect_resolver.gd")
const TileGeneratorScript = preload("res://core/board/tile_generator.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const MAX_CASCADE_STEPS := 100
const EMPTY_CELL := -1

var _rules: Resource
var _match_finder := MatchFinderScript.new()
var _collapser := BoardCollapserScript.new()
var _effect_resolver := TileEffectResolverScript.new()
var _tile_generator: RefCounted
var _tile_provider: Callable
var _empty_stone_count := 0
var cascade_bonus := 0.0


func _init(rules: Resource, seed: int = 0, tile_provider: Callable = Callable()) -> void:
	assert(rules != null and rules.is_valid(), "BoardResolver requires valid GameRules")
	_rules = rules
	_tile_generator = TileGeneratorScript.new(rules, seed)
	_tile_provider = tile_provider


func resolve(board: RefCounted) -> RefCounted:
	assert(board != null, "BoardResolver requires a board")
	var result = BoardResolutionResultScript.new()
	_empty_stone_count = _count_empty_stones(board)
	for cascade_index in range(1, MAX_CASCADE_STEPS + 1):
		var matches := _match_finder.find_matches(board, _rules.minimum_match_size)
		if matches.is_empty():
			return result
		var cascade_multiplier := cascade_multiplier_for(cascade_index)
		var effects = _effect_resolver.evaluate(board, matches, cascade_multiplier, _rules)
		var removed_cells := _remove_effect_cells(board, matches, effects)
		_empty_stone_count -= effects.cleared_empty_stones.size()
		var spawned := _collapser.collapse_and_refill(board, _next_tile)
		result.add_step(CascadeStepScript.new(cascade_index, matches, removed_cells, spawned, effects))
	result.stable = false
	push_error("Cascade resolution exceeded the safety limit")
	return result


func cascade_multiplier_for(cascade_index: int) -> float:
	var multiplier := CascadeStepScript.multiplier_for(cascade_index)
	if cascade_index > 1:
		multiplier = minf(2.0, multiplier + cascade_bonus)
	return multiplier


func _remove_effect_cells(board: RefCounted, matches: Array, effects: RefCounted) -> Array[Vector2i]:
	var unique_cells := {}
	for match_group in matches:
		for cell in match_group.cells:
			unique_cells[cell] = true
	for blocker in effects.cleared_empty_stones:
		unique_cells[blocker] = true
	var removed: Array[Vector2i] = []
	for cell in unique_cells:
		board.set_cell(cell, EMPTY_CELL)
		removed.append(cell)
	return removed


func _next_tile() -> int:
	var allow_empty: bool = _empty_stone_count < int(_rules.maximum_empty_stones)
	var tile: int
	if _tile_provider.is_valid():
		tile = int(_tile_provider.call(allow_empty))
	else:
		tile = _tile_generator.pick_tile(allow_empty)
	assert(TileTypeScript.is_valid(tile), "Tile provider returned an invalid tile")
	assert(allow_empty or tile != TileTypeScript.Value.EMPTY_STONE, "Tile provider exceeded blocker limit")
	if tile == TileTypeScript.Value.EMPTY_STONE:
		_empty_stone_count += 1
	return tile


func _count_empty_stones(board: RefCounted) -> int:
	var count := 0
	for tile in board.cells():
		if tile == TileTypeScript.Value.EMPTY_STONE:
			count += 1
	return count

class_name BoardGenerator
extends RefCounted

const BoardModelScript = preload("res://core/board/board_model.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const MAX_GENERATION_ATTEMPTS := 256

var _rules: Resource
var _random := RandomNumberGenerator.new()


func _init(rules: Resource, seed: int = 0) -> void:
	assert(rules != null and rules.is_valid(), "BoardGenerator requires valid GameRules")
	_rules = rules
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed


func generate_starting_board() -> RefCounted:
	for _attempt in MAX_GENERATION_ATTEMPTS:
		var board := _generate_match_free_board()
		if board.has_valid_move(_rules.minimum_match_size):
			return board
	push_error("Could not generate a starting board with a valid move")
	return null


func _generate_match_free_board() -> RefCounted:
	var board := BoardModelScript.new(_rules.board_size())
	var empty_stone_count := 0
	for y in board.size.y:
		for x in board.size.x:
			var position := Vector2i(x, y)
			var tile := _pick_tile(board, position, empty_stone_count)
			board.set_cell(position, tile)
			if tile == TileTypeScript.Value.EMPTY_STONE:
				empty_stone_count += 1
	return board


func _pick_tile(board: RefCounted, position: Vector2i, empty_stone_count: int) -> int:
	var candidates: Array[int] = []
	var weights: Array[float] = []
	for tile in TileTypeScript.COUNT:
		if tile == TileTypeScript.Value.EMPTY_STONE and empty_stone_count >= _rules.maximum_empty_stones:
			continue
		if _would_create_match(board, position, tile):
			continue
		candidates.append(tile)
		weights.append(_weight_for(tile))
	assert(not candidates.is_empty(), "At least one tile type must be available")
	return candidates[_weighted_index(weights)]


func _would_create_match(board: RefCounted, position: Vector2i, tile: int) -> bool:
	if not TileTypeScript.can_match(tile):
		return false
	var required_neighbors: int = int(_rules.minimum_match_size) - 1
	var horizontal_match: bool = position.x >= required_neighbors
	for offset in range(1, required_neighbors + 1):
		horizontal_match = horizontal_match and board.get_cell(position - Vector2i(offset, 0)) == tile
	var vertical_match: bool = position.y >= required_neighbors
	for offset in range(1, required_neighbors + 1):
		vertical_match = vertical_match and board.get_cell(position - Vector2i(0, offset)) == tile
	return horizontal_match or vertical_match


func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := _random.randf() * total
	for index in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return weights.size() - 1


func _weight_for(tile: int) -> float:
	match tile:
		TileTypeScript.Value.SWORD:
			return _rules.sword_weight
		TileTypeScript.Value.MAGIC:
			return _rules.magic_weight
		TileTypeScript.Value.HEART:
			return _rules.heart_weight
		TileTypeScript.Value.COIN:
			return _rules.coin_weight
		TileTypeScript.Value.EMPTY_STONE:
			return _rules.empty_stone_weight
		_:
			return 0.0

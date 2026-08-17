class_name BoardModel
extends RefCounted

const TileTypeScript = preload("res://core/board/tile_type.gd")

var size: Vector2i
var _cells: PackedInt32Array


func _init(board_size: Vector2i, cells: PackedInt32Array = PackedInt32Array()) -> void:
	assert(board_size.x > 0 and board_size.y > 0, "Board size must be positive")
	size = board_size
	if cells.is_empty():
		_cells.resize(cell_count())
		_cells.fill(-1)
	else:
		assert(cells.size() == cell_count(), "Cell count must match board dimensions")
		_cells = cells.duplicate()


func cell_count() -> int:
	return size.x * size.y


func contains(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < size.x and position.y < size.y


func get_cell(position: Vector2i) -> int:
	assert(contains(position), "Position is outside the board")
	return _cells[_index(position)]


func set_cell(position: Vector2i, tile: int) -> void:
	assert(contains(position), "Position is outside the board")
	assert(TileTypeScript.is_valid(tile) or tile == -1, "Unknown tile type")
	_cells[_index(position)] = tile


func cells() -> PackedInt32Array:
	return _cells.duplicate()


func swap(first: Vector2i, second: Vector2i) -> void:
	assert(contains(first) and contains(second), "Swap positions must be on the board")
	var first_index := _index(first)
	var second_index := _index(second)
	var temporary := _cells[first_index]
	_cells[first_index] = _cells[second_index]
	_cells[second_index] = temporary


func has_any_match(minimum_size: int = 3) -> bool:
	for y in size.y:
		for x in size.x:
			if has_match_at(Vector2i(x, y), minimum_size):
				return true
	return false


func has_match_at(position: Vector2i, minimum_size: int = 3) -> bool:
	if not contains(position):
		return false
	var tile := get_cell(position)
	if not TileTypeScript.can_match(tile):
		return false
	var horizontal := 1 + _count_direction(position, Vector2i.LEFT, tile) + _count_direction(position, Vector2i.RIGHT, tile)
	if horizontal >= minimum_size:
		return true
	var vertical := 1 + _count_direction(position, Vector2i.UP, tile) + _count_direction(position, Vector2i.DOWN, tile)
	return vertical >= minimum_size


func has_valid_move(minimum_size: int = 3) -> bool:
	for y in size.y:
		for x in size.x:
			var current := Vector2i(x, y)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor: Vector2i = current + direction
				if not contains(neighbor) or get_cell(current) == get_cell(neighbor):
					continue
				swap(current, neighbor)
				var creates_match := has_match_at(current, minimum_size) or has_match_at(neighbor, minimum_size)
				swap(current, neighbor)
				if creates_match:
					return true
	return false


func _index(position: Vector2i) -> int:
	return position.y * size.x + position.x


func _count_direction(origin: Vector2i, direction: Vector2i, tile: int) -> int:
	var count := 0
	var position := origin + direction
	while contains(position) and get_cell(position) == tile:
		count += 1
		position += direction
	return count

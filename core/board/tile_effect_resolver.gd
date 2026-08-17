class_name TileEffectResolver
extends RefCounted

const MatchEffectsScript = preload("res://core/board/match_effects.gd")
const MatchShapeScript = preload("res://core/board/match_shape.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func evaluate(board: RefCounted, matches: Array, cascade_multiplier: float, rules: Resource) -> RefCounted:
	assert(board != null and rules != null, "TileEffectResolver requires board and rules")
	var effects = MatchEffectsScript.new()
	var blockers := {}
	for match_group in matches:
		var strength: float = float(match_group.cells.size()) * match_group.multiplier() * cascade_multiplier
		match match_group.tile:
			TileTypeScript.Value.SWORD:
				effects.physical_damage += ceili(float(rules.base_physical_damage) * strength)
			TileTypeScript.Value.MAGIC:
				effects.magic_damage += ceili(float(rules.base_magic_damage) * strength)
			TileTypeScript.Value.HEART:
				effects.healing += ceili(float(rules.base_healing) * strength)
			TileTypeScript.Value.COIN:
				effects.coins += ceili(float(rules.base_coins) * strength)
		_collect_blockers(board, match_group, blockers)
	for position in blockers:
		effects.cleared_empty_stones.append(position)
	effects.cleared_empty_stones.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		return first.y < second.y or (first.y == second.y and first.x < second.x)
	)
	return effects


func _collect_blockers(board: RefCounted, match_group: RefCounted, blockers: Dictionary) -> void:
	match match_group.shape:
		MatchShapeScript.Value.LINE_4:
			_collect_line_end_blockers(board, match_group, blockers)
		MatchShapeScript.Value.LINE_5_PLUS:
			for cell in match_group.cells:
				_collect_area_blockers(board, cell, 1, blockers)
		MatchShapeScript.Value.T_OR_L:
			for intersection in _intersections(match_group.lines):
				_collect_area_blockers(board, intersection, 1, blockers)


func _collect_line_end_blockers(board: RefCounted, match_group: RefCounted, blockers: Dictionary) -> void:
	if match_group.lines.is_empty():
		return
	var line: Dictionary = match_group.lines[0]
	var direction := Vector2i.RIGHT if line.horizontal else Vector2i.DOWN
	_add_if_blocker(board, line.cells.front() - direction, blockers)
	_add_if_blocker(board, line.cells.back() + direction, blockers)


func _collect_area_blockers(board: RefCounted, center: Vector2i, radius: int, blockers: Dictionary) -> void:
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			if offset_x == 0 and offset_y == 0:
				continue
			_add_if_blocker(board, center + Vector2i(offset_x, offset_y), blockers)


func _intersections(lines: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for first_index in lines.size():
		for second_index in range(first_index + 1, lines.size()):
			var first: Dictionary = lines[first_index]
			var second: Dictionary = lines[second_index]
			if first.horizontal == second.horizontal:
				continue
			for cell in first.cells:
				if cell in second.cells and cell not in result:
					result.append(cell)
	return result


func _add_if_blocker(board: RefCounted, position: Vector2i, blockers: Dictionary) -> void:
	if board.contains(position) and board.get_cell(position) == TileTypeScript.Value.EMPTY_STONE:
		blockers[position] = true

class_name TileGenerator
extends RefCounted

const TileTypeScript = preload("res://core/board/tile_type.gd")

var _rules: Resource
var _random := RandomNumberGenerator.new()


func _init(rules: Resource, seed: int = 0) -> void:
	assert(rules != null and rules.is_valid(), "TileGenerator requires valid GameRules")
	_rules = rules
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed


func pick_tile(allow_empty_stone: bool = true) -> int:
	var candidates: Array[int] = []
	for tile in TileTypeScript.COUNT:
		if tile != TileTypeScript.Value.EMPTY_STONE or allow_empty_stone:
			candidates.append(tile)
	return pick_from(candidates)


func pick_from(candidates: Array[int]) -> int:
	assert(not candidates.is_empty(), "At least one tile candidate is required")
	var total := 0.0
	for tile in candidates:
		total += weight_for(tile)
	var roll := _random.randf() * total
	for tile in candidates:
		roll -= weight_for(tile)
		if roll <= 0.0:
			return tile
	return candidates.back()


func weight_for(tile: int) -> float:
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

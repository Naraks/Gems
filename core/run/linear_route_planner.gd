class_name LinearRoutePlanner
extends RefCounted

const RouteNodeScript = preload("res://core/run/route_node.gd")
const BATTLES_PER_BLOCK := 10
const MAX_SHOPS_PER_BLOCK := 2

var _random := RandomNumberGenerator.new()
var _shop_cache := {}


func _init(seed: int = 0) -> void:
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed


func generate_block(block_index: int) -> Array[RefCounted]:
	assert(block_index >= 0, "Block index cannot be negative")
	var shops := shop_positions_for_block(block_index)
	var nodes: Array[RefCounted] = []
	var first_battle := block_index * BATTLES_PER_BLOCK + 1
	for offset in BATTLES_PER_BLOCK:
		var battle_number := first_battle + offset
		var kind := RouteNodeScript.Kind.BOSS if battle_number % BATTLES_PER_BLOCK == 0 else RouteNodeScript.Kind.BATTLE
		nodes.append(RouteNodeScript.new(kind, battle_number, block_index + 1))
		if offset + 1 in shops:
			nodes.append(RouteNodeScript.new(RouteNodeScript.Kind.SHOP, battle_number, block_index + 1))
	return nodes


func shop_positions_for_block(block_index: int) -> Array[int]:
	assert(block_index >= 0, "Block index cannot be negative")
	if _shop_cache.has(block_index):
		return _shop_cache[block_index].duplicate()
	var count := _random.randi_range(1, 2) if block_index == 0 else _random.randi_range(0, 2)
	var positions: Array[int] = []
	if count == 1:
		positions.append(_random.randi_range(2, 5) if block_index == 0 else _random.randi_range(2, 9))
	elif count == 2:
		var first := _random.randi_range(2, 5 if block_index == 0 else 6)
		positions.append(first)
		positions.append(_random.randi_range(first + 3, 9))
	_shop_cache[block_index] = positions
	return positions.duplicate()

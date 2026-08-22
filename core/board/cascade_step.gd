class_name CascadeStep
extends RefCounted

var index: int
var multiplier: float
var matches: Array
var removed_cells: Array[Vector2i]
var spawned_tiles: int
var effects: RefCounted
var before_cells: PackedInt32Array
var cleared_cells: PackedInt32Array
var after_cells: PackedInt32Array
var movements: Array[Dictionary]
var spawns: Array[Dictionary]


func _init(
	step_index: int,
	found_matches: Array,
	removed: Array[Vector2i],
	spawned: int,
	resolved_effects: RefCounted,
	before := PackedInt32Array(),
	cleared := PackedInt32Array(),
	after := PackedInt32Array(),
	tile_movements: Array[Dictionary] = [],
	new_spawns: Array[Dictionary] = [],
) -> void:
	index = step_index
	multiplier = multiplier_for(step_index)
	matches = found_matches.duplicate()
	removed_cells = removed.duplicate()
	spawned_tiles = spawned
	effects = resolved_effects
	before_cells = before.duplicate()
	cleared_cells = cleared.duplicate()
	after_cells = after.duplicate()
	movements = tile_movements.duplicate(true)
	spawns = new_spawns.duplicate(true)


static func multiplier_for(step_index: int) -> float:
	assert(step_index >= 1, "Cascade index starts at one")
	return minf(1.0 + 0.25 * float(step_index - 1), 2.0)

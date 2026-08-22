class_name BoardView
extends Control

signal swap_requested(first: Vector2i, second: Vector2i)

const BoardInputControllerScript = preload("res://core/board/board_input_controller.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const TILE_COLORS := [
	Color("#ef6048"),
	Color("#6688ff"),
	Color("#ed5799"),
	Color("#f0bd3f"),
	Color("#9ba6ad"),
]
const TILE_SLOT_COLORS := [
	Color("#3a211f"),
	Color("#202b45"),
	Color("#3b2030"),
	Color("#3b321d"),
	Color("#2d3437"),
]
const TILE_TOOLTIPS := [
	"Меч — наносит урон",
	"Магия — наносит магический урон",
	"Сердце — восстанавливает здоровье",
	"Монета — приносит золото",
	"Камень — не образует комбинации",
]
const BOARD_COLOR := Color("#101b19")
const BOARD_EDGE := Color("#8ebd72")
const SLOT_COLOR := Color("#24302e")
const SLOT_INSET := Color("#182321")
const PIXEL_OUTLINE := Color("#101514")
const PIXEL_HIGHLIGHT := Color("#fff2c7")
const GEM_PIXEL_GRID := 24.0
const MATCH_SECONDS := 0.18
const SWAP_SECONDS := 0.14
const INVALID_HOLD_SECONDS := 0.07
const REMOVE_SECONDS := 0.18
const MIN_FALL_SECONDS := 0.14
const FALL_SECONDS_PER_CELL := 0.04
const MAX_FALL_SECONDS := 0.36
const SETTLE_SECONDS := 0.11
const CASCADE_PAUSE_SECONDS := 0.08
const FAST_SPEED := 6.0
const DEFAULT_HINT_DELAY_SECONDS := 5.0
const HINT_COLOR := Color("#fff2a8")

var _board: RefCounted
var _input_controller: RefCounted
var _hovered_position := BoardInputControllerScript.NO_POSITION
var animation_active := false
var _animation_phase := &""
var _animation_cells := PackedInt32Array()
var _animation_removed: Array[Vector2i] = []
var _animation_movements: Array[Dictionary] = []
var _animation_spawns: Array[Dictionary] = []
var _animation_cascade_index := 0
var _animation_multiplier := 1.0
var _animation_speed := 1.0
var _animation_tween: Tween
var _animation_progress := 0.0:
	set(value):
		_animation_progress = value
		queue_redraw()
var hint_delay_seconds := DEFAULT_HINT_DELAY_SECONDS
var hint_visible := false
var hinted_cells: Array[Vector2i] = []
var _hint_enabled := true
var _hint_elapsed := 0.0
var _hint_cycle := 0
var _hint_pulse := 0.0


func _ready() -> void:
	mouse_exited.connect(_clear_hover)
	set_process(true)


func setup(board: RefCounted) -> void:
	assert(board != null, "BoardView requires a board")
	_board = board
	_input_controller = BoardInputControllerScript.new(board.size)
	_input_controller.swap_requested.connect(_on_swap_requested)
	_input_controller.selection_changed.connect(_on_selection_changed)
	reset_hint_timer()
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	if _input_controller != null:
		_input_controller.set_input_enabled(enabled)
	if not enabled:
		clear_transient_state()
	else:
		reset_hint_timer()
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_hint_enabled(enabled: bool) -> void:
	_hint_enabled = enabled
	reset_hint_timer()


func reset_hint_timer() -> void:
	_hint_elapsed = 0.0
	hide_move_hint()


func hide_move_hint() -> void:
	if not hint_visible and hinted_cells.is_empty():
		return
	hint_visible = false
	hinted_cells.clear()
	queue_redraw()


func notify_player_interaction() -> void:
	reset_hint_timer()


func _process(delta: float) -> void:
	if not _can_show_hint():
		reset_hint_timer()
		return
	_hint_elapsed += delta
	if hint_visible:
		_hint_pulse += delta
		queue_redraw()
	elif _hint_elapsed >= hint_delay_seconds:
		_show_move_hint()


func _can_show_hint() -> bool:
	return (
		_hint_enabled
		and _board != null
		and _input_controller != null
		and _input_controller.input_enabled
		and not animation_active
		and not get_tree().paused
		and not _board.has_any_match()
	)


func _show_move_hint() -> void:
	var moves: Array = _board.find_valid_moves()
	if moves.is_empty():
		return
	var move: RefCounted = moves[_hint_cycle % moves.size()]
	_hint_cycle += 1
	hinted_cells.assign([move.first, move.second])
	hint_visible = true
	_hint_pulse = 0.0
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func play_resolution(resolution: RefCounted) -> void:
	reset_hint_timer()
	if resolution == null or resolution.steps.is_empty():
		return
	animation_active = true
	_animation_speed = 1.0
	_clear_hover()
	for step in resolution.steps:
		if step.index > 1:
			_play_sfx(&"cascade")
		_play_sfx(_gem_sound_for_step(step))
		_animation_cascade_index = step.index
		_animation_multiplier = step.multiplier
		_animation_cells = step.before_cells
		_animation_removed = step.removed_cells
		await _play_animation_phase(&"match", MATCH_SECONDS, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		await _play_animation_phase(&"remove", REMOVE_SECONDS, Tween.TRANS_QUAD, Tween.EASE_IN)
		_animation_cells = step.cleared_cells
		_animation_movements = step.movements
		_animation_spawns = step.spawns
		await _play_animation_phase(&"fall", _fall_duration(step), Tween.TRANS_QUAD, Tween.EASE_IN)
		_animation_cells = step.after_cells
		await _play_animation_phase(&"settle", SETTLE_SECONDS, Tween.TRANS_BACK, Tween.EASE_OUT)
		if step.index < resolution.steps.size():
			await get_tree().create_timer(CASCADE_PAUSE_SECONDS / _animation_speed).timeout
	_animation_phase = &""
	_animation_cells = PackedInt32Array()
	_animation_removed.clear()
	_animation_movements.clear()
	_animation_spawns.clear()
	_animation_cascade_index = 0
	animation_active = false
	queue_redraw()


func play_swap(first: Vector2i, second: Vector2i, before_cells: PackedInt32Array) -> void:
	reset_hint_timer()
	_play_sfx(&"swap")
	animation_active = true
	_animation_speed = 1.0
	_animation_cells = before_cells.duplicate()
	_animation_movements = [
		{"tile": _cell_from_snapshot(before_cells, first), "from": first, "to": second},
		{"tile": _cell_from_snapshot(before_cells, second), "from": second, "to": first},
	]
	_animation_spawns.clear()
	_animation_removed = [first, second]
	await _play_animation_phase(&"swap", SWAP_SECONDS, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	_animation_phase = &""
	_animation_cells = PackedInt32Array()
	_animation_movements.clear()
	_animation_removed.clear()
	animation_active = false
	queue_redraw()


func play_invalid_swap_return(first: Vector2i, second: Vector2i, swapped_cells: PackedInt32Array) -> void:
	reset_hint_timer()
	animation_active = true
	_animation_speed = 1.0
	_animation_cells = swapped_cells.duplicate()
	_animation_removed = [first, second]
	await _play_animation_phase(&"invalid", INVALID_HOLD_SECONDS, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_animation_movements = [
		{"tile": _cell_from_snapshot(swapped_cells, first), "from": first, "to": second},
		{"tile": _cell_from_snapshot(swapped_cells, second), "from": second, "to": first},
	]
	await _play_animation_phase(&"swap", SWAP_SECONDS, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	_animation_phase = &""
	_animation_cells = PackedInt32Array()
	_animation_movements.clear()
	_animation_removed.clear()
	animation_active = false
	queue_redraw()


func _fall_duration(step: RefCounted) -> float:
	var maximum_distance := 1
	for movement in step.movements:
		var movement_from: Vector2i = movement["from"]
		var movement_to: Vector2i = movement["to"]
		maximum_distance = maxi(maximum_distance, absi(movement_to.y - movement_from.y))
	for spawn in step.spawns:
		var spawn_from: Vector2i = spawn["from"]
		var spawn_to: Vector2i = spawn["to"]
		maximum_distance = maxi(maximum_distance, absi(spawn_to.y - spawn_from.y))
	return minf(MAX_FALL_SECONDS, MIN_FALL_SECONDS + FALL_SECONDS_PER_CELL * float(maximum_distance - 1))


func accelerate_animation() -> void:
	if not animation_active:
		return
	_animation_speed = FAST_SPEED
	if _animation_tween != null and _animation_tween.is_valid():
		_animation_tween.set_speed_scale(FAST_SPEED)


func _play_animation_phase(phase: StringName, duration: float, transition: Tween.TransitionType, easing: Tween.EaseType) -> void:
	_animation_phase = phase
	_animation_progress = 0.0
	_animation_tween = create_tween()
	_animation_tween.set_speed_scale(_animation_speed)
	_animation_tween.tween_property(self, "_animation_progress", 1.0, duration).set_trans(transition).set_ease(easing)
	await _animation_tween.finished


func cell_at(local_position: Vector2) -> Vector2i:
	if _board == null:
		return BoardInputControllerScript.NO_POSITION
	var board_rect := _board_rect()
	if not board_rect.has_point(local_position):
		return BoardInputControllerScript.NO_POSITION
	var cell_size := board_rect.size / Vector2(_board.size)
	var relative := local_position - board_rect.position
	return Vector2i(floori(relative.x / cell_size.x), floori(relative.y / cell_size.y))


func _gui_input(event: InputEvent) -> void:
	if _input_controller == null or not _input_controller.input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		notify_player_interaction()
		_handle_pointer(event.position, event.pressed)
		accept_event()
	elif event is InputEventScreenTouch:
		notify_player_interaction()
		_handle_pointer(event.position, event.pressed)
		accept_event()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			notify_player_interaction()
		var hovered := cell_at(event.position)
		if hovered != _hovered_position:
			_hovered_position = hovered
			queue_redraw()


func _draw() -> void:
	if _board == null:
		return
	var board_rect := _board_rect()
	var cell_size := board_rect.size / Vector2(_board.size)
	var frame := board_rect.grow(10.0)
	draw_rect(Rect2(frame.position + Vector2(5, 5), frame.size), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(frame, BOARD_EDGE.darkened(0.35), true)
	draw_rect(frame.grow(-4.0), BOARD_COLOR, true)
	if animation_active:
		_draw_animated_board(cell_size)
	else:
		_draw_idle_board(cell_size)
	_draw_cascade_label(board_rect)
	if not animation_active:
		_draw_hover_tooltip(board_rect)


func _draw_idle_board(cell_size: Vector2) -> void:
	for y in _board.size.y:
		for x in _board.size.x:
			var position := Vector2i(x, y)
			var tile: int = _board.get_cell(position)
			var rect := _draw_tile(tile, Vector2(position), cell_size)
			if _input_controller.selected_position != BoardInputControllerScript.NO_POSITION and _input_controller.are_adjacent(_input_controller.selected_position, position):
				draw_rect(rect.grow(-1.0), Color(BOARD_EDGE, 0.72), false, 2.0)
			if _hovered_position == position:
				draw_rect(rect.grow(1.0), Color("#d8f0bd"), false, 2.0)
			if _input_controller.selected_position == position:
				draw_rect(rect.grow(2.0), Color("#fff1a8"), false, 3.0)
				draw_rect(rect.grow(-2.0), Color("#fff1a8"), false, 2.0)
			if hint_visible and position in hinted_cells:
				var pulse := 0.72 + sin(_hint_pulse * TAU * 1.5) * 0.20
				draw_rect(rect.grow(2.0), Color(HINT_COLOR, pulse), false, 3.0)
				draw_rect(rect.grow(-3.0), Color(HINT_COLOR, pulse * 0.65), false, 2.0)
	if hint_visible and hinted_cells.size() == 2:
		_draw_hint_direction(cell_size)


func _draw_hint_direction(cell_size: Vector2) -> void:
	var board_rect := _board_rect()
	var first_center := board_rect.position + (Vector2(hinted_cells[0]) + Vector2.ONE * 0.5) * cell_size
	var second_center := board_rect.position + (Vector2(hinted_cells[1]) + Vector2.ONE * 0.5) * cell_size
	var direction := first_center.direction_to(second_center)
	var inset := minf(cell_size.x, cell_size.y) * 0.24
	var start := first_center + direction * inset
	var end := second_center - direction * inset
	var color := Color(HINT_COLOR, 0.62 + sin(_hint_pulse * TAU * 1.5) * 0.16)
	draw_line(start, end, color, 3.0)
	var side := direction.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([end, end - direction * 8.0 + side, end - direction * 8.0 - side]), color)


func _draw_animated_board(cell_size: Vector2) -> void:
	match _animation_phase:
		&"invalid":
			for y in _board.size.y:
				for x in _board.size.x:
					var position := Vector2i(x, y)
					var tile := _cell_from_snapshot(_animation_cells, position)
					if tile < 0:
						continue
					var rect := _draw_tile(tile, Vector2(position), cell_size)
					if position in _animation_removed:
						draw_rect(rect.grow(2.0), Color("#ff6658"), false, 3.0)
		&"swap":
			for y in _board.size.y:
				for x in _board.size.x:
					var position := Vector2i(x, y)
					if position in _animation_removed:
						continue
					var tile := _cell_from_snapshot(_animation_cells, position)
					if tile >= 0:
						_draw_tile(tile, Vector2(position), cell_size)
			for movement in _animation_movements:
				var from := Vector2(movement["from"])
				var to := Vector2(movement["to"])
				_draw_tile(int(movement["tile"]), from.lerp(to, _animation_progress), cell_size)
		&"match", &"remove":
			for y in _board.size.y:
				for x in _board.size.x:
					var position := Vector2i(x, y)
					var tile := _cell_from_snapshot(_animation_cells, position)
					if tile < 0:
						continue
					var is_removed := position in _animation_removed
					var scale := Vector2.ONE
					if is_removed and _animation_phase == &"match":
						scale = Vector2.ONE * (1.0 + sin(_animation_progress * PI) * 0.12)
					elif is_removed and _animation_phase == &"remove":
						scale = Vector2.ONE * maxf(0.0, 1.0 - _animation_progress)
					var rect := _draw_tile(tile, Vector2(position), cell_size, scale)
					if is_removed and _animation_phase == &"match":
						draw_rect(rect.grow(2.0), Color("#fff4a8"), false, 3.0)
		&"fall":
			for movement in _animation_movements:
				var from := Vector2(movement["from"])
				var to := Vector2(movement["to"])
				_draw_tile(int(movement["tile"]), from.lerp(to, _animation_progress), cell_size)
			for spawn in _animation_spawns:
				var from := Vector2(spawn["from"])
				var to := Vector2(spawn["to"])
				_draw_tile(int(spawn["tile"]), from.lerp(to, _animation_progress), cell_size)
		&"settle":
			var settle_scale := Vector2(1.0 + (1.0 - _animation_progress) * 0.06, 0.86 + _animation_progress * 0.14)
			for y in _board.size.y:
				for x in _board.size.x:
					var position := Vector2i(x, y)
					var tile := _cell_from_snapshot(_animation_cells, position)
					if tile >= 0:
						_draw_tile(tile, Vector2(position), cell_size, settle_scale)


func _draw_tile(tile: int, grid_position: Vector2, cell_size: Vector2, scale := Vector2.ONE) -> Rect2:
	var gap := maxf(2.0, floorf(minf(cell_size.x, cell_size.y) * 0.055))
	var rect := Rect2(_board_rect().position + grid_position * cell_size, cell_size).grow(-gap)
	if scale.x <= 0.01 or scale.y <= 0.01:
		return rect
	var scaled_rect := Rect2(rect.get_center() - rect.size * scale * 0.5, rect.size * scale)
	draw_rect(Rect2(scaled_rect.position + Vector2(0, 3), scaled_rect.size), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(scaled_rect, TILE_SLOT_COLORS[tile], true)
	draw_rect(scaled_rect.grow(-3.0), TILE_SLOT_COLORS[tile].darkened(0.28), true)
	_draw_pixel_gem(tile, scaled_rect.grow(-maxf(5.0, scaled_rect.size.x * 0.13)))
	return scaled_rect


func _cell_from_snapshot(cells: PackedInt32Array, position: Vector2i) -> int:
	return cells[position.y * _board.size.x + position.x]


func _draw_cascade_label(board_rect: Rect2) -> void:
	if not animation_active or _animation_cascade_index <= 1:
		return
	var label := tr("КАСКАД ×%s") % ("%.2f" % _animation_multiplier)
	var font := get_theme_default_font()
	var font_size := 16
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var label_rect := Rect2(board_rect.get_center().x - text_size.x * 0.5 - 10.0, board_rect.position.y + 8.0, text_size.x + 20.0, text_size.y + 12.0)
	draw_rect(label_rect, Color(0.04, 0.08, 0.06, 0.9), true)
	draw_rect(label_rect, Color("#d7f0a8"), false, 2.0)
	draw_string(font, label_rect.position + Vector2(10.0, text_size.y + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#fff4c4"))


func _draw_pixel_gem(tile: int, rect: Rect2) -> void:
	match tile:
		TileTypeScript.Value.SWORD:
			_draw_pixel_shape(rect, [Vector2(8, 5), Vector2(12, 0), Vector2(16, 5), Vector2(16, 14), Vector2(14, 17), Vector2(10, 17), Vector2(8, 14)], Color("#7f2526"))
			_draw_pixel_shape(rect, [Vector2(9, 5), Vector2(12, 1), Vector2(12, 16), Vector2(10, 14)], Color("#ff9a72"), false)
			_draw_pixel_shape(rect, [Vector2(12, 1), Vector2(15, 5), Vector2(15, 14), Vector2(13, 16), Vector2(12, 16)], Color("#d9443e"), false)
			_draw_pixel_rect(rect, Rect2(2, 14, 20, 5), PIXEL_OUTLINE)
			_draw_pixel_rect(rect, Rect2(3, 15, 18, 3), Color("#a86d21"))
			_draw_pixel_rect(rect, Rect2(4, 15, 16, 1), Color("#ffd36a"))
			_draw_pixel_rect(rect, Rect2(2, 15, 3, 3), Color("#d99c36"))
			_draw_pixel_rect(rect, Rect2(19, 15, 3, 3), Color("#d99c36"))
			_draw_pixel_rect(rect, Rect2(9, 18, 6, 5), PIXEL_OUTLINE)
			_draw_pixel_rect(rect, Rect2(10, 18, 4, 5), Color("#713d30"))
			_draw_pixel_rect(rect, Rect2(10, 18, 4, 1), Color("#e28b4d"))
			_draw_pixel_rect(rect, Rect2(10, 20, 4, 1), Color("#e28b4d"))
			_draw_pixel_shape(rect, [Vector2(9, 22), Vector2(15, 22), Vector2(17, 24), Vector2(7, 24)], Color("#b97922"))
			_draw_pixel_rect(rect, Rect2(10, 22, 4, 1), Color("#ffe184"))
		TileTypeScript.Value.MAGIC:
			_draw_pixel_shape(rect, [Vector2(12, 0), Vector2(15, 8), Vector2(24, 12), Vector2(15, 15), Vector2(12, 24), Vector2(9, 15), Vector2(0, 12), Vector2(9, 8)], Color("#273e9d"))
			_draw_pixel_shape(rect, [Vector2(12, 2), Vector2(14, 10), Vector2(22, 12), Vector2(14, 14), Vector2(12, 22), Vector2(10, 14), Vector2(2, 12), Vector2(10, 10)], Color("#5d82ff"), false)
			_draw_pixel_shape(rect, [Vector2(12, 3), Vector2(12, 12), Vector2(9, 10)], Color("#91adff"), false)
			_draw_pixel_shape(rect, [Vector2(3, 12), Vector2(12, 12), Vector2(9, 10)], Color("#91adff"), false)
			_draw_pixel_shape(rect, [Vector2(12, 12), Vector2(21, 12), Vector2(14, 14), Vector2(12, 21)], Color("#365bcf"), false)
			_draw_pixel_shape(rect, [Vector2(12, 7), Vector2(14, 11), Vector2(18, 12), Vector2(14, 13), Vector2(12, 17), Vector2(10, 13), Vector2(6, 12), Vector2(10, 11)], Color("#f5f0ce"), false)
			_draw_pixel_rect(rect, Rect2(11, 10, 3, 3), Color("#ffffff"))
			for sparkle in [Rect2(3, 5, 2, 2), Rect2(19, 5, 1, 2), Rect2(4, 18, 1, 1), Rect2(19, 18, 2, 1)]:
				_draw_pixel_rect(rect, sparkle, Color("#9fc2ff"))
		TileTypeScript.Value.HEART:
			_draw_pixel_shape(rect, [Vector2(2, 6), Vector2(6, 2), Vector2(10, 2), Vector2(12, 5), Vector2(14, 2), Vector2(19, 2), Vector2(23, 6), Vector2(23, 12), Vector2(12, 23), Vector2(1, 12)], Color("#9d2759"))
			_draw_pixel_shape(rect, [Vector2(3, 7), Vector2(7, 3), Vector2(10, 4), Vector2(12, 8), Vector2(14, 4), Vector2(19, 3), Vector2(22, 7), Vector2(21, 12), Vector2(12, 21), Vector2(3, 12)], Color("#ef5798"), false)
			_draw_pixel_shape(rect, [Vector2(12, 8), Vector2(21, 6), Vector2(21, 12), Vector2(12, 21)], Color("#bd356e"), false)
			_draw_pixel_shape(rect, [Vector2(4, 7), Vector2(7, 4), Vector2(10, 5), Vector2(10, 9), Vector2(7, 11), Vector2(4, 10)], Color("#ff9fc7"), false)
			_draw_pixel_rect(rect, Rect2(5, 5, 4, 3), Color("#ffd4e5"))
			_draw_pixel_shape(rect, [Vector2(7, 13), Vector2(12, 18), Vector2(12, 21), Vector2(4, 13)], Color("#db417e"), false)
		TileTypeScript.Value.COIN:
			_draw_pixel_shape(rect, [Vector2(7, 1), Vector2(17, 1), Vector2(23, 7), Vector2(23, 17), Vector2(17, 23), Vector2(7, 23), Vector2(1, 17), Vector2(1, 7)], Color("#9d6a14"))
			_draw_pixel_shape(rect, [Vector2(7, 2), Vector2(17, 2), Vector2(22, 7), Vector2(22, 17), Vector2(17, 22), Vector2(7, 22), Vector2(2, 17), Vector2(2, 7)], Color("#efb62d"), false)
			_draw_pixel_shape(rect, [Vector2(8, 5), Vector2(16, 5), Vector2(19, 8), Vector2(19, 16), Vector2(16, 19), Vector2(8, 19), Vector2(5, 16), Vector2(5, 8)], Color("#b77d18"), false)
			_draw_pixel_shape(rect, [Vector2(9, 6), Vector2(16, 6), Vector2(18, 9), Vector2(18, 15), Vector2(15, 18), Vector2(9, 18), Vector2(6, 15), Vector2(6, 9)], Color("#dca025"), false)
			_draw_pixel_rect(rect, Rect2(7, 4, 9, 2), Color("#ffe277"))
			_draw_pixel_rect(rect, Rect2(7, 7, 3, 8), Color("#f5c84a"))
			_draw_pixel_rect(rect, Rect2(10, 8, 6, 2), Color("#fff0a0"))
			_draw_pixel_rect(rect, Rect2(10, 9, 2, 7), Color("#fff0a0"))
			_draw_pixel_rect(rect, Rect2(11, 14, 5, 2), Color("#fff0a0"))
			_draw_pixel_rect(rect, Rect2(14, 12, 2, 3), Color("#fff0a0"))
			_draw_pixel_rect(rect, Rect2(17, 17, 2, 2), Color("#835311"))
		TileTypeScript.Value.EMPTY_STONE:
			_draw_pixel_shape(rect, [Vector2(10, 1), Vector2(17, 3), Vector2(22, 8), Vector2(23, 15), Vector2(17, 22), Vector2(9, 23), Vector2(2, 18), Vector2(1, 10), Vector2(5, 4)], Color("#515c61"))
			_draw_pixel_shape(rect, [Vector2(10, 2), Vector2(17, 4), Vector2(21, 8), Vector2(21, 14), Vector2(16, 20), Vector2(9, 21), Vector2(3, 17), Vector2(3, 10), Vector2(6, 5)], Color("#929da3"), false)
			_draw_pixel_shape(rect, [Vector2(7, 5), Vector2(15, 4), Vector2(18, 8), Vector2(14, 11), Vector2(6, 10), Vector2(4, 8)], Color("#c0c9cd"), false)
			_draw_pixel_shape(rect, [Vector2(14, 11), Vector2(21, 9), Vector2(21, 15), Vector2(16, 20), Vector2(10, 18)], Color("#69757b"), false)
			_draw_pixel_shape(rect, [Vector2(3, 11), Vector2(9, 11), Vector2(10, 18), Vector2(7, 20), Vector2(3, 17)], Color("#7d898f"), false)
			_draw_pixel_shape(rect, [Vector2(8, 6), Vector2(13, 5), Vector2(12, 8), Vector2(7, 9)], Color("#e2e7e8"), false)
			_draw_pixel_line(rect, Vector2(13, 9), Vector2(11, 13), Color("#434d52"), 1.5)
			_draw_pixel_line(rect, Vector2(11, 13), Vector2(15, 16), Color("#434d52"), 1.5)
			_draw_pixel_line(rect, Vector2(11, 13), Vector2(8, 17), Color("#434d52"), 1.5)
			_draw_pixel_line(rect, Vector2(15, 16), Vector2(18, 15), Color("#434d52"), 1.0)


func _draw_pixel_shape(rect: Rect2, points: Array[Vector2], color: Color, outline := true) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(_pixel_point(rect, point))
	if outline:
		var pixel := maxf(1.0, floorf(rect.size.x / GEM_PIXEL_GRID))
		for offset in [Vector2(-pixel, 0), Vector2(pixel, 0), Vector2(0, -pixel), Vector2(0, pixel), Vector2(pixel, pixel)]:
			var shadow := PackedVector2Array()
			for point in polygon:
				shadow.append(point + offset)
			draw_colored_polygon(shadow, PIXEL_OUTLINE)
	draw_colored_polygon(polygon, color)


func _draw_pixel_rect(rect: Rect2, pixel_rect: Rect2, color: Color) -> void:
	var from := _pixel_point(rect, pixel_rect.position)
	var to := _pixel_point(rect, pixel_rect.end)
	draw_rect(Rect2(from, to - from), color, true)


func _draw_pixel_line(rect: Rect2, from: Vector2, to: Vector2, color: Color, width_in_pixels: float) -> void:
	var pixel_width := maxf(1.0, floorf(rect.size.x / GEM_PIXEL_GRID) * width_in_pixels)
	draw_line(_pixel_point(rect, from), _pixel_point(rect, to), color, pixel_width, false)


func _pixel_point(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		roundf(rect.position.x + point.x * rect.size.x / GEM_PIXEL_GRID),
		roundf(rect.position.y + point.y * rect.size.y / GEM_PIXEL_GRID),
	)


func _handle_pointer(local_position: Vector2, pressed: bool) -> void:
	var cell := cell_at(local_position)
	if pressed:
		_input_controller.begin_pointer(cell)
	else:
		_input_controller.end_pointer(cell)


func tooltip_for_position(at_position: Vector2) -> String:
	var position := cell_at(at_position)
	if position == BoardInputControllerScript.NO_POSITION:
		return ""
	return tr(TILE_TOOLTIPS[_board.get_cell(position)])


func _get_tooltip(_at_position: Vector2) -> String:
	return ""


func _draw_hover_tooltip(board_rect: Rect2) -> void:
	if _hovered_position == BoardInputControllerScript.NO_POSITION or _board == null:
		return
	var text := tr(TILE_TOOLTIPS[_board.get_cell(_hovered_position)])
	var font := get_theme_default_font()
	var font_size := 12
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var tooltip_rect := Rect2(
		board_rect.get_center().x - text_size.x * 0.5 - 10.0,
		board_rect.position.y + 8.0,
		text_size.x + 20.0,
		text_size.y + 12.0,
	)
	draw_rect(tooltip_rect, Color(0.03, 0.07, 0.05, 0.96), true)
	draw_rect(tooltip_rect, Color(BOARD_EDGE, 0.9), false, 2.0)
	draw_string(font, tooltip_rect.position + Vector2(10.0, text_size.y + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f4f0d0"))


func clear_transient_state() -> void:
	_clear_hover()
	hide_move_hint()
	tooltip_text = ""


func _clear_hover() -> void:
	if _hovered_position == BoardInputControllerScript.NO_POSITION:
		return
	_hovered_position = BoardInputControllerScript.NO_POSITION
	queue_redraw()


func _board_rect() -> Rect2:
	var padding := clampf(minf(size.x, size.y) * 0.035, 10.0, 24.0)
	var side := minf(size.x, size.y) - padding * 2.0
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)


func _on_swap_requested(first: Vector2i, second: Vector2i) -> void:
	notify_player_interaction()
	swap_requested.emit(first, second)


func _on_selection_changed(_position: Vector2i) -> void:
	notify_player_interaction()
	queue_redraw()


func _play_sfx(sound_name: StringName) -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.play_sfx(sound_name)


func _gem_sound_for_step(step: RefCounted) -> StringName:
	var counts := PackedInt32Array()
	counts.resize(TileTypeScript.COUNT)
	for position in step.removed_cells:
		var tile := _cell_from_snapshot(step.before_cells, position)
		if tile >= 0 and tile < counts.size():
			counts[tile] += 1
	var dominant_tile := TileTypeScript.Value.SWORD
	for tile in counts.size():
		if counts[tile] > counts[dominant_tile]:
			dominant_tile = tile
	match dominant_tile:
		TileTypeScript.Value.SWORD: return &"gem_sword"
		TileTypeScript.Value.MAGIC: return &"gem_magic"
		TileTypeScript.Value.HEART: return &"gem_heart"
		TileTypeScript.Value.COIN: return &"gem_coin"
		TileTypeScript.Value.EMPTY_STONE: return &"gem_stone"
	return &"match"

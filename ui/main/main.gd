extends Control

const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")
const SWAP_PREVIEW_SECONDS := 0.12

@export var rules: GameRules

@onready var board_view: Control = %BoardView
@onready var turn_result_label: Label = %TurnResultLabel

var _board: RefCounted
var _turn_controller: RefCounted


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	_board = BoardGeneratorScript.new(rules).generate_starting_board()
	assert(_board != null, "Starting board generation failed")
	_turn_controller = BoardTurnControllerScript.new(_board, rules.minimum_match_size)
	board_view.setup(_board)
	board_view.swap_requested.connect(_on_swap_requested)


func _on_swap_requested(first: Vector2i, second: Vector2i) -> void:
	board_view.set_input_enabled(false)
	if not _turn_controller.begin_swap(first, second):
		board_view.set_input_enabled(true)
		return
	board_view.refresh()
	await get_tree().create_timer(SWAP_PREVIEW_SECONDS).timeout
	var is_valid: bool = _turn_controller.finish_swap()
	board_view.refresh()
	if is_valid:
		turn_result_label.text = "Ход %d" % _turn_controller.move_count
	else:
		turn_result_label.text = "Недопустимый ход"
		await get_tree().create_timer(SWAP_PREVIEW_SECONDS).timeout
	board_view.set_input_enabled(true)

extends Control

const BoardGeneratorScript = preload("res://core/board/board_generator.gd")

@export var rules: GameRules

@onready var board_view: Control = %BoardView

var _board: RefCounted


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	_board = BoardGeneratorScript.new(rules).generate_starting_board()
	assert(_board != null, "Starting board generation failed")
	board_view.setup(_board)
	board_view.swap_requested.connect(_on_swap_requested)


func _on_swap_requested(first: Vector2i, second: Vector2i) -> void:
	board_view.set_input_enabled(false)
	_board.swap(first, second)
	board_view.refresh()
	# Match resolution will become asynchronous in subsequent prototype issues.
	board_view.call_deferred("set_input_enabled", true)

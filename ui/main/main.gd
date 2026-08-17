extends Control

const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardShufflerScript = preload("res://core/board/board_shuffler.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")
const SWAP_PREVIEW_SECONDS := 0.12

@export var rules: GameRules

@onready var board_view: Control = %BoardView
@onready var turn_result_label: Label = %TurnResultLabel

var _board: RefCounted
var _board_resolver: RefCounted
var _board_shuffler: RefCounted
var _turn_controller: RefCounted


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	_board = BoardGeneratorScript.new(rules).generate_starting_board()
	assert(_board != null, "Starting board generation failed")
	_board_resolver = BoardResolverScript.new(rules)
	_board_shuffler = BoardShufflerScript.new()
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
		var resolution = _board_resolver.resolve(_board)
		var was_reshuffled: bool = _board_shuffler.reshuffle_if_stuck(_board, rules.minimum_match_size)
		board_view.refresh()
		turn_result_label.text = "Ход %d · каскадов: %d%s" % [
			_turn_controller.move_count,
			resolution.steps.size(),
			" · ⚔%d ✦%d ♥%d ◉%d%s" % [
				resolution.total_physical_damage,
				resolution.total_magic_damage,
				resolution.total_healing,
				resolution.total_coins,
				" · поле перемешано" if was_reshuffled else "",
			],
		]
	else:
		turn_result_label.text = "Недопустимый ход"
		await get_tree().create_timer(SWAP_PREVIEW_SECONDS).timeout
	board_view.set_input_enabled(true)

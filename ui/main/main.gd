extends Control

const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardShufflerScript = preload("res://core/board/board_shuffler.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const CombatTurnResolverScript = preload("res://core/combat/combat_turn_resolver.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const SWAP_PREVIEW_SECONDS := 0.12

@export var rules: GameRules

@onready var board_view: Control = %BoardView
@onready var turn_result_label: Label = %TurnResultLabel
@onready var combat_status_label: Label = %CombatStatusLabel

var _board: RefCounted
var _board_resolver: RefCounted
var _board_shuffler: RefCounted
var _turn_controller: RefCounted
var _battle: RefCounted
var _combat_resolver := CombatTurnResolverScript.new()


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	_board = BoardGeneratorScript.new(rules).generate_starting_board()
	assert(_board != null, "Starting board generation failed")
	_board_resolver = BoardResolverScript.new(rules)
	_board_shuffler = BoardShufflerScript.new()
	_turn_controller = BoardTurnControllerScript.new(_board, rules.minimum_match_size)
	_battle = BattleStateScript.new(
		HeroStateScript.new(
			rules.hero_max_health,
			-1,
			rules.hero_sword_power,
			rules.hero_magic_power,
			rules.hero_healing_power,
			rules.hero_coin_multiplier,
		),
		EnemyStateScript.new(rules.enemy_base_health),
	)
	board_view.setup(_board)
	board_view.swap_requested.connect(_on_swap_requested)
	_update_combat_status()


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
		var combat_result = _combat_resolver.resolve(resolution, _battle, _perform_enemy_action)
		var was_reshuffled: bool = _board_shuffler.reshuffle_if_stuck(_board, rules.minimum_match_size)
		board_view.refresh()
		_update_combat_status()
		turn_result_label.text = "Ход %d · каскадов: %d%s" % [
			_turn_controller.move_count,
			resolution.steps.size(),
			" · ⚔%d ✦%d ♥%d ◉%d%s" % [
				combat_result.physical_damage_applied,
				combat_result.magic_damage_applied,
				combat_result.healing_applied,
				combat_result.coins_granted,
				" · поле перемешано" if was_reshuffled else "",
			],
		]
		if combat_result.victory:
			turn_result_label.text += " · ПОБЕДА"
		elif combat_result.defeat:
			turn_result_label.text += " · ПОРАЖЕНИЕ"
	else:
		turn_result_label.text = "Недопустимый ход"
		await get_tree().create_timer(SWAP_PREVIEW_SECONDS).timeout
	board_view.set_input_enabled(not _battle.is_over)


func _perform_enemy_action(battle: RefCounted) -> void:
	battle.hero.take_damage(rules.enemy_base_damage)


func _update_combat_status() -> void:
	combat_status_label.text = "Герой: %d/%d HP · Монеты: %d                         Враг: %d/%d HP" % [
		_battle.hero.health,
		_battle.hero.max_health,
		_battle.hero.coins,
		_battle.enemy.health,
		_battle.enemy.max_health,
	]

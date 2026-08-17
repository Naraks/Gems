extends Control

const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardShufflerScript = preload("res://core/board/board_shuffler.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const CombatTurnResolverScript = preload("res://core/combat/combat_turn_resolver.gd")
const EnemyStateScript = preload("res://core/combat/enemy_state.gd")
const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const SWAP_PREVIEW_SECONDS := 0.12

@export var rules: GameRules

@onready var board_view: Control = %BoardView
@onready var turn_result_label: Label = %TurnResultLabel
@onready var battle_number_label: Label = %BattleNumberLabel
@onready var pause_button: Button = %PauseButton
@onready var pause_overlay: ColorRect = %PauseOverlay
@onready var hero_health_label: Label = %HeroHealthLabel
@onready var coins_label: Label = %CoinsLabel
@onready var enemy_health_label: Label = %EnemyHealthLabel
@onready var enemy_intent_label: Label = %EnemyIntentLabel
@onready var weakness_label: Label = %WeaknessLabel

var _board: RefCounted
var _board_resolver: RefCounted
var _board_shuffler: RefCounted
var _turn_controller: RefCounted
var _battle: RefCounted
var _combat_resolver := CombatTurnResolverScript.new()
var _intent_executor := EnemyIntentExecutorScript.new()


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	_board = BoardGeneratorScript.new(rules).generate_starting_board()
	assert(_board != null, "Starting board generation failed")
	_board_resolver = BoardResolverScript.new(rules)
	_board_shuffler = BoardShufflerScript.new()
	_turn_controller = BoardTurnControllerScript.new(_board, rules.minimum_match_size)
	var enemy = EnemyStateScript.new(rules.enemy_base_health)
	enemy.configure_affinities(AttackTypeScript.Kind.PHYSICAL, AttackTypeScript.Kind.NONE, rules.weakness_multiplier, rules.boss_resistance_multiplier)
	enemy.current_intent = EnemyIntentScript.new(EnemyIntentScript.Kind.ATTACK, rules.enemy_base_damage)
	_battle = BattleStateScript.new(
		HeroStateScript.new(
			rules.hero_max_health,
			-1,
			rules.hero_sword_power,
			rules.hero_magic_power,
			rules.hero_healing_power,
			rules.hero_coin_multiplier,
		),
		enemy,
	)
	board_view.setup(_board)
	board_view.swap_requested.connect(_on_swap_requested)
	pause_button.pressed.connect(_toggle_pause)
	resized.connect(_apply_responsive_style)
	_apply_responsive_style()
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
	_intent_executor.execute(battle.enemy.current_intent, battle)


func _update_combat_status() -> void:
	battle_number_label.text = "Бой 1"
	hero_health_label.text = "HP %d / %d" % [_battle.hero.health, _battle.hero.max_health]
	coins_label.text = "Монеты: %d" % _battle.hero.coins
	enemy_health_label.text = "HP %d / %d" % [_battle.enemy.health, _battle.enemy.max_health]
	enemy_intent_label.text = "Намерение: %s" % _battle.enemy.current_intent.display_text()
	weakness_label.text = "Слабость: %s" % _battle.enemy.weakness_display()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_overlay.visible = paused
	pause_button.text = "Продолжить" if paused else "Пауза"


func _apply_responsive_style() -> void:
	var compact := size.y < 420.0
	var body_font_size := 14 if compact else 18
	var title_font_size := 15 if compact else 20
	for label in [hero_health_label, coins_label, enemy_health_label, enemy_intent_label, weakness_label, turn_result_label]:
		if label != null:
			label.add_theme_font_size_override("font_size", body_font_size)
	if battle_number_label != null:
		battle_number_label.add_theme_font_size_override("font_size", title_font_size)

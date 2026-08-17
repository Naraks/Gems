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
const FEEDBACK_SECONDS := 0.28
const SKIP_SPEED := 8.0

@export var rules: GameRules
@export var tutorial_completed := true

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
@onready var board_flash: ColorRect = %BoardFlash
@onready var weakness_flash: ColorRect = %WeaknessFlash
@onready var enemy_feedback_label: Label = %EnemyFeedbackLabel
@onready var hero_feedback_label: Label = %HeroFeedbackLabel
@onready var coin_feedback_label: Label = %CoinFeedbackLabel
@onready var weakness_feedback_label: Label = %WeaknessFeedbackLabel
@onready var weakness_sound: AudioStreamPlayer = %WeaknessSound

var _board: RefCounted
var _board_resolver: RefCounted
var _board_shuffler: RefCounted
var _turn_controller: RefCounted
var _battle: RefCounted
var _combat_resolver := CombatTurnResolverScript.new()
var _intent_executor := EnemyIntentExecutorScript.new()
var _feedback_active := false
var _feedback_tweens: Array[Tween] = []
var _feedback_speed := 1.0
var feedback_events: PackedStringArray = []


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
	weakness_sound.stream = _create_weakness_sound()
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
		await _play_combat_feedback(combat_result, resolution.steps.size())
		_update_combat_status()
		if combat_result.victory:
			turn_result_label.text += " · ПОБЕДА"
		elif combat_result.defeat:
			turn_result_label.text += " · ПОРАЖЕНИЕ"
	else:
		turn_result_label.text = "Недопустимый ход"
		await get_tree().create_timer(SWAP_PREVIEW_SECONDS).timeout
	board_view.set_input_enabled(not _battle.is_over)


func _unhandled_input(event: InputEvent) -> void:
	if not _feedback_active or not tutorial_completed:
		return
	var pressed: bool = (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accelerate_feedback()
		get_viewport().set_input_as_handled()


func accelerate_feedback() -> void:
	if not tutorial_completed:
		return
	feedback_events.append("accelerated")
	_feedback_speed = SKIP_SPEED
	for tween in _feedback_tweens:
		if tween != null and tween.is_valid():
			tween.set_speed_scale(SKIP_SPEED)


func _play_combat_feedback(result: RefCounted, cascade_count: int) -> void:
	_feedback_active = true
	_feedback_tweens.clear()
	_feedback_speed = 1.0
	feedback_events.clear()
	if cascade_count > 0:
		feedback_events.append("board")
		await _flash_board(cascade_count)
	var total_damage: int = result.physical_damage_applied + result.magic_damage_applied
	if total_damage > 0:
		feedback_events.append("enemy_damage")
		await _float_feedback(enemy_feedback_label, "−%d HP" % total_damage, Color("#ff6b5f"))
	if result.healing_applied > 0:
		feedback_events.append("hero_heal")
		await _float_feedback(hero_feedback_label, "+%d HP" % result.healing_applied, Color("#66e68c"))
	if result.coins_granted > 0:
		feedback_events.append("coins")
		await _float_feedback(coin_feedback_label, "+%d монет" % result.coins_granted, Color("#ffd45c"))
	if result.weakness_revealed:
		feedback_events.append("weakness")
		await _show_weakness_feedback(result.weakness_hit)
	if result.enemy_responded:
		feedback_events.append("intent")
		await _pulse_intent()
		if _battle.enemy.current_intent.kind == EnemyIntentScript.Kind.ATTACK:
			feedback_events.append("enemy_attack")
			await _float_feedback(hero_feedback_label, "−%d HP" % _battle.enemy.current_intent.value, Color("#ff6b5f"))
	_feedback_active = false
	_feedback_tweens.clear()


func _flash_board(cascade_count: int) -> void:
	board_flash.visible = true
	board_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	var tween := _new_feedback_tween()
	var flashes := mini(cascade_count, 3)
	for _index in flashes:
		tween.tween_property(board_flash, "color:a", 0.16, FEEDBACK_SECONDS * 0.35)
		tween.tween_property(board_flash, "color:a", 0.0, FEEDBACK_SECONDS * 0.35)
	await tween.finished
	board_flash.visible = false


func _float_feedback(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.modulate = Color(color, 1.0)
	label.position.y += 8.0
	label.visible = true
	var start_y := label.position.y
	var tween := _new_feedback_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start_y - 18.0, FEEDBACK_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FEEDBACK_SECONDS).set_delay(FEEDBACK_SECONDS * 0.35)
	await tween.finished
	label.position.y = start_y - 8.0
	label.visible = false


func _show_weakness_feedback(hit_weakness: bool) -> void:
	weakness_feedback_label.text = "СЛАБОСТЬ ×1.50" if hit_weakness else "СЛАБОСТЬ РАСКРЫТА"
	weakness_feedback_label.modulate = Color.WHITE
	weakness_feedback_label.visible = true
	weakness_flash.visible = true
	weakness_flash.color.a = 0.0
	weakness_sound.play()
	var tween := _new_feedback_tween()
	tween.tween_property(weakness_flash, "color:a", 0.32, FEEDBACK_SECONDS * 0.45)
	tween.tween_property(weakness_flash, "color:a", 0.0, FEEDBACK_SECONDS * 0.55)
	tween.parallel().tween_property(weakness_feedback_label, "modulate:a", 0.0, FEEDBACK_SECONDS * 0.55)
	await tween.finished
	weakness_flash.visible = false
	weakness_feedback_label.visible = false


func _pulse_intent() -> void:
	enemy_intent_label.pivot_offset = enemy_intent_label.size * 0.5
	var tween := _new_feedback_tween()
	tween.tween_property(enemy_intent_label, "scale", Vector2(1.12, 1.12), FEEDBACK_SECONDS * 0.5)
	tween.tween_property(enemy_intent_label, "scale", Vector2.ONE, FEEDBACK_SECONDS * 0.5)
	await tween.finished


func _new_feedback_tween() -> Tween:
	var tween := create_tween()
	tween.set_speed_scale(_feedback_speed)
	_feedback_tweens.append(tween)
	return tween


func _create_weakness_sound() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * 0.12)
	var samples := PackedByteArray()
	samples.resize(sample_count)
	for index in sample_count:
		var fade := 1.0 - float(index) / sample_count
		var wave := sin(TAU * 880.0 * float(index) / sample_rate)
		samples[index] = clampi(roundi(128.0 + wave * 72.0 * fade), 0, 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = samples
	return stream


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

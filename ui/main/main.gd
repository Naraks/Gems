extends Control

signal battle_completed
signal battle_defeated

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
const UpgradeCatalogScript = preload("res://core/progression/upgrade_catalog.gd")
const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyCatalogScript = preload("res://core/enemies/enemy_catalog.gd")
const EndlessCycleScript = preload("res://core/run/endless_cycle.gd")
const LocalizationServiceScript = preload("res://core/localization/localization_service.gd")
const SWAP_PREVIEW_SECONDS := 0.12
const FEEDBACK_SECONDS := 0.28
const SKIP_SPEED := 8.0
const AUTO_CONTINUE_SECONDS := 0.65

@export var rules: GameRules
@export var tutorial_completed := true
@export_range(1, 1000000, 1) var battle_number := 1
var run_hero: RefCounted

@onready var board_view: Control = %BoardView
@onready var biome_background: Control = %BiomeBackground
@onready var fighters: HBoxContainer = %Fighters
@onready var turn_result_label: Label = %TurnResultLabel
@onready var battle_number_label: Label = %BattleNumberLabel
@onready var pause_button: Button = %PauseButton
@onready var cycle_modifier_label: Label = %CycleModifierLabel
@onready var pause_overlay: ColorRect = %PauseOverlay
@onready var hero_health_label: Label = %HeroHealthLabel
@onready var hero_portrait: Control = %HeroPortrait
@onready var coins_label: Label = %CoinsLabel
@onready var experience_label: Label = %ExperienceLabel
@onready var enemy_health_label: Label = %EnemyHealthLabel
@onready var enemy_portrait: Control = %EnemyPortrait
@onready var enemy_title_label: Label = %EnemyTitleLabel
@onready var enemy_intent_label: Label = %EnemyIntentLabel
@onready var weakness_label: Label = %WeaknessLabel
@onready var resistance_label: Label = %ResistanceLabel
@onready var board_flash: ColorRect = %BoardFlash
@onready var weakness_flash: ColorRect = %WeaknessFlash
@onready var enemy_feedback_label: Label = %EnemyFeedbackLabel
@onready var hero_feedback_label: Label = %HeroFeedbackLabel
@onready var coin_feedback_label: Label = %CoinFeedbackLabel
@onready var weakness_feedback_label: Label = %WeaknessFeedbackLabel
@onready var weakness_sound: AudioStreamPlayer = %WeaknessSound
@onready var special_feedback_label: Label = %SpecialFeedbackLabel
@onready var level_up_overlay: ColorRect = %LevelUpOverlay
@onready var battle_transition_overlay: ColorRect = %BattleTransitionOverlay
@onready var battle_reward_label: Label = %BattleRewardLabel
@onready var upgrade_buttons: Array[Button] = [%UpgradeButton1, %UpgradeButton2, %UpgradeButton3]

var _board: RefCounted
var _board_resolver: RefCounted
var _board_shuffler: RefCounted
var _turn_controller: RefCounted
var _battle: RefCounted
var _combat_resolver := CombatTurnResolverScript.new()
var _intent_executor := EnemyIntentExecutorScript.new()
var _upgrade_catalog := UpgradeCatalogScript.new()
var _upgrade_choices: Array[RefCounted] = []
var _victory_experience_granted := false
var _enemy_controller: RefCounted
var _feedback_active := false
var _feedback_tweens: Array[Tween] = []
var _feedback_speed := 1.0
var _auto_transition_started := false
var _defeat_reported := false
var feedback_events: PackedStringArray = []


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	biome_background.setup_for_battle(battle_number)
	_apply_biome_palette()
	_board = BoardGeneratorScript.new(rules).generate_starting_board()
	assert(_board != null, "Starting board generation failed")
	_board_resolver = BoardResolverScript.new(rules)
	_board_shuffler = BoardShufflerScript.new()
	_turn_controller = BoardTurnControllerScript.new(_board, rules.minimum_match_size)
	var hero = run_hero
	if hero == null:
		hero = HeroStateScript.new(
			rules.hero_max_health,
			-1,
			rules.hero_sword_power,
			rules.hero_magic_power,
			rules.hero_healing_power,
			rules.hero_coin_multiplier,
		)
	hero.reset_battle_relics()
	var enemy_definition: Resource = (
		EnemyCatalogScript.new().boss_for_battle(battle_number)
		if battle_number % rules.boss_interval == 0
		else EnemyCatalogScript.new().for_battle(battle_number)
	)
	var enemy = EnemyFactoryScript.new().create(enemy_definition, battle_number, hero.weakness_multiplier)
	hero_portrait.setup(CombatantPortrait.Role.HERO, Color("4e78d0"), "⚔")
	enemy_portrait.setup(
		CombatantPortrait.Role.ENEMY,
		enemy_definition.visual_color,
		enemy_definition.visual_symbol,
		enemy_definition.id,
		enemy_definition.is_boss,
	)
	_enemy_controller = EnemyControllerScript.new(
		enemy,
		_board,
		rules.maximum_empty_stones + EndlessCycleScript.blocker_limit_bonus(battle_number),
	)
	_battle = BattleStateScript.new(
		hero,
		enemy,
	)
	board_view.setup(_board)
	board_view.swap_requested.connect(_on_swap_requested)
	pause_button.pressed.connect(_toggle_pause)
	for index in upgrade_buttons.size():
		upgrade_buttons[index].pressed.connect(_choose_upgrade.bind(index))
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
		_board_resolver.cascade_bonus = _battle.hero.cascade_bonus
		_board_resolver.cascade_start_bonus = 0.10 if _battle.hero.has_relic(RelicDefinitionScript.Id.CASCADE_CLOVER) else 0.0
		var resolution = _board_resolver.resolve(_board)
		var combat_result = _combat_resolver.resolve(resolution, _battle, _perform_enemy_action)
		var was_reshuffled: bool = _board_shuffler.reshuffle_if_stuck(_board, rules.minimum_match_size)
		board_view.refresh()
		turn_result_label.text = tr("Ход %d · каскадов: %d%s") % [
			_turn_controller.move_count,
			resolution.steps.size(),
			tr(" · ⚔%d ✦%d ♥%d ◉%d%s") % [
				combat_result.physical_damage_applied,
				combat_result.magic_damage_applied,
				combat_result.healing_applied,
				combat_result.coins_granted,
				tr(" · поле перемешано") if was_reshuffled else "",
			],
		]
		await _play_combat_feedback(combat_result, resolution.steps.size())
		_update_combat_status()
		if combat_result.victory:
			turn_result_label.text += tr(" · ПОБЕДА")
			_grant_victory_experience()
		elif combat_result.defeat:
			turn_result_label.text += tr(" · ПОРАЖЕНИЕ")
			_notify_defeat()
	else:
		turn_result_label.text = tr("Недопустимый ход")
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
		if result.physical_damage_applied > 0:
			await hero_portrait.play_state(CombatantPortrait.State.SWORD)
		if result.magic_damage_applied > 0:
			await hero_portrait.play_state(CombatantPortrait.State.MAGIC)
		await enemy_portrait.play_state(CombatantPortrait.State.HURT)
		feedback_events.append("enemy_damage")
		await _float_feedback(enemy_feedback_label, "−%d HP" % total_damage, Color("#ff6b5f"))
	if result.healing_applied > 0:
		await hero_portrait.play_state(CombatantPortrait.State.HEAL)
		feedback_events.append("hero_heal")
		await _float_feedback(hero_feedback_label, "+%d HP" % result.healing_applied, Color("#66e68c"))
	if result.coins_granted > 0:
		feedback_events.append("coins")
		await _float_feedback(coin_feedback_label, tr("+%d монет") % result.coins_granted, Color("#ffd45c"))
	if result.weakness_revealed:
		feedback_events.append("weakness")
		await _show_weakness_feedback(result.weakness_hit)
	if result.enemy_responded:
		feedback_events.append("intent")
		await _pulse_intent()
		if result.enemy_intent_delayed:
			feedback_events.append("relic_delay")
			await _float_feedback(enemy_feedback_label, tr("ЗЕРКАЛЬНЫЙ ОСКОЛОК · ЗАДЕРЖАНО"), Color("#b9d7ff"))
		elif result.enemy_intent != null and result.enemy_intent.kind == EnemyIntentScript.Kind.ATTACK:
			await enemy_portrait.play_state(CombatantPortrait.State.ATTACK)
			await hero_portrait.play_state(CombatantPortrait.State.HURT)
			feedback_events.append("enemy_attack")
			await _float_feedback(hero_feedback_label, "−%d HP" % result.enemy_intent.value, Color("#ff6b5f"))
		elif result.enemy_intent != null and result.enemy_intent.kind in [EnemyIntentScript.Kind.SPECIAL, EnemyIntentScript.Kind.PREPARE]:
			var state := (
				CombatantPortrait.State.PREPARE
				if result.enemy_intent.kind == EnemyIntentScript.Kind.PREPARE or "Подготовка" in result.enemy_intent.title
				else CombatantPortrait.State.SPECIAL
			)
			await enemy_portrait.play_state(state, 0.28)
			feedback_events.append("boss_special")
			await _show_special_feedback(result.enemy_intent)
		elif result.enemy_intent != null and result.enemy_intent.kind == EnemyIntentScript.Kind.HEAL:
			await enemy_portrait.play_state(CombatantPortrait.State.HEAL)
	if result.victory:
		await enemy_portrait.play_state(CombatantPortrait.State.DEFEAT, 0.32)
	elif result.defeat:
		await hero_portrait.play_state(CombatantPortrait.State.DEFEAT, 0.32)
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
	weakness_feedback_label.text = tr("СЛАБОСТЬ ×1.50") if hit_weakness else tr("СЛАБОСТЬ РАСКРЫТА")
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


func _show_special_feedback(intent: RefCounted) -> void:
	if intent.show_value:
		var value_text := "−%d HP" % intent.value if "Огненный удар" in intent.title else "+%d" % intent.value
		special_feedback_label.text = "%s · %s" % [tr(intent.title).to_upper(), value_text]
	else:
		special_feedback_label.text = tr(intent.title).to_upper()
	special_feedback_label.modulate = Color("#d8d1c4")
	special_feedback_label.visible = true
	board_flash.visible = true
	board_flash.color = Color(0.55, 0.52, 0.46, 0.0)
	var tween := _new_feedback_tween()
	tween.tween_property(board_flash, "color:a", 0.38, FEEDBACK_SECONDS * 0.4)
	tween.tween_property(board_flash, "color:a", 0.0, FEEDBACK_SECONDS * 0.6)
	tween.parallel().tween_property(special_feedback_label, "modulate:a", 0.0, FEEDBACK_SECONDS * 0.6)
	await tween.finished
	board_flash.visible = false
	special_feedback_label.visible = false


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
	if not battle.enemy_intent_delayed:
		_enemy_controller.advance_intent()


func _update_combat_status() -> void:
	battle_number_label.text = tr("Бой %s · %s") % [LocalizationServiceScript.format_integer(battle_number), biome_background.biome_name()]
	cycle_modifier_label.text = EndlessCycleScript.modifier_text(battle_number)
	cycle_modifier_label.visible = not cycle_modifier_label.text.is_empty()
	hero_health_label.text = "HP %s / %s" % [LocalizationServiceScript.format_integer(_battle.hero.health), LocalizationServiceScript.format_integer(_battle.hero.max_health)]
	coins_label.text = tr("Монеты: %s") % LocalizationServiceScript.format_integer(_battle.hero.coins)
	experience_label.text = tr("Уровень %s · Опыт %s / %s") % [
		LocalizationServiceScript.format_integer(_battle.hero.level),
		LocalizationServiceScript.format_integer(_battle.hero.experience),
		LocalizationServiceScript.format_integer(_battle.hero.experience_for_next_level()),
	]
	enemy_health_label.text = "HP %s / %s" % [LocalizationServiceScript.format_integer(_battle.enemy.health), LocalizationServiceScript.format_integer(_battle.enemy.max_health)]
	enemy_title_label.text = "%s · %s" % [tr(_battle.enemy.definition.display_name), tr(_battle.enemy.definition.archetype)]
	enemy_intent_label.text = tr("Намерение: %s") % _battle.enemy.current_intent.display_text()
	weakness_label.text = tr("Слабость: %s") % _battle.enemy.weakness_display()
	resistance_label.text = tr("Сопротивление: %s") % AttackTypeScript.display_name(_battle.enemy.resistance_type)


func _apply_biome_palette() -> void:
	var panel_color: Color = biome_background.panel_color()
	var accent_color: Color = biome_background.accent_color()
	for panel in [%BoardArea, %TurnResultArea, %CombatArea]:
		var style := StyleBoxFlat.new()
		style.bg_color = panel_color
		style.border_color = Color(accent_color, 0.42)
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
	battle_number_label.add_theme_color_override("font_color", accent_color)
	turn_result_label.add_theme_color_override("font_color", Color(accent_color, 0.92))


func _grant_victory_experience() -> void:
	if _victory_experience_granted:
		return
	_victory_experience_granted = true
	_battle.hero.add_experience(_battle.enemy.experience_reward)
	_battle.hero.add_coins(_battle.enemy.base_coin_reward)
	_battle.hero.apply_victory_relics()
	battle_reward_label.text = tr("+%d опыта · +%d монет") % [
		_battle.enemy.experience_reward,
		_battle.enemy.base_coin_reward,
	]
	battle_transition_overlay.visible = true
	_battle.level_up_pending = _battle.hero.can_level_up()
	_update_combat_status()
	if _battle.level_up_pending:
		_show_level_up_choices()
	else:
		_continue_run_automatically()


func _show_level_up_choices() -> void:
	_upgrade_choices = _upgrade_catalog.draw_three()
	for index in upgrade_buttons.size():
		var upgrade = _upgrade_choices[index]
		upgrade_buttons[index].text = "%s\n[%s]\n%s" % [tr(upgrade.title), upgrade.rarity_name(), tr(upgrade.description)]
	level_up_overlay.visible = true


func _choose_upgrade(index: int) -> void:
	if not level_up_overlay.visible or index < 0 or index >= _upgrade_choices.size():
		return
	_upgrade_catalog.apply(_upgrade_choices[index], _battle.hero)
	_battle.hero.level_up()
	_battle.level_up_pending = _battle.hero.can_level_up()
	_update_combat_status()
	if _battle.level_up_pending:
		_show_level_up_choices()
	else:
		level_up_overlay.visible = false
		_continue_run_automatically()


func _continue_run_automatically() -> void:
	if _auto_transition_started:
		return
	_auto_transition_started = true
	await get_tree().create_timer(AUTO_CONTINUE_SECONDS).timeout
	if is_inside_tree():
		battle_completed.emit()


func _notify_defeat() -> void:
	if _defeat_reported:
		return
	_defeat_reported = true
	battle_defeated.emit.call_deferred()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_overlay.visible = paused
	pause_button.text = tr("Продолжить") if paused else tr("Пауза")


func refresh_localized_text() -> void:
	_update_combat_status()
	pause_button.text = tr("Продолжить") if get_tree().paused else tr("Пауза")
	if _turn_controller.move_count == 0:
		turn_result_label.text = tr("Сделайте комбинацию из трёх камней")


func _apply_responsive_style() -> void:
	var compact := size.y < 420.0
	var body_font_size := 14 if compact else 18
	var title_font_size := 15 if compact else 20
	fighters.add_theme_constant_override("separation", 8 if compact else 24)
	for portrait in [hero_portrait, enemy_portrait]:
		portrait.custom_minimum_size = Vector2(44, 66) if compact else Vector2(64, 96)
	for label in [hero_health_label, coins_label, experience_label, enemy_health_label, enemy_intent_label, weakness_label, resistance_label, turn_result_label]:
		if label != null:
			label.add_theme_font_size_override("font_size", body_font_size)
	if battle_number_label != null:
		battle_number_label.add_theme_font_size_override("font_size", title_font_size)

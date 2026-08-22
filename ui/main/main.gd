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
const FEEDBACK_SECONDS := 0.70
const FEEDBACK_HOLD_SECONDS := 0.32
const FEEDBACK_FADE_SECONDS := 0.38
const SKIP_SPEED := 8.0
const AUTO_CONTINUE_SECONDS := 0.65
const VICTORY_HOLD_SECONDS := 1.20

@export var rules: GameRules
@export var tutorial_completed := true:
	set(value):
		tutorial_completed = value
		if is_instance_valid(board_view):
			board_view.set_hint_enabled(value)
@export_range(1, 1000000, 1) var battle_number := 1
@export var show_battle_heading := true
@export var defer_enemy_arrival := false
var run_hero: RefCounted

@onready var board_view: Control = %BoardView
@onready var biome_background: Control = %BiomeBackground
@onready var layout: VBoxContainer = %Layout
@onready var top_bar: MarginContainer = $Layout/BoardArea/BoardLayout/TopBar
@onready var board_area: PanelContainer = %BoardArea
@onready var turn_result_area: PanelContainer = %TurnResultArea
@onready var combat_area: PanelContainer = %CombatArea
@onready var fighters: HBoxContainer = %Fighters
@onready var hero_panel: VBoxContainer = $Layout/CombatArea/CombatMargin/Fighters/HeroPanel
@onready var enemy_panel: VBoxContainer = $Layout/CombatArea/CombatMargin/Fighters/EnemyPanel
@onready var turn_result_label: Label = %TurnResultLabel
@onready var battle_number_label: Label = %BattleNumberLabel
@onready var cycle_modifier_label: Label = %CycleModifierLabel
@onready var music_toggle_button: Button = %MusicToggleButton
@onready var sfx_toggle_button: Button = %SfxToggleButton
@onready var pause_overlay: ColorRect = %PauseOverlay
@onready var hero_health_label: Label = %HeroHealthLabel
@onready var hero_portrait: Control = %HeroPortrait
@onready var coins_label: Label = %CoinsLabel
@onready var experience_label: Label = %ExperienceLabel
@onready var enemy_health_label: Label = %EnemyHealthLabel
@onready var enemy_portrait: Control = %EnemyPortrait
@onready var enemy_title_label: Label = %EnemyTitleLabel
@onready var enemy_intent_label: Label = %EnemyIntentLabel
@onready var enemy_intent_icon: Control = %EnemyIntentIcon
@onready var weakness_label: Label = %WeaknessLabel
@onready var resistance_label: Label = %ResistanceLabel
@onready var feedback_layer: Control = %FeedbackLayer
@onready var board_flash: ColorRect = %BoardFlash
@onready var enemy_feedback_label: Label = %EnemyFeedbackLabel
@onready var hero_feedback_label: Label = %HeroFeedbackLabel
@onready var coin_feedback_label: Label = %CoinFeedbackLabel
@onready var weakness_feedback_label: Label = %WeaknessFeedbackLabel
@onready var weakness_sound: AudioStreamPlayer = %WeaknessSound
@onready var special_feedback_label: Label = %SpecialFeedbackLabel
@onready var level_up_overlay: ColorRect = %LevelUpOverlay
@onready var battle_transition_overlay: ColorRect = %BattleTransitionOverlay
@onready var battle_reward_label: Label = %BattleRewardLabel
@onready var pixel_wipe: Control = %PixelWipe
@onready var transition_title: Label = %TransitionTitle
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
var _hero_side: VBoxContainer
var _enemy_side: VBoxContainer
var _hero_portrait_stage: CenterContainer
var _enemy_portrait_stage: CenterContainer
var _transition_active := false
var _transition_speed := 1.0
var _transition_tweens: Array[Tween] = []


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
	_layout_battlefield()
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
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.play_music_for_battle(battle_number, enemy_definition.is_boss)
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
	board_view.set_hint_enabled(tutorial_completed)
	board_view.swap_requested.connect(_on_swap_requested)
	music_toggle_button.pressed.connect(_toggle_music)
	sfx_toggle_button.pressed.connect(_toggle_sfx)
	_update_audio_buttons()
	for index in upgrade_buttons.size():
		upgrade_buttons[index].pressed.connect(_choose_upgrade.bind(index))
	resized.connect(_apply_responsive_style)
	weakness_sound.stream = _create_weakness_sound()
	_apply_responsive_style()
	_update_combat_status()
	if defer_enemy_arrival:
		enemy_portrait.modulate.a = 0.0
	else:
		play_enemy_arrival.call_deferred()


func _layout_battlefield() -> void:
	var board_layout := board_area.get_node("BoardLayout") as VBoxContainer
	var divider := fighters.get_node("Divider") as VSeparator
	top_bar.reparent(layout)
	layout.move_child(top_bar, 0)

	turn_result_area.reparent(board_layout)
	board_layout.move_child(turn_result_area, board_layout.get_child_count() - 1)
	turn_result_area.visible = false
	turn_result_area.size_flags_vertical = Control.SIZE_SHRINK_END
	turn_result_area.size_flags_stretch_ratio = 0.0
	turn_result_area.custom_minimum_size.y = 0.0

	_hero_side = VBoxContainer.new()
	_hero_side.name = "HeroSide"
	_hero_side.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hero_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_side.size_flags_stretch_ratio = 1.0
	_hero_side.add_theme_constant_override("separation", 8)
	fighters.add_child(_hero_side)
	_hero_portrait_stage = CenterContainer.new()
	_hero_portrait_stage.name = "HeroPortraitStage"
	_hero_portrait_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_side.add_child(_hero_portrait_stage)
	hero_portrait.reparent(_hero_portrait_stage)
	hero_panel.reparent(_hero_side)

	_enemy_side = VBoxContainer.new()
	_enemy_side.name = "EnemySide"
	_enemy_side.alignment = BoxContainer.ALIGNMENT_BEGIN
	_enemy_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_side.size_flags_stretch_ratio = 1.0
	_enemy_side.add_theme_constant_override("separation", 8)
	fighters.add_child(_enemy_side)
	_enemy_portrait_stage = CenterContainer.new()
	_enemy_portrait_stage.name = "EnemyPortraitStage"
	_enemy_portrait_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_side.add_child(_enemy_portrait_stage)
	enemy_portrait.reparent(_enemy_portrait_stage)
	enemy_panel.reparent(_enemy_side)

	board_area.reparent(fighters)
	board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.size_flags_stretch_ratio = 2.65
	fighters.move_child(_hero_side, 0)
	fighters.move_child(board_area, 1)
	fighters.move_child(_enemy_side, 2)
	divider.visible = false

	combat_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_area.size_flags_stretch_ratio = 1.0


func play_enemy_arrival() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var destination_x := enemy_portrait.position.x
	enemy_portrait.position.x += 72.0
	enemy_portrait.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_speed_scale(_transition_speed)
	_transition_tweens.append(tween)
	tween.tween_property(enemy_portrait, "position:x", destination_x, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_portrait, "modulate:a", 1.0, 0.24)
	await tween.finished


func _on_swap_requested(first: Vector2i, second: Vector2i) -> void:
	board_view.set_input_enabled(false)
	var before_swap: PackedInt32Array = _board.cells()
	if not _turn_controller.begin_swap(first, second):
		board_view.set_input_enabled(true)
		return
	await board_view.play_swap(first, second, before_swap)
	var swapped_cells: PackedInt32Array = _board.cells()
	var is_valid: bool = _turn_controller.finish_swap()
	board_view.refresh()
	if is_valid:
		_board_resolver.cascade_bonus = _battle.hero.cascade_bonus
		_board_resolver.cascade_start_bonus = 0.10 if _battle.hero.has_relic(RelicDefinitionScript.Id.CASCADE_CLOVER) else 0.0
		var resolution = _board_resolver.resolve(_board)
		await board_view.play_resolution(resolution)
		var combat_result = _combat_resolver.resolve(resolution, _battle, _perform_enemy_action)
		_update_vitals_status()
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
		await board_view.play_invalid_swap_return(first, second, swapped_cells)
	board_view.set_input_enabled(not _battle.is_over)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	) or (event is InputEventScreenTouch and event.pressed)
	if pressed and board_view.animation_active and tutorial_completed:
		board_view.accelerate_animation()
		get_viewport().set_input_as_handled()
		return
	if pressed and _transition_active and tutorial_completed:
		accelerate_transition()
		get_viewport().set_input_as_handled()
		return
	if pressed and _feedback_active and tutorial_completed:
		accelerate_feedback()
		get_viewport().set_input_as_handled()


func accelerate_feedback() -> void:
	if not tutorial_completed:
		return
	feedback_events.append("accelerated")
	_feedback_speed = SKIP_SPEED
	hero_portrait.set_animation_speed(SKIP_SPEED)
	enemy_portrait.set_animation_speed(SKIP_SPEED)
	for tween in _feedback_tweens:
		if tween != null and tween.is_valid():
			tween.set_speed_scale(SKIP_SPEED)


func accelerate_transition() -> void:
	_transition_speed = SKIP_SPEED
	for tween in _transition_tweens:
		if tween != null and tween.is_valid():
			tween.set_speed_scale(SKIP_SPEED)
	biome_background.set_travel_speed(SKIP_SPEED)


func _play_combat_feedback(result: RefCounted, _cascade_count: int) -> void:
	_feedback_active = true
	_feedback_tweens.clear()
	_feedback_speed = 1.0
	hero_portrait.set_animation_speed(1.0)
	enemy_portrait.set_animation_speed(1.0)
	feedback_events.clear()
	var total_damage: int = result.physical_damage_applied + result.magic_damage_applied
	if total_damage > 0:
		_play_sfx(&"damage")
		var attack_state := CombatantPortrait.State.MAGIC if result.magic_damage_applied > result.physical_damage_applied else CombatantPortrait.State.SWORD
		hero_portrait.play_state(attack_state)
		enemy_portrait.play_state(CombatantPortrait.State.HURT)
		feedback_events.append("enemy_damage")
		if result.weakness_revealed:
			feedback_events.append("weakness")
			_show_weakness_feedback(result.weakness_hit)
		await _float_feedback(enemy_feedback_label, "−%d HP" % total_damage, Color("#ff6b5f"))
	elif result.weakness_revealed:
		feedback_events.append("weakness")
		await _show_weakness_feedback(result.weakness_hit)
	var has_healing: bool = result.healing_applied > 0
	var has_coins: bool = result.coins_granted > 0
	if has_healing:
		hero_portrait.play_state(CombatantPortrait.State.HEAL)
		feedback_events.append("hero_heal")
	if has_coins:
		feedback_events.append("coins")
	if has_healing and has_coins:
		_float_feedback(hero_feedback_label, "+%d HP" % result.healing_applied, Color("#66e68c"))
		await _float_feedback(coin_feedback_label, tr("+%d монет") % result.coins_granted, Color("#ffd45c"))
	elif has_healing:
		await _float_feedback(hero_feedback_label, "+%d HP" % result.healing_applied, Color("#66e68c"))
	elif has_coins:
		await _float_feedback(coin_feedback_label, tr("+%d монет") % result.coins_granted, Color("#ffd45c"))
	if result.enemy_responded:
		feedback_events.append("intent")
		_pulse_intent()
		if result.enemy_intent_delayed:
			feedback_events.append("relic_delay")
			await _float_feedback(enemy_feedback_label, tr("ЗЕРКАЛЬНЫЙ ОСКОЛОК · ЗАДЕРЖАНО"), Color("#b9d7ff"))
		elif result.enemy_intent != null and result.enemy_intent.kind == EnemyIntentScript.Kind.ATTACK:
			_play_sfx(&"damage")
			enemy_portrait.play_state(CombatantPortrait.State.ATTACK)
			hero_portrait.play_state(CombatantPortrait.State.HURT)
			feedback_events.append("enemy_attack")
			await _float_feedback(hero_feedback_label, "−%d HP" % result.enemy_intent.value, Color("#ff6b5f"))
		elif result.enemy_intent != null and result.enemy_intent.kind in [EnemyIntentScript.Kind.SPECIAL, EnemyIntentScript.Kind.PREPARE]:
			var state := (
				CombatantPortrait.State.PREPARE
				if result.enemy_intent.kind == EnemyIntentScript.Kind.PREPARE or "Подготовка" in result.enemy_intent.title
				else CombatantPortrait.State.SPECIAL
			)
			enemy_portrait.play_state(state, 0.28)
			feedback_events.append("boss_special")
			await _show_special_feedback(result.enemy_intent)
		elif result.enemy_intent != null and result.enemy_intent.kind == EnemyIntentScript.Kind.HEAL:
			await enemy_portrait.play_state(CombatantPortrait.State.HEAL)
	if result.victory:
		_play_sfx(&"victory")
		await enemy_portrait.play_state(CombatantPortrait.State.DEFEAT, 0.32)
	elif result.defeat:
		_play_sfx(&"defeat")
		await hero_portrait.play_state(CombatantPortrait.State.DEFEAT, 0.32)
	_feedback_active = false
	_feedback_tweens.clear()
	hero_portrait.set_animation_speed(1.0)
	enemy_portrait.set_animation_speed(1.0)


func _float_feedback(label: Label, text: String, color: Color) -> void:
	label.text = text
	if label == enemy_feedback_label:
		_align_label_to_portrait(label, enemy_portrait, -enemy_portrait.size.y * 0.30)
	elif label == hero_feedback_label:
		_align_label_to_portrait(label, hero_portrait, -hero_portrait.size.y * 0.30)
	elif label == coin_feedback_label:
		_align_label_to_portrait(label, hero_portrait, hero_portrait.size.y * 0.18)
	label.modulate = Color(color, 1.0)
	label.position.y += 8.0
	label.visible = true
	var start_y := label.position.y
	var tween := _new_feedback_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start_y - 18.0, FEEDBACK_FADE_SECONDS).set_delay(FEEDBACK_HOLD_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FEEDBACK_FADE_SECONDS).set_delay(FEEDBACK_HOLD_SECONDS)
	await tween.finished
	label.position.y = start_y - 8.0
	label.visible = false


func _show_weakness_feedback(hit_weakness: bool) -> void:
	weakness_feedback_label.text = tr("СЛАБОСТЬ ×1.50") if hit_weakness else tr("СЛАБОСТЬ РАСКРЫТА")
	_align_label_to_enemy(weakness_feedback_label, -enemy_portrait.size.y * 0.68)
	weakness_feedback_label.modulate = Color.WHITE
	weakness_feedback_label.pivot_offset = weakness_feedback_label.size * 0.5
	weakness_feedback_label.scale = Vector2(0.9, 0.9)
	weakness_feedback_label.visible = true
	_play_sfx(&"weakness")
	var tween := _new_feedback_tween()
	tween.tween_property(weakness_feedback_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.42)
	tween.chain().tween_property(weakness_feedback_label, "modulate:a", 0.0, 0.22)
	await tween.finished
	weakness_feedback_label.visible = false
	weakness_feedback_label.scale = Vector2.ONE


func _align_label_to_enemy(label: Label, vertical_offset: float) -> void:
	_align_label_to_portrait(label, enemy_portrait, vertical_offset)


func _align_label_to_portrait(label: Label, portrait: Control, vertical_offset: float) -> void:
	var portrait_center: Vector2 = feedback_layer.get_global_transform().affine_inverse() * portrait.get_global_rect().get_center()
	label.position = portrait_center - label.size * 0.5 + Vector2(0.0, vertical_offset)


func _pulse_intent() -> void:
	enemy_intent_icon.pivot_offset = enemy_intent_icon.size * 0.5
	var tween := _new_feedback_tween()
	tween.tween_property(enemy_intent_icon, "scale", Vector2(1.16, 1.16), FEEDBACK_SECONDS * 0.5)
	tween.tween_property(enemy_intent_icon, "scale", Vector2.ONE, FEEDBACK_SECONDS * 0.5)
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
	tween.tween_property(board_flash, "color:a", 0.28, 0.12)
	tween.tween_interval(0.72)
	tween.tween_property(board_flash, "color:a", 0.0, 0.25)
	tween.parallel().tween_property(special_feedback_label, "modulate:a", 0.0, 0.25)
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


func _play_sfx(sound_name: StringName) -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.play_sfx(sound_name)
	elif sound_name == &"weakness":
		weakness_sound.play()


func _perform_enemy_action(battle: RefCounted) -> void:
	_intent_executor.execute(battle.enemy.current_intent, battle)
	if not battle.enemy_intent_delayed:
		_enemy_controller.advance_intent()


func _update_combat_status() -> void:
	battle_number_label.text = tr("Бой %s · %s") % [LocalizationServiceScript.format_integer(battle_number), biome_background.biome_name()]
	battle_number_label.visible = show_battle_heading
	cycle_modifier_label.text = EndlessCycleScript.modifier_text(battle_number)
	cycle_modifier_label.visible = not cycle_modifier_label.text.is_empty()
	top_bar.visible = battle_number_label.visible or cycle_modifier_label.visible
	_update_vitals_status()
	enemy_title_label.text = "%s · %s" % [tr(_battle.enemy.definition.display_name), tr(_battle.enemy.definition.archetype)]
	enemy_intent_label.text = tr("Следующий ход: %s") % _battle.enemy.current_intent.display_text()
	enemy_intent_icon.setup(_battle.enemy.current_intent)
	weakness_label.text = tr("Слабость: %s") % _battle.enemy.weakness_display()
	resistance_label.text = tr("Сопротивление: %s") % AttackTypeScript.display_name(_battle.enemy.resistance_type)


func _update_vitals_status() -> void:
	hero_health_label.text = "HP %s / %s" % [LocalizationServiceScript.format_integer(_battle.hero.health), LocalizationServiceScript.format_integer(_battle.hero.max_health)]
	coins_label.text = tr("Монеты: %s") % LocalizationServiceScript.format_integer(_battle.hero.coins)
	experience_label.text = tr("Уровень %s · Опыт %s / %s") % [
		LocalizationServiceScript.format_integer(_battle.hero.level),
		LocalizationServiceScript.format_integer(_battle.hero.experience),
		LocalizationServiceScript.format_integer(_battle.hero.experience_for_next_level()),
	]
	enemy_health_label.text = "HP %s / %s" % [LocalizationServiceScript.format_integer(_battle.enemy.health), LocalizationServiceScript.format_integer(_battle.enemy.max_health)]


func _apply_biome_palette() -> void:
	var panel_color: Color = biome_background.panel_color()
	var accent_color: Color = biome_background.accent_color()
	for panel in [%BoardArea, %TurnResultArea, %CombatArea]:
		var style := StyleBoxFlat.new()
		style.bg_color = panel_color
		style.border_color = Color(accent_color, 0.68)
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	%BoardArea.add_theme_stylebox_override("panel", board_style)
	battle_number_label.add_theme_color_override("font_color", accent_color)
	turn_result_label.add_theme_color_override("font_color", Color(accent_color, 0.92))


func _grant_victory_experience() -> void:
	if _victory_experience_granted:
		return
	_victory_experience_granted = true
	_clear_transient_feedback()
	_battle.hero.add_experience(_battle.enemy.experience_reward)
	_battle.hero.add_coins(_battle.enemy.base_coin_reward)
	_battle.hero.apply_victory_relics()
	battle_reward_label.text = tr("+%d опыта · +%d монет") % [
		_battle.enemy.experience_reward,
		_battle.enemy.base_coin_reward,
	]
	transition_title.text = tr("ПОБЕДА · ПУТЬ ПРОДОЛЖАЕТСЯ").replace(" · ", "\n")
	enemy_portrait.visible = false
	enemy_intent_icon.visible = false
	enemy_health_label.visible = false
	weakness_label.visible = false
	resistance_label.visible = false
	battle_transition_overlay.visible = true
	_battle.level_up_pending = _battle.hero.can_level_up()
	_update_combat_status()
	if _battle.level_up_pending:
		_show_level_up_choices()
	else:
		_continue_run_automatically()


func _clear_transient_feedback() -> void:
	board_view.clear_transient_state()
	for label in [enemy_feedback_label, hero_feedback_label, coin_feedback_label, weakness_feedback_label, special_feedback_label]:
		label.visible = false
		label.modulate.a = 1.0
	board_flash.visible = false
	enemy_intent_icon.scale = Vector2.ONE


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
	_transition_active = true
	_transition_speed = 1.0
	_transition_tweens.clear()
	pixel_wipe.progress = 0.0
	transition_title.modulate.a = 1.0
	battle_reward_label.modulate.a = 1.0
	var hold := create_tween()
	_transition_tweens.append(hold)
	hold.tween_interval(VICTORY_HOLD_SECONDS)
	await hold.finished
	await _play_journey_transition()
	_transition_active = false
	_transition_tweens.clear()
	if is_inside_tree():
		battle_completed.emit()


func _play_journey_transition() -> void:
	board_view.set_input_enabled(false)
	var hero_start_x := hero_portrait.position.x
	var tween := create_tween().set_parallel(true)
	tween.set_speed_scale(_transition_speed)
	_transition_tweens.append(tween)
	tween.tween_property(board_area, "modulate:a", 0.22, AUTO_CONTINUE_SECONDS * 0.7)
	tween.tween_property(turn_result_area, "modulate:a", 0.18, AUTO_CONTINUE_SECONDS * 0.7)
	tween.tween_property(enemy_portrait, "position:x", enemy_portrait.position.x + 90.0, AUTO_CONTINUE_SECONDS * 0.45)
	tween.tween_property(enemy_portrait, "modulate:a", 0.0, AUTO_CONTINUE_SECONDS * 0.35)
	tween.tween_property(hero_portrait, "position:x", hero_start_x + 64.0, AUTO_CONTINUE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pixel_wipe, "progress", 1.0, AUTO_CONTINUE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(transition_title, "position:y", transition_title.position.y - 12.0, AUTO_CONTINUE_SECONDS * 0.72)
	tween.tween_property(transition_title, "modulate:a", 0.0, AUTO_CONTINUE_SECONDS * 0.78).set_delay(AUTO_CONTINUE_SECONDS * 0.20)
	tween.tween_property(battle_reward_label, "modulate:a", 0.0, AUTO_CONTINUE_SECONDS * 0.58).set_delay(AUTO_CONTINUE_SECONDS * 0.28)
	await biome_background.play_travel(AUTO_CONTINUE_SECONDS, _transition_speed)


func _notify_defeat() -> void:
	if _defeat_reported:
		return
	_defeat_reported = true
	battle_defeated.emit.call_deferred()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	board_view.reset_hint_timer()
	get_tree().paused = paused
	pause_overlay.visible = paused


func _toggle_music() -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service == null:
		return
	audio_service.set_music_enabled(not audio_service.music_enabled)
	_update_audio_buttons()


func _toggle_sfx() -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service == null:
		return
	audio_service.set_sfx_enabled(not audio_service.sfx_enabled)
	_update_audio_buttons()


func _update_audio_buttons() -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service == null:
		return
	music_toggle_button.set_active(audio_service.music_enabled)
	music_toggle_button.tooltip_text = tr("Выключить музыку") if audio_service.music_enabled else tr("Включить музыку")
	sfx_toggle_button.set_active(audio_service.sfx_enabled)
	sfx_toggle_button.tooltip_text = tr("Выключить звук") if audio_service.sfx_enabled else tr("Включить звук")


func refresh_localized_text() -> void:
	_update_combat_status()
	if _turn_controller.move_count == 0:
		turn_result_label.text = tr("Соберите 3 камня в ряд")


func _apply_responsive_style() -> void:
	var compact := size.y <= 540.0
	var body_font_size := 12 if compact else 14
	var title_font_size := 14 if compact else 16
	fighters.add_theme_constant_override("separation", 8 if compact else 24)
	if _hero_side != null and _enemy_side != null:
		var side_width := 128.0 if compact else 220.0
		_hero_side.custom_minimum_size.x = side_width
		_enemy_side.custom_minimum_size.x = side_width
		var details_height := 104.0 if compact else 172.0
		hero_panel.custom_minimum_size.y = details_height
		enemy_panel.custom_minimum_size.y = details_height
		hero_health_label.custom_minimum_size.y = 28.0
		enemy_health_label.custom_minimum_size.y = 28.0
	weakness_feedback_label.add_theme_font_size_override("font_size", 12 if compact else 16)
	weakness_feedback_label.offset_left = -140.0 if compact else -220.0
	weakness_feedback_label.offset_right = 140.0 if compact else 220.0
	enemy_intent_icon.scale = Vector2(0.82, 0.82) if compact else Vector2.ONE
	for portrait in [hero_portrait, enemy_portrait]:
		portrait.custom_minimum_size = Vector2(90, 120) if compact else Vector2(210, 280)
	for secondary_label in [coins_label, experience_label, weakness_label, resistance_label]:
		secondary_label.visible = not compact
	for label in [hero_health_label, coins_label, experience_label, enemy_health_label, enemy_intent_label, weakness_label, resistance_label, turn_result_label]:
		if label != null:
			label.add_theme_font_size_override("font_size", body_font_size)
	if battle_number_label != null:
		battle_number_label.add_theme_font_size_override("font_size", title_font_size)

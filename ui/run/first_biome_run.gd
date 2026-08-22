class_name FirstBiomeRun
extends Control

const HeroStateScript = preload("res://core/combat/hero_state.gd")
const RunStateScript = preload("res://core/run/first_biome_run_state.gd")
const BATTLE_SCENE := preload("res://ui/main/main.tscn")
const SHOP_SCENE := preload("res://ui/shop/shop_screen.tscn")
const LocalizationServiceScript = preload("res://core/localization/localization_service.gd")

@onready var node_title_label: Label = %NodeTitleLabel
@onready var language_selector: OptionButton = %LanguageSelector
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var content: Control = %RunContent
@onready var completion_panel: Control = %BiomeComplete
@onready var completion_summary: Label = %CompletionSummary
@onready var defeat_panel: Control = %RunSummaryPanel
@onready var defeat_summary: Label = %RunSummaryLabel
@onready var return_to_menu_button: Button = %ReturnToMenuButton
@onready var menu_panel: Control = %RunMenuPanel
@onready var new_run_button: Button = %NewRunButton
@onready var journey_stage: Control = %JourneyStage
@onready var journey_hero: ColorRect = %JourneyHero
@onready var distant_ruins: Label = %DistantRuins
@onready var road_marks: Label = %RoadMarks
@onready var encounter_avatar: ColorRect = %EncounterAvatar
@onready var encounter_label: Label = %EncounterLabel
@onready var journey_status: Label = %JourneyStatus

var run_state: RefCounted
var current_screen: Node
var is_travelling := false
var _journey_tween: Tween
var _collapse_tween: Tween
var _encounter_intro_active := false
var _journey_speed := 1.0
@export var localization_settings_path := LocalizationServiceScript.SETTINGS_PATH
@export var audio_settings_path := "user://settings.cfg"


func _ready() -> void:
	var locale := LocalizationServiceScript.initialize(localization_settings_path)
	language_selector.clear()
	language_selector.add_item("Русский")
	language_selector.add_item("English")
	language_selector.select(1 if locale == "en" else 0)
	language_selector.item_selected.connect(_on_language_selected)
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.load_settings(audio_settings_path)
		music_volume_slider.value = audio_service.music_volume * 100.0
		sfx_volume_slider.value = audio_service.sfx_volume * 100.0
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	return_to_menu_button.pressed.connect(_on_return_to_menu)
	new_run_button.pressed.connect(_start_new_run)
	if run_state == null:
		run_state = RunStateScript.new(HeroStateScript.new(100))
	_show_current_node()


func setup(state: RefCounted) -> void:
	run_state = state
	if is_node_ready():
		_show_current_node()


func _show_current_node() -> void:
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null
	completion_panel.visible = false
	defeat_panel.visible = false
	menu_panel.visible = false
	node_title_label.text = run_state.node_title()
	if run_state.status == RunStateScript.Status.DEFEAT_SUMMARY:
		encounter_avatar.visible = false
		journey_status.text = tr("Путешествие завершено")
		defeat_summary.text = run_state.summary_text()
		defeat_panel.visible = true
		return
	if run_state.status == RunStateScript.Status.MENU:
		encounter_avatar.visible = false
		journey_status.text = tr("Камни и Клинки")
		menu_panel.visible = true
		return
	match run_state.current_kind:
		RunStateScript.NodeKind.BATTLE, RunStateScript.NodeKind.BOSS:
			var battle = BATTLE_SCENE.instantiate()
			battle.battle_number = run_state.battle_number
			battle.show_battle_heading = false
			battle.defer_enemy_arrival = true
			battle.run_hero = run_state.hero
			battle.battle_completed.connect(_on_battle_completed)
			battle.battle_defeated.connect(_on_battle_defeated)
			content.add_child(battle)
			battle.board_view.set_input_enabled(false)
			current_screen = battle
			var definition: Resource = battle._battle.enemy.definition
			var kind_text := "БОСС" if run_state.current_kind == RunStateScript.NodeKind.BOSS else "ВРАГ"
			_show_encounter(kind_text, false, definition)
		RunStateScript.NodeKind.SHOP:
			var shop = SHOP_SCENE.instantiate()
			content.add_child(shop)
			shop.setup(run_state.hero, 19000 + run_state.battle_number)
			shop.closed.connect(_on_shop_closed)
			current_screen = shop
			_show_encounter("ТОРГОВЕЦ", true)
		RunStateScript.NodeKind.COMPLETE:
			encounter_avatar.visible = false
			journey_status.text = tr("Путь через руины завершён")
			completion_panel.visible = true
			completion_summary.text = tr("10 боёв завершено · Магазинов: %d\nУровень: %d · Монеты: %d") % [
				run_state.shops_visited,
				run_state.hero.level,
				run_state.hero.coins,
			]


func _on_battle_completed() -> void:
	run_state.complete_battle()
	_show_current_node()


func _on_shop_closed() -> void:
	run_state.leave_shop()
	_show_current_node()


func _on_battle_defeated() -> void:
	run_state.finish_defeat()
	_show_current_node()


func _on_return_to_menu() -> void:
	run_state.open_menu()
	_show_current_node()


func _start_new_run() -> void:
	run_state = RunStateScript.new(HeroStateScript.new(100))
	_show_current_node()


func _show_encounter(kind_text: String, is_merchant: bool, definition: Resource = null) -> void:
	_encounter_intro_active = true
	_journey_speed = 1.0
	journey_stage.visible = true
	journey_stage.anchor_bottom = 0.30
	content.anchor_top = 0.30
	content.modulate.a = 0.32
	encounter_avatar.visible = true
	encounter_avatar.color = Color("251f12") if is_merchant else Color(definition.visual_color.darkened(0.72), 0.96)
	encounter_avatar.border_color = Color("c5a24d") if is_merchant else definition.visual_color.lightened(0.28)
	var symbol: String = "☰" if is_merchant else definition.visual_symbol
	var localized_kind := tr(kind_text)
	var title: String = localized_kind if is_merchant else "%s · %s" % [localized_kind, tr(definition.display_name).to_upper()]
	encounter_label.text = "%s\n%s" % [symbol, title]
	var arrival_text := tr("Встреча с торговцем") if is_merchant else tr("Встреча с боссом") if kind_text == "БОСС" else tr("Встреча с врагом")
	_play_travel_animation(arrival_text)


func _play_travel_animation(arrival_text: String) -> void:
	if _journey_tween != null and _journey_tween.is_valid():
		_journey_tween.kill()
	is_travelling = true
	journey_status.text = "%s\n%s" % [tr("Герой идёт дальше..."), arrival_text.to_upper()]
	distant_ruins.position.x = 0.0
	road_marks.position.x = 0.0
	encounter_avatar.position.x = journey_stage.size.x + 20.0
	encounter_avatar.modulate.a = 0.0
	_journey_tween = create_tween().set_parallel(true)
	_journey_tween.set_speed_scale(_journey_speed)
	_journey_tween.tween_property(distant_ruins, "position:x", -90.0, 0.65).set_trans(Tween.TRANS_LINEAR)
	_journey_tween.tween_property(road_marks, "position:x", -150.0, 0.65).set_trans(Tween.TRANS_LINEAR)
	_journey_tween.tween_property(encounter_avatar, "position:x", journey_stage.size.x * 0.72 - encounter_avatar.size.x * 0.5, 0.50).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_journey_tween.tween_property(encounter_avatar, "modulate:a", 1.0, 0.34).set_delay(0.12)
	_journey_tween.chain().tween_callback(func() -> void:
		journey_status.text = arrival_text.to_upper()
	)
	_journey_tween.chain().tween_interval(1.10)
	_journey_tween.chain().tween_callback(func() -> void:
		is_travelling = false
		_collapse_encounter_stage()
	)


func _collapse_encounter_stage() -> void:
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.set_speed_scale(_journey_speed)
	_collapse_tween.tween_property(journey_stage, "anchor_bottom", 0.066, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(content, "anchor_top", 0.05, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(content, "modulate:a", 1.0, 0.35)
	_collapse_tween.chain().tween_callback(func() -> void:
		journey_stage.visible = false
		_finish_encounter_intro()
	)


func _finish_encounter_intro() -> void:
	var intro_screen := current_screen
	if intro_screen != null and intro_screen.has_method("play_enemy_arrival"):
		await intro_screen.play_enemy_arrival()
		if is_instance_valid(intro_screen) and current_screen == intro_screen and not intro_screen._battle.is_over:
			intro_screen.board_view.set_input_enabled(true)
	_encounter_intro_active = false


func _unhandled_input(event: InputEvent) -> void:
	if not _encounter_intro_active:
		return
	var pressed: bool = (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	_journey_speed = 6.0
	if _journey_tween != null and _journey_tween.is_valid():
		_journey_tween.set_speed_scale(_journey_speed)
	if _collapse_tween != null and _collapse_tween.is_valid():
		_collapse_tween.set_speed_scale(_journey_speed)
	if current_screen != null and current_screen.has_method("accelerate_transition"):
		current_screen.accelerate_transition()
	get_viewport().set_input_as_handled()


func _on_language_selected(index: int) -> void:
	var locale := "en" if index == 1 else "ru"
	LocalizationServiceScript.select_locale(locale, localization_settings_path)
	node_title_label.text = run_state.node_title()
	if current_screen != null and current_screen.has_method("refresh_localized_text"):
		current_screen.refresh_localized_text()


func _on_music_volume_changed(value: float) -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_music_volume(value / 100.0)


func _on_sfx_volume_changed(value: float) -> void:
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_sfx_volume(value / 100.0)

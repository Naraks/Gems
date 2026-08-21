class_name FirstBiomeRun
extends Control

const HeroStateScript = preload("res://core/combat/hero_state.gd")
const RunStateScript = preload("res://core/run/first_biome_run_state.gd")
const BATTLE_SCENE := preload("res://ui/main/main.tscn")
const SHOP_SCENE := preload("res://ui/shop/shop_screen.tscn")
const LocalizationServiceScript = preload("res://core/localization/localization_service.gd")

@onready var node_title_label: Label = %NodeTitleLabel
@onready var language_selector: OptionButton = %LanguageSelector
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
@export var localization_settings_path := LocalizationServiceScript.SETTINGS_PATH


func _ready() -> void:
	var locale := LocalizationServiceScript.initialize(localization_settings_path)
	language_selector.clear()
	language_selector.add_item("Русский")
	language_selector.add_item("English")
	language_selector.select(1 if locale == "en" else 0)
	language_selector.item_selected.connect(_on_language_selected)
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
			battle.run_hero = run_state.hero
			battle.battle_completed.connect(_on_battle_completed)
			battle.battle_defeated.connect(_on_battle_defeated)
			content.add_child(battle)
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
	encounter_avatar.visible = true
	encounter_avatar.color = Color("8b692f") if is_merchant else definition.visual_color
	var symbol: String = "☰" if is_merchant else definition.visual_symbol
	var localized_kind := tr(kind_text)
	var title: String = localized_kind if is_merchant else "%s · %s" % [localized_kind, tr(definition.display_name).to_upper()]
	encounter_label.text = "%s\n%s" % [symbol, title]
	_play_travel_animation(tr("Встреча: %s") % localized_kind.to_lower())


func _play_travel_animation(arrival_text: String) -> void:
	if _journey_tween != null and _journey_tween.is_valid():
		_journey_tween.kill()
	is_travelling = true
	journey_status.text = tr("Герой идёт дальше...")
	distant_ruins.position.x = 0.0
	road_marks.position.x = 0.0
	encounter_avatar.position.x = journey_stage.size.x + 20.0
	encounter_avatar.modulate.a = 0.0
	_journey_tween = create_tween().set_parallel(true)
	_journey_tween.tween_property(distant_ruins, "position:x", -70.0, 0.45).set_trans(Tween.TRANS_LINEAR)
	_journey_tween.tween_property(road_marks, "position:x", -120.0, 0.45).set_trans(Tween.TRANS_LINEAR)
	_journey_tween.tween_property(encounter_avatar, "position:x", journey_stage.size.x * 0.72 - encounter_avatar.size.x * 0.5, 0.35).set_delay(0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_journey_tween.tween_property(encounter_avatar, "modulate:a", 1.0, 0.25).set_delay(0.10)
	_journey_tween.chain().tween_callback(func() -> void:
		is_travelling = false
		journey_status.text = arrival_text
	)


func _on_language_selected(index: int) -> void:
	var locale := "en" if index == 1 else "ru"
	LocalizationServiceScript.select_locale(locale, localization_settings_path)
	node_title_label.text = run_state.node_title()
	if current_screen != null and current_screen.has_method("refresh_localized_text"):
		current_screen.refresh_localized_text()

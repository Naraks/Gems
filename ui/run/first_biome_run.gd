class_name FirstBiomeRun
extends Control

const HeroStateScript = preload("res://core/combat/hero_state.gd")
const RunStateScript = preload("res://core/run/first_biome_run_state.gd")
const BATTLE_SCENE := preload("res://ui/main/main.tscn")
const SHOP_SCENE := preload("res://ui/shop/shop_screen.tscn")

@onready var node_title_label: Label = %NodeTitleLabel
@onready var content: Control = %RunContent
@onready var completion_panel: Control = %BiomeComplete
@onready var completion_summary: Label = %CompletionSummary

var run_state: RefCounted
var current_screen: Node


func _ready() -> void:
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
	node_title_label.text = run_state.node_title()
	match run_state.current_kind:
		RunStateScript.NodeKind.BATTLE, RunStateScript.NodeKind.BOSS:
			var battle = BATTLE_SCENE.instantiate()
			battle.battle_number = run_state.battle_number
			battle.run_hero = run_state.hero
			battle.battle_completed.connect(_on_battle_completed)
			content.add_child(battle)
			current_screen = battle
		RunStateScript.NodeKind.SHOP:
			var shop = SHOP_SCENE.instantiate()
			content.add_child(shop)
			shop.setup(run_state.hero, 19000 + run_state.battle_number)
			shop.closed.connect(_on_shop_closed)
			current_screen = shop
		RunStateScript.NodeKind.COMPLETE:
			completion_panel.visible = true
			completion_summary.text = "10 боёв завершено · Магазинов: %d\nУровень: %d · Монеты: %d" % [
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

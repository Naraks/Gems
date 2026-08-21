class_name FirstBiomeRunState
extends RefCounted

enum NodeKind {
	BATTLE,
	SHOP,
	BOSS,
	COMPLETE,
}

enum Status {
	ACTIVE,
	DEFEAT_SUMMARY,
	MENU,
	COMPLETE,
}

const LinearRoutePlannerScript = preload("res://core/run/linear_route_planner.gd")
const EndlessCycleScript = preload("res://core/run/endless_cycle.gd")

var hero: RefCounted
var battle_number := 1
var current_kind := NodeKind.BATTLE
var completed_battles := 0
var shops_visited := 0
var shop_after_battles: Array[int]
var status := Status.ACTIVE
var duration_seconds := 0.0
var _started_at_msec: int
var _route_planner: RefCounted


func _init(hero_state: RefCounted, route_seed: int = 19020) -> void:
	assert(hero_state != null, "Run state requires hero")
	hero = hero_state
	_route_planner = LinearRoutePlannerScript.new(route_seed)
	_load_shops_for_block(0)
	_started_at_msec = Time.get_ticks_msec()


func complete_battle() -> void:
	assert(current_kind in [NodeKind.BATTLE, NodeKind.BOSS], "Current run node is not a battle")
	completed_battles += 1
	if battle_number in shop_after_battles:
		current_kind = NodeKind.SHOP
	else:
		_advance_to_next_battle()


func leave_shop() -> void:
	assert(current_kind == NodeKind.SHOP, "Current run node is not a shop")
	shops_visited += 1
	_advance_to_next_battle()


func finish_defeat(elapsed_seconds: float = -1.0) -> void:
	assert(status == Status.ACTIVE, "Only an active run can be defeated")
	duration_seconds = elapsed_seconds if elapsed_seconds >= 0.0 else float(Time.get_ticks_msec() - _started_at_msec) / 1000.0
	status = Status.DEFEAT_SUMMARY


func open_menu() -> void:
	assert(status in [Status.DEFEAT_SUMMARY, Status.COMPLETE], "Run menu opens after an ending")
	status = Status.MENU


func summary_text() -> String:
	var total_seconds := maxi(0, roundi(duration_seconds))
	return "Глубина: бой %d · Побед: %d\nДлительность: %02d:%02d · Магазинов: %d\nУровень: %d · Монеты: %d · Реликвии: %d" % [
		battle_number,
		completed_battles,
		total_seconds / 60,
		total_seconds % 60,
		shops_visited,
		hero.level,
		hero.coins,
		hero.relic_ids.size(),
	]


func node_title() -> String:
	var biome_name := EndlessCycleScript.biome_name(battle_number)
	var battle_in_biome := EndlessCycleScript.battle_in_biome(battle_number)
	var cycle_suffix := " · Цикл %d" % EndlessCycleScript.cycle_number(battle_number) if battle_number > 30 else ""
	match current_kind:
		NodeKind.SHOP:
			return "%s · Магазин после боя %d%s" % [biome_name, battle_number, cycle_suffix]
		NodeKind.BOSS:
			return "%s · Босс %d/10%s" % [biome_name, battle_in_biome, cycle_suffix]
		NodeKind.COMPLETE:
			return "Забег завершён"
		_:
			return "%s · Бой %d/10%s" % [biome_name, battle_in_biome, cycle_suffix]


func _advance_to_next_battle() -> void:
	battle_number += 1
	if (battle_number - 1) % 10 == 0:
		_load_shops_for_block((battle_number - 1) / 10)
	current_kind = NodeKind.BOSS if battle_number % 10 == 0 else NodeKind.BATTLE


func _load_shops_for_block(block_index: int) -> void:
	shop_after_battles.clear()
	for local_battle in _route_planner.shop_positions_for_block(block_index):
		shop_after_battles.append(block_index * 10 + local_battle)

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

var hero: RefCounted
var battle_number := 1
var current_kind := NodeKind.BATTLE
var completed_battles := 0
var shops_visited := 0
var shop_after_battles: Array[int]
var status := Status.ACTIVE
var duration_seconds := 0.0
var _started_at_msec: int


func _init(hero_state: RefCounted, route_seed: int = 19020) -> void:
	assert(hero_state != null, "Run state requires hero")
	hero = hero_state
	shop_after_battles = LinearRoutePlannerScript.new(route_seed).shop_positions_for_block(0)
	_started_at_msec = Time.get_ticks_msec()


func complete_battle() -> void:
	assert(current_kind in [NodeKind.BATTLE, NodeKind.BOSS], "Current run node is not a battle")
	completed_battles += 1
	if battle_number == 10:
		current_kind = NodeKind.COMPLETE
		status = Status.COMPLETE
	elif battle_number in shop_after_battles:
		current_kind = NodeKind.SHOP
	else:
		battle_number += 1
		current_kind = NodeKind.BOSS if battle_number == 10 else NodeKind.BATTLE


func leave_shop() -> void:
	assert(current_kind == NodeKind.SHOP, "Current run node is not a shop")
	shops_visited += 1
	battle_number += 1
	current_kind = NodeKind.BOSS if battle_number == 10 else NodeKind.BATTLE


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
	match current_kind:
		NodeKind.SHOP:
			return "Заросшие руины · Магазин после боя %d" % battle_number
		NodeKind.BOSS:
			return "Заросшие руины · Босс 10/10"
		NodeKind.COMPLETE:
			return "Заросшие руины пройдены"
		_:
			return "Заросшие руины · Бой %d/10" % battle_number

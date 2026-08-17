extends SceneTree

const PlannerScript = preload("res://core/run/linear_route_planner.gd")
const RouteNodeScript = preload("res://core/run/route_node.gd")


func _init() -> void:
	var failed := false
	for seed in range(1, 101):
		var planner = PlannerScript.new(seed)
		for block_index in 5:
			var nodes: Array[RefCounted] = planner.generate_block(block_index)
			var shops: Array[int] = planner.shop_positions_for_block(block_index)
			failed = _check_silent(shops.size() <= 2, "Block has at most two shops") or failed
			if shops.size() == 2:
				failed = _check_silent(shops[1] - shops[0] >= 3, "At least two battles separate shops") or failed
			var battles: Array[int] = []
			var bosses: Array[int] = []
			for node in nodes:
				if node.kind != RouteNodeScript.Kind.SHOP:
					battles.append(node.battle_number)
				if node.kind == RouteNodeScript.Kind.BOSS:
					bosses.append(node.battle_number)
			failed = _check_silent(battles.size() == 10 and battles[0] == block_index * 10 + 1 and battles[-1] == block_index * 10 + 10, "Route is linear within block") or failed
			failed = _check_silent(bosses == [(block_index + 1) * 10], "Every tenth battle is the only boss in its block") or failed
		if planner.shop_positions_for_block(0).is_empty():
			failed = _check_silent(false, "First block has a guaranteed shop") or failed
		else:
			var first_shop_after: int = planner.shop_positions_for_block(0)[0]
			failed = _check_silent(first_shop_after <= 5, "First shop appears no later than route node six") or failed
		failed = _check_silent(planner.shop_positions_for_block(0) == planner.shop_positions_for_block(0), "Generated route is stable for the run") or failed

	failed = _check(not failed, "100 seeded routes across 5 blocks satisfy all placement rules") or failed
	quit(1 if failed else 0)


func _check_silent(condition: bool, _description: String) -> bool:
	return not condition


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

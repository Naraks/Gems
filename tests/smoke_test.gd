extends SceneTree

const RULES_PATH := "res://data/game_rules.tres"
const MAIN_SCENE_PATH := "res://ui/main/main.tscn"


func _init() -> void:
	var failed := false
	var rules := load(RULES_PATH) as GameRules
	failed = _check(rules != null, "GameRules resource loads") or failed
	if rules != null:
		failed = _check(rules.is_valid(), "GameRules resource is valid") or failed
		failed = _check(rules.board_size() == Vector2i(7, 7), "Board is 7x7") or failed
		failed = _check(is_equal_approx(rules.generator_weight_total(), 1.0), "Generator weights total 1.0") or failed

	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	failed = _check(main_scene != null, "Main scene loads") or failed
	if main_scene != null:
		var instance := main_scene.instantiate()
		failed = _check(instance != null, "Main scene instantiates") or failed
		instance.free()

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

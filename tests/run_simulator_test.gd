extends SceneTree

const SimulatorScript = preload("res://core/run/run_simulator.gd")
const RUN_COUNT := 100
const FIRST_SEED := 24001


func _init() -> void:
	var failed := false
	var simulator = SimulatorScript.new()
	var batch: Dictionary = simulator.simulate_many(RUN_COUNT, FIRST_SEED)
	failed = _check(batch.runs.size() == RUN_COUNT, "Simulator completes 100 seeded runs") or failed
	var valid_runs := 0
	for run in batch.runs:
		valid_runs += int(run.valid and run.cause in ["defeat", "completed"] and run.depth >= 1 and run.depth <= 10)
	failed = _check(valid_runs == RUN_COUNT, "All runs end without hangs or impossible states") or failed
	failed = _check(_sum(batch.depth_distribution) == RUN_COUNT and _sum(batch.duration_distribution) == RUN_COUNT and _sum(batch.cause_distribution) == RUN_COUNT, "Depth, duration and end-cause distributions cover every run") or failed
	failed = _check(batch.total_shops > 0 and batch.total_levels > 0 and batch.total_bosses_encountered > 0, "Batch traverses shops, levels and bosses") or failed
	var replay_a: Dictionary = simulator.simulate(FIRST_SEED + 37)
	var replay_b: Dictionary = simulator.simulate(FIRST_SEED + 37)
	failed = _check(replay_a == replay_b, "A run is exactly reproducible from its seed") or failed
	if not failed:
		print("100-run depth distribution: ", batch.depth_distribution)
		print("100-run duration distribution: ", batch.duration_distribution)
		print("100-run cause distribution: ", batch.cause_distribution)
		print("100-run systems: shops=%d levels=%d bosses=%d" % [batch.total_shops, batch.total_levels, batch.total_bosses_encountered])
	quit(1 if failed else 0)


func _sum(distribution: Dictionary) -> int:
	var total := 0
	for value in distribution.values():
		total += int(value)
	return total


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

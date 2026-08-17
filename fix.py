extends Node
signal reward_double_started()
signal reward_double_ended()

class_name BossRewardMultiplier

const BASE_DURATION: float = 6.0

var active_multiplier: float = 2.0
var duration_remaining: float = BASE_DURATION
var is_active: bool = false

var target_nodes: Array[Node] = []

func _ready() -> void:
	add_to_group("BossRewardMultipliers")

func activate(reward_node: Node = null, multiplier: float = 2.0, duration: float = BASE_DURATION) -> void:
	if duration_remaining > 0:
		duration_remaining = duration
	is_active = true
	if reward_node != null:
		target_nodes.append(reward_node)
		connect_signal(reward_node, "reward_granted", _on_reward_granted)
	else:
		# Default to emitting signal if a generic trigger was used
		target_nodes.append(self)

func deactivate() -> void:
	if duration_remaining <= 0:
		duration_remaining = 0.0
		is_active = false
		reward_double_ended.emit()

func _process(delta: float) -> void:
	if is_active and duration_remaining > 0:
		duration_remaining -= delta
		if duration_remaining <= 0:
			duration_remaining = 0.0
			is_active = false
			reward_double_ended.emit()

func _on_reward_granted(amt: float) -> void:
	if is_active:
		# Apply multiplier
		var doubled: float = amt * active_multiplier
		reward_double_started.emit()

func set_multiplier(value: float) -> void:
	if value >= 1:
		active_multiplier = value

func set_duration(value: float) -> void:
	if value > 0:
		duration_remaining = value

func reset() -> void:
	duration_remaining = BASE_DURATION
	is_active = true
	reward_double_started.emit()

func connect_signal(node: Node, signal_name: String, callback: Signal) -> void:
	if node.is_connected("reward_granted", callback):
		node.disconnect("reward_granted", callback)
	node.connect("reward_granted", callback)
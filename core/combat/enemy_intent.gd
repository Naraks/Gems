class_name EnemyIntent
extends RefCounted

enum Kind {
	ATTACK,
	HEAL,
	SPECIAL,
	PREPARE,
}

var kind: Kind
var value: int
var title: String
var action: Callable
var show_value: bool


func _init(intent_kind: Kind, exact_value: int, intent_title := "", intent_action: Callable = Callable(), should_show_value := true) -> void:
	assert(exact_value >= 0, "Intent value cannot be negative")
	kind = intent_kind
	value = exact_value
	title = intent_title
	action = intent_action
	show_value = should_show_value


func display_text() -> String:
	var label := title
	if label.is_empty():
		match kind:
			Kind.ATTACK: label = "Атака"
			Kind.HEAL: label = "Лечение"
			Kind.SPECIAL: label = "Особое действие"
			Kind.PREPARE: label = "Подготовка"
	return "%s: %d" % [label, value] if show_value else label

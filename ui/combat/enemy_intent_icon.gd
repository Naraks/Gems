class_name EnemyIntentIcon
extends Control

const EnemyIntentScript = preload("res://core/combat/enemy_intent.gd")

var kind := EnemyIntentScript.Kind.ATTACK
var value := 0
var show_value := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func setup(intent: RefCounted) -> void:
	kind = intent.kind
	value = intent.value
	show_value = intent.show_value
	tooltip_text = tr("Следующий ход: %s") % intent.display_text()
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	draw_rect(frame, Color(0.035, 0.07, 0.055, 0.94), true)
	draw_rect(frame, _intent_color(), false, 3.0)
	match kind:
		EnemyIntentScript.Kind.ATTACK: _draw_sword()
		EnemyIntentScript.Kind.HEAL: _draw_heal()
		EnemyIntentScript.Kind.SPECIAL: _draw_special()
		EnemyIntentScript.Kind.PREPARE: _draw_prepare()
	if show_value:
		_draw_value_badge()


func _draw_value_badge() -> void:
	var badge := Rect2(size.x - 25.0, size.y - 25.0, 20.0, 20.0)
	draw_rect(badge, Color(0.035, 0.07, 0.055, 1.0), true)
	draw_rect(badge, Color("fff2c7"), false, 2.0)
	var font := get_theme_default_font()
	var text := str(value)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var baseline := badge.position + Vector2((badge.size.x - text_size.x) * 0.5, (badge.size.y + text_size.y) * 0.5 - 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_sword() -> void:
	draw_line(Vector2(18, 37), Vector2(39, 16), Color("ff6b55"), 7.0)
	draw_line(Vector2(16, 35), Vector2(23, 42), Color("f0bd3f"), 5.0)
	draw_line(Vector2(14, 42), Vector2(20, 36), Color("9b5b36"), 5.0)


func _draw_heal() -> void:
	draw_rect(Rect2(24, 13, 10, 32), Color("66e68c"), true)
	draw_rect(Rect2(13, 24, 32, 10), Color("66e68c"), true)


func _draw_special() -> void:
	var center := Vector2(29, 28)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -17), center + Vector2(5, -5), center + Vector2(17, 0),
		center + Vector2(5, 5), center + Vector2(0, 17), center + Vector2(-5, 5),
		center + Vector2(-17, 0), center + Vector2(-5, -5),
	]), Color("a987ff"))


func _draw_prepare() -> void:
	var color := Color("f0bd3f")
	draw_line(Vector2(17, 14), Vector2(41, 14), color, 4.0)
	draw_line(Vector2(17, 42), Vector2(41, 42), color, 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, 17), Vector2(38, 17), Vector2(31, 27), Vector2(38, 39),
		Vector2(20, 39), Vector2(27, 27),
	]), color)


func _intent_color() -> Color:
	match kind:
		EnemyIntentScript.Kind.ATTACK: return Color("ff6b55")
		EnemyIntentScript.Kind.HEAL: return Color("66e68c")
		EnemyIntentScript.Kind.SPECIAL: return Color("a987ff")
		EnemyIntentScript.Kind.PREPARE: return Color("f0bd3f")
	return Color.WHITE

class_name CombatantPortrait
extends Control

enum Role { HERO, ENEMY }

@export var role := Role.HERO
@export var primary_color := Color("4e78d0")
@export var symbol := "⚔"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func setup(new_role: int, new_color: Color, new_symbol: String) -> void:
	role = new_role
	primary_color = new_color
	symbol = new_symbol
	queue_redraw()


func _draw() -> void:
	var scale_factor := maxf(1.0, floorf(minf(size.x / 12.0, size.y / 16.0)))
	var sprite_size := Vector2(12.0, 16.0) * scale_factor
	var origin := (size - sprite_size) * 0.5
	var outline := Color("17151d")
	var highlight := primary_color.lightened(0.28)
	var shadow := primary_color.darkened(0.3)
	if role == Role.HERO:
		_pixel_rect(origin, Vector2i(4, 1), Vector2i(4, 4), outline, scale_factor)
		_pixel_rect(origin, Vector2i(5, 2), Vector2i(2, 2), Color("e5bd82"), scale_factor)
		_pixel_rect(origin, Vector2i(3, 5), Vector2i(6, 7), outline, scale_factor)
		_pixel_rect(origin, Vector2i(4, 5), Vector2i(4, 6), primary_color, scale_factor)
		_pixel_rect(origin, Vector2i(5, 5), Vector2i(2, 5), highlight, scale_factor)
		_pixel_rect(origin, Vector2i(2, 7), Vector2i(2, 5), shadow, scale_factor)
		_pixel_rect(origin, Vector2i(8, 7), Vector2i(1, 6), Color("d6dce8"), scale_factor)
		_pixel_rect(origin, Vector2i(9, 6), Vector2i(1, 2), Color("f4f6f8"), scale_factor)
		_pixel_rect(origin, Vector2i(3, 12), Vector2i(2, 3), outline, scale_factor)
		_pixel_rect(origin, Vector2i(7, 12), Vector2i(2, 3), outline, scale_factor)
	else:
		_pixel_rect(origin, Vector2i(2, 1), Vector2i(2, 3), outline, scale_factor)
		_pixel_rect(origin, Vector2i(8, 1), Vector2i(2, 3), outline, scale_factor)
		_pixel_rect(origin, Vector2i(3, 2), Vector2i(6, 5), outline, scale_factor)
		_pixel_rect(origin, Vector2i(4, 3), Vector2i(4, 3), primary_color, scale_factor)
		_pixel_rect(origin, Vector2i(4, 4), Vector2i(1, 1), Color("fff1a1"), scale_factor)
		_pixel_rect(origin, Vector2i(7, 4), Vector2i(1, 1), Color("fff1a1"), scale_factor)
		_pixel_rect(origin, Vector2i(2, 7), Vector2i(8, 6), outline, scale_factor)
		_pixel_rect(origin, Vector2i(3, 7), Vector2i(6, 5), primary_color, scale_factor)
		_pixel_rect(origin, Vector2i(5, 7), Vector2i(2, 5), highlight, scale_factor)
		_pixel_rect(origin, Vector2i(1, 8), Vector2i(2, 4), shadow, scale_factor)
		_pixel_rect(origin, Vector2i(9, 8), Vector2i(2, 4), shadow, scale_factor)
		_pixel_rect(origin, Vector2i(3, 13), Vector2i(2, 2), outline, scale_factor)
		_pixel_rect(origin, Vector2i(7, 13), Vector2i(2, 2), outline, scale_factor)
	_draw_symbol()


func _draw_symbol() -> void:
	if symbol.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := maxi(10, floori(minf(size.x, size.y) * 0.2))
	var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2((size.x - text_size.x) * 0.5, size.y - 2.0), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _pixel_rect(origin: Vector2, cell: Vector2i, dimensions: Vector2i, color: Color, scale_factor: float) -> void:
	draw_rect(Rect2(origin + Vector2(cell) * scale_factor, Vector2(dimensions) * scale_factor), color, true)

class_name BiomeBackground
extends Control

const EndlessCycleScript = preload("res://core/run/endless_cycle.gd")

const BIOME_IDS := [&"ruins", &"mines", &"tower"]
const BIOME_NAMES := {
	&"ruins": "Заросшие руины",
	&"mines": "Пепельные шахты",
	&"tower": "Башня безмолвия",
}
const BIOME_TEXTURES := {
	&"ruins": preload("res://assets/backgrounds/overgrown_ruins.png"),
	&"mines": preload("res://assets/backgrounds/ashen_mines.png"),
	&"tower": preload("res://assets/backgrounds/tower_of_silence.png"),
}
const PANEL_COLORS := {
	&"ruins": Color("17251f"),
	&"mines": Color("28191c"),
	&"tower": Color("17162b"),
}
const ACCENT_COLORS := {
	&"ruins": Color("b8df91"),
	&"mines": Color("f0a064"),
	&"tower": Color("aaa2ff"),
}
const PARALLAX_RANGE := Vector2(5.0, 3.0)

var biome_id: StringName = &"ruins"
var parallax_offset := Vector2.ZERO
var _elapsed := 0.0
var _palette_hue_shift := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	queue_redraw()


func setup_for_battle(battle_number: int) -> void:
	assert(battle_number >= 1, "Battle number starts at one")
	_palette_hue_shift = EndlessCycleScript.palette_hue_shift(battle_number)
	set_biome(EndlessCycleScript.biome_id(battle_number))


func set_biome(new_biome_id: StringName) -> void:
	assert(new_biome_id in BIOME_IDS, "Unknown biome")
	biome_id = new_biome_id
	queue_redraw()


func biome_name() -> String:
	return tr(BIOME_NAMES[biome_id])


func panel_color(alpha := 0.9) -> Color:
	return _shifted_color(PANEL_COLORS[biome_id], alpha)


func accent_color() -> Color:
	return _shifted_color(ACCENT_COLORS[biome_id])


func background_texture() -> Texture2D:
	return BIOME_TEXTURES[biome_id]


func _process(delta: float) -> void:
	_elapsed += delta
	var viewport_size := get_viewport_rect().size
	var pointer_ratio := Vector2.ZERO
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		pointer_ratio = (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)) * 2.0
	var idle_drift := Vector2(sin(_elapsed * 0.32), cos(_elapsed * 0.27)) * 0.35
	var target := (pointer_ratio + idle_drift) * PARALLAX_RANGE
	parallax_offset = parallax_offset.lerp(target, minf(1.0, delta * 2.5))
	queue_redraw()


func _draw() -> void:
	var texture := background_texture()
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	var scale_factor := maxf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn_size := texture_size * scale_factor + PARALLAX_RANGE * 4.0
	var destination := Rect2((size - drawn_size) * 0.5 + parallax_offset, drawn_size)
	draw_texture_rect(texture, destination, false, _shifted_color(Color(0.72, 0.72, 0.72, 1.0)))
	draw_rect(Rect2(Vector2.ZERO, size), panel_color(0.28), true)


func _shifted_color(color: Color, alpha := -1.0) -> Color:
	var shifted := Color.from_hsv(fmod(color.h + _palette_hue_shift, 1.0), color.s, color.v, color.a)
	if alpha >= 0.0:
		shifted.a = alpha
	return shifted

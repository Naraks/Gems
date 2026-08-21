class_name CombatantPortrait
extends Control

enum Role { HERO, ENEMY }
enum State { IDLE, SWORD, MAGIC, ATTACK, SPECIAL, HURT, HEAL, PREPARE, DEFEAT }

const HERO_TEXTURE := preload("res://assets/characters/hero.png")
const ENEMY_TEXTURE := preload("res://assets/characters/ordinary_enemy.png")
const BOSS_TEXTURES := {
	&"stone_guardian": preload("res://assets/characters/stone_guardian.png"),
	&"fire_golem": preload("res://assets/characters/fire_golem.png"),
	&"void_archmage": preload("res://assets/characters/void_archmage.png"),
}
const STATE_NAMES := [&"idle", &"sword", &"magic", &"attack", &"special", &"hurt", &"heal", &"prepare", &"defeat"]

@export var role := Role.HERO
@export var primary_color := Color("4e78d0")
@export var symbol := "⚔"

var definition_id: StringName = &""
var is_boss := false
var current_state := State.IDLE
var played_states: PackedStringArray = []
var animation_progress := 0.0:
	set(value):
		animation_progress = value
		queue_redraw()
var _elapsed := 0.0
var _state_tween: Tween
var _texture: Texture2D = HERO_TEXTURE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	queue_redraw()


func setup(new_role: int, new_color: Color, new_symbol: String, new_definition_id: StringName = &"", boss := false) -> void:
	role = new_role
	primary_color = new_color
	symbol = new_symbol
	definition_id = new_definition_id
	is_boss = boss
	_texture = HERO_TEXTURE if role == Role.HERO else BOSS_TEXTURES.get(definition_id, ENEMY_TEXTURE)
	current_state = State.IDLE
	animation_progress = 0.0
	queue_redraw()


func play_state(state: State, duration := 0.18) -> void:
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	current_state = state
	played_states.append(STATE_NAMES[state])
	animation_progress = 0.0
	_state_tween = create_tween()
	_state_tween.tween_property(self, "animation_progress", 1.0, duration)
	await _state_tween.finished
	if current_state == state and state != State.DEFEAT:
		current_state = State.IDLE
		animation_progress = 0.0


func supports_state(state: State) -> bool:
	if role == Role.HERO:
		return state in [State.IDLE, State.SWORD, State.MAGIC, State.HURT, State.HEAL, State.DEFEAT]
	if is_boss:
		return state in [State.IDLE, State.ATTACK, State.SPECIAL, State.HURT, State.HEAL, State.PREPARE, State.DEFEAT]
	return state in [State.IDLE, State.ATTACK, State.SPECIAL, State.HURT, State.HEAL, State.DEFEAT]


func vfx_color() -> Color:
	match definition_id:
		&"stone_guardian": return Color("d4b65c")
		&"fire_golem": return Color("ff6a2d")
		&"void_archmage": return Color("9b67ff")
	return Color("78c6ff") if role == Role.HERO else primary_color.lightened(0.25)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var progress := animation_progress
	var wave := sin(progress * PI)
	var offset := Vector2(0.0, sin(_elapsed * 2.4) * 1.4)
	var sprite_scale := Vector2.ONE
	var rotation := 0.0
	var tint := Color.WHITE
	match current_state:
		State.SWORD, State.ATTACK:
			offset.x += (1.0 if role == Role.HERO else -1.0) * wave * 12.0
			rotation = (1.0 if role == Role.HERO else -1.0) * wave * 0.08
		State.MAGIC, State.SPECIAL, State.PREPARE:
			sprite_scale = Vector2.ONE * (1.0 + wave * 0.09)
		State.HURT:
			offset.x += sin(progress * PI * 8.0) * 4.0 * (1.0 - progress)
			tint = Color(1.0, 0.45 + progress * 0.55, 0.45 + progress * 0.55)
		State.HEAL:
			offset.y -= wave * 5.0
			tint = Color(0.65, 1.0, 0.72)
		State.DEFEAT:
			rotation = progress * (PI * 0.42 if role == Role.HERO else -PI * 0.42)
			offset.y += progress * 16.0
			tint.a = 1.0 - progress * 0.75
	_draw_vfx(wave)
	var target_height := minf(size.y, size.x * 1.34)
	var target_width := target_height * 0.75
	var rect := Rect2(Vector2(-target_width * 0.5, -target_height * 0.5), Vector2(target_width, target_height))
	draw_set_transform(size * 0.5 + offset, rotation, sprite_scale)
	var sprite_tint := tint
	if role == Role.ENEMY and not is_boss:
		sprite_tint *= primary_color.lightened(0.55)
	draw_texture_rect(_texture, rect, false, sprite_tint)
	draw_set_transform(Vector2.ZERO)


func _draw_vfx(wave: float) -> void:
	if current_state not in [State.MAGIC, State.SPECIAL, State.PREPARE, State.HEAL, State.SWORD, State.ATTACK]:
		return
	var center := size * 0.5
	var color := Color("63e68a") if current_state == State.HEAL else vfx_color()
	color.a = 0.25 + wave * 0.55
	if current_state in [State.SWORD, State.ATTACK]:
		var direction := 1.0 if role == Role.HERO else -1.0
		draw_arc(center + Vector2(direction * 7.0, 0.0), 24.0 + wave * 5.0, -1.1 if direction > 0 else 2.0, 1.1 if direction > 0 else 4.2, 10, color, 3.0)
		return
	var radius := 16.0 + wave * (18.0 if current_state == State.PREPARE else 10.0)
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.0)
	if definition_id == &"stone_guardian":
		for index in 4:
			var angle := TAU * float(index) / 4.0
			draw_rect(Rect2(center + Vector2.from_angle(angle) * radius - Vector2(3, 3), Vector2(6, 6)), color, false, 2.0)
	elif definition_id == &"fire_golem":
		for index in 5:
			var angle := TAU * float(index) / 5.0
			draw_line(center + Vector2.from_angle(angle) * 10.0, center + Vector2.from_angle(angle) * (radius + 8.0), color, 3.0)
	elif definition_id == &"void_archmage":
		for index in 3:
			var angle := _elapsed * 3.0 + TAU * float(index) / 3.0
			draw_circle(center + Vector2.from_angle(angle) * radius, 3.0, color)

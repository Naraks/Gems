extends SceneTree

const MAIN_SCENE := preload("res://ui/main/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var biome_ids: Array[StringName] = []
	var textures: Array[Texture2D] = []
	var colors: Array[Color] = []
	for battle_number in [1, 11, 21]:
		var main = MAIN_SCENE.instantiate()
		main.battle_number = battle_number
		root.add_child(main)
		await process_frame
		var background = main.biome_background
		biome_ids.append(background.biome_id)
		textures.append(background.background_texture())
		colors.append(background.panel_color())
		failed = _check(background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Biome %s disables texture smoothing" % background.biome_id) or failed
		failed = _check(background.biome_name() in main.battle_number_label.text, "Biome name is visible for battle %d" % battle_number) or failed
		var board_style := main.get_node("%BoardArea").get_theme_stylebox("panel") as StyleBoxFlat
		failed = _check(
			board_style != null
			and board_style.bg_color.a <= 0.1
			and main.board_view.BOARD_COLOR.a >= 0.85,
			"Background remains visible while the board stays readable over %s" % background.biome_name(),
		) or failed
		failed = _check(main.hero_portrait.visible and main.hero_portrait.size.x >= 44.0, "Hero portrait remains visible in the combat HUD") or failed
		failed = _check(main.enemy_portrait.visible and main.enemy_portrait.primary_color == main._battle.enemy.definition.visual_color, "Current enemy has a data-driven portrait") or failed
		main.queue_free()
		await process_frame

	failed = _check(biome_ids == [&"ruins", &"mines", &"tower"], "Battles select all three biomes in order") or failed
	failed = _check(textures[0] != textures[1] and textures[1] != textures[2] and textures[0] != textures[2], "Every biome has a distinct background asset") or failed
	failed = _check(colors[0] != colors[1] and colors[1] != colors[2], "Every biome has a distinct HUD palette") or failed

	var parallax = MAIN_SCENE.instantiate()
	root.add_child(parallax)
	await process_frame
	var original_offset: Vector2 = parallax.biome_background.parallax_offset
	await create_timer(0.2).timeout
	failed = _check(parallax.biome_background.parallax_offset.distance_to(original_offset) > 0.0, "Background has subtle independent parallax motion") or failed
	parallax.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

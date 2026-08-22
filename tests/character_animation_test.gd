extends SceneTree

const PortraitScript = preload("res://ui/combat/combatant_portrait.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var portrait = PortraitScript.new()
	portrait.size = Vector2(96, 128)
	root.add_child(portrait)
	await process_frame

	portrait.setup(PortraitScript.Role.HERO, Color("4e78d0"), "⚔")
	failed = _check(portrait.ART_SCALE == 2.0, "Combatant artwork is rendered at double scale") or failed
	failed = _check(portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Character art uses nearest-neighbour filtering") or failed
	for state in [PortraitScript.State.IDLE, PortraitScript.State.SWORD, PortraitScript.State.MAGIC, PortraitScript.State.HURT, PortraitScript.State.HEAL, PortraitScript.State.DEFEAT]:
		failed = _check(portrait.supports_state(state), "Hero supports state %s" % PortraitScript.STATE_NAMES[state]) or failed
	for state in [PortraitScript.State.SWORD, PortraitScript.State.MAGIC, PortraitScript.State.HURT, PortraitScript.State.HEAL]:
		await portrait.play_state(state, 0.01)
		failed = _check(portrait.current_state == PortraitScript.State.IDLE, "Hero %s animation returns to idle" % PortraitScript.STATE_NAMES[state]) or failed
	failed = _check(&"sword" in portrait.played_states and &"magic" in portrait.played_states, "Hero combat states are animated") or failed

	portrait.setup(PortraitScript.Role.ENEMY, Color("8a4b42"), "!", &"ruins_fighter", false)
	for state in [PortraitScript.State.IDLE, PortraitScript.State.ATTACK, PortraitScript.State.SPECIAL, PortraitScript.State.HURT, PortraitScript.State.DEFEAT]:
		failed = _check(portrait.supports_state(state), "Regular enemy supports state %s" % PortraitScript.STATE_NAMES[state]) or failed
	failed = _check(not portrait.supports_state(PortraitScript.State.PREPARE), "Boss preparation is not assigned to regular enemies") or failed
	for state in [PortraitScript.State.ATTACK, PortraitScript.State.SPECIAL, PortraitScript.State.HURT]:
		await portrait.play_state(state, 0.01)
		failed = _check(portrait.current_state == PortraitScript.State.IDLE, "Regular enemy %s animation returns to idle" % PortraitScript.STATE_NAMES[state]) or failed

	var boss_textures: Array[Texture2D] = []
	var boss_colors: Array[Color] = []
	for boss_id in [&"stone_guardian", &"fire_golem", &"void_archmage"]:
		portrait.setup(PortraitScript.Role.ENEMY, Color.WHITE, "★", boss_id, true)
		boss_textures.append(portrait._texture)
		boss_colors.append(portrait.vfx_color())
		failed = _check(portrait.supports_state(PortraitScript.State.PREPARE), "%s has preparation animation" % boss_id) or failed
		failed = _check(portrait.has_unique_boss_vfx(), "%s has a dedicated VFX profile" % boss_id) or failed
		await portrait.play_state(PortraitScript.State.PREPARE, 0.01)
		await portrait.play_state(PortraitScript.State.SPECIAL, 0.01)
	failed = _check(boss_textures[0] != boss_textures[1] and boss_textures[1] != boss_textures[2], "Bosses use unique art") or failed
	failed = _check(boss_colors[0] != boss_colors[1] and boss_colors[1] != boss_colors[2], "Bosses use unique VFX palettes") or failed
	for biome in ["ruins", "mines", "tower"]:
		var regular_textures: Array[Texture2D] = []
		for archetype in ["fighter", "healer", "berserker"]:
			portrait.setup(PortraitScript.Role.ENEMY, Color.WHITE, "?", StringName("%s_%s" % [biome, archetype]), false)
			regular_textures.append(portrait._texture)
		failed = _check(
			regular_textures[0] != regular_textures[1]
			and regular_textures[1] != regular_textures[2]
			and regular_textures[0] != regular_textures[2],
			"%s biome has three unique regular enemy portraits" % biome,
		) or failed

	for path in [
		"res://assets/characters/hero.png", "res://assets/characters/ordinary_enemy.png",
		"res://assets/characters/ruins_root_fighter.png", "res://assets/characters/ruins_moss_shaman.png", "res://assets/characters/ruins_vine_brute.png",
		"res://assets/characters/mines_ash_raider.png", "res://assets/characters/mines_ember_shaman.png", "res://assets/characters/mines_crystal_brute.png",
		"res://assets/characters/tower_silent_duelist.png", "res://assets/characters/tower_arcane_cultist.png", "res://assets/characters/tower_spectral_sentinel.png",
		"res://assets/characters/stone_guardian.png", "res://assets/characters/fire_golem.png", "res://assets/characters/void_archmage.png",
	]:
		var texture := load(path) as Texture2D
		failed = _check(texture != null and texture.get_size() == Vector2(portrait.ART_SIZE), "%s is a normalized character sheet" % path) or failed
		var import_text := FileAccess.get_file_as_string(path + ".import")
		failed = _check("mipmaps/generate=false" in import_text and "compress/mode=0" in import_text, "%s keeps pixel-safe import settings" % path) or failed

	failed = _check(FileAccess.file_exists("res://docs/character_art_style_sheet.md"), "Character assets have a shared style sheet and cleanup checklist") or failed
	failed = _check(portrait.MAX_VFX_DURATION <= 0.5, "Character VFX budget follows the GDD limit") or failed

	portrait.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

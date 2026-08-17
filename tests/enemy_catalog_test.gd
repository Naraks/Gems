extends SceneTree

const EnemyCatalogScript = preload("res://core/enemies/enemy_catalog.gd")
const EnemyFactoryScript = preload("res://core/enemies/enemy_factory.gd")
const EnemyControllerScript = preload("res://core/enemies/enemy_controller.gd")
const EnemyIntentExecutorScript = preload("res://core/combat/enemy_intent_executor.gd")
const BattleStateScript = preload("res://core/combat/battle_state.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const AttackTypeScript = preload("res://core/combat/attack_type.gd")

const ARCHETYPES := ["Боец", "Лекарь", "Проклинатель", "Берсерк", "Щитоносец"]


func _init() -> void:
	var failed := false
	var catalog = EnemyCatalogScript.new()
	var definitions: Array[Resource] = catalog.all()
	failed = _check(definitions.size() == 30, "Catalog contains 30 regular enemies") or failed
	var ids := {}
	var factory = EnemyFactoryScript.new()
	var biome_health_averages: Array[float] = []
	for biome_index in EnemyCatalogScript.BIOMES.size():
		var biome: StringName = EnemyCatalogScript.BIOMES[biome_index]
		var biome_definitions := catalog.for_biome(biome)
		var slots := {}
		var archetype_counts := {}
		var total_health := 0
		for definition in biome_definitions:
			ids[definition.id] = true
			slots[definition.battle_slot] = true
			archetype_counts[definition.archetype] = archetype_counts.get(definition.archetype, 0) + 1
			failed = _check(definition.is_valid(), "%s is a valid enemy definition" % definition.id) or failed
			failed = _check(definition.biome_id == biome and definition.visual_color.a > 0.0, "%s has biome and visual data" % definition.id) or failed
			var battle_number: int = biome_index * 10 + definition.battle_slot
			var enemy = factory.create(definition, battle_number)
			total_health += enemy.max_health
			failed = _check(enemy.base_damage > 0 and enemy.experience_reward > 0 and enemy.base_coin_reward > 0, "%s has positive balanced parameters" % definition.id) or failed
		failed = _check(biome_definitions.size() == 10 and slots.size() == 10, "%s has ten distinct battle slots" % biome) or failed
		for archetype in ARCHETYPES:
			failed = _check(archetype_counts.get(archetype, 0) == 2, "%s has two %s enemies" % [biome, archetype]) or failed
		biome_health_averages.append(float(total_health) / biome_definitions.size())
	failed = _check(ids.size() == 30, "All enemy ids are unique") or failed
	failed = _check(catalog.for_battle(1).biome_id == &"ruins" and catalog.for_battle(11).biome_id == &"mines" and catalog.for_battle(21).biome_id == &"tower", "Battle number selects the expected biome") or failed
	failed = _check(biome_health_averages[0] < biome_health_averages[1] and biome_health_averages[1] < biome_health_averages[2], "Average enemy health rises between biomes") or failed

	var board = BoardModelScript.new(Vector2i(7, 7), _filled_board())
	var berserker_definition: Resource = load("res://data/enemies/ruins_berserker.tres")
	var berserker = factory.create(berserker_definition, 4)
	var berserker_controller = EnemyControllerScript.new(berserker, board, 12, 25)
	var normal_damage: int = berserker.current_intent.value
	berserker.take_damage(ceili(berserker.max_health * 0.6))
	berserker_controller.advance_intent()
	failed = _check(berserker.current_intent.value > normal_damage, "Berserker attack grows below half health") or failed

	var shield_definition: Resource = load("res://data/enemies/ruins_shieldbearer.tres")
	var shield_enemy = factory.create(shield_definition, 5)
	var shield_controller = EnemyControllerScript.new(shield_enemy, board, 12, 25)
	shield_enemy.record_player_attack(AttackTypeScript.Kind.PHYSICAL)
	shield_controller.advance_intent()
	var shield_battle = BattleStateScript.new(HeroStateScript.new(100), shield_enemy)
	EnemyIntentExecutorScript.new().execute(shield_enemy.current_intent, shield_battle)
	failed = _check(is_equal_approx(shield_enemy.physical_damage_multiplier, 0.65), "Shieldbearer resists the last attack type") or failed
	shield_enemy.record_player_attack(AttackTypeScript.Kind.PHYSICAL)
	failed = _check(is_equal_approx(shield_enemy.physical_damage_multiplier, 1.5), "Shieldbearer resistance expires after one incoming attack") or failed

	quit(1 if failed else 0)


func _filled_board() -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(49)
	cells.fill(TileTypeScript.Value.SWORD)
	return cells


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

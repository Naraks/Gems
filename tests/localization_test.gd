extends SceneTree

const LocalizationServiceScript = preload("res://core/localization/localization_service.gd")
const HeroStateScript = preload("res://core/combat/hero_state.gd")
const SETTINGS_PATH := "user://localization_test.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var absolute_settings_path := ProjectSettings.globalize_path(SETTINGS_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_settings_path)

	failed = _check(LocalizationServiceScript.select_locale("en", SETTINGS_PATH), "English locale can be selected and saved") or failed
	failed = _check(LocalizationServiceScript.load_saved_locale(SETTINGS_PATH) == "en", "Saved English locale loads from user settings") or failed
	failed = _check(tr("Заросшие руины") == "Overgrown Ruins" and tr("Пауза") == "Pause", "English translations are registered") or failed
	failed = _check(LocalizationServiceScript.format_integer(1234567) == "1,234,567", "English integers use comma grouping") or failed

	var main = (load("res://ui/main/main.tscn") as PackedScene).instantiate()
	main.battle_number = 20
	root.add_child(main)
	await process_frame
	failed = _check("Battle 20" in main.battle_number_label.text and "Ashen Mines" in main.battle_number_label.text, "Battle heading is localized in English") or failed
	failed = _check("Fire Golem" in main.enemy_title_label.text and "Next turn:" in main.enemy_intent_label.text, "Enemy data and combat hints are localized in English") or failed
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	failed = _check(main.battle_number_label.size.x > 0.0 and main.enemy_intent_label.size.x > 0.0, "English combat HUD remains readable at 640x360") or failed
	main.queue_free()
	await process_frame

	var shop = (load("res://ui/shop/shop_screen.tscn") as PackedScene).instantiate()
	root.add_child(shop)
	var hero = HeroStateScript.new(100)
	hero.coins = 1234567
	shop.setup(hero, 30030)
	await process_frame
	failed = _check(shop.coins_label.text == "Coins: 1,234,567" and "Refresh" in shop.refresh_button.text, "Shop numbers and hints are formatted in English") or failed
	failed = _check(shop.item_buttons[0].size.y >= 44.0 and shop.leave_button.size.y >= 44.0, "English shop controls remain readable at 640x360") or failed
	shop.queue_free()
	await process_frame

	var run = (load("res://ui/run/first_biome_run.tscn") as PackedScene).instantiate()
	run.localization_settings_path = SETTINGS_PATH
	root.add_child(run)
	await process_frame
	failed = _check(run.language_selector.selected == 1 and "Overgrown Ruins" in run.node_title_label.text, "Saved language is applied to the run screen") or failed
	failed = _check(run.language_selector.size.y >= 44.0 and run.language_selector.get_parent().name == "MenuLayout", "Language selector is a valid touch target inside the run menu") or failed
	run._on_language_selected(0)
	await process_frame
	failed = _check(LocalizationServiceScript.load_saved_locale(SETTINGS_PATH) == "ru" and "Заросшие руины" in run.node_title_label.text, "Language can switch to Russian without restarting the battle") or failed
	failed = _check(LocalizationServiceScript.format_integer(1234567) == "1 234 567", "Russian integers use non-breaking-space grouping") or failed
	run.queue_free()
	await process_frame

	DirAccess.remove_absolute(absolute_settings_path)
	TranslationServer.set_locale("ru")
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true

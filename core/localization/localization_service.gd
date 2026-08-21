class_name LocalizationService
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := ["ru", "en"]
const DEFAULT_LOCALE := "ru"


static func initialize(settings_path := SETTINGS_PATH) -> String:
	var locale := load_saved_locale(settings_path)
	TranslationServer.set_locale(locale)
	return locale


static func load_saved_locale(settings_path := SETTINGS_PATH) -> String:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return DEFAULT_LOCALE
	var locale: String = str(config.get_value("localization", "locale", DEFAULT_LOCALE))
	return locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE


static func select_locale(locale: String, settings_path := SETTINGS_PATH) -> bool:
	if locale not in SUPPORTED_LOCALES:
		return false
	TranslationServer.set_locale(locale)
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("localization", "locale", locale)
	return config.save(settings_path) == OK


static func current_locale() -> String:
	var locale := TranslationServer.get_locale().left(2)
	return locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE


static func format_integer(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var separator := "," if current_locale() == "en" else " "
	var formatted := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += separator
		formatted += digits[index]
	return ("−" if negative else "") + formatted

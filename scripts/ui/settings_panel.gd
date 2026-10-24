extends Panel

# Languages available in the switcher, shown in their own language,
# together with the matching Godot locale code used by
# TranslationServer.set_locale(). Both arrays must stay in the same
# order and length. English is always first and is the game's default
# language, regardless of the player's system locale.
#
# The save file stores the selected language as its position number
# (language_index on GameManager), so the ORDER OF THESE LISTS IS FIXED
# from release 1.0.2 on: new languages are added at the END of both
# lists, never in the middle, otherwise returning players would quietly
# switch to a different language.
# One known exception before 1.0.2: Ukrainian was put right after Russian
# on purpose (positions 0 and 1 stayed the same). Players of release 1.0.1
# who had Spanish selected (it was position 2) will see Ukrainian once and
# can switch back. Their progress is not affected, only the language.
#
# The display names themselves live in ui.csv (LANG_ENGLISH, LANG_RUSSIAN,
# LANG_UKRAINIAN and so on), with the SAME value repeated in every one of
# that CSV's language columns - a language's own name never changes
# depending on which language is currently selected, so tr() always
# returns the same text for these keys no matter the active locale. This
# keeps them in the same place/pipeline as every other piece of UI text
# (e.g. so a future formatting change, like the all-caps pass, only ever
# needs to touch the CSV) instead of being hardcoded separately here.
const LANGUAGE_KEYS: Array[String] = ["LANG_ENGLISH", "LANG_RUSSIAN", "LANG_UKRAINIAN", "LANG_SPANISH", "LANG_GERMAN", "LANG_FRENCH", "LANG_CHINESE"]
const LOCALE_CODES: Array[String] = ["en", "ru", "uk", "es", "de", "fr", "zh_CN"] # uk = Ukrainian, zh_CN = Simplified Chinese (the same codes as the columns in ui.csv)

# The game's shared theme. Every menu, button and text in the game gets
# its font from this theme's Default Font (a FontVariation).
const GAME_THEME: Theme = preload("res://assets/game_theme.tres")
# The pixel font for every language except Chinese (Press Start 2P with redrawn accented capitals)
const MAIN_FONT: Font = preload("res://assets/fonts/TaveronenStart-Regular.ttf")
# The pixel font with Chinese characters (Fusion Pixel with its line height
# changed to exactly the font size, the same as MAIN_FONT). It is swapped
# in as a whole instead of being added as a fallback, and both fonts have
# the same line height, so switching languages never makes a label grow:
# a label that grows once is never shrunk back by Godot, and the auto-fit
# system would then fill it with a bigger font in every other language.
const CHINESE_FONT: Font = preload("res://assets/fonts/TaveronenHanzi-Regular.woff2")
const CHINESE_LOCALE: String = "zh_CN"

# Called once when this node enters the scene tree
func _ready() -> void:
	# Look up the SFX bus by name
	var sfx_bus := AudioServer.get_bus_index("SFX")
	# Set the slider to the bus's current volume (convert dB to a 0-100 range),
	# so the slider shows the real value instead of resetting on open
	%SFXVolumeSlider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) * 100.0
	# React whenever the player drags the SFX slider
	%SFXVolumeSlider.value_changed.connect(_on_sfx_volume_changed)

	# Same setup, but for the Music bus
	var music_bus := AudioServer.get_bus_index("Music")
	%MusicVolumeSlider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus)) * 100.0
	%MusicVolumeSlider.value_changed.connect(_on_music_volume_changed)

	# Language switcher: the selected index lives on GameManager (an
	# autoload, so it survives scene changes) instead of on this panel -
	# this node gets recreated every time main_menu.tscn loads, including
	# when returning here from the tavern, so keeping the index here would
	# reset the language back to English every time. GameManager also
	# loads language_index from save.json at startup, so it survives full
	# game restarts too - see _on_language_prev/_on_language_next below,
	# which save it right away whenever the player changes it.
	_apply_language()
	%LanguagePrevButton.pressed.connect(_on_language_prev)
	%LanguageNextButton.pressed.connect(_on_language_next)

# Called every time the SFX slider's value changes
func _on_sfx_volume_changed(value: float) -> void:
	var sfx_bus := AudioServer.get_bus_index("SFX")
	# Convert the slider's 0-100 range back into decibels for the audio bus
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value / 100.0))
	# Remember it on GameManager (survives scene changes and full
	# restarts) and persist it right away, same pattern as the language
	# switcher below.
	GameManager.sfx_volume = value
	GameManager.save_audio_settings()

# Called every time the Music slider's value changes
func _on_music_volume_changed(value: float) -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(value / 100.0))
	GameManager.music_volume = value
	GameManager.save_audio_settings()

# Moves the language switcher one step back, wrapping around at the start
func _on_language_prev() -> void:
	GameManager.language_index = (GameManager.language_index - 1 + LANGUAGE_KEYS.size()) % LANGUAGE_KEYS.size()
	_apply_language()
	GameManager.save_language()

# Moves the language switcher one step forward, wrapping around at the end
func _on_language_next() -> void:
	GameManager.language_index = (GameManager.language_index + 1) % LANGUAGE_KEYS.size()
	_apply_language()
	GameManager.save_language()

# Updates the switcher's own label and actually switches the game's
# language via TranslationServer - this is what makes every translated
# Button/Label text on screen update automatically. It also picks the
# font for that language (see CHINESE_FONT above). Since translated
# text is usually a different length than the English original, we
# also ask the auto-fit system to re-check every button/label's size.
func _apply_language() -> void:
	var locale: String = LOCALE_CODES[GameManager.language_index] # The code of the chosen language, like "de"
	var theme_font: FontVariation = GAME_THEME.default_font as FontVariation # The theme's Default Font, shared by the whole game
	theme_font.base_font = CHINESE_FONT if locale == CHINESE_LOCALE else MAIN_FONT # Chinese gets the font with Chinese characters, every other language the main pixel font
	%LanguageValueLabel.text = tr(LANGUAGE_KEYS[GameManager.language_index])
	TranslationServer.set_locale(locale)
	AutoFitRuntime.refit_all()

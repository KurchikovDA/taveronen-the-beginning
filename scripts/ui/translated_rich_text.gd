# translated_rich_text.gd
#
# Attach this directly to a RichTextLabel that shows a fixed block of
# translated text (multi-paragraph BBCode, like Credits, the intro story,
# or the victory screen). Set the "Translation Key" export below to a key
# from translations/ui.csv - its value for the current language becomes
# this label's text, and it updates automatically whenever the game's
# language changes (Godot fires NOTIFICATION_TRANSLATION_CHANGED on every
# node when TranslationServer.set_locale() is called).
@tool
extends RichTextLabel

# The key to look up in translations/ui.csv, e.g. "CREDITS_BODY".
@export var translation_key: String = "":
	set(value):
		translation_key = value
		_refresh()

func _ready() -> void:
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()

# Pulls the translated string for translation_key, applies it as this
# label's text, and asks the shared TextFitter to resize it to fit.
func _refresh() -> void:
	if translation_key.is_empty():
		return
	text = tr(translation_key)
	TextFitter.fit_rich_text(self)

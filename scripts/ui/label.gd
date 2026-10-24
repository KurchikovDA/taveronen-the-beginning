extends RichTextLabel

# The gold value currently shown on screen - animates toward GameManager.gold
var displayed_gold: int = 0

# Keeps track of the current animation, so rapid changes don't stack up oddly
var count_tween: Tween

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	displayed_gold = GameManager.gold
	_update_display(displayed_gold)

func _notification(what: int) -> void:
	# Rebuild the displayed text when the game's language changes, so the
	# "Gold" word updates too, not just the number.
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_display(displayed_gold)

func _on_gold_changed(new_amount: int) -> void:
	if count_tween:
		count_tween.kill()
	count_tween = create_tween()
	count_tween.set_ease(Tween.EASE_OUT)
	count_tween.tween_method(_update_display, displayed_gold, new_amount, 0.4)

func _update_display(value: float) -> void:
	displayed_gold = int(round(value))
	# A small coin icon (see assets/interactions/gold_coin.png) drawn
	# inline right before the "<Gold label>: X" text, via BBCode's [img]
	# tag - no extra scene nodes needed. valign=center vertically
	# centers the icon against the text line, so the coin lines up with
	# the middle of "Gold" instead of sitting above it. The label word
	# itself comes from translations/ui.csv (key GOLD_LABEL), so it
	# follows the current language automatically.
	text = "[img=32x32 valign=center]res://assets/interactions/gold_coin.png[/img][color=#e8b23a]%s: %d[/color]" % [tr("GOLD_LABEL"), displayed_gold]

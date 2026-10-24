class_name ButtonGroupFitter
extends RefCounted

# Shared by every place in the project that needs several differently-
# worded buttons (e.g. "Continue"/"Settings"/"Return to Main Menu"/"Quit",
# or "Keep Playing"/"Return to Main Menu") to read at one consistent
# size, no matter which language is active - instead of each button
# picking its own size independently, which makes short words look
# bigger than long ones sitting right next to them.

const MAX_FONT_SIZE: int = 28
const MIN_FONT_SIZE: int = 6

# Picks the largest font size (within MIN_FONT_SIZE..MAX_FONT_SIZE) at
# which every button's own currently-translated text still fits inside
# its own box width, then applies that one size to all of them.
static func fit(buttons: Array[Button]) -> void:
	if buttons.is_empty():
		return
	var font: Font = buttons[0].get_theme_font("font")
	if font == null:
		return
	var button_style: StyleBox = buttons[0].get_theme_stylebox("normal")
	var style_left: float = 0.0
	var style_right: float = 0.0
	if button_style != null:
		style_left = button_style.get_margin(SIDE_LEFT)
		style_right = button_style.get_margin(SIDE_RIGHT)

	var chosen_size: int = MIN_FONT_SIZE
	for candidate_size in range(MAX_FONT_SIZE, MIN_FONT_SIZE - 1, -1):
		var all_fit: bool = true
		for button in buttons:
			var available_width: float = button.size.x - style_left - style_right
			var text_size: Vector2 = font.get_string_size(button.atr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, candidate_size)
			if text_size.x > available_width:
				all_fit = false
				break
		if all_fit:
			chosen_size = candidate_size
			break

	for button in buttons:
		button.add_theme_font_size_override("font_size", chosen_size)

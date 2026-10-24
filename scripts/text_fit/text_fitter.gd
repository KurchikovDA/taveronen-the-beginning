class_name TextFitter
extends RefCounted

const MAX_BUTTON_FONT_SIZE: int = 28
const MAX_LABEL_FONT_SIZE: int = 64
const MIN_FONT_SIZE: int = 6
const MIN_SCALE: float = 0.3
const SCALE_STEP: float = 0.02

# Any Button, Label, or RichTextLabel added to this group is left
# completely alone by the auto-fit system: no clip_text, no font
# size override, no scaling. Use this for controls whose sizing is
# already handled by their own custom code - for example the shop's
# item buttons (an invisible-text Button with a hand-built
# RichTextLabel color overlay drawn on top of it). Auto-fitting
# either of those two controls independently breaks that layout.
const EXCLUDE_GROUP: String = "autofit_exclude"

# Metadata key a node can carry (Inspector -> Metadata -> Add Metadata)
# to use its own font size ceiling instead of the shared
# MAX_BUTTON_FONT_SIZE/MAX_LABEL_FONT_SIZE default. Useful for a
# special, heavily-styled element (like a title with a thick outline)
# that should never grow as large as an ordinary button or label.
const MAX_SIZE_META_KEY: String = "autofit_max_size"

static func fit_button_or_label(control: Control) -> void:
	if control.is_in_group(EXCLUDE_GROUP):
		return
	if not (control is Button or control is Label):
		return
	if control is Button:
		control.clip_text = true
	var raw_text: String = control.get("text")
	if raw_text.is_empty():
		return
	# Measure the actual on-screen text, not the raw property - once
	# translations are involved, control.text can hold a translation
	# key (like "MENU_NEW_GAME") while the real displayed string is
	# whatever atr() resolves it to for the currently active language.
	var display_text: String = control.atr(raw_text)
	var font: Font = control.get_theme_font("font")
	if font == null:
		return
	var style_left: float = 0.0
	var style_right: float = 0.0
	var style_top: float = 0.0
	var style_bottom: float = 0.0
	if control is Button:
		var style: StyleBox = control.get_theme_stylebox("normal")
		if style != null:
			style_left = style.get_margin(SIDE_LEFT)
			style_right = style.get_margin(SIDE_RIGHT)
			style_top = style.get_margin(SIDE_TOP)
			style_bottom = style.get_margin(SIDE_BOTTOM)
	var available_width: float = control.size.x - style_left - style_right
	var available_height: float = control.size.y - style_top - style_bottom
	var max_size: int = MAX_BUTTON_FONT_SIZE if control is Button else MAX_LABEL_FONT_SIZE
	if control.has_meta(MAX_SIZE_META_KEY):
		max_size = control.get_meta(MAX_SIZE_META_KEY)
	var chosen_size: int = MIN_FONT_SIZE
	for candidate_size in range(max_size, MIN_FONT_SIZE - 1, -1):
		var text_size: Vector2 = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, candidate_size)
		if text_size.x <= available_width and text_size.y <= available_height:
			chosen_size = candidate_size
			break
	control.add_theme_font_size_override("font_size", chosen_size)

static func fit_rich_text(label: RichTextLabel) -> void:
	if label.is_in_group(EXCLUDE_GROUP):
		return

	var current_size: int = label.get_theme_font_size("normal_font_size")
	var last_applied_text: String = label.get_meta("_autofit_last_applied", "")
	var last_set_size: int = label.get_meta("_autofit_last_set_size", -1)

	var text_changed: bool = not label.has_meta("_autofit_original_bbcode") or label.text != last_applied_text
	var size_changed_by_hand: bool = last_set_size != -1 and current_size != last_set_size
	if text_changed or size_changed_by_hand:
		label.set_meta("_autofit_original_bbcode", label.text)
		label.set_meta("_autofit_base_normal_size", current_size)

	var original_bbcode: String = label.get_meta("_autofit_original_bbcode")
	var base_normal_size: int = label.get_meta("_autofit_base_normal_size")
	if original_bbcode.is_empty():
		return

	var available_height: float = label.size.y

	# Nothing actually changed since the last time this label was fitted
	# (same text, same manual font size, same available height) - skip
	# the expensive rescan. This matters a lot in the editor, where the
	# auto_fit_text plugin calls this every single frame for every
	# RichTextLabel in the open scene: without this early-out, every one
	# of them re-parses its BBCode and recomputes layout every frame,
	# forever, even while nothing is being edited.
	var last_available_height: float = label.get_meta("_autofit_last_available_height", -1.0)
	if not text_changed and not size_changed_by_hand and available_height == last_available_height:
		return

	var scale: float = 1.0
	while true:
		_apply_rich_text_scale(label, original_bbcode, base_normal_size, scale)
		if label.get_content_height() <= available_height or scale <= MIN_SCALE:
			break
		scale -= SCALE_STEP

	label.set_meta("_autofit_last_set_size", max(1, int(round(base_normal_size * scale))))
	label.set_meta("_autofit_last_available_height", available_height)

static func _apply_rich_text_scale(label: RichTextLabel, original_bbcode: String, base_normal_size: int, scale: float) -> void:
	var scaled_text: String = original_bbcode
	var regex := RegEx.new()
	regex.compile("\\[font_size=(\\d+)\\]")
	for result in regex.search_all(original_bbcode):
		var original_tag: String = result.get_string(0)
		var original_size: int = int(result.get_string(1))
		var new_tag: String = "[font_size=%d]" % max(1, int(round(original_size * scale)))
		scaled_text = scaled_text.replace(original_tag, new_tag)
	label.add_theme_font_size_override("normal_font_size", max(1, int(round(base_normal_size * scale))))
	label.text = scaled_text
	label.set_meta("_autofit_last_applied", scaled_text)

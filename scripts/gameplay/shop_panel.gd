extends Panel
# Reference to the VBoxContainer where item buttons will be placed
@onready var item_list: VBoxContainer = $ItemList

# Shop item definition: id, translation key for the display name, price.
# Each item can only be bought once - after purchase its button
# disappears from the shop. Ordered by ascending price so the shop list
# reads cheapest-to-most-expensive from top to bottom. The display name
# is looked up via tr(name_key) at runtime (see _update_button_text),
# so it automatically follows the current language.
#
# Prices balanced so the full game (all 7 items, at gold_per_second = 1)
# takes 30 minutes of real time in total: 5 + 60 + 100 + 170 + 280 +
# 460 + 725 = 1800 seconds. Reverted (29.09.2026) back to this 30-minute
# curve after briefly trying a 60-minute version (5 + 120 + 200 + 340 +
# 560 + 920 + 1455) and a flat equal-price version (600 each) - this is
# the original, kept curve: the very first item is a deliberately cheap,
# almost-instant hook (5 gold), and every item after that grows by a
# gentle, consistent ~x1.6-1.7 instead of sharp jumps.
# Furnishing order (set 25.09.2026): Torch comes right after the
# Fireplace, then Chair, then Table - unchanged here.
var items: Array[Dictionary] = [
	{"id": "fireplace", "name_key": "ITEM_FIREPLACE", "price": 5},
	{"id": "torch", "name_key": "ITEM_TORCH", "price": 60},
	{"id": "chair", "name_key": "ITEM_CHAIR", "price": 100},
	{"id": "table", "name_key": "ITEM_TABLE", "price": 170},
	{"id": "barrel", "name_key": "ITEM_BARREL", "price": 280},
	{"id": "bar_counter", "name_key": "ITEM_BAR_COUNTER", "price": 460},
	{"id": "dragon_trophy", "name_key": "ITEM_DRAGON_TROPHY", "price": 725},
]
# Keeps track of each button (and its overlay label) alongside its item,
# so we can update/remove the right one even after others are removed.
var shop_entries: Array[Dictionary] = []

# Font size search range used only for the shop's own item rows. These
# rows are excluded from the global TextFitter (see EXCLUDE_GROUP in
# text_fitter.gd), so this panel picks its own font size instead - one
# single size shared by every row, chosen so every item's text (plus the
# button's own built-in side padding) still fits the panel's width. Row
# height is then stretched separately to fill the panel's full height -
# see _fit_shop_text below.
#
# A per-row (independent) version of this was tried instead, but was
# reverted - having each row pick its own size made short names look
# noticeably bigger than long ones sitting right next to them, which
# read as inconsistent/messy rather than helpful. One shared size keeps
# the whole list visually uniform; the actual fix for non-English
# languages reading smaller than English is giving the panel more width
# (see ShopPanel's offset_left in tavern.tscn), not changing this logic.
const MAX_ITEM_FONT_SIZE: int = 32
const MIN_ITEM_FONT_SIZE: int = 6

# How long to wait after the last item is purchased before showing the
# victory screen. 5s (was 2s originally, then 10s; shortened to 5s on
# 30.09.2026) - once the shop panel empties out, that spot reveals the
# "Taveronen" wall sign (see _reveal_taveronen_sign below and
# taveronen_sign.gd, which owns its own reveal timing) before the
# victory screen appears on top of it, so the player still gets a
# moment to notice it.
const VICTORY_DELAY_SECONDS: float = 5.0

func _ready() -> void:
	# Stay invisible until every button below has its correct
	# affordable/disabled look and its final font size - Godot only
	# applies a Button's theme style on the next redraw after a
	# property change, so without this the very first frame briefly
	# shows the default (enabled-looking) style before it flips to the
	# real one. Restored to visible at the end of this function.
	modulate.a = 0.0

	# Reaching the shop means the player has actually entered the
	# tavern - the first real sign of a game in progress, so the Main
	# Menu's Continue button can light up from here on (see
	# GameManager.mark_game_started for why this can't just be "does a
	# save file exist").
	GameManager.mark_game_started()

	for item in items:
		if GameManager.purchased_items.has(item["id"]):
			_show_sprite_for(item["id"], false)
			continue
		var button := Button.new()
		button.name = item["id"]
		# This button's text is fully transparent by design (see below,
		# the visible text is drawn by the RichTextLabel overlay instead).
		# Its size is handled by this script directly, so it must be
		# excluded from the global auto-fit system - see EXCLUDE_GROUP in
		# text_fitter.gd for why.
		button.add_to_group("autofit_exclude")
		button.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		button.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))
		button.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		button.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		var label := RichTextLabel.new()
		# Same reason as the button above: this overlay must not be
		# resized independently by the auto-fit system.
		label.add_to_group("autofit_exclude")
		label.bbcode_enabled = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_child(label)
		_update_button_text(button, label, item)
		button.pressed.connect(_on_item_pressed.bind(item, button))
		item_list.add_child(button)
		shop_entries.append({"item": item, "button": button, "label": label})
	GameManager.gold_changed.connect(_on_gold_changed)
	# Buttons above are created with Godot's default disabled = false, so
	# without this they'd all briefly look affordable until the next
	# gold tick (up to 1 second later) fires gold_changed for real -
	# apply today's actual gold amount immediately instead of waiting.
	_on_gold_changed(GameManager.gold)

	# If every item was already owned from a previous save, check right
	# away - but with animate_sign = false, since in that case the
	# "Taveronen" sign was already fully revealed in an earlier session
	# and should just appear instantly, not play its grow animation
	# again every time this scene loads (same idea as passing false to
	# _show_sprite_for above for already-owned furniture).
	_check_for_victory(false)

	# The hidden "Legend of Gold" easter egg - shown the moment total
	# gold first reaches GameManager.GOLD_MILESTONE_AMOUNT, which in
	# practice only happens well after the tavern is fully furnished and
	# the player just kept playing (see GameManager.victory_continued).
	GameManager.gold_milestone_reached.connect(_show_gold_milestone_screen)

	# Wait one frame so this panel's own size (set by its anchors) is
	# fully settled, then pick a font size and row height that makes
	# every row fit and fill the panel.
	await get_tree().process_frame
	_fit_shop_text()

	# Everything is styled and sized correctly now - safe to reveal.
	modulate.a = 1.0

func _notification(what: int) -> void:
	# When the game's language changes, rebuild every row's text (name +
	# price + "gold" word all come from translations) and re-run the fit,
	# since translated text can be a different length than before.
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for entry in shop_entries:
			_update_button_text(entry["button"], entry["label"], entry["item"])
		_fit_shop_text()

# Picks the largest font size (within MIN_ITEM_FONT_SIZE..MAX_ITEM_FONT_SIZE)
# at which every item's full text ("Name N gold"), together with the
# button's own built-in side padding, still fits inside the panel's
# width. Then stretches the row container to the full available width
# (so short rows don't hug the left edge) and stretches every row's
# height so all rows together evenly fill the panel's full height.
func _fit_shop_text() -> void:
	if shop_entries.is_empty():
		return
	var sample_button: Button = shop_entries[0]["button"]
	var font: Font = sample_button.get_theme_font("font")
	if font == null:
		return

	var content_style: StyleBox = get_theme_stylebox("panel")
	var right_margin: float = 12.0
	var bottom_margin: float = 12.0
	if content_style != null:
		right_margin = content_style.get_margin(SIDE_RIGHT)
		bottom_margin = content_style.get_margin(SIDE_BOTTOM)

	# The button's own default style also reserves some space around its
	# text - this has to be counted too, or the button ends up wider than
	# we planned for and the row overflows past the panel's right edge.
	var button_style: StyleBox = sample_button.get_theme_stylebox("normal")
	var style_left: float = 0.0
	var style_right: float = 0.0
	var style_top: float = 0.0
	var style_bottom: float = 0.0
	if button_style != null:
		style_left = button_style.get_margin(SIDE_LEFT)
		style_right = button_style.get_margin(SIDE_RIGHT)
		style_top = button_style.get_margin(SIDE_TOP)
		style_bottom = button_style.get_margin(SIDE_BOTTOM)

	var available_width: float = size.x - item_list.offset_left - right_margin
	var available_height: float = size.y - item_list.offset_top - bottom_margin
	var separation: float = item_list.get_theme_constant("separation")
	var row_count: int = shop_entries.size()

	var price_suffix: String = tr("ITEM_PRICE_SUFFIX")
	var chosen_size: int = MIN_ITEM_FONT_SIZE
	for candidate_size in range(MAX_ITEM_FONT_SIZE, MIN_ITEM_FONT_SIZE - 1, -1):
		var widest_fits: bool = true
		for entry in shop_entries:
			var item: Dictionary = entry["item"]
			var full_text: String = "%s %d %s" % [tr(item["name_key"]), item["price"], price_suffix]
			var text_size: Vector2 = font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, candidate_size)
			if text_size.x + style_left + style_right > available_width:
				widest_fits = false
				break
		if widest_fits:
			chosen_size = candidate_size
			break

	# Force the row container itself to span the full available width -
	# otherwise, whenever the chosen font size leaves a little slack, the
	# container (and every row inside it) ends up narrower than the
	# panel and hugs the left edge instead of filling it evenly.
	item_list.custom_minimum_size.x = available_width

	# Split the panel's full height evenly between all rows, but never
	# shrink a row below what its own text actually needs.
	var row_height: float = (available_height - separation * (row_count - 1)) / row_count
	row_height = max(row_height, font.get_height(chosen_size) + style_top + style_bottom)

	for entry in shop_entries:
		var button: Button = entry["button"]
		button.add_theme_font_size_override("font_size", chosen_size)
		button.custom_minimum_size.y = row_height
		entry["label"].add_theme_font_size_override("normal_font_size", chosen_size)

func _on_item_pressed(item: Dictionary, button: Button) -> void:
	if GameManager.spend_gold(item["price"]):
		_show_sprite_for(item["id"], true)
		%ItemAppearSound.play()
		GameManager.mark_purchased(item["id"])
		shop_entries = shop_entries.filter(func(entry): return entry["button"] != button)
		button.queue_free()
		_check_for_victory()

func _check_for_victory(animate_sign: bool = true) -> void:
	if GameManager.purchased_items.size() >= items.size():
		_reveal_taveronen_sign(animate_sign)
		# The victory screen is shown only once: as soon as the player has
		# left it through either button ("Keep Playing" or "Return to Main
		# Menu"), GameManager.victory_continued is set. Without this check,
		# reopening an already-finished save via Continue would pop the
		# victory screen (and its music) up again on every single visit.
		if GameManager.victory_continued:
			return
		var timer := get_tree().create_timer(VICTORY_DELAY_SECONDS)
		timer.timeout.connect(_show_victory_screen)

# Reveals the "Taveronen" sign that takes over the wall spot where the
# shop panel used to be, once every item is purchased. The panel itself
# (this node - the script is attached directly to ShopPanel) fades out
# and hides, since by this point it's just an empty frame with nothing
# left to buy. The sign's own script (taveronen_sign.gd) owns how its
# letters actually grow into place - this just tells it whether to
# animate that (a live completion during play) or skip straight to
# fully shown (a returning player reopening an already-fully-furnished
# save - see the _check_for_victory(false) call in _ready above).
func _reveal_taveronen_sign(animate: bool) -> void:
	if not animate:
		visible = false
		%TaveronenSign.reveal(false)
		return

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.0)
	# Actually hide (not just fully transparent) once faded, so this
	# empty panel stops taking up any click area behind the sign.
	fade_tween.tween_callback(hide)

	%TaveronenSign.reveal(true)

func _show_victory_screen() -> void:
	%VictoryPanel.visible = true
	GameManager.play_victory_theme()
	# Note: this screen's "Keep Playing" button (continue_playing_button.gd)
	# already calls GameManager.mark_victory_continued() itself whenever
	# it's pressed - no need to wire that up again from here.

# The hidden gold-milestone easter egg - same presentation as the main
# victory screen, just a different panel/text, shown once the player has
# finished the tavern, continued playing, and kept it running long
# enough to hoard GameManager.GOLD_MILESTONE_AMOUNT.
func _show_gold_milestone_screen() -> void:
	%GoldMilestonePanel.visible = true
	GameManager.play_victory_theme()

# Plays a little "pop" animation (scale up + fade in) when a sprite appears.
# When animate is false (restoring an already-owned item on game start),
# the sprite just appears instantly with no animation.
func _animate_appear(node: CanvasItem, animate: bool) -> void:
	if not animate:
		node.visible = true
		return

	var target_scale: Vector2 = node.scale
	node.scale = target_scale * 0.3
	node.modulate.a = 0.0
	node.visible = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", target_scale, 0.35)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.25)

func _show_sprite_for(item_id: String, animate: bool = true) -> void:
	if item_id == "fireplace":
		_animate_appear(%FireplaceSprite, animate)
	elif item_id == "chair":
		_animate_appear(%ChairSprite, animate)
		_animate_appear(%ChairSprite2, animate)
	elif item_id == "table":
		_animate_appear(%TableSprite, animate)
	elif item_id == "barrel":
		_animate_appear(%BarrelSprite, animate)
	elif item_id == "bar_counter":
		_animate_appear(%BarCounterSprite, animate)
	elif item_id == "torch":
		_animate_appear(%TorchSprite, animate)
	elif item_id == "dragon_trophy":
		_animate_appear(%DragonTrophySprite, animate)

func _on_gold_changed(new_amount: int) -> void:
	for entry in shop_entries:
		var button: Button = entry["button"]
		var item: Dictionary = entry["item"]
		var can_afford: bool = new_amount >= item["price"]
		button.disabled = not can_afford
		entry["label"].modulate.a = 1.0 if can_afford else 0.5

func _update_button_text(button: Button, label: RichTextLabel, item: Dictionary) -> void:
	var item_name: String = tr(item["name_key"])
	var price_suffix: String = tr("ITEM_PRICE_SUFFIX")
	button.text = "%s %d %s" % [item_name, item["price"], price_suffix]
	label.text = "[color=white]%s[/color] [color=#e8b23a]%d %s[/color]" % [item_name, item["price"], price_suffix]

extends Node2D

# Simple click-to-earn interaction: each purchased item can pay out a
# random gold bonus after a random wait (see GameManager.BONUS_MIN_WAIT_SECONDS
# / BONUS_MAX_WAIT_SECONDS), repeating indefinitely for as long as the
# item is owned. While an item is eligible, its sprite(s) pulse gently
# as a hint; clicking it then plays a stronger pulse, pops up a little
# coin with a "+N" label, plays a dedicated coin sound, pays out the
# bonus, and starts the wait for its next one - all in one place, with
# no per-item Area2D nodes needed in the scene.

const COIN_TEXTURE: Texture2D = preload("res://assets/interactions/gold_coin.png")

# The "+N" popup label is created purely in code, so it needs its own
# explicit font - without this it silently falls back to Godot's built-in
# default font instead of the project's pixel font.
const POPUP_FONT: Font = preload("res://assets/fonts/TaveronenStart-Regular.ttf") # The game's pixel font (Press Start 2P with redrawn accented capitals)

const IDLE_PULSE_SCALE: float = 1.03
const IDLE_PULSE_DURATION: float = 0.7
const CLICK_PULSE_SCALE: float = 1.12
const CLICK_PULSE_UP_DURATION: float = 0.12
const CLICK_PULSE_DOWN_DURATION: float = 0.25
const COIN_FLOAT_DISTANCE: float = 40.0
const COIN_SCALE: Vector2 = Vector2(2, 2)

# Maps each shop item id to the sprite(s) that represent it in the
# scene. "chair" has two, since one purchase places two chair sprites.
var item_sprites: Dictionary = {}

# item_id -> currently running idle "ready to click" Tween, if any
var _idle_tweens: Dictionary = {}

# Caches each texture's tightly-cropped "visible pixels" rectangle (in
# the texture's own pixel space, alpha channel > 0), computed once per
# texture the first time it's needed - see _content_rect_for_texture.
# Keyed by the Texture2D resource itself.
var _content_rect_cache: Dictionary = {}

func _ready() -> void:
	item_sprites = {
		"fireplace": [%FireplaceSprite],
		"chair": [%ChairSprite, %ChairSprite2],
		"torch": [%TorchSprite],
		"table": [%TableSprite],
		"barrel": [%BarrelSprite],
		"bar_counter": [%BarCounterSprite],
		"dragon_trophy": [%DragonTrophySprite],
	}

	# Remember each sprite's own authored scale, so pulsing can always
	# animate relative to it and land back on it exactly.
	for sprites in item_sprites.values():
		for sprite in sprites:
			sprite.set_meta("base_scale", sprite.scale)

	GameManager.bonus_available.connect(_on_bonus_available)

	# Items whose random click-bonus wait (60-300 seconds, see
	# GameManager.BONUS_MIN_WAIT_SECONDS / BONUS_MAX_WAIT_SECONDS) had
	# already finished before this scene was (re)loaded - e.g. the game
	# was closed and reopened later - should start pulsing right away
	# instead of waiting for a fresh bonus_available signal that will
	# never fire again for them.
	for item_id in item_sprites.keys():
		if GameManager.can_collect_bonus(item_id):
			_start_idle_pulse(item_id)

func _on_bonus_available(item_id: String) -> void:
	_start_idle_pulse(item_id)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var click_pos: Vector2 = get_global_mouse_position()
	for item_id in item_sprites.keys():
		if not GameManager.can_collect_bonus(item_id):
			continue
		for sprite in item_sprites[item_id]:
			if not sprite.visible:
				continue
			var bounds: Rect2 = _global_bounds(sprite, _local_rect_for(sprite))
			if bounds.has_point(click_pos):
				_collect_bonus_for(item_id, sprite)
				get_viewport().set_input_as_handled()
				return

func _collect_bonus_for(item_id: String, clicked_sprite: Node2D) -> void:
	_stop_idle_pulse(item_id)
	var amount: int = GameManager.collect_bonus(item_id)
	if amount <= 0:
		return
	_play_click_pulse(item_id)
	_spawn_coin(clicked_sprite, amount)
	%CoinSound.play()

# -- Local bounding rect + hit-testing helpers ------------------------------

# Returns tex's tightly-cropped "visible pixels" rect (alpha > 0), in the
# texture's own pixel coordinates, computed once and cached. AtlasTexture
# (used by animated sprites, where several frames share one sheet) is
# handled specially - the shared sheet's image is cropped down to just
# this frame's region first, so the alpha scan can't accidentally pick
# up a neighboring frame.
func _content_rect_for_texture(tex: Texture2D) -> Rect2:
	if _content_rect_cache.has(tex):
		return _content_rect_cache[tex]
	var img: Image
	if tex is AtlasTexture:
		var atlas_img: Image = tex.atlas.get_image()
		img = atlas_img.get_region(Rect2i(tex.region))
	else:
		img = tex.get_image()
	var used: Rect2i = img.get_used_rect()
	var rect := Rect2(used.position, used.size)
	_content_rect_cache[tex] = rect
	return rect

# Local (pre-transform) rect a sprite occupies, used for click hit-testing.
# Trimmed to the texture's actual non-transparent pixels instead of the
# full rectangular frame, so items with a lot of empty padding around the
# art (chair, table, barrel in particular) don't get a click zone far
# bigger than what's actually drawn on screen. Works the same way for
# Sprite2D and AnimatedSprite2D - both have centered/offset, only how the
# texture itself is fetched differs.
#
# flip_h handling: Godot's flip_h does NOT change the sprite's transform
# (get_global_transform() is identical either way) - it only mirrors what
# gets drawn inside the frame that transform already defines. So if the
# visible (non-transparent) pixels aren't perfectly centered horizontally
# within the texture, a flipped sprite draws them mirrored to the other
# side of the frame, and the crop's X position has to be mirrored the
# same way here, or the computed click rect quietly drifts away from
# what's actually on screen. Currently only chair.png's second copy uses
# flip_h, and its content happens to be centered (so this bug had no
# visible effect yet) - but any art that isn't horizontally centered
# would have broken hit-testing the moment flip_h was used on it.
func _local_rect_for(sprite: Node2D) -> Rect2:
	var tex: Texture2D
	if sprite is AnimatedSprite2D:
		var frames: SpriteFrames = sprite.sprite_frames
		tex = frames.get_frame_texture(sprite.animation, sprite.frame)
	else:
		tex = sprite.texture
	var tex_size: Vector2 = tex.get_size()
	var top_left: Vector2 = (-tex_size / 2.0) if sprite.centered else Vector2.ZERO
	top_left += sprite.offset
	var content: Rect2 = _content_rect_for_texture(tex)

	var content_x: float = content.position.x
	if sprite.flip_h:
		content_x = tex_size.x - content.position.x - content.size.x

	return Rect2(top_left + Vector2(content_x, content.position.y), content.size)

# Transforms a sprite's local rect into a global, axis-aligned bounding
# rect - safe even with scaling and horizontal flipping.
func _global_bounds(sprite: Node2D, local_rect: Rect2) -> Rect2:
	var xform: Transform2D = sprite.get_global_transform()
	var corners: Array[Vector2] = [
		xform * local_rect.position,
		xform * (local_rect.position + Vector2(local_rect.size.x, 0)),
		xform * (local_rect.position + Vector2(0, local_rect.size.y)),
		xform * (local_rect.position + local_rect.size),
	]
	var min_x: float = corners[0].x
	var min_y: float = corners[0].y
	var max_x: float = corners[0].x
	var max_y: float = corners[0].y
	for corner in corners:
		min_x = min(min_x, corner.x)
		min_y = min(min_y, corner.y)
		max_x = max(max_x, corner.x)
		max_y = max(max_y, corner.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

# -- Pulsing -----------------------------------------------------------------

# Adds one "leg" of a pulse to tween, moving every sprite in sprites to
# target_scale_func(sprite) over duration. All sprites in the group move
# together (in parallel); the leg itself runs after whatever was already
# added to tween before it.
func _add_pulse_leg(tween: Tween, sprites: Array, target_scale_func: Callable, duration: float) -> void:
	for i in range(sprites.size()):
		var sprite: Node2D = sprites[i]
		var target: Vector2 = target_scale_func.call(sprite)
		var tweener: PropertyTweener
		if i == 0:
			tweener = tween.tween_property(sprite, "scale", target, duration)
		else:
			tweener = tween.parallel().tween_property(sprite, "scale", target, duration)
		tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Starts (or leaves alone, if already running) a slow, weak, endless
# pulse on item_id's sprite(s) - the visual hint that it can be clicked.
func _start_idle_pulse(item_id: String) -> void:
	if _idle_tweens.has(item_id):
		return
	var sprites: Array = item_sprites.get(item_id, [])
	if sprites.is_empty():
		return

	var tween := create_tween()
	tween.set_loops()
	_add_pulse_leg(tween, sprites, func(s): return s.get_meta("base_scale") * IDLE_PULSE_SCALE, IDLE_PULSE_DURATION)
	_add_pulse_leg(tween, sprites, func(s): return s.get_meta("base_scale"), IDLE_PULSE_DURATION)
	_idle_tweens[item_id] = tween

# Stops item_id's idle pulse (if any) and snaps its sprite(s) back to
# their exact authored scale.
func _stop_idle_pulse(item_id: String) -> void:
	if _idle_tweens.has(item_id):
		var tween: Tween = _idle_tweens[item_id]
		if tween.is_valid():
			tween.kill()
		_idle_tweens.erase(item_id)
	for sprite in item_sprites.get(item_id, []):
		sprite.scale = sprite.get_meta("base_scale")

# A single, stronger pulse played once when the bonus is actually collected.
func _play_click_pulse(item_id: String) -> void:
	var sprites: Array = item_sprites.get(item_id, [])
	if sprites.is_empty():
		return
	var tween := create_tween()
	_add_pulse_leg(tween, sprites, func(s): return s.get_meta("base_scale") * CLICK_PULSE_SCALE, CLICK_PULSE_UP_DURATION)
	_add_pulse_leg(tween, sprites, func(s): return s.get_meta("base_scale"), CLICK_PULSE_DOWN_DURATION)

# -- Coin + "+N" popup --------------------------------------------------------

# Spawns a little coin with a "+N" label above source_sprite that pops
# in, floats up together, then fades away and removes itself.
func _spawn_coin(source_sprite: Node2D, amount: int) -> void:
	var bounds: Rect2 = _global_bounds(source_sprite, _local_rect_for(source_sprite))
	var start_pos: Vector2 = to_local(Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.position.y))

	# A small container holding both the coin and its "+N" text, so both
	# fade and float up together as one unit.
	var popup := Node2D.new()
	popup.position = start_pos
	popup.modulate.a = 0.0
	popup.z_index = 100
	add_child(popup)

	var coin := Sprite2D.new()
	coin.texture = COIN_TEXTURE
	coin.scale = COIN_SCALE
	coin.position = Vector2(-14, 0)
	popup.add_child(coin)

	var label := Label.new()
	label.text = "+%d" % amount
	label.position = Vector2(0, -14)
	# Sized and styled entirely here in code, so keep the global auto-fit
	# system from touching it too, same as the other custom dynamic text
	# in the project (e.g. taveronen_sign.gd).
	label.add_to_group("autofit_exclude")
	label.add_theme_font_override("font", POPUP_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	popup.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "modulate:a", 1.0, 0.15)
	tween.tween_property(popup, "position:y", start_pos.y - COIN_FLOAT_DISTANCE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(popup, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(popup.queue_free)

extends Control

# Builds the "Taveronen" wall sign out of nine separate Label nodes (one
# per letter, stacked top to bottom) instead of a single RichTextLabel -
# this lets each letter be animated independently even though, in this
# version, all of them animate in lockstep. Every letter uses the same
# size and outline - no illuminated-capital-style first letter, since
# all in-game text is already uppercase, so a bigger first letter had no
# case distinction to justify it.
#
# Concept note: earlier versions had the letters carved with a knife,
# then rising up out of the wall as a fast "wave", then materializing
# one after another with a stagger between them. This version drops the
# stagger too - every letter sits at its final (slightly imperfect)
# resting pose from the very start, motionless, and the whole word
# materializes together: all nine letters begin as a barely-visible dark
# smudge, almost indistinguishable from the wood, and very slowly gain
# their warm color and full brightness at the same time - as if the
# whole message were developing out of shadow at once, like a single
# photograph appearing in developer fluid, rather than being spelled out
# letter by letter.

const WORD: String = "TAVERONEN"
const FONT: Font = preload("res://assets/fonts/TaveronenStart-Regular.ttf") # The game's pixel font (Press Start 2P with redrawn accented capitals)

# Warm, pale fresh-cut-wood tone - reads as lighter wood against the
# darker, aged wood of the wall/sign behind it, rather than blending in.
const LETTER_COLOR: Color = Color(224.0 / 255.0, 184.0 / 255.0, 128.0 / 255.0)
const OUTLINE_COLOR: Color = Color(30.0 / 255.0, 20.0 / 255.0, 10.0 / 255.0)
const OUTLINE_SIZE: int = 3

const LETTER_FONT_SIZE: int = 24

# How long the whole word takes to materialize out of darkness. This is
# the entire effect now - there is no movement, no scale animation, and
# no stagger between letters, just this one slow, shared color/visibility
# transition, so it needs to feel unhurried.
const LETTER_APPEAR_DURATION: float = 2.4

# The letters' starting appearance: almost fully transparent and tinted
# very dark (near-black, not the warm wood color) - a faint smudge you'd
# barely notice on the wall. Because this is a single Color that gets
# tweened toward Color(1,1,1,1) (see reveal()), both the alpha and the
# color brighten together: early in the tween every letter is a dim,
# dark shape; as it progresses they simultaneously become more visible
# AND shift toward their true warm color - reading as "coalescing out of
# shadow" rather than a plain fade-in.
const DARK_START_COLOR: Color = Color(0.08, 0.07, 0.06, 0.0)

# Each letter rests at a small random tilt/offset from its "perfectly
# upright, perfectly aligned" pose instead of exactly 0deg/0px - a little
# per-letter unevenness reads as age and character. Rolled once per
# letter in _ready(), so it stays the same for the lifetime of the sign
# (including for a returning player). This is the only "imperfection" -
# the letter never moves from this pose, it only changes color/visibility.
const LETTER_JITTER_ROTATION_DEGREES: float = 4.0
const LETTER_JITTER_OFFSET_PIXELS: float = 3.0

# A few soft, warm motes of light that drift gently upward and fade out -
# a brief magic accent tied to each letter's materialization.
const SPARKLE_COLOR: Color = Color(1.0, 0.92, 0.7, 0.9)
const SPARKLE_LIFETIME: float = 0.9
const SPARKLE_AMOUNT: int = 10
const SPARKLE_SCALE_MIN: float = 1.0
const SPARKLE_SCALE_MAX: float = 2.0

# How soon into the materialize animation the sparkle burst fires, as a
# fraction of LETTER_APPEAR_DURATION: 0.0 would fire it right at the
# start (while the letter is still almost invisible), 1.0 would fire it
# only once the letter is fully materialized (the old behavior). 0.5
# fires it partway through, while the letter is still visibly forming -
# lower this further to have the sparkles appear even earlier.
const SPARKLE_DELAY_FRACTION: float = 0.5

# A little pitch variation on the single appear sound, so repeated
# reveals (e.g. a returning player who deletes their save) don't sound
# like an exact identical replay every time.
const APPEAR_SOUND_PITCH_MIN: float = 0.97
const APPEAR_SOUND_PITCH_MAX: float = 1.03

var _letters: Array[Label] = []
var _letter_base_positions: Array[Vector2] = []
var _letter_jitter_rotation: Array[float] = []
var _letter_jitter_offset: Array[Vector2] = []

func _ready() -> void:
	var slice_height: float = size.y / float(WORD.length())
	for i in range(WORD.length()):
		var letter := Label.new()
		letter.text = WORD[i]
		# Sized and positioned entirely by this script, so the global
		# auto-fit system must leave it alone.
		letter.add_to_group("autofit_exclude")
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_override("font", FONT)
		letter.add_theme_color_override("font_color", LETTER_COLOR)
		letter.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		letter.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		letter.add_theme_font_size_override("font_size", LETTER_FONT_SIZE)
		# Each letter gets an equal vertical slice of this control's full
		# height, stacked top to bottom in reading order.
		letter.position = Vector2(0, slice_height * i)
		letter.size = Vector2(size.x, slice_height)
		letter.pivot_offset = letter.size / 2.0

		# Roll this letter's permanent resting jitter once, and remember
		# its clean authored position so the jittered resting pose is
		# always computed relative to that.
		_letter_base_positions.append(letter.position)
		_letter_jitter_rotation.append(deg_to_rad(randf_range(-LETTER_JITTER_ROTATION_DEGREES, LETTER_JITTER_ROTATION_DEGREES)))
		_letter_jitter_offset.append(Vector2(
			randf_range(-LETTER_JITTER_OFFSET_PIXELS, LETTER_JITTER_OFFSET_PIXELS),
			randf_range(-LETTER_JITTER_OFFSET_PIXELS, LETTER_JITTER_OFFSET_PIXELS)
		))

		# The letter is placed at its final resting pose immediately and
		# never moves from it - there is no rise, no squash/unfold, no
		# shake, and no stagger. All that changes over time is modulate
		# (see reveal()), and it changes the same way, at the same time,
		# for every letter.
		letter.rotation = _letter_jitter_rotation[i]
		letter.position = _letter_base_positions[i] + _letter_jitter_offset[i]
		letter.scale = Vector2.ONE
		letter.modulate = DARK_START_COLOR
		add_child(letter)
		_letters.append(letter)

# Reveals the sign. animate = true has every letter slowly materialize
# out of darkness together, all at once; animate = false (a returning
# player reopening an already-finished save) shows every letter instantly
# at its full, jittered resting pose, no animation.
func reveal(animate: bool) -> void:
	if not animate:
		for letter in _letters:
			letter.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	# A single unified sound for the whole reveal.
	_play_appear_sound()

	for letter in _letters:
		# The color tween itself - every letter starts this in the same
		# frame, so the whole word materializes in lockstep.
		var tween := create_tween()
		tween.tween_property(letter, "modulate", Color(1.0, 1.0, 1.0, 1.0), LETTER_APPEAR_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Sparkles run on their own separate tween instead of being a
		# second step chained after the one above - that's what lets them
		# fire partway through the materialize animation (at
		# SPARKLE_DELAY_FRACTION of the way through) instead of only once
		# it's fully finished.
		var sparkle_tween := create_tween()
		sparkle_tween.tween_interval(LETTER_APPEAR_DURATION * SPARKLE_DELAY_FRACTION)
		sparkle_tween.tween_callback(_spawn_sparkles.bind(letter))

# A few soft motes of warm light drifting gently upward and fading out,
# spawned from the center of the given letter. Purely cosmetic, no
# gameplay meaning.
func _spawn_sparkles(letter: Label) -> void:
	var burst := CPUParticles2D.new()
	burst.position = letter.position + letter.size / 2.0
	burst.z_index = letter.z_index + 1
	add_child(burst)

	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = SPARKLE_AMOUNT
	burst.lifetime = SPARKLE_LIFETIME

	# A gentle upward drift rather than a scattering burst - a narrow cone
	# pointing up, not a full 360-degree spread, so the motes read as
	# rising rather than exploding off the letter.
	burst.direction = Vector2(0, -1)
	burst.spread = 40.0
	burst.initial_velocity_min = 8.0
	burst.initial_velocity_max = 20.0

	# A slight upward pull (negative gravity) instead of falling back
	# down - these are meant to drift up and away like light, not drop
	# like debris.
	burst.gravity = Vector2(0, -12.0)

	burst.angular_velocity_min = -60.0
	burst.angular_velocity_max = 60.0

	burst.scale_amount_min = SPARKLE_SCALE_MIN
	burst.scale_amount_max = SPARKLE_SCALE_MAX

	burst.color = SPARKLE_COLOR
	# Fades each mote's alpha down to nothing over its lifetime, so they
	# visibly dissolve into the air rather than popping out of existence.
	var fade_out := Gradient.new()
	fade_out.set_color(0, SPARKLE_COLOR)
	fade_out.add_point(1.0, Color(SPARKLE_COLOR.r, SPARKLE_COLOR.g, SPARKLE_COLOR.b, 0.0))
	burst.color_ramp = fade_out

	burst.emitting = true

	# CPUParticles2D with one_shot = true stops emitting on its own but
	# doesn't free itself - clean it up once the burst has fully played
	# out. Done with a tween owned by this sign rather than awaiting
	# get_tree().create_timer(): the SceneTree timer would outlive the sign
	# if the player left the tavern within that second, resuming this
	# function on an already-freed node ("instance is gone" error). If the
	# sign is freed first, this tween is killed with it and the burst is
	# freed anyway as the sign's own child.
	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(SPARKLE_LIFETIME + 0.1)
	cleanup_tween.tween_callback(burst.queue_free)

# Plays the single unified appear sound for the whole reveal, if one has
# been wired up. Looks for a node named "LetterAppearSound" marked
# unique ("%") anywhere in this scene. Until that AudioStreamPlayer
# exists (with a stream assigned), this is a silent no-op.
func _play_appear_sound() -> void:
	var sound := get_node_or_null("%LetterAppearSound") as AudioStreamPlayer
	if sound == null:
		return
	sound.pitch_scale = randf_range(APPEAR_SOUND_PITCH_MIN, APPEAR_SOUND_PITCH_MAX)
	sound.play()

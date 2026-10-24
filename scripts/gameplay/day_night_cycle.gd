extends CanvasModulate

# Slowly tints the whole tavern room (background + furniture only - the
# CanvasLayer holding the UI/HUD is a separate canvas layer and is not
# affected by this node) between a gently cooler, moonlit night look and
# a normal daytime look, and back, forever. Starts at night. Purely a
# mood effect - doesn't touch gameplay, and like the (intentionally
# absent) offline income, only progresses while the tavern scene is
# actually running: closing the game resets the cycle to nighttime on
# the next visit, it doesn't track real-world time.

const DAY_COLOR: Color = Color(1.0, 1.0, 1.0)
const NIGHT_COLOR: Color = Color(0.88, 0.89, 0.96)
const HALF_CYCLE_SECONDS: float = 15.0 * 60.0 # 15 minutes each way, 30 minutes full day+night

func _ready() -> void:
	color = NIGHT_COLOR
	_run_cycle()

func _run_cycle() -> void:
	while true:
		var to_day := create_tween()
		to_day.tween_property(self, "color", DAY_COLOR, HALF_CYCLE_SECONDS)
		await to_day.finished

		var to_night := create_tween()
		to_night.tween_property(self, "color", NIGHT_COLOR, HALF_CYCLE_SECONDS)
		await to_night.finished

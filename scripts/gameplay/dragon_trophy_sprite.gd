extends AnimatedSprite2D

func _ready() -> void:
	# In case "Autoplay" is still set to "blink" on this node in the
	# editor, cancel whatever animation that triggered right away - this
	# script schedules its own blinking below, so the sprite should stay
	# fully idle until its first randomly-timed blink, regardless of
	# whatever the scene's own Autoplay field happens to be set to.
	stop()
	_schedule_next_blink()

func _schedule_next_blink() -> void:
	# Wait a long, random amount of time before blinking again —
	# rare and unpredictable, not a constant loop
	var wait_time := randf_range(5.0, 240.0)
	# The wait runs on a tween owned by this sprite instead of
	# get_tree().create_timer(): a SceneTree timer outlives the sprite, so
	# leaving the tavern mid-wait used to resume this function on an
	# already-freed node ("instance is gone" error). A node-owned tween is
	# killed together with the sprite, so the wait simply never finishes.
	var wait_tween := create_tween()
	wait_tween.tween_interval(wait_time)
	await wait_tween.finished
	play("blink")
	await animation_finished
	_schedule_next_blink()

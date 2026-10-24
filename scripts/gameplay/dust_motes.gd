extends CPUParticles2D

# Purely cosmetic ambient dust, drifting slowly and randomly in the tavern's
# light - no gameplay meaning, always on. Configured entirely here in code so
# the whole effect is one reproducible file, rather than several nested
# Gradient/Curve resources buried in the Inspector.

func _ready() -> void:
	amount = 8
	lifetime = 10.0
	preprocess = 10.0 # so dust is already scattered when the scene starts, not all born at once
	emitting = true

	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(550, 300) # covers almost the whole 1152x648 room, small margin from the edges

	# Full 360-degree spread instead of one fixed direction, so each mote
	# starts drifting its own way instead of all streaming upward together.
	direction = Vector2(0, -1)
	spread = 180.0

	# No gravity pull - dust should hang in the air and wander, not
	# consistently rise or fall.
	gravity = Vector2(0, 0)

	initial_velocity_min = 1.0
	initial_velocity_max = 4.0

	# Gentle curling motion instead of a straight path - this is what makes
	# it read as "randomly floating" rather than "flying somewhere".
	tangential_accel_min = -3.0
	tangential_accel_max = 3.0
	orbit_velocity_min = -0.15
	orbit_velocity_max = 0.15

	angular_velocity_min = -15.0
	angular_velocity_max = 15.0

	scale_amount_min = 0.5
	scale_amount_max = 1.3

	color = Color(1.0, 0.93, 0.75, 0.35) # warm, soft, mostly transparent

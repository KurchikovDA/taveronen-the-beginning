shader_type canvas_item;

const int STAR_COUNT = 12;
const vec4 STARS[STAR_COUNT] = vec4[](
	vec4(240.0, 30.0, 242.0, 32.0),
	vec4(1000.0, 30.0, 1002.0, 32.0),
	vec4(80.0, 40.0, 82.0, 42.0),
	vec4(820.0, 40.0, 822.0, 42.0),
	vec4(1050.0, 60.0, 1052.0, 62.0),
	vec4(320.0, 70.0, 322.0, 72.0),
	vec4(160.0, 90.0, 162.0, 92.0),
	vec4(880.0, 90.0, 882.0, 92.0),
	vec4(750.0, 110.0, 752.0, 112.0),
	vec4(60.0, 130.0, 62.0, 132.0),
	vec4(1100.0, 130.0, 1102.0, 132.0),
	vec4(700.0, 150.0, 702.0, 152.0)
);

const float STAR_STEP_INTERVAL = 0.12;
const float STAR_DIM_FRAMES = 4.0;

const float SMOKE_BAND_TOP = 28.0;
const float SMOKE_BAND_BOTTOM = 99.0;
const float SMOKE_BAND_HEIGHT = SMOKE_BAND_BOTTOM - SMOKE_BAND_TOP;
const vec3 SMOKE_SKY_COLOR = vec3(36.0 / 255.0, 26.0 / 255.0, 58.0 / 255.0);
const float SMOKE_RISE_SPEED = 10.0;
const float SMOKE_FADE_ZONE = 10.0;
const float STEP_INTERVAL = 0.15;

// The night sky background is not a smooth gradient - it is drawn in flat
// horizontal color bands. There is a hard edge at y = 120.0 (pixel space)
// where the sky color steps from SMOKE_SKY_COLOR down to a second, slightly
// lighter/warmer band. Stars below that line need to fade into THAT color,
// not the top band's color, or they read as a mismatched dark blob instead
// of vanishing.
const float SKY_BAND_SPLIT_Y = 120.0;
const vec3 SMOKE_SKY_COLOR_LOWER = vec3(58.0 / 255.0, 42.0 / 255.0, 92.0 / 255.0);

vec3 sky_color_at(float pixel_y) {
	if (pixel_y < SKY_BAND_SPLIT_Y) {
		return SMOKE_SKY_COLOR;
	}
	return SMOKE_SKY_COLOR_LOWER;
}

bool inside(vec2 p, vec4 rect) {
	return p.x >= rect.x && p.x < rect.z + 1.0 && p.y >= rect.y && p.y < rect.w + 1.0;
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 sample_uv = UV;
	float smoke_visible = 1.0;

	if (pixel.x >= 405.0 && pixel.x < 446.0 && pixel.y >= 15.0 && pixel.y < 106.0) {
		float frame_index = floor(TIME / STEP_INTERVAL);
		float frame_time = frame_index * STEP_INTERVAL;
		float local_y = mod(pixel.y - SMOKE_BAND_TOP + frame_time * SMOKE_RISE_SPEED, SMOKE_BAND_HEIGHT);
		local_y = floor(local_y);
		float wobble_index = mod(frame_index, 4.0);
		float wobble_px = 0.0;
		if (wobble_index < 1.0) { wobble_px = 0.0; }
		else if (wobble_index < 2.0) { wobble_px = 1.0; }
		else if (wobble_index < 3.0) { wobble_px = 0.0; }
		else { wobble_px = -1.0; }
		float sample_y = SMOKE_BAND_TOP + local_y + 0.5;
		sample_uv = vec2(UV.x + wobble_px * TEXTURE_PIXEL_SIZE.x, sample_y * TEXTURE_PIXEL_SIZE.y);
		if (local_y < SMOKE_FADE_ZONE || local_y > SMOKE_BAND_HEIGHT - SMOKE_FADE_ZONE) {
			smoke_visible = 0.0;
		}
	}

	vec4 col = texture(TEXTURE, sample_uv);
	if (smoke_visible < 0.5) {
		// The chimney smoke band (y 28-99) sits entirely inside the upper
		// sky band, so it always fades to the same SMOKE_SKY_COLOR.
		col.rgb = SMOKE_SKY_COLOR;
	}

	float brightness = 1.0;

	if (inside(pixel, vec4(160.0, 258.0, 197.0, 309.0))
	 || inside(pixel, vec4(434.0, 258.0, 471.0, 309.0))) {
		brightness = 0.82 + 0.18 * (0.5 + 0.5 * sin(TIME * 1.1));
	}

	if (inside(pixel, vec4(245.0, 444.0, 256.0, 453.0))) {
		float flicker = 0.5 * sin(TIME * 6.3) + 0.5 * sin(TIME * 2.1 + 1.7);
		brightness = clamp(0.75 + 0.35 * flicker, 0.45, 1.0);
	}

	// Instead of dimming a star's own color toward black, a star that's
	// in its "off" phase is replaced outright with the local night sky
	// color - same idea as the chimney smoke fading into the sky - so it
	// reads as briefly vanishing into the sky rather than turning into a
	// dark speck. Which sky color depends on the star's own y position,
	// since the sky is banded rather than a single flat color.
	bool star_off = false;
	float off_pixel_y = 0.0;
	for (int i = 0; i < STAR_COUNT; i++) {
		if (inside(pixel, STARS[i])) {
			float fi = float(i);
			float star_frame = floor(TIME / STAR_STEP_INTERVAL);
			float cycle_len = 100.0 + fract(fi * 37.719) * 150.0;
			float phase_offset = fract(fi * 91.345) * cycle_len;
			float pos_in_cycle = mod(star_frame + phase_offset, cycle_len);
			star_off = pos_in_cycle < STAR_DIM_FRAMES;
			off_pixel_y = STARS[i].y;
		}
	}

	col.rgb *= brightness;
	if (star_off) {
		col.rgb = sky_color_at(off_pixel_y);
	}
	COLOR = col;
}
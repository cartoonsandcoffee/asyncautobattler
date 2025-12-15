shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

const float curvature = 9.0;  // - Higher number = less curve
const float y_resolution = 810.0;

const float vignette_multiplier = 0.25;  	// - Mid vale = 0.25  (Higher is larger vignette, ie: more black)
const float vignette_bightness = 6.0;		// - Mid vale = 5.5  (Higher is brighter)
const float vignette_spread = 1.0;			// - Mid vale = 1.5  (Lower is less intense and therefore brighter)

const float scanline_thickness = 3.0;
const float scanline_subtlty = 0.1;
const float scanline_brightness = 0.9;

const float blur = 0.2;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;  // REMOVE: filter_linear_mipmap - to remove blur

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	vec2 uv_offset = centered_uv.yx / curvature;
	vec2 warped_uv = centered_uv + centered_uv * uv_offset * uv_offset;
	vec3 cutoff = vec3(step(abs(warped_uv.x), 1.0) * step(abs(warped_uv.y), 1.0));

	vec3 scanlines = vec3(sin(2.0 * warped_uv.y * (y_resolution/scanline_thickness)) * scanline_subtlty + scanline_brightness);

	vec3 vignette = vec3(length(pow(abs(centered_uv), vec2(vignette_bightness) / vignette_spread)));

	//vec3 screen_color = texture(screen_texture, (warped_uv + 1.0) / 2.0).rgb * cutoff * scanlines; // - No blur (for removing filter_linear_mipmap
	vec3 screen_color = textureLod(screen_texture, (warped_uv + 1.0) / 2.0, blur).rgb * cutoff * scanlines;
	screen_color -= vignette * vignette_multiplier;

	COLOR = vec4(screen_color, 1.0);
}

shader_type canvas_item;

// Transition douce du sommeil paradoxal : l'ecran ondule puis se fond dans une teinte de reve.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.78, 0.72, 1.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 40.0 + TIME * 8.0) * 0.025 * progress;
	uv.y += cos(uv.x * 30.0 + TIME * 6.0) * 0.01 * progress;
	vec4 c = texture(screen_tex, uv);
	COLOR = vec4(mix(c.rgb, tint.rgb, progress * progress), 1.0);
}

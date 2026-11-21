shader_type canvas_item;
render_mode unshaded;

// Onde de choc en pixel art dessine (voir scripts/combat/hazards/ring_wave.gd) : une vague de
// bouffees (bord exterieur festonne), eclairee de l'exterieur, cernee, avec des motifs qui voyagent
// dessus et une trainee tramee derriere. Les trous restent nets (on voit ou passer). La zone qui
// blesse reste l'anneau de rayon `radius`.

#include "res://assets/shaders/pixel_common.gdshaderinc"

uniform float radius = 40.0;
uniform float thickness = 12.0;
uniform vec2 gaps[4];  // (angle, demi-largeur en radians)
uniform int gap_count = 0;
uniform float seed = 0.0;

float gap_distance(float a) {
	float best = 10.0;
	for (int i = 0; i < 4; i++) {
		if (i >= gap_count)
			break;
		float diff = abs(mod(a - gaps[i].x + 3.14159, 6.28318) - 3.14159) - gaps[i].y;
		best = min(best, diff);
	}
	return best;  // < 0 : dans un trou
}

void fragment() {
	vec4 tint = COLOR;
	vec2 c = cell_px(local);
	vec2 q = snap_px(local);
	float d = length(q);
	float a = atan(q.y, q.x);
	float gd = gap_distance(a);
	float half_t = thickness * 0.5;
	// Feston : une bosse tous les ~10 pixels d'art le long de l'onde, qui roule doucement.
	float lobes = max(6.0, floor(radius / 10.0));
	float bump = pow(abs(sin(a * lobes * 0.5 + time * 1.5 + seed)), 0.7);
	float inner = radius - half_t;
	float outer = radius + half_t * (0.2 + 0.9 * bump);
	vec4 col = vec4(0.0);
	// Trainee tramee derriere l'onde.
	if (gd > 0.0 && d < inner && d > inner - 16.0 && stipple(c, seed) < (d - inner + 16.0) / 16.0 * 0.45)
		col = with_alpha(mid_color, 0.4);
	if (gd > 0.0 && d >= inner - px && d <= outer + px) {
		if (d > outer || d < inner)
			col = with_alpha(outline_color, 0.95);
		else {
			float t = (d - inner) / max(outer - inner, px);
			col = with_alpha(t > 0.7 ? light_color : (t > 0.25 ? mid_color : dark_color), 0.95);
			int m = motif_at(c, 9.0, 0.28, seed);
			if (m == 1)
				col = with_alpha(light_color, 1.0);
			else if (m == 2)
				col = with_alpha(outline_color, 1.0);
		}
		if (pattern == 1 && abs(d - (inner + px)) < px * 0.6) {
			float k = (a + 3.14159) * radius / px - time * 8.0;
			if (mod(floor(k), 4.0) < 2.0)
				col = with_alpha(light_color, 1.0);  // fil cousu (lundi)
		}
		// Bords des trous : une bouffee claire, on voit ou passer.
		if (gap_count > 0 && gd * radius < px * 2.5)
			col = with_alpha(light_color, 1.0);
	}
	COLOR = col * tint;
}

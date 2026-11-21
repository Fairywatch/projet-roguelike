shader_type canvas_item;
render_mode unshaded;

// Rayon (et bras qui balaie) en pixel art dessine, le long de +X (le noeud est tourne) : voir
// scripts/combat/hazards/beam.gd et sweep.gd. Bords qui ondulent, coeur lumineux, halo trame,
// contour casse comme trace a la main, poussieres et motifs qui filent dedans.
// mode 0 : annonce (une trainee d'etincelles qui serpente, de plus en plus vive) ;
// mode 1 : frappe. Lundi (pattern 1) : un rayon de lune ou danse la poussiere de sommeil.
// La zone qui blesse reste la bande droite de largeur `width`.

#include "res://assets/shaders/pixel_common.gdshaderinc"

uniform float width = 26.0;
uniform float beam_length = 1000.0;
uniform int mode = 0;
uniform float progress = 0.0;  // annonce : 0 -> 1 ; frappe : puissance 1 -> 0
uniform float taper = 0.0;  // bras qui balaie : la lame s'affine vers la pointe (0 : rayon droit)
uniform float seed = 0.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 c = cell_px(local);
	vec2 q = snap_px(local);
	float along = clamp(local.x / beam_length, 0.0, 1.0);
	float swell = 1.0 + 0.2 * (value_noise(vec2(c.x * 0.06 - time * 2.0, seed)) - 0.5) * 2.0;
	float half_w = width * 0.5 * (1.0 - taper * along) * swell;
	float y = abs(q.y);
	vec4 col = vec4(0.0);
	if (q.x < 0.0 || q.x > beam_length) {
		COLOR = col;
	} else if (mode == 0) {
		// Annonce : un couloir a peine visible, et une trainee d'etincelles qui serpente au centre.
		bool urgent = progress > 0.75 && mod(floor(time * 16.0), 2.0) == 0.0;
		if (y < half_w && stipple(c, seed) < 0.04 + 0.2 * progress)
			col = with_alpha(mid_color, 0.4);
		float snake = floor(sin(c.x * 0.12 - time * 7.0 + seed) * 1.5);
		float spark = hash12(vec2(floor(c.x / 3.0 - time * (8.0 + 20.0 * progress)), seed));
		if (abs(c.y - snake) < 0.5 && spark > 0.45 - 0.3 * progress)
			col = with_alpha(urgent ? light_color : mid_color, 0.95);
		if (length(q) < 3.0 + 6.0 * progress && bayer4(c) < 0.7)
			col = with_alpha(light_color, 0.7 + 0.3 * progress);
	} else {
		float power = progress;
		float halo = half_w * 1.6;
		if (y < halo && bayer4(c) < 0.38 * (1.0 - (y - half_w) / max(halo - half_w, 1.0)))
			col = with_alpha(mid_color, 0.45 * power);
		if (y < half_w + px && hash12(vec2(c.x, seed + sign(q.y))) > 0.25)
			col = with_alpha(outline_color, 0.85 * power);  // contour casse
		if (y < half_w)
			col = with_alpha(mid_color, 0.95 * power);
		if (y < half_w * 0.7 + (bayer4(c) - 0.5) * px)
			col = with_alpha(light_color, 0.95 * power);
		if (y < half_w * 0.28)
			col = with_alpha(vec4(1.0), 0.95 * power);
		// Poussieres et motifs qui remontent le rayon.
		float speed = pattern == 1 ? 9.0 : 18.0;
		int m = motif_at(c - vec2(floor(time * speed), 0.0), 11.0, 0.3, seed);
		if (m != 0 && y < halo)
			col = with_alpha(m == 1 ? vec4(1.0) : outline_color, power);
		if (length(q) < half_w * 1.4 + px && bayer4(c) < 0.85)
			col = with_alpha(length(q) < half_w * 0.8 ? vec4(1.0) : light_color, 0.9 * power);
	}
	COLOR = col * tint;
}

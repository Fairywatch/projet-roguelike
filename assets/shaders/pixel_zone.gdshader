shader_type canvas_item;
render_mode unshaded;

// Zone au sol en pixel art dessine (voir scripts/combat/hazards/zone.gd) : contours qui ondulent,
// traces a la main, trames douces, motifs de la nuit semes dedans. La zone qui blesse reste le
// cercle de rayon `radius` : seul le dessin s'en ecarte un peu.
// mode 0 : annonce (une ombre qui se forme) ; 1 : frappe breve (un nuage qui eclate) ;
// 2 : zone qui couve (lundi : un drap plisse, borde d'une couture) ; 3 : brume (petits nuages a
// lobes, eclaires par le haut) ; 4 : zone qui pousse (courants d'air).

#include "res://assets/shaders/pixel_common.gdshaderinc"

uniform float radius = 60.0;
uniform int mode = 0;
uniform float progress = 0.0;  // annonce : 0 -> 1 ; frappe : 0 -> 1 ; couve / brume : fondu
uniform vec2 push_dir = vec2(1.0, 0.0);
uniform float seed = 0.0;

// Champ de nuage : bosses de bruit, plus fortes au centre, pour des formes a lobes.
float cloud_field(vec2 c, float r_px) {
	float n = value_noise(c * 0.2 + vec2(time * 0.45, time * 0.2) + seed) * 0.7
		+ value_noise(c * 0.09 - vec2(time * 0.2, 0.0) + seed * 1.7) * 0.3;
	float center = 1.0 - length(c) / r_px;
	return n * 0.85 + center * 0.4;  // bosses de bruit plus fortes : plusieurs petits nuages
}

void fragment() {
	vec4 tint = COLOR;
	vec2 c = cell_px(local);
	vec2 q = snap_px(local);
	float d = length(q);
	float a = atan(q.y, q.x);
	float r = radius;
	float r_px = radius / px;
	vec4 col = vec4(0.0);
	if (mode == 0) {
		// Annonce : une ombre qui se forme, plus dense vers le bord ; le bord trace a la main ;
		// des motifs apparaissent a mesure que la frappe approche.
		float rr = r * wobble(a, 0.06, seed);
		bool urgent = progress > 0.75 && mod(floor(time * 14.0), 2.0) == 0.0;
		if (d < rr) {
			float rim = pow(d / rr, 2.0);
			float density = 0.06 + (0.18 + 0.4 * rim) * progress;
			col = stipple(c, seed) < density ? with_alpha(mid_color, 0.55) : with_alpha(mid_color, 0.05);
			int m = motif_at(c, 11.0, progress * 0.55, seed);
			if (m == 1)
				col = with_alpha(light_color, 0.85);
			else if (m == 2)
				col = with_alpha(outline_color, 0.6);
		}
		if (abs(d - rr) < px * 0.8 && hand_line((a + 3.14159) * rr / (px * 2.0) + time * 2.0, seed))
			col = with_alpha(urgent ? light_color : mid_color, 0.95);
		if (abs(d - (rr + px)) < px * 0.6 && hand_line((a + 3.14159) * rr / px, seed + 4.0))
			col = with_alpha(outline_color, 0.5);
	} else if (mode == 1) {
		// Frappe : un nuage a lobes qui eclate et s'efface, eclaire par le haut.
		float flash = 1.0 - progress;
		float lobes = 0.78 + 0.22 * pow(abs(sin(a * 3.5 + seed)), 0.6);
		float rr = r * lobes * (0.95 + 0.3 * progress);
		if (d < rr) {
			float lit = clamp(-q.y / rr * 0.8 + 0.5, 0.0, 1.0);
			vec4 base = lit > 0.62 ? light_color : (lit > 0.3 ? mid_color : dark_color);
			col = with_alpha(base, 0.95 * flash + 0.05);
			if (d < rr * 0.45 * flash)
				col = with_alpha(vec4(1.0), 0.9);
			if (bayer4(c) < progress * 0.9)
				col = vec4(0.0);  // il se dissipe en trame
		}
		if (abs(d - rr) < px * 0.8 && bayer4(c) > progress)
			col = with_alpha(outline_color, 0.95 * flash);
		int m = motif_at(c + vec2(0.0, floor(progress * 6.0)), 13.0, 0.35 * flash, seed);
		if (m != 0 && d < r * 1.3 && d > rr * 0.7)
			col = with_alpha(m == 1 ? light_color : outline_color, flash);
	} else if (mode == 2) {
		// Zone qui couve : un drap plisse qui respire (plis = bandes de bruit tramees), un bord qui
		// ondule, une couture irreguliere ; quelques motifs endormis dessus.
		float rr = r * wobble(a, 0.12, seed);  // un drap jete : bord bien irregulier
		float breath = 0.9 + 0.1 * sin(time * 2.5 + seed);
		if (d < rr) {
			// Plis du drap : de larges vagues en biais, deformees doucement, qui ondulent.
			float warp = value_noise(c * 0.05 + seed) * 5.0;
			float fold = sin((c.x * 0.55 + c.y) * 0.32 + warp + time * 0.6) * 0.5 + 0.5;
			fold += (bayer4(c) - 0.5) * 0.22;
			vec4 base = fold > 0.72 ? light_color : (fold > 0.3 ? mid_color : dark_color);
			col = with_alpha(base, 0.78 * breath * progress);
			int m = motif_at(c, 14.0, 0.22, seed);
			if (m == 1)
				col = with_alpha(light_color, progress);
			else if (m == 2)
				col = with_alpha(dark_color, progress);
		}
		if (abs(d - rr) < px * 0.8)
			col = with_alpha(outline_color, progress);
		if (pattern == 1 && abs(d - (rr - px * 2.0)) < px * 0.6) {
			float k = (a + 3.14159) * rr / px;
			if (mod(floor(k), 4.0) < 2.0 && hand_line(k * 0.5, seed + 9.0))
				col = with_alpha(light_color, progress);  // la couture
		}
	} else if (mode == 3) {
		// Brume : petits nuages a lobes (cerne, corps, rehaut en haut, ombre en bas) qui derivent ;
		// des motifs (lundi : des z) montent dedans.
		float f = cloud_field(c, r_px);
		float above = cloud_field(c + vec2(0.0, -1.0), r_px);
		float below = cloud_field(c + vec2(0.0, 1.0), r_px);
		float k = 0.62;
		if (f > k) {
			col = with_alpha(mid_color, 0.62 * progress);
			if (above < k + 0.03)
				col = with_alpha(light_color, 0.8 * progress);
			else if (below < k + 0.03)
				col = with_alpha(dark_color, 0.6 * progress);
			int m = motif_at(c + vec2(0.0, floor(time * 5.0)), 12.0, 0.3, seed);
			if (m == 1)
				col = with_alpha(light_color, 0.9 * progress);
		} else if (f > k - 0.04) {
			col = with_alpha(outline_color, 0.45 * progress);
		}
	} else {
		// Zone qui pousse : courants d'air, traits qui filent dans le sens de la poussee.
		float rr = r * wobble(a, 0.06, seed);
		if (d < rr) {
			col = with_alpha(mid_color, 0.1 * progress);
			vec2 along = vec2(dot(c, push_dir), dot(c, vec2(-push_dir.y, push_dir.x)));
			float lane = floor(along.y / 3.0);
			float run = mod(along.x - time * 40.0 / px + hash12(vec2(lane, seed)) * 40.0, 16.0);
			if (run < 5.0 && hash12(vec2(lane, seed + 1.0)) > 0.4)
				col = with_alpha(light_color, 0.75 * progress);
		}
		if (abs(d - rr) < px * 0.8 && hand_line((a + 3.14159) * rr / (px * 2.0), seed))
			col = with_alpha(outline_color, 0.6 * progress);
	}
	COLOR = col * tint;
}

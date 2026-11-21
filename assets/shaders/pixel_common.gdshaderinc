// Outils communs des dangers en pixel art (zones, anneaux, rayons) : tout est calcule sur la
// grille des pixels d'art (PX pixels du jeu, comme les sprites affiches x2), sans lissage.
// Palette de 4 tons par danger : outline (cerne), dark, mid, light ; voir PixelFx.palette().

uniform float px = 2.0;
uniform vec4 outline_color : source_color = vec4(0.1, 0.05, 0.15, 1.0);
uniform vec4 dark_color : source_color = vec4(0.4, 0.2, 0.5, 1.0);
uniform vec4 mid_color : source_color = vec4(0.7, 0.5, 0.9, 1.0);
uniform vec4 light_color : source_color = vec4(0.95, 0.9, 1.0, 1.0);
uniform int pattern = 0;  // motif de la nuit : 0 neutre, 1 lundi (tissu, coutures)
uniform float time = 0.0;
uniform float alpha = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// Centre du pixel d'art qui contient p.
vec2 snap_px(vec2 p) {
	return (floor(p / px) + 0.5) * px;
}

// Coordonnees entieres du pixel d'art.
vec2 cell_px(vec2 p) {
	return floor(p / px);
}

// Tramage ordonne 4x4 (Bayer) : seuil entre 0 et 1 pour le pixel c.
float bayer4(vec2 c) {
	int x = int(mod(c.x, 4.0));
	int y = int(mod(c.y, 4.0));
	int idx = x + y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 with_alpha(vec4 c, float a) {
	return vec4(c.rgb, c.a * a * alpha);
}

// --- Pour un rendu dessine (pas geometrique) ----------------------------------------------------

// Motifs de la nuit (tools/gen_projectiles.py) : bande de MOTIF x MOTIF pixels d'art, en deux tons
// (blanc : le motif, noir : son contour). Vide (motif_count = 0) : pas de motifs.
uniform sampler2D motifs : filter_nearest, repeat_disable;
uniform int motif_count = 0;
const float MOTIF = 8.0;

// Motif seme dans une grille de `cell` pixels d'art (densite 0..1) : 0 rien, 1 motif, 2 contour.
int motif_at(vec2 c, float cell, float density, float seed) {
	if (motif_count == 0)
		return 0;
	vec2 id = floor(c / cell);
	if (hash12(id + seed) > density)
		return 0;
	vec2 jitter = floor(vec2(hash12(id + seed + 7.1), hash12(id + seed + 3.3)) * max(cell - MOTIF, 0.0));
	vec2 inner = c - id * cell - jitter;
	if (inner.x < 0.0 || inner.y < 0.0 || inner.x >= MOTIF || inner.y >= MOTIF)
		return 0;
	float index = floor(hash12(id + seed + 11.7) * float(motif_count));
	vec2 uv = (vec2(index * MOTIF, 0.0) + inner + 0.5) / vec2(float(motif_count) * MOTIF, MOTIF);
	vec4 t = texture(motifs, uv);
	if (t.a < 0.5)
		return 0;
	return t.r > 0.5 ? 1 : 2;
}

// Bord qui ondule et respire : facteur de rayon (1 +- amp) selon l'angle, continu tout autour.
float wobble(float a, float amp, float seed) {
	vec2 around = vec2(cos(a), sin(a)) * 2.4 + vec2(seed + time * 0.35, seed * 0.7);
	return 1.0 + amp * (value_noise(around) - 0.5) * 2.0;
}

// Contour trace a la main : un trait qui saute parfois un pixel (k : position le long du bord).
bool hand_line(float k, float seed) {
	return hash12(vec2(floor(k), seed)) > 0.18;
}

// Pointille irregulier (grain de crayon) qui scintille un peu : seuil entre 0 et 1, moins
// mecanique que la trame de Bayer.
float stipple(vec2 c, float seed) {
	return hash12(c + seed + floor(time * 4.0) * 0.37);
}

shader_type canvas_item;

// Voile sombre perce d'un trou rond (le halo de la veilleuse), ou vignette elliptique.
// Le rectangle couvre l'ecran ; center, radius et feather sont en pixels 1280x720.
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 0.0;
uniform float feather = 170.0;
uniform bool ellipse = false;
uniform vec4 tint : source_color = vec4(0.016, 0.012, 0.039, 0.97);

void fragment() {
	float d = ellipse ? length((UV - 0.5) * 2.0) / 1.4142 : distance(UV * vec2(1280.0, 720.0), center);
	COLOR = vec4(tint.rgb, tint.a * smoothstep(radius, radius + feather, d));
}

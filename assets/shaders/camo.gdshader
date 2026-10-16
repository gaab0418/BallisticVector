// Repinta o sprite do tanque com uma paleta de camuflagem pela luminancia de
// cada pixel: sombras, meio e luzes viram as tres cores escolhidas, e os
// detalhes do pixel art continuam. Contornos quase pretos e luzes quase brancas
// ficam como estao. O modulate (flash de dano) e aplicado por cima.
shader_type canvas_item;

uniform vec4 c_dark : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 c_mid : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 c_light : source_color = vec4(0.8, 0.8, 0.8, 1.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float l = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 low = mix(c_dark.rgb, c_mid.rgb, smoothstep(0.1, 0.3, l));
	vec3 col = mix(low, c_light.rgb, smoothstep(0.3, 0.55, l));
	float keep = clamp(step(l, 0.08) + step(0.82, l), 0.0, 1.0);
	COLOR = vec4(mix(col, tex.rgb, keep), tex.a) * tint;
}

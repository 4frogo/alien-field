shader_type canvas_item;
// Plasma vivo: as bordas do feixe respiram por domain warping, o miolo
// tem bolhas subindo e a cor varia como um plasma real (roxo -> vermelho
// -> laranja -> amarelo -> branco quente).

uniform float speed : hint_range(0.5, 12.0) = 5.0;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise1(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise1(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// paleta de plasma: quanto mais quente, mais branco
vec3 plasma(float x) {
	x = clamp(x, 0.0, 1.0);
	vec3 roxo   = vec3(0.30, 0.02, 0.35);
	vec3 vermelho = vec3(0.95, 0.08, 0.30);
	vec3 laranja = vec3(1.00, 0.50, 0.08);
	vec3 amarelo = vec3(1.00, 0.88, 0.45);
	vec3 branco  = vec3(1.00, 1.00, 1.00);
	vec3 c;
	if (x < 0.30) {
		c = mix(roxo, vermelho, x / 0.30);
	} else if (x < 0.58) {
		c = mix(vermelho, laranja, (x - 0.30) / 0.28);
	} else if (x < 0.82) {
		c = mix(laranja, amarelo, (x - 0.58) / 0.24);
	} else {
		c = mix(amarelo, branco, (x - 0.82) / 0.18);
	}
	return c;
}

void fragment() {
	float t = TIME * speed;

	// ---- domain warping: distorce o eixo do feixe com ruido animado.
	// E o que tira o visual de "tubo" e da sensacao de coisa viva.
	vec2 wp = vec2(UV.y * 3.2 - t * 0.85, t * 0.30);
	float w1 = fbm(wp);
	float w2 = fbm(wp * 1.9 + vec2(0.0, t * 0.5));
	float sway = (w1 - 0.5) * 0.9 + (w2 - 0.5) * 0.4;

	float d = abs(UV.x - 0.5) * 2.0;
	d += sway * 0.30;               // borda organica
	float larg = 0.55 + 0.13 * sin(t * 1.7) + (w2 - 0.5) * 0.22;  // respira

	float nucleo = smoothstep(larg, 0.0, d);
	float nucleo_quente = smoothstep(larg * 0.34, 0.0, d);
	float meio = smoothstep(larg * 1.9, 0.05, d);
	float borda = smoothstep(larg * 2.3, larg * 0.6, d);

	// ---- bolhas de plasma subindo pelo miolo
	float bolha = fbm(vec2(UV.y * 7.0 - t * 1.5, UV.x * 2.0));
	float quent = nucleo_quente * (0.55 + bolha * 0.9);

	vec3 col = plasma(0.05) * borda * 0.9;
	col += plasma(0.32 + bolha * 0.20) * meio * (0.55 + 0.7 * bolha);
	col += plasma(0.62 + bolha * 0.25) * nucleo * (0.9 + 0.8 * bolha);
	col += plasma(1.0) * quent * 1.5;

	// ---- pulsos de energia subindo
	float pulso = smoothstep(0.70, 1.0, sin((UV.y * 4.0 - t * 1.1) * 6.2831) * 0.5 + 0.5);
	col += plasma(0.95) * pulso * smoothstep(larg * 1.6, 0.0, d) * 0.85;

	// ---- cintilacao RGB
	col.r += 0.12 * sin(t * 7.0 + UV.y * 20.0);
	col.g += 0.09 * sin(t * 7.0 + UV.y * 20.0 + 2.094);
	col.b += 0.14 * sin(t * 7.0 + UV.y * 20.0 + 4.188);

	vec4 tex = texture(TEXTURE, UV);
	float ponta = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float corpo = pow(max(1.0 - min(d, 1.0), 0.0), 0.9) * 0.9 + 0.1;
	float alpha = tex.a * corpo * (0.82 + 0.18 * bolha);
	alpha *= mix(0.55, 1.0, ponta);
	COLOR = vec4(col * 2.0, min(1.0, alpha));
}
shader_type canvas_item;
// SUPER LASER VERDE TRIPLO
// Usa a arte dos 3 feixes e da vida a ela: as bordas respiram por domain
// warping, bolhas sobem pelo miolo e pulsos de energia correm na direcao do
// disparo. A paleta e verde (escuro -> verde vivo -> branco quente), casando
// com o casco da Hulk2.

uniform float speed : hint_range(0.5, 12.0) = 5.0;
uniform float intensidade : hint_range(0.0, 2.0) = 1.0;

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

// Paleta verde do plasma. O topo e um verde-amarelado quente, NAO branco:
// branco puro saturava a coluna inteira e matava a leitura de "3 feixes".
vec3 plasma(float x) {
	x = clamp(x, 0.0, 1.0);
	vec3 verde_escuro = vec3(0.01, 0.16, 0.04);
	vec3 verde        = vec3(0.08, 0.88, 0.24);
	vec3 verde_claro  = vec3(0.42, 1.00, 0.44);
	vec3 quente       = vec3(0.78, 1.00, 0.62);
	vec3 c;
	if (x < 0.38) {
		c = mix(verde_escuro, verde, x / 0.38);
	} else if (x < 0.70) {
		c = mix(verde, verde_claro, (x - 0.38) / 0.32);
	} else {
		c = mix(verde_claro, quente, (x - 0.70) / 0.30);
	}
	return c;
}

void fragment() {
	float t = TIME * speed;
	vec4 tex = texture(TEXTURE, UV);

	// ---- domain warping: faz a coluna de luz tremer como coisa viva
	vec2 wp = vec2(UV.y * 3.0 - t * 0.80, t * 0.30);
	float w1 = fbm(wp);
	float w2 = fbm(wp * 1.9 + vec2(0.0, t * 0.5));
	float sway = (w1 - 0.5) + (w2 - 0.5) * 0.45;

	// desloca a amostra na horizontal para a arte "respirar"
	float dx = sway * 0.012;
	vec4 texd = texture(TEXTURE, UV + vec2(dx, 0.0));

	// ---- bolhas subindo pelo miolo
	float bolha = fbm(vec2(UV.y * 6.5 - t * 1.4, UV.x * 2.4));

	// ---- onde ha feixe (usa o alfa da arte, com a borda dilatada pelo warp)
	float corpo = clamp(tex.a + texd.a, 0.0, 1.0);
	float nucleo = smoothstep(0.30, 0.85, corpo);   // miolo branco dos feixes
	float halo   = smoothstep(0.02, 0.55, corpo);   // brilho difuso

	// ---- pulsos de energia correndo na direcao do tiro
	float pulso = smoothstep(0.62, 1.0, sin((UV.y * 3.0 + t * 1.2) * 6.2831) * 0.5 + 0.5);

	vec3 col = plasma(0.20 + bolha * 0.15) * halo * 0.80;
	col += plasma(0.58 + bolha * 0.20) * nucleo * (0.70 + 0.5 * bolha);
	col += plasma(0.90) * nucleo * pow(bolha, 3.0) * 0.55;
	col += plasma(0.85) * pulso * halo * 0.35;

	// cintilacao rapida pra dar leitura de energia viva
	col.g += 0.10 * sin(t * 8.0 + UV.y * 18.0);
	col.r += 0.05 * sin(t * 8.0 + UV.y * 18.0 + 2.094);

	// ---- pontas: some nas duas extremidades pra nao cortar seco
	float pontas = smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.90, UV.y);

	float alpha = clamp(corpo * 0.85 + halo * 0.45, 0.0, 1.0);
	alpha *= mix(0.35, 1.0, pontas);

	COLOR = vec4(col * intensidade, clamp(alpha * intensidade, 0.0, 1.0));
}
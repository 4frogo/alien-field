shader_type canvas_item;

// SHURIKEN DE ENERGIA — tiro carregado da CAIXA VERMELHA.
//
// Desenhada em coordenadas POLARES (nao SDF de segmento, que dava forma de
// quadrado): o raio maximo varia com o angulo formando 4 laminas curvas.
//
//   r_max(a) = R * (0.30 + 0.70 * |cos(2a)|^1.6)
//
//   - 4 maximos (a = 0, 90, 180, 270) = as 4 pontas
//   - 4 minimos (a = 45, 135, ...) = os vales entre as laminas
//   - as laminas sao CURVADAS: o angulo e deslocado por um termo em r,
//     que e o que da o visual de shuriken (laminas em foice)
//
// Camadas: laminas de energia -> aresta quente -> nucleo -> vortice de ruido

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform vec3 cor_energia : source_color = vec3(1.0, 0.42, 0.10);
uniform vec3 cor_quente : source_color = vec3(1.0, 0.90, 0.60);
uniform vec3 cor_nucleo : source_color = vec3(1.0, 1.0, 1.0);
uniform float intensidade : hint_range(0.0, 3.0) = 1.0;
uniform float comprimento_ponta : hint_range(0.3, 1.0) = 0.94;
uniform float curvatura : hint_range(0.0, 1.5) = 0.55;   // laminas em foice
uniform float giro : hint_range(-30.0, 30.0) = 19.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 3; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.05;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a <= 0.002) {
		discard;
	}

	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);

	// giro: o no ja gira, mas o shader tambem gira o padrao interno
	float g = tempo * giro * 0.25;

	// --- LAMINAS EM FOICE: desloca o angulo conforme o raio, criando a
	// curvatura. As pontas "atrasam" em relacao ao centro.
	float a4 = ang - g - curvatura * r * 1.6;
	float prof = 0.30 + 0.70 * pow(abs(cos(2.0 * a4)), 1.6);
	float R = comprimento_ponta * prof;

	// corpo da lamina: dentro do raio maximo
	float corpo = 1.0 - smoothstep(R - 0.10, R, r);
	// aresta: brilho fino na borda
	float aresta = (1.0 - smoothstep(0.0, 0.10, abs(r - R))) * (1.0 - smoothstep(R, R + 0.30, r));

	// --- VORTICE: ruido girando dentro das laminas (nao e plana)
	vec2 q = vec2(cos(g), sin(g)) * p * 2.4 + vec2(0.0, -tempo * 2.2);
	float vort = fbm(q);
	float energia = corpo * (0.45 + vort * 0.75);

	// --- NUCLEO: centro branco quente pulsante
	float nucleo = (1.0 - smoothstep(0.0, 0.30, r)) * (0.70 + 0.30 * sin(tempo * 12.0));

	// --- cor: energia laranja -> quente -> nucleo branco
	vec3 cor = cor_energia.rgb;
	cor = mix(cor, cor_quente.rgb, clamp(energia * 1.1 + aresta * 0.7, 0.0, 1.0));
	cor = mix(cor, cor_nucleo.rgb, clamp(nucleo + vort * 0.25, 0.0, 1.0));
	cor += cor_energia.rgb * (vort - 0.5) * 0.5;

	// --- alfa: laminas + aresta + nucleo
	float a = max(max(corpo * (0.45 + vort * 0.55), aresta * 0.9), nucleo * 0.95);
	a *= 1.0 - smoothstep(comprimento_ponta, comprimento_ponta + 0.12, r);
	a *= alfa * intensidade;

	COLOR = vec4(cor, clamp(a, 0.0, 1.0));
}
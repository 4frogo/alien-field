shader_type canvas_item;
// Nebulosa procedural + estrelas cintilantes para o fundo do space.
// Fica ATRAS das artes de cenario (z_index -20) e preenche o "vazio"
// preto com nebulosa colorida e estrelas com parallax proprio.

uniform float scroll : hint_range(0.0, 2000.0) = 0.0;
uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform vec3 cor_base = vec3(0.015, 0.008, 0.035);
uniform vec3 cor_nebulosa_a = vec3(0.35, 0.06, 0.45);   // roxo/magenta
uniform vec3 cor_nebulosa_b = vec3(0.05, 0.30, 0.42);   // azul/ciano
uniform vec3 cor_nebulosa_c = vec3(0.45, 0.10, 0.08);   // vermelho/quente
uniform float intensidade_nebulosa : hint_range(0.0, 3.0) = 1.0;
uniform float densidade_estrelas : hint_range(0.0, 1.0) = 0.75;
uniform float brilho_estrelas : hint_range(0.0, 2.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n));
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
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.02;
		amp *= 0.5;
	}
	return v;
}

// estrelas: grid com hash por celula, tamanho e brilho variaveis
vec3 estrelas(vec2 uv, float escala, float parallax, float semente) {
	vec3 acc = vec3(0.0);
	vec2 p = uv * escala;
	p.y += scroll * parallax;
	vec2 cel = floor(p);
	vec2 f = fract(p);
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			vec2 o = vec2(float(ox), float(oy));
			vec2 id = cel + o;
			vec2 h = hash22(id + semente);
			// so algumas celulas tem estrela (sparse)
			if (h.x > densidade_estrelas) {
				continue;
			}
			vec2 pos = o + vec2(h.x, h.y);
			float d = length(f - pos);
			float r = mix(0.02, 0.09, hash21(id + 17.3));
			float brilho = hash21(id + 51.7);
			// cintilacao com fase individual
			float tw = 0.55 + 0.45 * sin(tempo * mix(1.0, 4.0, brilho) + brilho * 30.0);
			float a = smoothstep(r, 0.0, d) * mix(0.35, 1.0, brilho) * tw;
			// cor da estrela: maioria branco-azulada, algumas quentes
			vec3 c = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.85, 0.65), hash21(id + 91.1));
			acc += c * a;
		}
	}
	return acc;
}

void fragment() {
	vec2 uv = UV;

	// --- nebulosa: 3 camadas de fbm com parallax diferentes ---
	vec2 p1 = vec2(uv.x * 2.4, uv.y * 1.6 - scroll * 0.030) + vec2(0.0, 0.0);
	vec2 p2 = vec2(uv.x * 4.1 + 13.7, uv.y * 2.8 - scroll * 0.055) ;
	vec2 p3 = vec2(uv.x * 7.3 + 41.2, uv.y * 5.1 - scroll * 0.090) ;

	float n1 = fbm(p1);
	float n2 = fbm(p2);
	float n3 = fbm(p3);

	// gradiente vertical: mais quente embaixo, mais frio em cima
	float g = uv.y;

	vec3 neb = vec3(0.0);
	neb += cor_nebulosa_a * pow(smoothstep(0.25, 1.0, n1), 2.0) * (0.55 + 0.45 * g);
	neb += cor_nebulosa_b * pow(smoothstep(0.35, 1.0, n2), 2.2) * (0.60 * (1.0 - g) + 0.20);
	neb += cor_nebulosa_c * pow(smoothstep(0.45, 1.0, n3), 2.6) * (0.30 + 0.55 * g);

	// brilho interno das "nuvens" densas
	neb += vec3(0.10, 0.05, 0.16) * pow(n1 * n2, 1.5) * 2.0;

	neb *= intensidade_nebulosa;

	// --- estrelas em 3 profundidades ---
	vec3 st = estrelas(uv, 26.0, 0.075, 0.0)   * 0.55;
	st += estrelas(uv, 44.0, 0.130, 31.7)       * 0.85;
	st += estrelas(uv, 72.0, 0.215, 77.3)       * 1.15;
	st *= brilho_estrelas;

	// --- vinheta suave nas bordas pra focar o centro ---
	vec2 c = uv - vec2(0.5);
	float vinh = 1.0 - smoothstep(0.32, 0.78, length(c * vec2(1.0, 0.62)));
	neb *= mix(0.55, 1.0, vinh);
	st  *= mix(0.65, 1.0, vinh);

	vec3 col = cor_base + neb + st;

	COLOR = vec4(col, 1.0);
}
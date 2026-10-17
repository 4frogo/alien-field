shader_type canvas_item;

// RASTRO DE PLASMA  tiro do jogador.
//
// Aplicado num Sprite2D rotacionado para a velocidade do projetil:
//   UV.y = 0 e a CAUDA (tras), UV.y = 1 e a PONTA (frente).
//
// Camadas, da cauda pra frente:
//   1. FORMA: fita que afina e ondula (ruido), nao um losango rigido
//   2. RESFRIAMENTO: verde vivo -> amarelo -> vermelho -> apaga na cauda
//   3. NUCLEO: branco saturado so na metade da frente
//   4. ELETRICO: ruido rapido ao longo do comprimento (fase do plasma)
//   5. GRADE: micro-interferencia que da "textura" de energia

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform vec3 cor_viva : source_color = vec3(0.20, 1.00, 0.42);
uniform vec3 cor_meia : source_color = vec3(0.85, 1.00, 0.35);
uniform vec3 cor_fria : source_color = vec3(1.00, 0.32, 0.08);
uniform vec3 cor_nucleo : source_color = vec3(1.0, 1.0, 1.0);
uniform float comprimento : hint_range(0.1, 1.0) = 0.5;  // 0..1 na UV.y
uniform float largura : hint_range(0.05, 1.0) = 0.35;     // meia-largura
uniform float nucleo : hint_range(0.0, 1.0) = 0.75;
uniform float ruido : hint_range(0.0, 1.0) = 0.35;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float semente = 0.0;

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

	float t = tempo + semente;
	// posicao ao longo do rastro: 0 = cauda, 1 = frente
	float f = UV.y;

	// --- FORMA: afina da frente pra cauda e ondula com ruido
	float largura_rel = comprimento > 0.0 ? pow(f, 0.55) : 0.0;
	largura_rel *= largura * (0.82 + 0.36 * fbm(vec2(UV.x * 2.0, f * 4.0 - t * 2.2)));

	float dist = abs(UV.x - 0.5) * 2.0;
	float dentro = 1.0 - smoothstep(largura_rel - 0.14, largura_rel, dist);
	if (dentro <= 0.002) {
		discard;
	}

	// --- RESFRIAMENTO: a frente e viva, a cauda esfriou e morre
	vec3 cor = cor_viva;
	cor = mix(cor, cor_meia, smoothstep(0.25, 0.65, f));
	cor = mix(cor, cor_fria, smoothstep(0.0, 0.35, 1.0 - f));

	// --- ELETRICO: ruido correndo pela frente (na cauda e caotico)
	float elec = fbm(vec2(UV.x * 4.0 + semente, f * 7.0 - t * 6.0)) - 0.5;
	cor += cor_meia * elec * ruido * smoothstep(0.1, 0.9, f);

	// --- NUCLEO: branco so na metade da frente, e no eixo
	float eixo = 1.0 - smoothstep(0.0, 0.42, dist / max(largura_rel, 0.001));
	float nucleo_f = smoothstep(0.45, 1.0, f);
	cor = mix(cor, cor_nucleo, clamp(eixo * nucleo_f * nucleo, 0.0, 1.0));

	// --- GRADE: micro interferencia transversal
	float grade = 0.5 + 0.5 * sin(f * 60.0 - t * 9.0);
	cor *= 0.88 + 0.22 * grade;

	// --- ALFA: opaco na frente, dissolve na cauda
	float a = dentro * smoothstep(0.0, 0.30, f) * (0.55 + 0.45 * f);
	a *= (0.80 + 0.20 * (elec + 0.5) * 2.0);
	a *= alfa;

	COLOR = vec4(cor, clamp(a, 0.0, 1.0));
}
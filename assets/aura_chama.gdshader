shader_type canvas_item;

// AURA DE CHAMA  envolve a nave enquanto a arma (Gunn) esta ativa.
//
// Nao e um escudo: e "a nave esta em chamas" de arma equipada. Camadas:
//   1. CHAMA: ruido que rola para cima, recortado numa elipse ao redor
//      da nave (mais larga embaixo, como chamas de motor)
//   2. LINGUA: pontas de fogo que sobem pela silhueta
//   3. NUCLEO: um calor branco-alaranjado dentro da nave
//   4. CINZA: fumaca escura que sobe (quebra a corso verde verde)
//   5. BORDA: um arco quente na frente inferior, como calor de saida
//
// Uniform `ativo` e o master: 0 = invisivel, 1 = plena. Quem anima e o
// script escudo_bolha-like (aura_chama.gd), que reduz no fim da duracao.

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform float ativo : hint_range(0.0, 1.0) = 1.0;
uniform vec3 cor_fogo : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 cor_quente : source_color = vec3(1.0, 0.94, 0.72);
uniform vec3 cor_nucleo : source_color = vec3(0.95, 0.45, 0.10);
uniform float intensidade : hint_range(0.0, 3.0) = 1.0;
uniform float velocidade : hint_range(0.0, 6.0) = 1.7;
uniform float largura : hint_range(0.2, 2.0) = 1.0;

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
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.05;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// mascara branca do quad
	vec4 src = texture(TEXTURE, UV);
	if (src.a <= 0.002) {
		discard;
	}

	vec2 p = (UV - vec2(0.5)) * 2.0;      // -1..1
	float t = tempo * velocidade;

	// --- elipse da aura: mais larga embaixo (chama de motor), estreita
	// em cima. A forma e a "silhueta" que a aura aceita.
	vec2 e = p * vec2(1.0 / largura, 1.0);
	e.y *= 1.25;                            // achata no eixo Y
	float ell = length(e);

	// a aura envolve a nave mas nao e um disco: tem topo irregular
	float topo = 0.85 + 0.20 * fbm(vec2(p.x * 3.0, t * 0.8));
	float borda_sup = 1.0 - smoothstep(0.55 * topo, 0.95 * topo, -p.y - 0.3);
	float base = 1.0 - smoothstep(0.70, 1.0, p.y);

	float dentro = (1.0 - smoothstep(0.65, 0.95, ell)) * borda_sup * base;
	if (dentro <= 0.002) {
		discard;
	}

	// --- CHAMA: ruido rolando pra cima,varios oitavas
	vec2 q = vec2(p.x * 2.6, p.y * 2.0 - t * 2.2);
	float f = fbm(q);
	float f2 = fbm(q * 2.1 + vec2(t * 0.7, -t * 1.4));

	// --- CINZA: fumaca escura, mais visivel nas bordas
	float fumaca = fbm(vec2(p.x * 1.8 - t * 0.6, p.y * 1.5 - t * 1.1));
	vec3 cor = cor_nucleo.rgb * (0.35 + f * 0.5);
	cor = mix(cor, vec3(0.10, 0.09, 0.10), smoothstep(0.45, 0.85, fumaca) * 0.45);

	// --- calor: mais quente no centro-baixo, esfria nas pontas
	float calor = (1.0 - ell) * 0.6 + (0.5 - p.y * 0.5) * 0.4;
	calor = clamp(calor + (f - 0.5) * 0.8, 0.0, 1.0);
	cor = mix(cor, cor_fogo.rgb, smoothstep(0.2, 0.7, calor));
	cor = mix(cor, cor_quente.rgb, pow(calor, 2.5) * 0.8);

	// --- NUCLEO: um claro quente bem dentro da nave
	float nucleo = pow(max(0.0, 1.0 - ell * 1.5), 3.0) * (0.5 - p.y * 0.5);
	cor += cor_quente.rgb * nucleo * 0.7;

	// --- LINGUA: pontas subindo pela borda
	float lingua = pow(1.0 - abs(f - 0.5) * 2.0, 3.0);
	cor += cor_quente.rgb * lingua * 0.5 * smoothstep(0.2, 0.8, -p.y);

	// --- alfa:.Combine mascaras, decomposto pelo calor (a chama "enfraquece" nas pontas)
	float a = dentro * (0.30 + calor * 0.85 + lingua * 0.35 + nucleo * 0.5);
	a *= ativo * intensidade;
	a *= 0.75 + 0.25 * f;

	COLOR = vec4(cor, clamp(a, 0.0, 1.0));
}
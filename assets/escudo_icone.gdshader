shader_type canvas_item;
// Icone de ESCUDO (escudoG.png): o liquido dentro da moldura e feito de
// PARTICULAS de plasma — verdes + vermelhas, 2 escalas fervendo no
// lugar. Ele drena da DIREITA PRA ESQUERDA quando a nave sofre dano
// (nivel = escudo/escudo_max; cheio = camara cheia; dano = a camara
// esvazia da direita pra esquerda ate sumir). O PNG vem com fundo preto
// OPUACO — key por CANAL MAXIMO abre o fundo; qualquer tom colorido
// (metal verde sombreado inclusive) fica solido. Moldura POR CIMA.

uniform sampler2D tex : source_color, filter_linear;
uniform float nivel : hint_range(0.0, 1.0) = 1.0;
uniform float tempo = 0.0;

const vec3 VERDE = vec3(0.24, 1.0, 0.44);
const vec3 VERDE_FUND = vec3(0.03, 0.30, 0.11);
const vec3 VERMELHA = vec3(1.0, 0.30, 0.24);
const vec3 BRANCO_PART = vec3(0.80, 1.0, 0.86);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 orna = texture(tex, UV);
	// key por CANAL MAXIMO (nao luminancia): preto puro = fundo; qualquer
	// tom colorido (o verde sombreado do metal inclusive) fica SOLIDO
	float chaves = max(orna.r, max(orna.g, orna.b));
	float oa = smoothstep(0.015, 0.045, chaves);

	// "vidro" interno: elipse no buraco da moldura
	vec2 e = (UV - vec2(0.5)) / vec2(0.335, 0.180);
	float d = length(e);
	float dentro = 1.0 - smoothstep(0.88, 1.0, d);

	// frente ondulante: liquido ancorado na ESQUERDA; o dano drena da
	// direita pra esquerda (fx: 1.0 cheio -> 0.0 vazio)
	float onda = sin(UV.y * 11.0 + tempo * 2.8) * 0.012
		+ sin(UV.y * 23.0 - tempo * 4.1) * 0.006;
	float fx = nivel + onda * (0.30 + 0.70 * (1.0 - nivel));
	float liq = smoothstep(fx + 0.006, fx - 0.004, UV.x); // x < frente

	// ---- PARTICULAS de plasma: 2 escalas fervendo dentro do liquido ----
	float dens = 0.0;
	vec3 cor_dens = vec3(0.0);
	for (int camada = 0; camada < 2; camada++) {
		float fc = float(camada);
		vec2 grade = mix(vec2(30.0, 15.0), vec2(46.0, 23.0), fc);
		vec2 p = UV * grade
			+ vec2(tempo * (0.10 + 0.13 * fc), tempo * 0.045 * fc);
		vec2 cid = floor(p);
		vec2 lf = fract(p) - 0.5;
		vec2 off = vec2(hash(cid + 7.0 + fc * 3.1),
			hash(cid + 13.0 - fc * 2.3)) - 0.5;
		// fervura: cada particula treme no lugar
		vec2 tremer = vec2(sin(tempo * 5.3 + hash(cid) * 40.0),
			cos(tempo * 4.7 + hash(cid + 3.0) * 40.0)) * 0.13;
		float dd = length(lf - off * 0.72 - tremer);
		float tam = 0.15 + 0.20 * hash(cid + 5.0);
		float nucleo = smoothstep(tam, tam * 0.35, dd);
		float halo = smoothstep(tam * 2.6, tam * 0.5, dd) * 0.42;
		// verde ou vermelha (~26% vermelhas); nucleo clarinho
		vec3 cp = mix(VERDE, VERMELHA, step(0.74, hash(cid + 9.0)));
		cp = mix(cp, BRANCO_PART, nucleo * 0.5);
		float brl = nucleo + halo;
		// a particula mais viva da celula vence a mistura de cor
		cor_dens = mix(cor_dens, cp, step(dens, brl));
		dens = max(dens, brl);
	}

	// corpo: leito fraco do liquido, mais vivo perto da frente
	float leito = liq * dentro;
	float prof = clamp(1.0 - (fx - UV.x) * 3.0, 0.0, 1.0); // 1 = na frente
	vec3 cl = mix(VERDE_FUND, VERDE, prof * 0.55);
	// particulas por cima do leito
	cl = mix(cl, cor_dens, clamp(dens, 0.0, 1.0));

	// menisco na frente (nucleo + halo largo)
	float m_core = smoothstep(0.008, 0.0, abs(UV.x - fx)) * dentro;
	float m_halo = smoothstep(0.055, 0.0, abs(UV.x - fx)) * dentro;
	cl = mix(cl, BRANCO_PART, m_core * 0.85);

	// vidro escuro de fundo (container legivel com escudo vazio)
	float a1 = 0.30 * dentro;
	// liquido por cima do vidro
	float a2 = clamp(leito * 0.45 + dens * leito * 0.85
		+ m_core * 0.85 + m_halo * 0.28, 0.0, 1.0);
	vec3 c = cl * a2 + vec3(0.02, 0.09, 0.05) * a1 * (1.0 - a2);
	float a = a2 + a1 * (1.0 - a2);
	if (a > 0.001) {
		c /= a;
	}
	// moldura por cima (preto keyado vira transparente)
	c = orna.rgb * oa + c * (1.0 - oa);
	a = oa + a * (1.0 - oa);
	COLOR = vec4(c, a);
}

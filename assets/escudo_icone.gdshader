shader_type canvas_item;
// Icone de ESCUDO (escudoG.png): quad 2x alto — metade de baixo = arte,
// metade de cima = AR da explosao. O liquido e feito de PARTICULAS de
// plasma (verdes + vermelhas fervendo, 2 escalas) e drena da DIREITA
// PRA ESQUERDA com o dano. Ao ZERAR o vidro ESTOURA (clarao, trincas,
// onda de choque) e o liquido vira particulas que voam pelo ar. Escudo
// CRITICO (ultimo quarto): particulas ficam vermelhas e o liquido
// pulsa. PNG com fundo preto OPUACO — key por CANAL MAXIMO abre o
// fundo; a moldura e desenhada POR CIMA do liquido.

uniform sampler2D tex : source_color, filter_linear;
uniform float nivel : hint_range(0.0, 1.0) = 1.0;
uniform float critico : hint_range(0.0, 1.0) = 0.0;
uniform float explosao : hint_range(0.0, 1.0) = 0.0;
uniform float nivel_exp : hint_range(0.0, 1.0) = 1.0;
uniform float tempo = 0.0;

const vec3 VERDE = vec3(0.24, 1.0, 0.44);
const vec3 VERDE_FUND = vec3(0.03, 0.30, 0.11);
const vec3 VERMELHA = vec3(1.0, 0.30, 0.24);
const vec3 BRANCO_PART = vec3(0.80, 1.0, 0.86);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// espaco da arte: quad 2x alto, arte na metade de baixo (uva = 0..1)
	vec2 uva = vec2(UV.x, (UV.y - 0.5) * 2.0);
	float na_arte = step(0.0, uva.y) * step(uva.y, 1.0);
	vec4 orna = texture(tex, clamp(uva, vec2(0.0), vec2(1.0)));
	// key por CANAL MAXIMO (nao luminancia): preto puro = fundo; tom
	// colorido (o verde sombreado do metal inclusive) fica SOLIDO
	float chaves = max(orna.r, max(orna.g, orna.b));
	float oa = smoothstep(0.015, 0.045, chaves) * na_arte;

	// "vidro" interno: elipse no buraco da moldura
	vec2 e = (uva - vec2(0.5)) / vec2(0.335, 0.180);
	float d = length(e);
	float dentro = 1.0 - smoothstep(0.88, 1.0, d);

	// frente ondulante: liquido ancorado na ESQUERDA; o dano drena da
	// direita pra esquerda (fx: 1.0 cheio -> 0.0 vazio)
	float onda = sin(uva.y * 11.0 + tempo * 2.8) * 0.012
		+ sin(uva.y * 23.0 - tempo * 4.1) * 0.006;
	float fx = nivel + onda * (0.30 + 0.70 * (1.0 - nivel));
	float liq = smoothstep(fx + 0.006, fx - 0.004, uva.x);

	// ---- PARTICULAS de plasma: 2 escalas fervendo dentro do liquido ----
	float dens = 0.0;
	vec3 cor_dens = vec3(0.0);
	for (int camada = 0; camada < 2; camada++) {
		float fc = float(camada);
		vec2 grade = mix(vec2(30.0, 15.0), vec2(46.0, 23.0), fc);
		vec2 p = uva * grade
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
		// verde ou vermelha (~26%); CRITICO empurra a mistura pro vermelho
		vec3 cp = mix(VERDE, VERMELHA,
			step(0.74 - 0.45 * critico, hash(cid + 9.0)));
		cp = mix(cp, BRANCO_PART, nucleo * 0.5);
		float brl = nucleo + halo;
		// a particula mais viva da celula vence a mistura de cor
		cor_dens = mix(cor_dens, cp, step(dens, brl));
		dens = max(dens, brl);
	}

	// corpo: leito fraco do liquido, mais vivo perto da frente
	float leito = liq * dentro;
	float prof = clamp(1.0 - (fx - uva.x) * 3.0, 0.0, 1.0); // 1 = na frente
	vec3 cl = mix(VERDE_FUND, VERDE, prof * 0.55);
	// particulas por cima do leito
	cl = mix(cl, cor_dens, clamp(dens, 0.0, 1.0));

	// menisco na frente (nucleo + halo); CRITICO esquenta a cor dele
	vec3 cor_men = mix(BRANCO_PART, vec3(1.0, 0.62, 0.55), critico);
	float m_core = smoothstep(0.008, 0.0, abs(uva.x - fx)) * dentro;
	float m_halo = smoothstep(0.055, 0.0, abs(uva.x - fx)) * dentro;
	cl = mix(cl, cor_men, m_core * 0.85);
	// CRITICO: liquido pulsa em brilho ate o escudo ser recomprado
	cl *= 1.0 + 0.32 * critico * (0.5 + 0.5 * sin(tempo * 9.0));

	// EXPLOSAO: liquido some cedo e o vidro estoura (repara no fim)
	float liq_exp = 1.0 - smoothstep(0.0, 0.18, explosao);
	float vidro = 1.0 - smoothstep(0.0, 0.06, explosao)
		* (1.0 - smoothstep(0.80, 0.98, explosao));
	// vidro escuro de fundo (container legivel com escudo vazio)
	float a1 = 0.30 * dentro * vidro;
	// liquido por cima do vidro
	float a2 = clamp(leito * 0.45 + dens * leito * 0.85
		+ m_core * 0.85 + m_halo * 0.28, 0.0, 1.0) * liq_exp;
	vec3 c = cl * a2 + vec3(0.02, 0.09, 0.05) * a1 * (1.0 - a2);
	float a = a2 + a1 * (1.0 - a2);
	if (a > 0.001) {
		c /= a;
	}
	// moldura por cima (preto keyado vira transparente)
	c = orna.rgb * oa + c * (1.0 - oa);
	a = oa + a * (1.0 - oa);

	// ---------------- EXPLOSAO DO ESCUDO ----------------
	// o vidro estoura (clarao + trincas + onda de choque) e o liquido
	// vira particulas que voam pelo ar, caindo com gravidade
	if (explosao > 0.001) {
		float ex = explosao;
		vec2 dd = (uva - vec2(0.5)) * vec2(1.0, 2.0);
		float rr = length(dd);
		float aa = atan(dd.y, dd.x);

		// clarao do estouro (instante zero)
		float flash = smoothstep(0.12, 0.0, ex) * dentro;
		c = mix(c, vec3(1.0), flash * 0.85);
		a = max(a, flash * 0.85);

		// onda de choque expandindo pra fora (esverdeada)
		float anel_e = smoothstep(0.025, 0.0, abs(rr - ex * 1.15))
			* (1.0 - smoothstep(0.30, 0.65, ex));
		c = mix(c, vec3(0.85, 1.0, 0.9), anel_e * 0.8);
		a = max(a, anel_e * 0.8);

		// trincas radiais serrilhadas (3 raios)
		float setor = floor((aa + 3.14159) / 2.0944);
		float ang_set = (setor - 1.0) * 2.0944
			+ (hash(vec2(setor, 7.0)) - 0.5) * 0.9;
		float dist_ang = abs(aa - ang_set) * rr;
		float serr = (hash(vec2(floor(rr * 42.0), setor)) - 0.5) * 0.06;
		float trinca = smoothstep(0.018, 0.0, abs(dist_ang - serr))
			* smoothstep(0.58, 0.12, rr);
		trinca *= smoothstep(0.01, 0.06, ex) * (1.0 - smoothstep(0.25, 0.60, ex));
		c = mix(c, vec3(1.0), trinca * 0.9);
		a = max(a, trinca * 0.9);

		// particulas: nascem do volume do liquido e voam pelo ar
		vec2 pc = uva * vec2(34.0, 17.0);
		vec2 cid = floor(pc);
		vec2 rnd = vec2(hash(cid + 1.1), hash(cid + 4.7)) - 0.5;
		float dist = 0.35 + 0.85 * hash(cid + 8.3);
		vec2 origem = vec2(hash(cid + 12.9) * nivel_exp - 0.5,
			(hash(cid + 15.3) - 0.5) * 0.34);
		vec2 pos = origem + rnd * vec2(2.0, 3.4) * dist * ex;
		pos.y += 0.55 * ex * ex; // cai no ar
		vec2 dp = (uva - vec2(0.5) - pos) * vec2(1.0, 2.0);
		float tam = (0.020 + 0.030 * hash(cid + 20.7)) * (1.0 - ex * 0.55);
		float part = smoothstep(tam, tam * 0.35, length(dp));
		float vivas = step(hash(cid + 26.1), 0.72); // so 72% viram particula
		part *= vivas * (1.0 - ex) * (1.0 - ex);
		vec3 cor_part = mix(VERDE, VERMELHA, step(0.6, hash(cid + 31.0)));
		cor_part = mix(cor_part, BRANCO_PART, clamp(0.75 - ex, 0.0, 1.0));
		c = cor_part * part + c * (1.0 - part);
		a = part + a * (1.0 - part);
	}
	COLOR = vec4(c, a);
}

shader_type canvas_item;
// barrasuperhold.png com PLASMA ELETRIFICADO enchendo da esquerda pra
// direita com a carga. O quad e 2x mais alto que a arte: metade de baixo
// = icone, metade de cima = AR, onde os raios REALISTAS voam quando a
// carga chega no maximo com o L ainda segurado (pronta).
// Camadas de energia no liquido: nucleo tubular, turbulencia gaseosa,
// faixas rolando, 2 filamentos, 2 ARCOS serrilhados, faiscas com halo,
// rim aceso no tanque, menisco com halo largo e tremida global.
// RELAMPOS: trilho serrilhado, nucleo branco + halo azulado, uma
// ramificacao por raio e estroboscopio (RESTRIKE: novo raio a cada
// ciclo, semente nova). Soltou o tiro: o vidro ESTOURA (clarao +
// trincas + onda de choque) e o liquido vira particulas no ar.

uniform sampler2D tex : source_color, filter_linear;
uniform float carga : hint_range(0.0, 1.0) = 0.0;
uniform float pronto : hint_range(0.0, 1.0) = 0.0;
uniform float tempo = 0.0;
uniform float explosao : hint_range(0.0, 1.0) = 0.0;
uniform float carga_exp : hint_range(0.0, 1.0) = 1.0;

const vec3 VERMELHO = vec3(1.0, 0.14, 0.09);
const vec3 LARANJA = vec3(1.0, 0.52, 0.07);
const vec3 AMARELO = vec3(1.0, 0.90, 0.33);
const vec3 BRANCO_QUENTE = vec3(1.0, 0.97, 0.86);
const vec3 AZUL_ELETRICO = vec3(0.42, 0.76, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// distancia de um ponto a um segmento
float dist_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
	return length(pa - ba * h);
}

// raio REALISTA: trilho serrilhado de 6 trechos (zigzag com deslocamento
// perpendicular; envelope sin() zera o desvio nas pontas e maxima no meio)
float raio_zig(vec2 p, vec2 ini, vec2 fim, float semente, float amp) {
	vec2 dir = fim - ini;
	float comp = max(length(dir), 1e-4);
	vec2 nor = vec2(-dir.y, dir.x) / comp;
	float dmin = 1e9;
	vec2 ant = ini;
	for (int i = 1; i <= 6; i++) {
		float t = float(i) / 7.0;
		float desl = (hash(vec2(semente, float(i) * 3.7)) - 0.5)
			* amp * comp * sin(t * 3.14159);
		vec2 pt = ini + dir * t + nor * desl;
		dmin = min(dmin, dist_seg(p, ant, pt));
		ant = pt;
	}
	dmin = min(dmin, dist_seg(p, ant, fim));
	return dmin;
}

// arco eletrico: trilho serpenteante + serrilhado ruidoso (distancia)
float arco(vec2 uv, float t, float seed) {
	float trilho = 0.5 + 0.30 * sin(uv.x * (6.0 + seed * 5.0) + seed * 17.0
		+ t * (4.5 + seed * 3.0));
	float serril = (hash(vec2(floor(uv.x * 30.0 + t * 26.0), seed * 91.0)) - 0.5) * 0.16;
	return abs(uv.y - trilho - serril);
}

// faisca COM halo: ponto luminoso dentro da celula (nao pixel solto)
float faisca_halo(vec2 uv, vec2 dens, float vel, float lim, float t) {
	vec2 p = uv * dens + vec2(t * vel, -t * vel * 1.3);
	vec2 cid = floor(p);
	vec2 lf = fract(p) - 0.5;
	vec2 off = vec2(hash(cid + 7.0), hash(cid + 13.0)) - 0.5;
	float d = length(lf - off * 0.6);
	float h = hash(cid);
	float tw = 0.55 + 0.45 * sin(t * 37.0 + h * 80.0);
	return step(lim, h) * smoothstep(0.34, 0.0, d) * tw;
}

void fragment() {
	// espaco da arte: quad 2x alto, arte na metade de baixo (uva = 0..1)
	vec2 uva = vec2(UV.x, (UV.y - 0.5) * 2.0);
	float na_arte = step(0.0, uva.y) * step(uva.y, 1.0);
	vec4 orna = texture(tex, clamp(uva, vec2(0.0), vec2(1.0)));
	// key por CANAL MAXIMO (nao luminancia): preto puro = fundo; qualquer
	// tom colorido (o verde sombreado do metal inclusive) fica SOLIDO
	float chaves = max(orna.r, max(orna.g, orna.b));
	float oa = smoothstep(0.015, 0.045, chaves) * na_arte;

	// tanque: elipse na camara do ornamento
	vec2 e = (uva - vec2(0.5)) / vec2(0.380, 0.215);
	float le = length(e);
	float dentro = 1.0 - smoothstep(0.86, 1.0, le);

	// frente ondulante da esquerda (0) pra direita (1)
	float ond = sin(uva.y * 18.0 + tempo * 6.0) * 0.009
		+ sin(uva.y * 41.0 - tempo * 9.5) * 0.005
		+ sin(uva.y * 90.0 + tempo * 14.0) * 0.002;
	float fx = carga + ond * (0.35 + 0.65 * (1.0 - carga));
	float df = fx - uva.x;                   // >0: dentro do liquido
	float liq = smoothstep(-0.003, 0.006, df);
	float deep = clamp(df * 2.4, 0.0, 1.0); // 0 = frente, 1 = fundo

	// cor base do plasma pela carga
	vec3 cor_liq = mix(AMARELO, LARANJA, smoothstep(0.0, 0.55, carga));
	cor_liq = mix(cor_liq, VERMELHO, smoothstep(0.55, 1.0, carga));

	// nucleo tubular (brilha no meio da altura)
	float tubo = smoothstep(0.42, 0.02, abs(uva.y - 0.5));

	// turbulencia gaseosa
	float w1 = sin(uva.x * 14.0 + tempo * 3.2) * sin(uva.y * 21.0 - tempo * 2.6);
	float w2 = sin((uva.x + uva.y) * 27.0 - tempo * 4.8)
		* sin((uva.x - uva.y) * 33.0 + tempo * 4.1);
	float turb = 0.5 + 0.28 * w1 + 0.22 * w2;

	// faixas de energia rolando pra tras
	float faixa = pow(0.5 + 0.5 * sin(uva.x * 10.0 + uva.y * 4.0 + tempo * 9.0), 4.0);

	// 2 filamentos serpenteando, cintilando
	float f1 = smoothstep(0.030, 0.0,
		abs(uva.y - (0.40 + 0.09 * sin(uva.x * 17.0 + tempo * 8.5))));
	float f2 = smoothstep(0.024, 0.0,
		abs(uva.y - (0.60 + 0.08 * sin(uva.x * 21.0 - tempo * 10.5 + 2.0))));
	float filamentos = (f1 * 0.70 + f2 * 0.55)
		* (0.35 + 0.65 * (0.5 + 0.5 * sin(tempo * 23.0 + uva.x * 6.0)));

	// 2 ARCOS eletricos serrilhados atravessando o liquido
	float da1 = arco(uva, tempo, 0.0);
	float da2 = arco(uva, tempo * 1.25, 1.7);
	float arcos = smoothstep(0.042, 0.0, da1) * 0.55
		+ smoothstep(0.013, 0.0, da1) * 1.15
		+ smoothstep(0.036, 0.0, da2) * 0.45
		+ smoothstep(0.011, 0.0, da2) * 1.00;
	// piscam em fatias de tempo (arco nao fica ligado direto)
	arcos *= 0.30 + 0.70 * (0.35 + 0.65 * hash(vec2(floor(tempo * 13.0), 5.0)));

	// faiscas em 2 escalas, com halo
	float fa1 = faisca_halo(uva, vec2(54.0, 24.0), 0.0, 0.972, tempo);
	float fa2 = faisca_halo(uva + vec2(0.37, 0.11), vec2(72.0, 34.0), 0.35, 0.958, tempo * 1.7);
	float faiscas = fa1 * 1.15 + fa2 * 0.75;

	// rim aceso do tanque (vidro eletrificado)
	float anel = smoothstep(0.68, 0.86, le) * dentro
		* (0.35 + 0.30 * sin(tempo * 8.0 + le * 14.0));

	// ------- energia total -------
	float energia = tubo * (0.45 + 0.75 * turb) * (0.50 + 0.55 * (1.0 - deep))
		+ faixa * 0.55
		+ filamentos * 1.0
		+ arcos * liq
		+ faiscas * liq
		+ anel * 0.5;
	energia = max(energia, 0.0);

	// corpo: bordas escuras -> cor viva -> branco quente
	vec3 cl = mix(cor_liq * 0.18, cor_liq, clamp(energia, 0.0, 1.0));
	cl = mix(cl, BRANCO_QUENTE, clamp(energia - 0.82, 0.0, 1.0) * 0.9);
	// overbright: pontos quentes explodem de luz
	cl *= 1.0 + 0.30 * clamp(energia - 1.0, 0.0, 1.0);

	// alpha emissivo mais opaco (plasma e luz, nao tinta)
	float a_liq = liq * dentro * clamp(0.52 + energia * 0.60, 0.0, 1.0);

	// menisco: nucleo branco + halo largo sangrando pra fora
	float m_core = smoothstep(0.007, 0.0, abs(df)) * dentro;
	float m_halo = smoothstep(0.065, 0.0, abs(df)) * dentro;
	cl = mix(cl, BRANCO_QUENTE, m_core * 0.9);
	a_liq = max(a_liq, m_core * 0.95);
	a_liq = max(a_liq, m_halo * 0.50);

	// EXPLOSAO: liquido vai pro ar e o vidro estoura (repara no fim)
	float liq_ae = a_liq * (1.0 - smoothstep(0.0, 0.18, explosao));
	float vidro = 1.0 - smoothstep(0.0, 0.06, explosao)
		* (1.0 - smoothstep(0.80, 0.98, explosao));
	// vidro escuro do tanque vazio (legivel sem carga)
	float a1 = 0.28 * dentro * vidro;
	vec3 c = cl * liq_ae + vec3(0.10, 0.035, 0.02) * a1 * (1.0 - liq_ae);
	float a = liq_ae + a1 * (1.0 - liq_ae);
	if (a > 0.001) {
		c /= a;
	}
	// moldura por cima (preto keyado = transparente)
	c = orna.rgb * oa + c * (1.0 - oa);
	a = oa + a * (1.0 - oa);

	// tremida eletrica global enquanto carrega
	c *= 1.0 + 0.05 * sin(tempo * 41.0) * step(0.02, carga) * (1.0 - pronto * 0.5);

	// PRONTA: pulso de brilho neutro ate o tiro sair (RGB removido a pedido)
	c *= 1.0 + 0.24 * pronto * sin(tempo * 9.0);

	// ------------- RAIOS REALISTAS (pronta: L segurado no maximo) -------------
	// RELAMPOS nascendo do liquido e voando pro AR acima do icone:
	// trilho serrilhado de 6 trechos + 1 ramificacao, nucleo branco
	// quente com halo azulado, estroboscopio e RESTRIKE (novo raio a
	// cada ciclo de tempo, com semente nova -> caminho sempre diferente)
	if (pronto > 0.02) {
		float flick = 0.45 + 0.55
			* step(0.30, hash(vec2(floor(tempo * 43.0), 2.0)));
		float alpha_r = 0.0;
		vec3 cor_r = vec3(0.0);
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float s = floor(tempo * 6.5) * 3.13 + fk * 19.7;
			// nasce em algum ponto do liquido (a camara estah cheia)
			vec2 ini = vec2(0.10 + 0.80 * hash(vec2(s, 1.0)),
				0.60 + 0.10 * hash(vec2(s, 2.0)));
			// voa pro ar, com inclinacao aleatoria
			float incl = (hash(vec2(s, 3.0)) - 0.5) * 0.85;
			vec2 fim = vec2(clamp(0.5 + incl, 0.02, 0.98),
				0.03 + 0.30 * hash(vec2(s, 4.0)));
			vec2 dir = fim - ini;
			float comp = max(length(dir), 1e-4);
			vec2 nor = vec2(-dir.y, dir.x) / comp;
			float d = raio_zig(UV, ini, fim, s, 0.30);
			// ramificacao saindo do meio do trilho
			vec2 base = mix(ini, fim, 0.35 + 0.30 * hash(vec2(s, 6.0)));
			vec2 bdir = normalize(dir + nor * (hash(vec2(s, 7.0)) - 0.5) * 3.2);
			d = min(d, raio_zig(UV, base, base + bdir * comp * 0.30, s + 91.0, 0.22));
			float nuc = smoothstep(0.0042, 0.0, d);
			float halo = smoothstep(0.052, 0.004, d) * 0.60;
			vec3 cb = BRANCO_QUENTE * nuc
				+ mix(BRANCO_QUENTE, AZUL_ELETRICO, 0.72) * halo;
			cor_r = max(cor_r, cb);
			alpha_r = max(alpha_r, clamp(nuc + halo, 0.0, 1.0));
		}
		alpha_r *= pronto * flick;
		c = cor_r * alpha_r + c * (1.0 - alpha_r);
		a = alpha_r + a * (1.0 - alpha_r);
	}

	// ---------------- EXPLOSAO DO SUPER ----------------
	// o vidro estoura (clarao + trincas + onda de choque) e o liquido
	// vira particulas que voam pelo ar: cada celha tem direcao propria,
	// nasce do volume cheio e cai com gravidade, sumindo no fim.
	if (explosao > 0.001) {
		float ex = explosao;
		vec2 dd = (uva - vec2(0.5)) * vec2(1.0, 2.0);
		float rr = length(dd);
		float aa = atan(dd.y, dd.x);

		// clarao do estouro (instante zero)
		float flash = smoothstep(0.12, 0.0, ex) * dentro;
		c = mix(c, vec3(1.0), flash * 0.85);
		a = max(a, flash * 0.85);

		// onda de choque expandindo pra fora
		float anel_e = smoothstep(0.025, 0.0, abs(rr - ex * 1.15))
			* (1.0 - smoothstep(0.30, 0.65, ex));
		c = mix(c, vec3(1.0, 0.98, 0.9), anel_e * 0.8);
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

		// particulas: celhas com direcao propria, nascem do volume cheio
		vec2 pc = uva * vec2(34.0, 17.0);
		vec2 cid = floor(pc);
		vec2 rnd = vec2(hash(cid + 1.1), hash(cid + 4.7)) - 0.5;
		float dist = 0.35 + 0.85 * hash(cid + 8.3);
		vec2 origem = vec2(hash(cid + 12.9) * carga_exp - 0.5,
			(hash(cid + 15.3) - 0.5) * 0.34);
		vec2 pos = origem + rnd * vec2(2.0, 3.4) * dist * ex;
		pos.y += 0.55 * ex * ex; // cai no ar
		vec2 dp = (uva - vec2(0.5) - pos) * vec2(1.0, 2.0);
		float tam = (0.020 + 0.030 * hash(cid + 20.7)) * (1.0 - ex * 0.55);
		float part = smoothstep(tam, tam * 0.35, length(dp));
		float vivas = step(hash(cid + 26.1), 0.72); // so 72% viram particula
		part *= vivas * (1.0 - ex) * (1.0 - ex);
		vec3 cor_part = mix(mix(AMARELO, LARANJA, smoothstep(0.0, 0.55, carga_exp)),
			BRANCO_QUENTE, clamp(0.75 - ex, 0.0, 1.0));
		c = cor_part * part + c * (1.0 - part);
		a = part + a * (1.0 - part);
	}
	COLOR = vec4(c, a);
}

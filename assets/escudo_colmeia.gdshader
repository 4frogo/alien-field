shader_type canvas_item;

// COLMEIA DE OCTOGONOS — escudo temporario (5s) ao coletar a caixa verde.
//
// 5 camadas, de fora pra dentro:
//   1. CELULA: grade de octogonos concentricos (cada anel tem raio e giro
//      proprios). O angulo de 45 graus e o que faz o octogono.
//   2. TRACO: a borda de cada celula acende — e o "vidro" da colmeia.
//   3. GLOW: halo suave no miolo de cada celula, para nao ficar seco.
//   4. VARREDURA: uma onda de brilho desce atravessando a bolha.
//   5. BORDA: um aro forte na circunferencia externa, marcando o limite.
//
// A bolha e um CIRCULO (descarta fora), entao nunca vira um quadrado.

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform vec4 cor_celula : source_color = vec4(0.25, 1.0, 0.55, 1.0);
uniform vec4 cor_borda : source_color = vec4(0.75, 1.0, 0.85, 1.0);
uniform float opacidade : hint_range(0.0, 1.0) = 0.55;
uniform float brilho : hint_range(0.0, 3.0) = 1.0;
uniform float raio_bolha : hint_range(0.1, 1.5) = 1.0;   // 0.5 = tela toda
uniform float largura_traco : hint_range(0.005, 0.08) = 0.028;
uniform float pulsos : hint_range(0.0, 4.0) = 1.15;     // batidas por segundo
uniform float fade_saida : hint_range(0.0, 1.0) = 1.0;  // 1 = normal, 0 = sumindo
uniform float aneis : hint_range(1.0, 8.0) = 4.0;

// distancia de um ponto ao octogono de raio 0.5 (o "shape" da celula).
// Octogono = intersecao de 8 meio-planos: |x|<=k e |y|<=k e |x|+|y|<=k2
float sdf_octogono(vec2 p, float raio) {
	vec2 q = abs(p);
	// k sao os cortes do octogono: 0.5 nos eixos, ~0.707 na diagonal
	float corte_eixo = raio;
	float corte_diag = raio * 1.306;   // raio*sqrt(2)*0.923 -> octogono regular
	float d = max(max(q.x, q.y) - corte_eixo, (q.x + q.y) - corte_diag);
	return d;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;      // -1..1
	float r = length(p);
	float ang = atan(p.y, p.x);

	// --- BORDA DA BOLHA: fora do raio e fora do jogo
	float rb = raio_bolha;
	if (r > rb) {
		discard;
	}

	// --- pulso geral (a bolha "respira")
	float pulso = 1.0 + 0.05 * sin(tempo * pulsos * 6.2831);
	float pulso_local = 0.92 + 0.08 * sin(tempo * pulsos * 6.2831 - r * 5.0);

	// --- TRACO mais forte na borda externa
	float aro_ext = smoothstep(0.80, 0.99, r / rb) * (1.0 - smoothstep(0.99, 1.0, r / rb));

	// --- COLMEIA: cada anel usa um raio e um giro proprios, para os
	//octogonos nao ficarem alinhados (vira "pano de效果图", nao colmeia)
	vec3 col = vec3(0.0);
	float traco = 0.0;
	float miolo = 0.0;

	for (int i = 0; i < 6; i++) {
		if (float(i) > aneis - 0.5) {
			break;
		}
		float fi = float(i);
		// raio do anel: 0 anel mais interno -> 0.85 anel externo
		float r0 = mix(0.16, 0.88, fi / max(aneis - 1.0, 1.0));
		float larg_an = mix(0.10, 0.20, fi / max(aneis - 1.0, 1.0));
		// giro por anel (impar/even alternado) + rotacao lenta
		float giro = (mod(fi, 2.0) * 0.26) + tempo * (0.10 + 0.04 * fi);
		float ca = cos(giro);
		float sa = sin(giro);
		vec2 pr = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);

		// celula octogonal: mede a distancia ao octogono de raio r0,
		//com tamanho grande (2*r0) para os centros cairem um em cada anel
		float s = sdf_octogono(pr, r0 * 1.05);
		float w = largura_traco * (0.7 + 0.5 * pulsos);

		// borda do octogono: |s| pequeno
		float linha = 1.0 - smoothstep(0.0, w, abs(s));
		// so desenha se estiver DENTRO da bolha (evita octogono vazando)
		linha *= 1.0 - smoothstep(0.86, 1.0, r / rb);
		traco = max(traco, linha);

		// miolo: preenchimento suave dentro do octogono
		float dentro_oct = 1.0 - smoothstep(-w * 2.0, 0.0, s);
		dentro_oct *= 1.0 - smoothstep(0.86, 1.0, r / rb);
		miolo = max(miolo, dentro_oct * (1.0 - linha));
	}

	// --- GLOW: halo a partir dos tracos (borrado pela propria linha)
	float glow = traco * 0.55 + miolo * 0.18;

	// --- VARREDURA: onda de brilho descendo pela bolha
	float sweep = fract(UV.y - tempo * 0.35);
	float scan = smoothstep(0.0, 0.06, sweep) * (1.0 - smoothstep(0.06, 0.22, sweep));
	// so o scan ilumina onde ja tem celula, para nao virar uma barra solta
	glow += scan * (traco * 0.6 + miolo * 0.12);

	// --- cor final: celula no meio, borda mais clara
	vec3 cor_cel = cor_celula.rgb * (miolo * 0.45 + 0.06);
	vec3 cor_lin = mix(cor_celula.rgb, cor_borda.rgb, 0.45) * traco;
	col = (cor_cel + cor_lin) * brilho * pulso_local;
	col += cor_borda.rgb * aro_ext * 0.9 * brilho;

	// --- alfa: combina tudo
	float a = (miolo * 0.22 + traco * 0.85 + aro_ext * 0.6 + glow * 0.35);
	a *= opacidade * fade_saida;
	a *= pulso;   // o pulso tambem "some" (nao vira branco)

	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
shader_type canvas_item;

// PLASMA DAS BARRAS — escudo e super tiro
//
// As barras desenham quads com draw_colored_polygon(), que nao tem
// textura. Para o shader ter UV, os quads passam a usar esta textura
// branca (via draw_color_rect_uv). O shader entao:
//   - usa o ALPHA da textura como mascara do quad
//   - pinta plasma procedural por cima, usando UV.y como altura
//   - aplica scanlines + aberracao cromatica (a parte que bugou antes
//     de a barra ter UV)
//
// Uniform `progresso` (0..1) = quanto da barra esta cheia: o plasma
// corre no sentido do preenchimento.

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform float progresso : hint_range(0.0, 1.0) = 1.0;
uniform vec3 cor_plasma : source_color = vec3(0.35, 1.0, 0.55);
uniform vec3 cor_quente : source_color = vec3(1.0, 0.85, 0.35);
uniform float intensidade : hint_range(0.0, 3.0) = 1.0;
uniform float velocidade : hint_range(0.0, 6.0) = 1.0;

uniform float intensidade_scanline : hint_range(0.0, 1.0) = 0.22;
uniform float aberracao : hint_range(0.0, 6.0) = 1.4;
uniform float brilho_borda : hint_range(0.0, 3.0) = 0.45;
uniform float usar_plasma : hint_range(0.0, 1.0) = 1.0;

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
	vec4 src = texture(TEXTURE, UV);
	float m = src.a;          // mascara do quad

	// --- aberracao cromatica (so onde tem pixel) ---
	float d = length(UV - vec2(0.5));
	vec2 desl = (UV - vec2(0.5)) * d * aberracao * 0.010;
	float mr = texture(TEXTURE, UV + desl).a;
	float mb = texture(TEXTURE, UV - desl).a;
	float m_safe = max(m, 0.001);

	// COLOR traz a cor de cada primitiva: no draw_texture_rect e a cor do
	// quad, nas draw_polyline (superficie/menisco) e a cor da linha. Sem
	// ler isso, as polylines sairiam brancas.
	vec3 col = src.rgb * COLOR.rgb;
	float alpha = m * COLOR.a;

	// --- plasma procedural ---
	// so pinta onde o quad e o LIQUIDO (alpha alta). Os quads de fundo/
	// trilha vem com alpha baixa e ficariam com um retangulo verde solido
	// por cima do painel — era o que parecia uma "area verde".
	float peso = smoothstep(0.30, 0.45, COLOR.a);
	if (usar_plasma > 0.0 && m > 0.01 && peso > 0.01) {
		float t = tempo * velocidade;
		// UV.y = altura da barra; UV.x = posicao horizontal
		vec2 q = vec2(UV.x * 2.2 - t * 0.55, UV.y * 3.4 - t * 0.95);
		float p = fbm(q);

		// veios de plasma: cristas do fbm realçadas
		float veio = pow(1.0 - abs(p - 0.5) * 2.0, 3.0);

		// bolhas subendo (círculos que atravessam a barra pra cima)
		float bol = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float bx = hash21(vec2(fi, 3.7));
			float by = fract(hash21(vec2(fi, 9.1)) - t * (0.20 + 0.10 * fi));
			float raio = 0.10 + 0.12 * hash21(vec2(fi, 17.3));
			float dd = length((UV - vec2(bx, by)) * vec2(1.0, 0.55));
			bol += (1.0 - smoothstep(raio * 0.7, raio, dd)) * 0.30;
		}

		

		// a mistura usa a cor do quad como base, nao branco puro
		vec3 base = max(src.rgb * COLOR.rgb, vec3(0.001));
		vec3 plasma = base * 1.15;
		plasma = mix(plasma, cor_quente.rgb, clamp(veio * 0.55 + bol * 0.45, 0.0, 1.0));
		plasma *= 1.0 + veio * 0.7 + bol * 1.0;

		// a frente do preenchimento (direita) fica mais quente
		float frente = smoothstep(progresso - 0.06, progresso, UV.x);
		plasma = mix(plasma, cor_quente.rgb * 1.6, frente * 0.50);

		col = mix(col, plasma, usar_plasma * peso);
		alpha = max(alpha, m * peso * clamp(0.50 + veio * 0.35 + bol * 0.5, 0.0, 1.0));
	}

	// aplica a aberracao no RGB final (canais separados pela mascara)
	col.r *= mix(1.0, mr / m_safe, 0.35);
	col.b *= mix(1.0, mb / m_safe, 0.35);

	// --- scanlines ---
	float linha = sin(UV.y * 3.14159 * 2.0 * 22.0 - tempo * 4.0);
	float sl = linha * 0.5 + 0.5;
	col = mix(col, col * 0.55, sl * intensidade_scanline * alpha);

	// --- brilho na borda do quad (vidro) ---
	float aro = clamp(max(max(mr, mb), m) - m, 0.0, 1.0);
	col = mix(col, vec3(1.0), aro * brilho_borda * 0.5);

	col *= intensidade;
	COLOR = vec4(col, alpha);
}
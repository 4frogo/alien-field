shader_type canvas_item;
// NEBLINA / NEVOA procedural que passa NA FRENTE do cenario e das naves.
//
// 2 camadas de ruido (fbm) rolando devagar em direcoes diferentes, com
// parallax em relacao ao scroll do fundo. A densidade e maior embaixo e
// nas bordas; no centro da tela ha uma clareira, pra nao esconder a
// acao (a nave e os tiros precisam continuar legiveis).
//
// Uniform `forca` controla a intensidade (a neblina entra suave e
// respira ao longo do tempo).

uniform float tempo = 0.0;
uniform float scroll = 0.0;
uniform vec3 cor_nevoa : source_color = vec3(0.30, 0.80, 0.52);
uniform vec3 cor_luz : source_color = vec3(0.82, 1.0, 0.92);
uniform float forca : hint_range(0.0, 2.0) = 1.0;
uniform float opacidade : hint_range(0.0, 1.0) = 0.80;

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

// 3 oitavas: suficiente pro desenho da nevoa e barato pra web
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
	vec2 uv = UV;

	// camada 1: deriva lenta pra cima (a nevoa "sobe" como vapor)
	// os fatores de scroll sao PEQUENOS de proposito: o scroll do fundo e
	// rapido (45 px/s) e com fator alto a nevoa corria pela tela. Aqui ela
	// desliza devagar, como vapor parado.
	// velocidades: a nevoa DESCE rapido de proposito — ela e a camada
	// mais frontal da cena, entao passar mais rapido que o cenario
	// (45 px/s) e o que da sensacao de velocidade da nave.
	// camada 1: ~86 px/s | camada 2: ~106 px/s.
	// O scroll do fundo entra multiplicado por 45 (px/s do cenario).
	float n1 = fbm(vec2(uv.x * 2.1 + scroll * 0.0013,
		uv.y * 3.4 - tempo * 0.025 - scroll * 0.0062));
	// camada 2: contra-deriva, mais fina e mais rapida
	float n2 = fbm(vec2(uv.x * 4.3 + 19.7 - scroll * 0.0016,
		uv.y * 6.1 - tempo * 0.045 - scroll * 0.0140));

	float f = n1 * 0.62 + n2 * 0.38;
	// o fbm de 3 oitavas tem media ~0.44 e maximo ~0.875: normaliza pra
	// 0..1 antes dos limiares, senao o smoothstep corta quase tudo e a
	// nevoa fica invisivel.
	f /= 0.875;
	// veios: cristas do ruido realçadas (a nevoa ganha filamentos)
	float veio = pow(clamp(1.0 - abs(f - 0.52) * 2.6, 0.0, 1.0), 2.0);

	// densidade: a parte alta do ruido vira nevoa de verdade
	float dens = smoothstep(0.34, 0.78, f);

	// gradiente vertical: mais nevoa embaixo, o topo e mais limpo
	float grad = mix(0.30, 1.0, smoothstep(0.05, 0.95, uv.y));
	// SEM clareira central: qualquer atenuao localizada (smoothstep ou
	// gaussiana) desenhava um circulo visivel no meio da tela — a nevoa
	// e uniforme e o jogador le a acao normalmente.
	dens *= mix(0.55, 1.0, grad);

	// vinheta: acumula um pouco nas laterais (bem gradual, sem aro)
	float vinh = smoothstep(0.15, 1.05, length((uv - vec2(0.5)) * vec2(0.9, 0.62)));
	dens *= 0.85 + 0.35 * vinh;

	// cor: nevoa fria na base, luz nos veios (névoa pega luz, nao é sombra).
	// Puxada um pouco pro branco: uma nevoa muito saturada cria contraste
	// de cor com a nebulosa roxa do fundo e o desenho dela aparece.
	vec3 base = mix(cor_nevoa * 0.85, cor_luz, 0.35);
	vec3 col = mix(base, cor_luz, clamp(dens * 0.55 + veio * 0.45, 0.0, 1.0));
	float a = clamp((dens * 0.85 + veio * 0.30) * opacidade, 0.0, 1.0) * forca;

	COLOR = vec4(col, a);
}

shader_type canvas_item;
render_mode blend_mix, unshaded;
// Bola de fogo procedural para explosoes. Substitui o "bolao liso"
// desenhado em _draw() por algo com textura, turbulencia e borda
// irregular. As faiscas/fumaca/detritos continuam no _draw().

uniform vec3 cor_fogo : source_color = vec3(1.0, 0.42, 0.14);
uniform float progresso : hint_range(0.0, 1.0) = 0.0;   // 0 -> 1 (idade/dur)
uniform float tamanho : hint_range(1.0, 400.0) = 40.0; // raio em px
uniform float semente = 0.0;
uniform float intensidade : hint_range(0.0, 4.0) = 1.0;
uniform float detalhe : hint_range(0.0, 3.0) = 1.0;    // turbulencia

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
	vec2 p = (UV - vec2(0.5)) * 2.0;   // -1..1
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);

	// raio encolhe ao longo da vida, com "pop" elastico no comeco
	float pop = sin(min(progresso / 0.28, 1.0) * 3.14159265) * 0.45;
	float raio = 1.0 - progresso * 0.72 + pop;

	// turbulencia que gira e escala com a vida (poeira se expandindo)
	float t = progresso * 2.2;
	vec2 q = vec2(cos(ang), sin(ang)) * 2.4 + vec2(semente, semente * 0.37);
	float turb = fbm(q * 2.2 + vec2(0.0, -t) * 1.6) - 0.5;
	float limiar = raio + turb * 0.34 * detalhe;

	// mascara: 1 dentro, 0 fora, borda suave e irregular
	float dentro = 1.0 - smoothstep(limiar - 0.10, limiar + 0.02, r);
	if (dentro <= 0.001) {
		discard;
	}

	// gradiente radial de calor: nucleo branco -> cor -> vermelho escuro
	float calor = 1.0 - smoothstep(0.0, limiar, r);
	float nucleo = pow(max(0.0, calor), 3.0);

	vec3 c = cor_fogo;
	c = mix(c * 0.55, c, pow(calor, 1.4));                 // borda escura
	c = mix(c, vec3(1.0, 0.95, 0.82), nucleo * 0.9);      // nucleo branco
	c += vec3(0.35, 0.10, 0.02) * pow(calor, 6.0) * 0.6;  // brilho quente

	// fade da vida inteira
	float fade = 1.0 - pow(progresso, 1.4);

	// perfil de alpha: pico suave, nao opaco. evita o "disco chapado"
	float perfil = pow(max(0.0, calor), 0.85);
	float alpha = dentro * fade * perfil * intensidade;
	alpha = clamp(alpha, 0.0, 0.82);   // teto: nunca vira bloco solido

	// vinheta pra nao cortar seco no limite do sprite
	float aa = 1.0 - smoothstep(limiar - 0.05, limiar, r);
	alpha *= aa;

	COLOR = vec4(c, alpha);
}
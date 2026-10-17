shader_type canvas_item;
render_mode blend_add, unshaded;

// FEIXE DO SUPER TIRO — aplicado no proprio Node2D do feixe, que desenha
// o caminho com polylines. O shader processa o resultado do _draw():
//   - Aqua = nucleo branco puro (o miolo do raio)
//   - cor = a cor original (verde/laser)
//   - UV.y = ao longo do comprimento, UV.x = a transversal
//
// Efeitos: brilho HDR no miolo, tremulacao eletrica que corre pelo
// comprimento, granulado fino e "raiz" quente nas bordas.

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform float intensidade : hint_range(0.0, 2.0) = 0.72;
uniform vec3 cor_nucleo : source_color = vec3(0.85, 1.0, 0.88);
uniform float tremor : hint_range(0.0, 1.0) = 0.22;
uniform float velocidade_tremor = 6.0;
uniform float nucleo : hint_range(0.0, 1.0) = 0.28;

float hash11(float p) {
	return fract(sin(p * 78.233) * 43758.5453);
}

float n11(float p) {
	float i = floor(p);
	float f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);

	// a transversal (UV.x) define o "nucleo": so a faixa central clareia
	float miolo = 1.0 - smoothstep(0.0, 0.20, abs(UV.x - 0.5) * 2.0);

	// tremulacao eletrica: ruido ao longo do comprimento
	float t = tempo * velocidade_tremor;
	float e1 = n11(UV.y * 34.0 - t * 1.6);
	float e2 = n11(UV.y * 71.0 + t * 2.7);
	float elec = (e1 * 0.65 + e2 * 0.35 - 0.5) * tremor;

	// granulado fino (interferencia de alta frequencia)
	float grao = (hash11(floor(UV.y * 480.0) + floor(UV.x * 26.0)) - 0.5) * 0.06;

	// ganho MODESTO: o raio ja é desenhado com 5 camadas aditivas de
	// verde. Com blend_add, qualquer ganho >1 satura os 3 canais e o
	// feixe inteiro vira branco.
	float ganho = 1.0 + elec * 0.6 + grao * 0.5;

	vec3 col = src.rgb * ganho;
	// so o miolo ganha um toque de branco — preserva o verde do raio
	col = mix(col, cor_nucleo, miolo * nucleo);
	col *= intensidade;

	float a = clamp(src.a * (1.0 + elec * 0.35), 0.0, 1.0);

	COLOR = vec4(col, a);
}
shader_type canvas_item;
// Glitch de varredura em overlay (nao precisa amostrar a cena).
// Desenha barras de ruido deslizantes, scanlines, franja cromatica
// e granulado. Use num ColorRect cobrindo a tela inteira.
// `forca` 0..1 = intensidade. `tempo` = animacao.

uniform float forca : hint_range(0.0, 1.0) = 0.0;
uniform float tempo = 0.0;   // cresce sem limite: nao use hint aqui
uniform vec3 cor_ghost : source_color = vec3(0.4, 0.95, 1.0);

float hash1(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float f = forca;
	if (f <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec3 col = vec3(0.0);
		float alpha = 0.0;

		// ---- barras horizontais de glitch (deslizam em X, piscam)
		float linhas = 34.0;
		float idx = floor(uv.y * linhas);
		float tick = floor(tempo * 14.0);
		float r = hash1(idx * 5.31 + tick * 2.17);
		if (r > 0.62) {
			float brilho = (r - 0.62) / 0.38;
			float larg = 0.03 + 0.5 * hash1(idx * 9.7 + tick);
			float x0 = hash1(idx * 2.3 + tick * 3.3) * (1.0 - larg);
			if (uv.x > x0 && uv.x < x0 + larg) {
				vec3 tom = mix(cor_ghost, vec3(1.0, 0.2, 0.5), hash1(idx + tick));
				col += tom * brilho * 0.9;
				alpha += brilho * 0.30;
			}
		}

		// ---- falha vertical momentanea (coluna com ruido)
		float colx = floor(uv.x * 48.0);
		float cv = hash1(colx + tick * 11.3);
		if (cv > 0.9) {
			col += cor_ghost * 0.35;
			alpha += 0.14;
		}

		// ---- scanlines
		float scan = sin(uv.y * 1100.0 - tempo * 30.0) * 0.5 + 0.5;
		col += vec3(scan * 0.06);
		alpha += scan * 0.05;

		// ---- faixa clara que desce
		float faixa = fract(uv.y - tempo * 0.7);
		float brilho_f = smoothstep(0.93, 1.0, faixa);
		col += cor_ghost * brilho_f * 0.5;
		alpha += brilho_f * 0.10;

		// ---- granulado fino
		float g = hash2(uv * vec2(640.0, 480.0) + vec2(tick * 13.0, tick * 7.0));
		col += vec3(g * 0.25);
		alpha += g * 0.06;

		COLOR = vec4(col * f, alpha * f);
	}
}
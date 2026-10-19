shader_type canvas_item;
// Icone de ESCUDO (escudoG.png) com liquido de plasma verde se movendo
// dentro. O PNG vem com fundo preto OPUACO (0,0,0 exato) — key por
// luminancia abre o fundo; o metal escuro (>0.05) e o verde ficam solidos.
// O liquido vive dentro de uma elipse no buraco da moldura; a moldura e
// desenhada POR CIMA do liquido.

uniform sampler2D tex : source_color, filter_linear;
uniform float nivel : hint_range(0.0, 1.0) = 1.0;
uniform float tempo = 0.0;

const vec3 VERDE = vec3(0.24, 1.0, 0.44);
const vec3 VERDE_FUND = vec3(0.03, 0.30, 0.11);

void fragment() {
	vec4 orna = texture(tex, UV);
	float lum = dot(orna.rgb, vec3(0.35, 0.5, 0.15));
	float oa = smoothstep(0.012, 0.055, lum);

	// "vidro" interno: elipse no buraco da moldura
	vec2 e = (UV - vec2(0.5)) / vec2(0.335, 0.180);
	float d = length(e);
	float dentro = 1.0 - smoothstep(0.88, 1.0, d);

	// nivel do liquido + duas ondas na superficie
	float ny = 1.0 - nivel;
	float onda = sin(UV.x * 9.0 + tempo * 2.6) * 0.011
		+ sin(UV.x * 19.0 - tempo * 3.9) * 0.006;
	float sup = ny + onda;
	float liq = smoothstep(sup - 0.004, sup + 0.006, UV.y);

	// corpo: fundo escuro, perto da superficie mais vivo
	vec3 cl = mix(VERDE_FUND, VERDE, clamp((UV.y - ny) * 2.4, 0.0, 1.0));
	// menisco brilhando na superficie
	float brilho = smoothstep(0.022, 0.0, abs(UV.y - sup)) * liq;
	cl = mix(cl, vec3(0.78, 1.0, 0.82), brilho * 0.85);
	// 2 bolhas subindo
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float by = 1.05 - fract(tempo * (0.20 + 0.11 * fi) + fi * 0.47) * 1.12;
		vec2 bp = vec2(0.30 + 0.40 * fi + 0.04 * sin(tempo * (1.3 + fi)), by);
		float bd = length((UV - bp) * vec2(1.0, 1.7)) / 0.010;
		cl = mix(cl, vec3(0.85, 1.0, 0.9), (1.0 - smoothstep(0.4, 1.0, bd)) * 0.55 * liq);
	}

	// vidro escuro de fundo (container legivel com escudo vazio)
	float a1 = 0.30 * dentro;
	// liquido por cima do vidro
	float a2 = liq * dentro;
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

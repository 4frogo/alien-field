shader_type canvas_item;
// SUPER.png com PLASMA enchendo da esquerda pra direita. Preto do PNG
// keyado por luminancia; o interior das letras deixa o plasma aparecer
// dentro delas. O plasma e feito de: nucleo tubular quente, turbulencia
// gaseosa, faixas de energia rolando pra tras, 2 filamentos eletricos
// serpenteando, faiscas raras e menisco com halo sangrando pra fora.
// Cheio, o icone inteiro cicla em RGB ate o disparo.

uniform sampler2D tex : source_color, filter_linear;
uniform float carga : hint_range(0.0, 1.0) = 0.0;
uniform float pronto : hint_range(0.0, 1.0) = 0.0;
uniform float tempo = 0.0;

const vec3 VERMELHO = vec3(1.0, 0.14, 0.09);
const vec3 LARANJA = vec3(1.0, 0.52, 0.07);
const vec3 AMARELO = vec3(1.0, 0.90, 0.33);
const vec3 BRANCO_QUENTE = vec3(1.0, 0.97, 0.86);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 hue_shift(vec3 c, float h) {
	vec3 k = vec3(0.57735);
	float cs = cos(6.28318 * h);
	float sn = sin(6.28318 * h);
	return c * cs + cross(k, c) * sn + k * dot(k, c) * (1.0 - cs);
}

void fragment() {
	vec4 orna = texture(tex, UV);
	float lum = dot(orna.rgb, vec3(0.35, 0.5, 0.15));
	float oa = smoothstep(0.012, 0.055, lum);

	// tanque: elipse na camara do ornamento (cobre as letras)
	vec2 e = (UV - vec2(0.5)) / vec2(0.380, 0.215);
	float dentro = 1.0 - smoothstep(0.86, 1.0, length(e));

	// frente ondulante da esquerda (0) pra direita (1)
	float ond = sin(UV.y * 18.0 + tempo * 6.0) * 0.009
		+ sin(UV.y * 41.0 - tempo * 9.5) * 0.005
		+ sin(UV.y * 90.0 + tempo * 14.0) * 0.002;
	float fx = carga + ond * (0.35 + 0.65 * (1.0 - carga));
	float df = fx - UV.x;                  // >0: dentro do liquido
	float liq = smoothstep(-0.003, 0.006, df);
	float deep = clamp(df * 2.4, 0.0, 1.0); // 0 = na frente, 1 = no fundo

	// cor base do plasma pela carga: amarelo -> laranja -> vermelho
	vec3 cor_liq = mix(AMARELO, LARANJA, smoothstep(0.0, 0.55, carga));
	cor_liq = mix(cor_liq, VERMELHO, smoothstep(0.55, 1.0, carga));

	// nucleo tubular: brilha no meio da altura (tubo de energia)
	float tubo = smoothstep(0.42, 0.02, abs(UV.y - 0.5));

	// turbulencia gaseosa barata (2 camadas de onda cruzada)
	float w1 = sin(UV.x * 14.0 + tempo * 3.2) * sin(UV.y * 21.0 - tempo * 2.6);
	float w2 = sin((UV.x + UV.y) * 27.0 - tempo * 4.8)
		* sin((UV.x - UV.y) * 33.0 + tempo * 4.1);
	float turb = 0.5 + 0.28 * w1 + 0.22 * w2;

	// faixas de energia rolando pra tras (da frente pro fundo)
	float faixa = pow(0.5 + 0.5 * sin(UV.x * 10.0 + UV.y * 4.0 + tempo * 9.0), 4.0);

	// filamentos eletricos: 2 linhas serpenteando, cintilando
	float f1 = smoothstep(0.030, 0.0,
		abs(UV.y - (0.40 + 0.09 * sin(UV.x * 17.0 + tempo * 8.5))));
	float f2 = smoothstep(0.024, 0.0,
		abs(UV.y - (0.60 + 0.08 * sin(UV.x * 21.0 - tempo * 10.5 + 2.0))));
	float filamentos = (f1 * 0.70 + f2 * 0.55)
		* (0.35 + 0.65 * (0.5 + 0.5 * sin(tempo * 23.0 + UV.x * 6.0)));

	// faiscas: celhas raras acendendo e apagando
	float fa = hash(floor(UV * vec2(46.0, 20.0)) + floor(tempo * 7.0));
	float faisca = step(0.982, fa) * (0.5 + 0.5 * sin(tempo * 31.0 + fa * 90.0));

	// energia total do plasma
	float energia = tubo * (0.30 + 0.70 * turb) * (0.40 + 0.60 * (1.0 - deep))
		+ faixa * 0.45
		+ filamentos * 0.85
		+ faisca * 0.9;
	energia = max(energia, 0.0);

	// corpo: bordas escuras -> cor viva -> nucleo branco quente
	vec3 cl = mix(cor_liq * 0.18, cor_liq, clamp(energia, 0.0, 1.0));
	cl = mix(cl, BRANCO_QUENTE, clamp(energia - 0.9, 0.0, 1.0) * 0.85);

	// alpha emissivo: regioes fortes mais opacas, fracas mais etereas
	float a_liq = liq * dentro * clamp(0.45 + energia * 0.55, 0.0, 1.0);

	// menisco: nucleo branco + halo sangrando um pouco pra fora do limite
	float m_core = smoothstep(0.007, 0.0, abs(df)) * dentro;
	float m_halo = smoothstep(0.045, 0.0, abs(df)) * dentro;
	cl = mix(cl, BRANCO_QUENTE, m_core * 0.9);
	a_liq = max(a_liq, m_core * 0.95);
	a_liq = max(a_liq, m_halo * 0.35);

	// vidro escuro do tanque vazio (legivel sem carga)
	float a1 = 0.28 * dentro;
	vec3 c = cl * a_liq + vec3(0.10, 0.035, 0.02) * a1 * (1.0 - a_liq);
	float a = a_liq + a1 * (1.0 - a_liq);
	if (a > 0.001) {
		c /= a;
	}
	// moldura + letras por cima (preto keyado = transparente)
	c = orna.rgb * oa + c * (1.0 - oa);
	a = oa + a * (1.0 - oa);

	// PRONTA: cicla em RGB + brilho pulsante ate o tiro sair
	if (pronto > 0.005) {
		c = mix(c, hue_shift(c, fract(tempo * 0.38)), pronto * 0.85);
		c *= 1.0 + 0.20 * pronto * sin(tempo * 9.0);
	}
	COLOR = vec4(c, a);
}

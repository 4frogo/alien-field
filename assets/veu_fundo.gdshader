shader_type canvas_item;

// VEU DE FUNDO
// Escurece as bordas e tira um pouco de saturacao da arte de fundo, para o
// verde da nave e o laranja dos tiros saltarem contra ela. Aplicado SO nos
// sprites do fundo — a nave, os inimigos e o HUD ficam intactos.

uniform float vinheta : hint_range(0.0, 1.5) = 0.85;  // forca do escurecimento
uniform float dessat : hint_range(0.0, 1.0) = 0.45;    // quanto tira de cor
uniform float escurecer : hint_range(0.0, 1.0) = 0.30; // escurecer o miolo
uniform float raio : hint_range(0.1, 1.2) = 0.72;      // onde a vinheta comeca
uniform vec4 tom_escuro : source_color = vec4(0.03, 0.02, 0.06, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	// --- dessaturação parcial (mistura com o luminancia)
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(lum), dessat);

	// --- escurecer o miolo de leve, pra nada ficar "chapado"
	c.rgb *= (1.0 - escurecer);

	// --- vinheta: distância ao centro da tela
	vec2 d = UV - vec2(0.5, 0.5);
	d.x *= 1.7777; // 540x960: corrige a proporcao pra ficar circular
	float dist = length(d) * 1.35;
	float v = smoothstep(raio, 1.25, dist) * vinheta;
	c.rgb = mix(c.rgb, tom_escuro.rgb, clamp(v, 0.0, 0.92));

	COLOR = c;
}
shader_type canvas_item;

// VEU DE FUNDO
// Escurece as bordas e tira um pouco de saturacao da arte de fundo, para o
// verde da nave e o laranja dos tiros saltarem contra ela. Aplicado SO nos
// sprites do fundo — a nave, os inimigos e o HUD ficam intactos.
//
// Os numeros nao sao "mais e menos": cada um cuida de uma coisa. Saturao
// baixa demais tira a cor da nebulosa; escurecer global demais apaga o miolo
// e a nave perde contraste; a vinheta e o que cria a separacao.

uniform float vinheta : hint_range(0.0, 1.5) = 1.00;   // forca do escurecimento nas bordas
uniform float dessat : hint_range(0.0, 1.0) = 0.22;     // tira pouco de cor (0.45 apagava a nebulosa)
uniform float escurecer : hint_range(0.0, 1.0) = 0.10;  // escurecer o miolo, de leve
uniform float raio : hint_range(0.1, 1.2) = 0.82;       // onde a vinheta comeca (maior = area central livre)
uniform float realce : hint_range(0.0, 1.0) = 0.35;     // levanta o centro, onde a nave fica
uniform vec3 tom_escuro : source_color = vec3(0.05, 0.03, 0.09);

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	// --- dessaturacao parcial (mantem a cor da nebulosa)
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(lum), dessat);

	// --- escurecer o miolo de leve, pra nao ficar chapado
	c.rgb *= (1.0 - escurecer);

	// --- vinheta: distancia ao centro da tela
	vec2 d = UV - vec2(0.5, 0.5);
	d.x *= 1.7777; // 540x960: corrige a proporcao pra ficar circular
	float dist = length(d) * 1.32;

	// realce suave no centro: escurece as bordas sem apagar o miolo,
	// o que e exatamente onde a nave fica
	float v = smoothstep(raio, 1.30, dist) * vinheta;
	c.rgb = mix(c.rgb, c.rgb * 0.35 + tom_escuro * 0.25, clamp(v, 0.0, 0.85));

	// leve levantamento no centro, o resto do fundo fica rebaixado
	float centro = 1.0 - smoothstep(0.0, 0.62, dist);
	c.rgb *= 1.0 + centro * realce * 0.18;

	COLOR = c;
}

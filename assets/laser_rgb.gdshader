shader_type canvas_item;

uniform float speed : hint_range(1.0, 10.0) = 5.0;

void fragment() {
	// d: 0 no centro, 1 nas bordas
	float d = abs(UV.x - 0.5) * 2.0;
	float t = TIME * speed;
	// faixas de energia subindo
	float bandas = sin((UV.y * 9.0 - t * 1.6) * 6.2831) * 0.5 + 0.5;
	float bandas2 = sin((UV.y * 23.0 + t * 2.2) * 6.2831) * 0.5 + 0.5;
	float energia = bandas * 0.65 + bandas2 * 0.35;

	vec3 branco = vec3(1.0, 0.98, 1.0);
	vec3 rosa = vec3(1.0, 0.35, 0.75);
	vec3 roxo = vec3(0.55, 0.2, 1.0);

	float nucleo = smoothstep(0.45, 0.0, d);
	float meio = smoothstep(0.85, 0.1, d);
	float borda = smoothstep(1.0, 0.35, d);

	vec3 col = roxo * borda * 0.7;
	col += rosa * meio * (0.5 + 0.7 * energia);
	col += branco * nucleo * (0.9 + 0.5 * energia);

	// cintilacao RGB
	col.r += 0.12 * sin(t * 7.0 + UV.y * 20.0);
	col.g += 0.10 * sin(t * 7.0 + UV.y * 20.0 + 2.094);
	col.b += 0.14 * sin(t * 7.0 + UV.y * 20.0 + 4.188);

	vec4 tex = texture(TEXTURE, UV);
	// afina na ponta e na base
	float ponta = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float alpha = tex.a * (pow(1.0 - d, 1.4) * 0.9 + 0.1) * (0.75 + 0.25 * energia);
	alpha *= mix(0.55, 1.0, ponta);
	COLOR = vec4(col * 1.6, alpha);
}

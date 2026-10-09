shader_type canvas_item;
// dissolve com poeira: pixels somem por ruido, borda brilha esverdeada
uniform float progresso : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cor_borda : source_color = vec3(0.5, 1.0, 0.6);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = floor(UV * vec2(110.0, 190.0));
	float n = hash(g);
	if (n < progresso) {
		discard;
	}
	vec2 uv2 = UV + vec2(hash(g + 7.0) - 0.5, -progresso * 0.06) * 0.02;
	vec4 c = texture(TEXTURE, uv2);
	float faixa = 1.0 - smoothstep(progresso, progresso + 0.10, n);
	vec3 col = mix(c.rgb, cor_borda * 1.6, faixa * 0.85);
	COLOR = vec4(col, c.a);
}

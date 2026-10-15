shader_type canvas_item;

// CONTORNO (OUTLINE)
// Amostra a textura em 8 direcoes e pinta uma borda onde o original e
// transparente. E o truque classico de shmup: a nave e os inimigos ganham
// silhueta e param de se misturar com o fundo.

uniform vec4 cor : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float espessura : hint_range(0.0005, 0.02) = 0.0055;
uniform float brilho_borda : hint_range(0.0, 1.0) = 0.0;  // realce na borda
uniform vec4 cor_brilho : source_color = vec4(1.0, 0.5, 0.15, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * espessura;

	float vizinho = 0.0;
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
	vizinho = max(vizinho, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	// a parte "fora" da silhueta (original transparente, vizinho opaco)
	float fora = clamp(vizinho - c.a, 0.0, 1.0);

	vec3 col = mix(c.rgb, cor.rgb, fora);
	float a = max(c.a, fora * cor.a);

	if (brilho_borda > 0.0) {
		// realce fino na beira da borda, opcional
		float aro = fora * (1.0 - smoothstep(0.0, 0.45, fora));
		col = mix(col, cor_brilho.rgb, aro * brilho_borda);
	}

	COLOR = vec4(col, a);
}
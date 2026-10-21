shader_type canvas_item;
render_mode blend_mix;

// Glitch de "compressao de video" na arte de transicao:
//  - separa os canais RGB (red shift) e desloca faixas horizontais
//  - scanlines (linhas de varredura)
//  - vinheta escurecendo as bordas
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float vinheta : hint_range(0.0, 1.0) = 0.45;
uniform float scan : hint_range(0.0, 1.0) = 0.0;
uniform float sep : hint_range(0.0, 0.1) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	float g = glitch;

	// desloca faixas horizontais de forma aleatoria (o "traqueado")
	float banda = floor(uv.y * 24.0);
	float ruido = fract(sin(banda * 91.7 + floor(TIME * 18.0) * 7.13) * 43758.5453);
	float desl = (ruido - 0.5) * 0.09 * g;
	// mais um arrasto horizontal fino no meio da tela
	float arrasto = (step(0.5, fract(uv.y * 3.0 + TIME * 0.7)) - 0.5) * 0.03 * g;
	vec4 base = texture(TEXTURE, uv + vec2(desl + arrasto, 0.0));

	// separa os canais: vermelho vai pra um lado, ciano pro outro
	float r = texture(TEXTURE, uv + vec2(sep, 0.0)).r;
	vec4 gb = texture(TEXTURE, uv - vec2(sep, 0.0));
	vec3 cor = mix(base.rgb, vec3(r, gb.g, gb.b), g);

	// linhas de varredura
	cor *= 1.0 - scan * 0.20 * step(0.5, fract(uv.y * 220.0));

	// vinheta
	float d = distance(uv, vec2(0.5, 0.5));
	cor *= 1.0 - vinheta * smoothstep(0.28, 0.82, d);

	COLOR = vec4(cor, base.a * fade);
}

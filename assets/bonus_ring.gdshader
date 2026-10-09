shader_type canvas_item;
// recorte circular com borda suave: some com cantos quadrados de JPG
uniform float raio : hint_range(0.5, 1.0) = 0.92;
uniform float pena : hint_range(0.0, 0.3) = 0.10;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length(UV - vec2(0.5)) * 2.0;
	float m = 1.0 - smoothstep(raio - pena, raio, d);
	COLOR = vec4(c.rgb, c.a * m);
}

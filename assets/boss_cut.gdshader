shader_type canvas_item;
// corta franja semitransparente em volta do sprite (fundo fantasma)
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = smoothstep(0.35, 0.62, c.a);
	if (a < 0.02) {
		discard;
	}
	COLOR = vec4(c.rgb, a);
}

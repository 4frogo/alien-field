shader_type canvas_item;

uniform float cutoff : hint_range(0.5, 1.0) = 0.78;
uniform float feather : hint_range(0.0, 0.3) = 0.18;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// fundo branco fica transparente, nave escura fica opaca
	float a = 1.0 - smoothstep(cutoff - feather, cutoff, lum);
	// preserva luzes vermelhas brilhantes mesmo se claras
	float red = c.r * 1.3 - (c.g + c.b) * 0.5;
	if (red > 0.25) {
		a = max(a, clamp((red - 0.15) * 2.0, 0.0, 1.0));
	}
	COLOR = vec4(c.rgb, c.a * a);
}

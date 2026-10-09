shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 0.3) = 0.06;
uniform float feather : hint_range(0.0, 0.4) = 0.18;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float a = smoothstep(cutoff, cutoff + feather, lum);
	// mantem o brilho verde mesmo em area escura
	float green_boost = c.g * 1.2 - (c.r + c.b) * 0.5;
	a = max(a, clamp(green_boost - cutoff * 2.0, 0.0, 1.0) * c.a);
	COLOR = vec4(c.rgb * 1.1, c.a * a);
}

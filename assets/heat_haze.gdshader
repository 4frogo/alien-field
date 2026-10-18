shader_type canvas_item;

uniform float time = 0.0;
uniform float intensity = 1.0;
uniform sampler2D screen_texture : hint_screen_texture;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	for (int i = 0; i < 4; ++i) {
		v += a * noise(p);
		p = p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 screen_uv = SCREEN_UV;

	// distorce baseado no tempo e posicao (fbm 4 camadas)
	float distort = fbm(uv * 4.0 + vec2(time * 0.6)) * 2.0 - 1.0;
	vec2 offset = vec2(distort, distort * 0.6) * intensity * 0.03;

	vec4 screen = texture(screen_texture, screen_uv + offset);

	// calor brilhante no centro (pontas de fogo)
	float heat = 1.0 - length(uv - vec2(0.5, 0.75)) * 1.6;
	heat = clamp(heat, 0.0, 1.0);
	heat = pow(heat, 4.0);

	// cor do calor: laranja/vermelho fraco
	vec3 heat_color = vec3(1.0, 0.45, 0.10) * heat * 0.25;

	COLOR = vec4(screen.rgb + heat_color, screen.a);
}

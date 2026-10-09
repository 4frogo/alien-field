shader_type canvas_item;

uniform float charge : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.5, 6.0) = 3.0;
uniform vec3 core_color : source_color = vec3(0.92, 1.0, 1.0);
uniform vec3 mid_color : source_color = vec3(0.15, 0.75, 1.0);
uniform vec3 outer_color : source_color = vec3(0.05, 0.25, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float d = length(centered) * 2.0;
	float t = TIME * speed;
	float ang = atan(centered.y, centered.x);

	// plasma girando em 2 camadas
	float swirl = sin(ang * 3.0 + t * 2.6 + d * 9.0) * 0.5 + 0.5;
	float swirl2 = sin(ang * 6.0 - t * 3.4 + d * 14.0) * 0.5 + 0.5;
	float energy = swirl * 0.6 + swirl2 * 0.4;

	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;

	float core = smoothstep(0.55, 0.0, d) * (0.55 + 0.45 * charge);
	float mid = smoothstep(0.95, 0.15, d) * (0.35 + 0.65 * energy);
	float outer = smoothstep(1.0, 0.35, d);

	vec3 col = outer_color * outer * 0.7;
	col += mid_color * mid * (0.45 + 0.9 * charge);
	col += core_color * core * (0.7 + 0.9 * charge);

	// raios eletricos
	float bolt = pow(energy, 3.0) * smoothstep(1.0, 0.0, d) * (0.3 + charge);
	col += vec3(0.45, 0.85, 1.0) * bolt * 1.6;

	// RGB split animado estilo kamehameha
	float wob = sin(t * 5.0 + d * 11.0);
	col.r += 0.22 * wob * mask * (0.3 + charge);
	col.g += 0.22 * sin(t * 5.0 + d * 11.0 + 2.094) * mask * (0.3 + charge);
	col.b += 0.22 * sin(t * 5.0 + d * 11.0 + 4.188) * mask * (0.3 + charge);

	float alpha = clamp(mask * (outer * 0.9 + core + mid * 0.85), 0.0, 1.0);

	if (charge >= 0.985) {
		float flash = 0.5 + 0.5 * sin(TIME * 18.0);
		col += vec3(0.35, 0.4, 0.45) * flash;
		alpha = clamp(alpha + flash * 0.15, 0.0, 1.0);
	}

	COLOR = vec4(col * 1.5, alpha);
}

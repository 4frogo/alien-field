shader_type canvas_item;

uniform float charge : hint_range(0.0, 1.0) = 0.8;
uniform float speed : hint_range(0.5, 8.0) = 4.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 mid_color : source_color = vec3(1.0, 0.3, 0.08);
uniform vec3 outer_color : source_color = vec3(0.55, 0.05, 0.03);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float d = length(centered) * 2.0;
	float t = TIME * speed;
	float ang = atan(centered.y, centered.x);

	float swirl = sin(ang * 4.0 + t * 3.0 + d * 10.0) * 0.5 + 0.5;
	float swirl2 = sin(ang * 7.0 - t * 4.0 + d * 16.0) * 0.5 + 0.5;
	float energy = swirl * 0.55 + swirl2 * 0.45;

	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;

	float core = smoothstep(0.45, 0.0, d) * (0.6 + 0.4 * charge);
	float mid = smoothstep(0.9, 0.12, d) * (0.4 + 0.6 * energy);
	float outer = smoothstep(1.0, 0.3, d);

	vec3 col = outer_color * outer * 0.8;
	col += mid_color * mid * (0.5 + 0.9 * charge);
	col += core_color * core * (0.8 + 0.8 * charge);

	float bolt = pow(energy, 3.0) * smoothstep(1.0, 0.0, d) * (0.4 + charge);
	col += vec3(1.0, 0.45, 0.15) * bolt * 1.7;

	float wob = sin(t * 6.0 + d * 12.0);
	col.r += 0.2 * wob * mask * (0.3 + charge);
	col.g += 0.1 * sin(t * 6.0 + d * 12.0 + 2.094) * mask * charge;
	col.b += 0.06 * sin(t * 6.0 + d * 12.0 + 4.188) * mask * charge;

	float alpha = clamp(mask * (outer * 0.95 + core + mid * 0.9), 0.0, 1.0);
	COLOR = vec4(col * 1.5, alpha);
}

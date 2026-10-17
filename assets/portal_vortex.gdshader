shader_type canvas_item;

// PORTAL — vortex com swirl, distorcao e chromosso
// Aplicado no Sprite2D principal do portal (o _glow usa blend aditivo e
// fica por baixo). O UV gira em espiral e distorce a arte, como se os
// pixels fossem puxados para o centro do vortice.

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform float forca_swirl : hint_range(0.0, 6.0) = 2.2;   // quao gira
uniform float distorcao : hint_range(0.0, 0.5) = 0.10;   // turbulencia
uniform float aberracao : hint_range(0.0, 6.0) = 2.2;    // separacao RGB
uniform float brilho_nucleo : hint_range(0.0, 3.0) = 1.35;
uniform vec4 cor_borda : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform float semente = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c);
	if (r > 0.5) {
		discard;
	}
	float ang = atan(c.y, c.x);

	// --- swirl: rotacao cresce conforme se aproxima do centro ---
	// (no centro gira infinito = o "buraco" do portal)
	float giro = tempo * 1.15 + semente;
	float swirl = forca_swirl * (0.25 + pow(1.0 - r * 2.0, 2.2));
	float a2 = ang + swirl + giro;

	vec2 p = vec2(cos(a2), sin(a2)) * r * 2.0 * 0.5 + vec2(0.5);

	// --- turbulencia radial (ondas entrando) ---
	float onda = sin(r * 22.0 - tempo * 5.0) * distorcao * r;
	p += normalize(c + vec2(0.0001)) * onda;

	// distorcao de ruido pra dar textura viva
	float n = vnoise(p * 7.0 + vec2(0.0, -tempo * 0.8 + semente)) - 0.5;
	p += vec2(n, n) * distorcao * 0.30;

	// --- chromatic aberration: quanto mais longe do centro, mais separa ---
	float sep = aberracao * r * 0.010;
	vec4 col;
	col.r = texture(TEXTURE, p + normalize(c + vec2(0.0001)) * sep).r;
	col.g = texture(TEXTURE, p).g;
	col.b = texture(TEXTURE, p - normalize(c + vec2(0.0001)) * sep).b;
	col.a = texture(TEXTURE, p).a;

	// --- nucleo incandescente ---
	float nucleo = pow(1.0 - r * 2.0, 3.0);
	col.rgb += cor_borda.rgb * nucleo * brilho_nucleo;

	// --- aro luminoso na borda (marca o limiar do portal) ---
	float aro = smoothstep(0.36, 0.48, r) * (1.0 - smoothstep(0.48, 0.5, r));
	col.rgb = mix(col.rgb, cor_borda.rgb, aro * 0.55);
	col.a = max(col.a, aro * 0.85);

	COLOR = col;
}
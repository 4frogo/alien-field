shader_type canvas_item;
render_mode blend_mix, unshaded;

// PAINEL DE HUD — vidro escuro com varredura, cantos chanfrados e
// brilho de canto. Substitui os StyleBoxFlat com moldura verde.
//
// A textura e branca (mascara) desenhada via draw_texture_rect, entao
// quem define a forma do painel e este shader: ele corta os cantos com
// chanfro (canto recortado, estilo sci-fi) em vez de arredondar.

uniform float tempo : hint_range(0.0, 100.0) = 0.0;
uniform vec4 cor_fundo : source_color = vec4(0.015, 0.045, 0.030, 0.72);
uniform vec4 cor_borda : source_color = vec4(0.30, 1.0, 0.50, 0.55);
uniform vec4 cor_acento : source_color = vec4(0.45, 1.0, 0.60, 0.85);
uniform float chanfro : hint_range(0.0, 0.5) = 0.14;    // tamanho do corte diagonal
uniform float espessura_borda : hint_range(0.0, 0.08) = 0.012;
uniform float varredura : hint_range(0.0, 1.0) = 0.30;  // linha de varredura
uniform float velocidade_varredura : hint_range(0.0, 200.0) = 34.0;
uniform float brilho_canto : hint_range(0.0, 3.0) = 1.1;
uniform float grade : hint_range(0.0, 1.0) = 0.14;      // grade sutil
uniform vec4 cor_acento_lateral : source_color = vec4(0.30, 1.0, 0.50, 0.0);
// LIGA/DESLIGA a MOLDURA do painel (borda verde + acento lateral + brilho
// de canto), sem mexer no vidro de fundo. 1 = moldura visivel (padrao),
// 0 = sem caixa verde em volta — as barrinhas ficam soltas sobre o vidro.
uniform float mostrar_borda : hint_range(0.0, 1.0) = 1.0;
// LIGA/DESLIGA o VIDRO DE FUNDO. 0 = painel totalmente invisivel: so as
// barrinhas aparecem, sem nenhuma caixa atras delas.
uniform float mostrar_fundo : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// SDF de retangulo com os 4 cantos chanfrados (corte diagonal)
float sdf_chamfro(vec2 p, vec2 b, float c) {
	vec2 q = abs(p) - b + c;
	// triangulo em cada canto
	float fora = max(q.x, q.y);
	float diag = (q.x + q.y) - c;
	return max(fora, diag);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5)) * 2.0;   // -1..1
	vec2 b = vec2(1.0);
	float ch = chanfro;

	float d = sdf_chamfro(p, b, ch);
	// normalizado: d<0 dentro, d>0 fora
	float dentro = 1.0 - smoothstep(-0.02, 0.005, d);
	if (dentro <= 0.002) {
		discard;
	}

	// --- fundo: vidro escuro com leve gradiente de cima pra baixo ---
	vec3 col = cor_fundo.rgb;
	col *= 0.75 + 0.55 * (1.0 - uv.y);       // mais claro embaixo
	col *= 1.0 - grade * 0.5 * step(0.5, fract(uv.x * 26.0));
	col *= 1.0 - grade * 0.5 * step(0.5, fract(uv.y * 8.0));

	// --- borda: onde d ~ 0 (some quando mostrar_borda = 0) ---
	float borda = (1.0 - smoothstep(0.0, espessura_borda * 2.2, abs(d))) * mostrar_borda;
	col = mix(col, cor_borda.rgb, borda * 0.85);

	// --- acento lateral esquerdo (marca "painel ativo") ---
	float lat = (1.0 - smoothstep(0.0, 0.09, abs(p.x + 1.0))) * dentro * mostrar_borda;
	col = mix(col, cor_acento.rgb, lat * 0.55);

	// --- brilho nos cantos chanfrados (pontos de luz) ---
	float canto_brilho = (1.0 - smoothstep(0.0, 0.30, abs(d + 0.10))) * mostrar_borda;
	canto_brilho *= 0.5 + 0.5 * sin(tempo * 2.4);
	col += cor_acento.rgb * canto_brilho * brilho_canto * 0.35;

	// --- linha de varredura descendo ---
	float linha = fract(uv.y - tempo * velocidade_varredura / 100.0);
	float scan = smoothstep(0.0, 0.03, linha) * (1.0 - smoothstep(0.03, 0.10, linha));
	col += vec3(0.25, 0.75, 0.45) * scan * varredura * dentro;

	// --- leve noise no vidro ---
	float n = hash21(floor(uv * vec2(120.0, 60.0)) + floor(tempo * 12.0));
	col += (n - 0.5) * 0.020;

	float alpha = dentro * cor_fundo.a * mostrar_fundo;
	alpha = max(alpha, borda * cor_borda.a);

	COLOR = vec4(col, alpha);
}
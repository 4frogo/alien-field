shader_type canvas_item;

// AVISO DE CHEFAO: crista vermelha so nas bordas da tela.
// Nada no centro, entao o jogo continua legivel durante o aviso.
// Uma "varredura" de luz desce pelas bordas a cada ciclo.

uniform vec4 cor : source_color = vec4(1.0, 0.10, 0.06, 1.0);
uniform float largura = 0.34;   // espessura da faixa (0..1 da meia-altura)
uniform float pulso = 0.0;     // 0..1, intensidade do alarme
uniform float varredura = 0.0;  // posicao da onda (0..1, cicla)
uniform float tempo = 0.0;

void fragment() {
	vec2 uv = UV;
	float ar = 1.7777; // 540x960 ->ividemos pela altura

	// distancia ate a borda mais proxima, corrigida pela proporcao
	float dx = min(uv.x, 1.0 - uv.x) * ar;
	float dy = min(uv.y, 1.0 - uv.y);
	float d = min(dx, dy);

	// crista principal: forte colada na borda, some pra dentro
	float base = pow(1.0 - smoothstep(0.0, largura, d), 1.8);

	// vinheta escura bem na borda (profundidade)
	float beirada = pow(1.0 - smoothstep(0.0, largura * 0.45, d), 2.2);

	// onda de varredura descendo pela tela dentro da faixa
	float onda = sin((uv.y - varredura) * 22.0 - tempo * 3.0) * 0.5 + 0.5;
	float varre = base * onda * 0.55;

	// tremidao constante do alarme
	float tremer = 0.78 + 0.22 * sin(tempo * 9.0 + uv.y * 6.0);

	float a = clamp(base * 0.26 + varre * 0.30 + beirada * 0.22, 0.0, 1.0);
	a *= pulso * tremer;

	COLOR = vec4(cor.rgb, a * cor.a);
}
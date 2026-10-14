extends Control

# Barra de carga do SUPER TIRO — liquido de plasma enchendo ate a direita.
#
# O liquido e desenhado como uma sequencia de quads simples (oGodot triangula
# mal poligonos concavos/degenerados, entao evitamos um unico poligono grande).
#
# Efeitos:
#   - liquido avanca da esquerda para a direita conforme a carga
#   - frente (menisco) ondulando e estufando pra fora
#   - profundidade: superficie clara -> fundo escuro
#   - bolhas subindo, brilho pulsante na parede
#   - moldura em paralelogramo (skew) com chanfros
#   - fase: ciano (0.0) -> ambar (0.6) -> vermelho (1.0)
#   - quando cheia: pulso + aneis de choque + faiscas

const SK := 9.0
const BEVEL := 5.0
const SEG := 20

var prog := 0.0
var pronta := false
var pulso := 0.0

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 16)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	if not visible:
		return
	if pronta:
		pulso = minf(1.0, pulso + delta * 3.5)
	else:
		pulso = maxf(0.0, pulso - delta * 2.0)
	queue_redraw()


func set_carga(p: float, ready_state: bool) -> void:
	prog = clampf(p, 0.0, 1.0)
	pronta = ready_state
	visible = prog > 0.001


# ---------------------------------------------------------------- cores

func _cor() -> Color:
	# rampa de 4 paradas: ciano -> verde -> ambar -> vermelho
	var stops := [
		[0.0, Color(0.10, 0.90, 1.00)],
		[0.45, Color(0.30, 1.00, 0.55)],
		[0.80, Color(1.00, 0.80, 0.18)],
		[1.0, Color(1.00, 0.25, 0.18)],
	]
	for i in range(stops.size() - 1):
		var a: float = stops[i][0]
		var b: float = stops[i + 1][0]
		if prog <= b:
			var k: float = clampf((prog - a) / (b - a), 0.0, 1.0)
			return (stops[i][1] as Color).lerp(stops[i + 1][1] as Color, k)
	return stops[stops.size() - 1][1] as Color


func _profundo() -> Color:
	return _cor().lerp(Color(0.02, 0.05, 0.09), 0.68)


func _clara() -> Color:
	return _cor().lerp(Color(1, 1, 1), 0.62)


# ------------------------------------------------------------ geometria

func _sk(y: float) -> float:
	var h: float = maxf(1.0, size.y)
	return SK * clampf(1.0 - y / h, 0.0, 1.0)


func _pt(x: float, y: float) -> Vector2:
	return Vector2(x + _sk(y), y)


# Quad de quatro pontos, sempre com area > 0.
func _quad(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	if x1 - x0 < 0.05 or y1 - y0 < 0.05:
		return
	draw_colored_polygon(PackedVector2Array([
		_pt(x0, y0), _pt(x1, y0), _pt(x1, y1), _pt(x0, y1),
	]), col)


# Estofamento horizontal da frente do liquido (nunca negativo).
func _ond(y: float, amp: float) -> float:
	var agit: float = 0.35 + 0.95 * prog
	var v: float = (sin(y * 0.42 + _t * (3.6 + 5.0 * prog)) * amp
		+ sin(y * 0.95 - _t * (5.4 + 3.0 * prog) + 1.3) * amp * 0.40) * agit
	return maxf(0.0, v)


# ---------------------------------------------------------------- draw

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c: Color = _cor()
	var clara: Color = _clara()
	var fundo: Color = _profundo()

	# ---- glow externo
	if pulso > 0.0:
		var breathe: float = 0.55 + 0.45 * sin(_t * 9.0)
		var ga: float = (0.18 + 0.24 * breathe) * pulso
		_quad(-5, -5, w + 5, h + 5, Color(c.r, c.g, c.b, ga * 0.45))
		_quad(-9, -9, w + 9, h + 9, Color(c.r, c.g, c.b, ga * 0.22))

	# ---- sombra interna
	_quad(0, 0, w, h, Color(0.02, 0.03, 0.05, 0.85))

	var pad := 1.5
	var y0: float = pad + 1.0
	var y1: float = maxf(y0 + 0.5, h - pad - 1.0)
	var fill_w: float = (w - pad * 2.0) * prog

	if fill_w > 0.6:
		var amp: float = clampf(h * 0.18, 0.5, 2.4)
		var meio: float = lerpf(y0, y1, 0.45)

		# ---- corpo do liquido
		_quad(pad, y0, pad + fill_w, y1, Color(c.r, c.g, c.b, 0.58))

		# ---- estufamento da frente: bulge organico no meio da parede
		var bulge := 2.0 + 3.0 * prog
		_quad(pad + fill_w, meio - h * 0.22, pad + fill_w + bulge, meio + h * 0.22,
			Color(c.r, c.g, c.b, 0.30))
		_quad(pad + fill_w + bulge * 0.45, meio - h * 0.10,
			pad + fill_w + bulge * 0.75, meio + h * 0.10,
			Color(clara.r, clara.g, clara.b, 0.22))

		# ---- profundidade: mais escuro embaixo, sem virar "meio vazio"
		_quad(pad, y0 + (y1 - y0) * 0.55, pad + fill_w, y1,
			Color(fundo.r, fundo.g, fundo.b, 0.34))
		_quad(pad, y0 + (y1 - y0) * 0.80, pad + fill_w, y1,
			Color(fundo.r, fundo.g, fundo.b, 0.28))
		var fx: float = maxf(pad + 0.4, pad + fill_w - 1.2)

		# ---- ondas internas (faixas diagonais rolando dentro do liquido)
		for i in 3:
			var ph: float = fmod(_t * (0.7 + 0.5 * float(i)) + float(i) * 0.37, 1.0)
			var sx: float = pad + (fill_w + h) * ph
			var fade: float = sin(ph * PI)
			_quad(sx, y0, sx + h * 0.22, y1,
				Color(1, 1, 1, 0.10 * fade))

		# ---- frente estufando pra fora, em faixas horizontais
		var frente := PackedVector2Array()
		for i in range(SEG + 1):
			var v: float = float(i) / float(SEG)
			var y: float = lerpf(y0, y1, v)
			frente.append(_pt(pad + fill_w + _ond(y, amp), y))
		for i in range(SEG):
			var ya: float = lerpf(y0, y1, float(i) / float(SEG))
			var yb: float = lerpf(y0, y1, float(i + 1) / float(SEG))
			var oa: float = _ond(ya, amp)
			var ob: float = _ond(yb, amp)
			# faixa entre a linha reta e a frente ondulada
			_quad(pad + fill_w, ya, pad + fill_w + maxf(oa, ob), yb,
				Color(c.r, c.g, c.b, 0.45))

		# ---- superficie superior ondulante (liquido agitado)
		var topo := PackedVector2Array()
		for i in range(SEG + 1):
			var x: float = pad + fill_w * (float(i) / SEG)
			var edge: float = clampf((float(i) / SEG) * 4.0, 0.0, 1.0)
			var ondul: float = (sin(x * 0.55 + _t * 4.2) * 0.8
				+ sin(x * 1.1 - _t * 6.5 + 1.1) * 0.45) * (0.35 + prog)
			topo.append(_pt(x, lerpf(y0, y0 + ondul, edge)))
		draw_polyline(topo, Color(clara.r, clara.g, clara.b, 0.30), 5.0, true)
		draw_polyline(topo, clara, 1.7, true)

		# cristas claras perto da superficie
		for i in 2:
			var ph: float = fmod(_t * 0.9 + float(i) * 0.5, 1.0)
			var cx2: float = pad + fill_w * ph
			var fa2: float = sin(ph * PI)
			if cx2 < pad + fill_w - 1.0:
				_quad(cx2, y0 + 1.0, cx2 + 2.5, y0 + 3.0, Color(1, 1, 1, 0.16 * fa2))

		# ---- menisco luminoso
		draw_polyline(frente, Color(clara.r, clara.g, clara.b, 0.30), 6.0, true)
		draw_polyline(frente, clara, 2.0, true)

		# ---- base interna mais escura, reforca o volume
		draw_line(_pt(pad, y1 - 0.6), _pt(fx, y1 - 0.6),
			Color(fundo.r, fundo.g, fundo.b, 0.55), 1.0, true)

		# ---- bolhas subindo
		for i in 7:
			var fs: float = float(i) / 7.0
			var bx: float = pad + fill_w * (0.10 + 0.70 * fs)
			var ph: float = fmod(_t * (0.5 + 0.5 * fs) + float(i) * 0.31, 1.0)
			var by: float = lerpf(y1 - 1.0, y0 + 1.0, ph)
			var br: float = 0.5 + 0.5 * sin(_t * 6.0 + float(i) * 2.1)
			draw_circle(_pt(bx, by), 0.9 + 0.7 * br,
				Color(clara.r, clara.g, clara.b, 0.42 * br))

		# ---- brilho pulsante na parede do liquido
		var cy: float = lerpf(y0, y1, 0.5)
		var cx: float = pad + fill_w + _ond(cy, amp)
		draw_circle(_pt(cx, cy), 5.5 + 2.0 * sin(_t * 6.0), Color(c.r, c.g, c.b, 0.20))
		draw_circle(_pt(cx, cy), 2.4 + 1.2 * sin(_t * 10.0), Color(clara.r, clara.g, clara.b, 0.55))

	# ---- moldura
	var bc: Color = clara if pronta else Color(c.r, c.g, c.b, 0.9)
	var bw: float = 2.0 if pronta else 1.4
	var mold := PackedVector2Array([
		_pt(0, 0), _pt(w, 0), _pt(w, h), _pt(0, h), _pt(0, 0),
	])
	draw_polyline(mold, bc, bw, true)

	# ---- chanfros
	var k: float = 1.0 + 0.9 * pulso
	var bc2: Color = clara if pronta else Color(c.r, c.g, c.b, 0.7)
	draw_line(_pt(SK, 0), _pt(SK - BEVEL * k, 0), bc2, bw * 1.6, true)
	draw_line(_pt(w - BEVEL * k, h), _pt(w, h), bc2, bw * 1.6, true)

	# ---- aneis de choque quando carregado
	if pulso > 0.05:
		for i in 3:
			var ph2: float = fmod(_t * 1.6 + float(i) / 3.0, 1.0)
			var rr: float = ph2 * (w * 0.85 + 18.0)
			draw_arc(Vector2(w * 0.5, h * 0.5), rr, 0.0, TAU, 40,
				Color(clara.r, clara.g, clara.b, (1.0 - ph2) * 0.45 * pulso), 1.6, true)

	# ---- faiscas orbitando quando pronto
	if pulso > 0.2:
		for i in 8:
			var ang: float = _t * 2.2 + TAU * float(i) / 8.0
			var d: float = w * 0.5 + 6.0 + 5.0 * sin(_t * 6.0 + float(i))
			var p: Vector2 = Vector2(w * 0.5, h * 0.5) + Vector2(cos(ang), sin(ang) * 0.45) * d
			draw_circle(p, 1.6 + 0.8 * sin(_t * 9.0 + float(i)),
				Color(clara.r, clara.g, clara.b, 0.7 * pulso))
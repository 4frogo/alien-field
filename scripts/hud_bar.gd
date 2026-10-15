extends Control

# Barra de HUD moderna: preenchimento animado, brilho, flash ao levar dano,
# serrilhado e varredura. Reaproveitada no escudo e na vida do chefao.

const SK := 7.0

@export var cor: Color = Color(0.25, 1.0, 0.45)
@export var cor_fundo: Color = Color(0.05, 0.12, 0.08)
@export var mostrar_segmentos := false
@export var segmentos := 12

var valor := 1.0          # exibido (suavizado)
var alvo := 1.0           # desejado
var flash := 0.0          # 0..1, dispara quando alvo cai
var liquido := false      # efeito de liquido animado (escudo)
@export var onda_amp := 1.0

const SEG := 18

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var dif: float = alvo - valor
	if absf(dif) > 0.001:
		valor = lerpf(valor, alvo, clampf(delta * 9.0, 0.0, 1.0))
		queue_redraw()
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.2)
		queue_redraw()
	if liquido:
		queue_redraw()


func definir(v: float, v_max: float = 1.0) -> void:
	var novo: float = clampf(v / maxf(0.0001, v_max), 0.0, 1.0)
	if novo < alvo - 0.001:
		flash = 1.0                      # caiu = levou dano
	alvo = novo
	queue_redraw()


func _pt(x: float, y: float) -> Vector2:
	var h: float = maxf(1.0, size.y)
	return Vector2(x + SK * clampf(1.0 - y / h, 0.0, 1.0), y)


func _quad(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	if x1 - x0 < 0.05 or y1 - y0 < 0.05:
		return
	draw_colored_polygon(PackedVector2Array([
		_pt(x0, y0), _pt(x1, y0), _pt(x1, y1), _pt(x0, y1),
	]), col)


# --------------------------------------------------------------- liquido

# Deslocamento horizontal da superficie: 2 senos cruzados, nunca negativo.
func _ond(y: float, amp: float) -> float:
	var agit: float = 0.45 + 0.55 * clampf(valor, 0.0, 1.0)
	var v: float = (sin(y * 0.40 + _t * 3.1) * amp
		+ sin(y * 0.86 - _t * 4.7 + 1.7) * amp * 0.42) * agit
	return maxf(0.0, v)


# Liquido agitado dentro da barra: superficie ondulante, ondas internas,
# bolhas subindo, frente luminosa e brilho na parede.
func _desenha_liquido(c: Color, clara: Color, fundo: Color,
		pad: float, y0: float, y1: float, fw: float) -> void:
	var h: float = y1 - y0
	var amp: float = clampf(h * 0.13, 0.4, 2.0) * onda_amp

	# ---- corpo do liquido
	_quad(pad, y0, pad + fw, y1, Color(c.r, c.g, c.b, 0.50))

	# ---- profundidade: fundo mais escuro embaixo
	_quad(pad, y0 + h * 0.55, pad + fw, y1, Color(fundo.r, fundo.g, fundo.b, 0.30))
	_quad(pad, y0 + h * 0.80, pad + fw, y1, Color(fundo.r, fundo.g, fundo.b, 0.26))

	# ---- ondas internas rolando
	for i in 3:
		var ph: float = fmod(_t * (0.6 + 0.4 * float(i)) + float(i) * 0.37, 1.0)
		var sx: float = pad + (fw + h) * ph
		_quad(sx, y0, sx + h * 0.20, y1, Color(1, 1, 1, 0.09 * sin(ph * PI)))

	# ---- superficie superior ondulante (amplitude contida dentro da barra)
	var topo := PackedVector2Array()
	for i in range(SEG + 1):
		var x: float = pad + fw * (float(i) / float(SEG))
		var edge: float = clampf((float(i) / float(SEG)) * 4.0, 0.0, 1.0)
		var ondul: float = (sin(x * 0.42 + _t * 3.2) * 0.55
			+ sin(x * 0.88 - _t * 4.9 + 1.1) * 0.28) * (0.22 + valor * 0.55)
		# nunca deixa a superficie descer abaixo do topo nem furar o fundo
		ondul = clampf(ondul, -h * 0.10, h * 0.26)
		topo.append(_pt(x, y0 + ondul * edge))
	draw_polyline(topo, Color(clara.r, clara.g, clara.b, 0.26), 4.0, true)
	draw_polyline(topo, clara, 1.5, true)

	# ---- cristas claras perto da superficie
	for i in 2:
		var ph: float = fmod(_t * 0.8 + float(i) * 0.5, 1.0)
		var cx: float = pad + fw * ph
		if cx < pad + fw - 1.0:
			_quad(cx, y0 + 1.0, cx + 2.5, y0 + 3.0, Color(1, 1, 1, 0.15 * sin(ph * PI)))

	# ---- frente do liquido em faixas horizontais (estufando)
	for i in range(SEG):
		var ya: float = lerpf(y0, y1, float(i) / float(SEG))
		var yb: float = lerpf(y0, y1, float(i + 1) / float(SEG))
		_quad(pad + fw, ya, pad + fw + maxf(_ond(ya, amp), _ond(yb, amp)), yb,
			Color(c.r, c.g, c.b, 0.42))

	# ---- menisco luminoso na frente
	var frente := PackedVector2Array()
	for i in range(SEG + 1):
		var y: float = lerpf(y0, y1, float(i) / float(SEG))
		frente.append(_pt(pad + fw + _ond(y, amp), y))
	draw_polyline(frente, Color(clara.r, clara.g, clara.b, 0.28), 6.0, true)
	draw_polyline(frente, clara, 1.8, true)

	# ---- bolhas subindo
	for i in 6:
		var fs: float = float(i) / 6.0
		var bx: float = pad + fw * (0.12 + 0.72 * fs)
		var ph: float = fmod(_t * (0.45 + 0.45 * fs) + float(i) * 0.33, 1.0)
		var by: float = lerpf(y1 - 1.0, y0 + 1.0, ph)
		var br: float = 0.5 + 0.5 * sin(_t * 5.5 + float(i) * 2.1)
		draw_circle(_pt(bx, by), 0.9 + 0.7 * br, Color(clara.r, clara.g, clara.b, 0.40 * br))

	# ---- brilho pulsante na parede
	var cy: float = lerpf(y0, y1, 0.5)
	var cx2: float = pad + fw + _ond(cy, amp)
	draw_circle(_pt(cx2, cy), 5.0 + 1.8 * sin(_t * 5.5), Color(c.r, c.g, c.b, 0.18))
	draw_circle(_pt(cx2, cy), 2.2 + 1.0 * sin(_t * 9.0), Color(clara.r, clara.g, clara.b, 0.50))


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var pad := 1.0
	var y0: float = pad
	var y1: float = maxf(y0 + 0.5, h - pad)
	var fw: float = (w - pad * 2.0) * clampf(valor, 0.0, 1.0)

	# ---- moldura externa com glow
	var bc: Color = cor
	if flash > 0.0:
		bc = cor.lerp(Color(1, 1, 1), flash * 0.8)
	_quad(-2, -2, w + 2, h + 2, Color(bc.r, bc.g, bc.b, 0.10 + 0.22 * flash))

	# ---- fundo
	_quad(0, 0, w, h, Color(cor_fundo.r, cor_fundo.g, cor_fundo.b, 0.92))
	_quad(0, 0, w, h * 0.45, Color(0, 0, 0, 0.22))

	# ---- preenchimento
	if fw > 0.5:
		if liquido:
			# versao liquida (escudo): superfície ondulante, bolhas, menisco
			var clara: Color = cor.lerp(Color(1, 1, 1), 0.60)
			var fundo: Color = cor.lerp(Color(0.02, 0.06, 0.03), 0.70)
			_desenha_liquido(cor, clara, fundo, pad, y0, y1, fw)
		else:
			_quad(pad, y0, pad + fw, y1, Color(cor.r, cor.g, cor.b, 0.95))
			_quad(pad, y0, pad + fw, y0 + (y1 - y0) * 0.35, Color(1, 1, 1, 0.22))
			_quad(pad, y1 - (y1 - y0) * 0.30, pad + fw, y1, Color(0, 0, 0, 0.20))

			# varredura de brilho
			var sweep: float = fmod(_t * 55.0, w * 1.5) - w * 0.2
			if sweep > pad and sweep < pad + fw:
				_quad(sweep, y0, minf(sweep + 7.0, pad + fw), y1, Color(1, 1, 1, 0.26))

			# frente luminosa
			_quad(pad + fw - 1.6, y0, pad + fw, y1, Color(1, 1, 1, 0.55))

	# ---- segmentacao (barra do chefao)
	if mostrar_segmentos and fw > 1.0:
		var passo: float = fw / float(segmentos)
		for i in range(1, segmentos):
			var sx: float = pad + passo * float(i)
			_quad(sx, y0, sx + 1.2, y1, Color(0, 0, 0, 0.42))

	# ---- tracado
	var mold := PackedVector2Array([_pt(0, 0), _pt(w, 0), _pt(w, h), _pt(0, h), _pt(0, 0)])
	draw_polyline(mold, Color(bc.r, bc.g, bc.b, 0.9), 1.4, true)
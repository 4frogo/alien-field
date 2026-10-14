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
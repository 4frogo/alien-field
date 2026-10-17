extends Control

# Barra de HUD moderna: preenchimento animado, brilho, flash ao levar dano,
# serrilhado e varredura. Reaproveitada no escudo e na vida do chefao.

# SK a 0: a inclinacao empurrava ate 7px para fora e a barra passava do
# painel. O gostinho paralelogramo so saiu porque nao valia o transtorno.
const SK := 0.0

@export var cor: Color = Color(0.25, 1.0, 0.45)
@export var cor_fundo: Color = Color(0.05, 0.12, 0.08)
@export var mostrar_segmentos := false
@export var segmentos := 12

var valor := 1.0          # exibido (suavizado)
var alvo := 1.0           # desejado
var flash := 0.0          # 0..1, dispara quando alvo cai
var liquido := false      # efeito de liquido animado (escudo)
# modo PILULA: barra arredondada, sem o paralelograma inclinado (SK) que
# vazava para fora do painel do HUD. Usado nas barras do rodape.
@export var moderno := false
@export var onda_amp := 1.0
# modo TRILHO: fundo quase transparente (so um outline fino). O painel de
# vidro do HUD ja da o fundo — a barra nao precisa repetir, e assim da pra
# ver o plasma/liquido se movendo em vez de um bloco solido.
@export var trilho := false

# StyleBoxFlat reaproveitados a cada frame (criar 2 por frame em 2 barras
# seria desperdicio). So o bg_color/corner mudam, o resto fica.
var _sb_trilho := StyleBoxFlat.new()
var _sb_fill := StyleBoxFlat.new()

const SEG := 18

var _t := 0.0
# Textura branca 4x4 usada nos quads do liquido. Sem ela o shader nao tem
# UV pra amostrar (draw_colored_polygon nao gera textura). E so a mascara:
# quem pinta o plasma e o shader.
var _tex_branca: Texture2D = null
var _plasma_mat: ShaderMaterial = null


func _tex() -> Texture2D:
	if _tex_branca == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_tex_branca = ImageTexture.create_from_image(img)
	return _tex_branca


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aplicar_plasma()


func _aplicar_plasma() -> void:
	# plasma procedural sobre o liquido das barras. So no modo liquido —
	# a barra moderna (pílula) mantem o desenho atual.
	if not liquido:
		return
	if not ResourceLoader.exists("res://assets/plasma_barra.gdshader"):
		return
	_plasma_mat = ShaderMaterial.new()
	_plasma_mat.shader = load("res://assets/plasma_barra.gdshader") as Shader
	if _plasma_mat.shader == null:
		_plasma_mat = null
		return
	_plasma_mat.set_shader_parameter("cor_plasma", cor)
	_plasma_mat.set_shader_parameter("cor_quente",
		Color(minf(1.0, cor.r + 0.55), minf(1.0, cor.g + 0.15), minf(1.0, cor.b + 0.25)))
	material = _plasma_mat


func _process(delta: float) -> void:
	_t += delta
	if _plasma_mat != null:
		_plasma_mat.set_shader_parameter("tempo", fmod(_t, 100.0))
		_plasma_mat.set_shader_parameter("progresso", clampf(valor, 0.0, 1.0))
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
	# com plasma: desenha a textura branca (mascara) em vez de poligono,
	# assim o shader recebe UV e consegue gerar o plasma. A cor do quad
	# vai em modulate, que o shader preserva.
	if _plasma_mat != null:
		var r := Rect2(_pt(x0, y0), Vector2(x1 - x0, y1 - y0))
		draw_texture_rect(_tex(), r, false, col)
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


# -------------------------------------------------------------- moderno

# Barra em pilula: trilho escuro com cantos redondos, preenchimento solido
# com um fio de brilho no topo e flash branco quando leva dano.
func _desenha_moderno() -> void:
	var w: float = size.x
	var h: float = size.y
	var r: int = int(h * 0.5)
	var fra: float = clampf(valor, 0.0, 1.0)

	_sb_trilho.bg_color = Color(0.03, 0.07, 0.05, 0.90)
	_sb_trilho.set_corner_radius_all(r)
	_sb_trilho.set_border_width_all(1)
	_sb_trilho.border_color = Color(cor.r, cor.g, cor.b, 0.20)
	draw_style_box(_sb_trilho, Rect2(0, 0, w, h))

	if fra <= 0.004:
		return

	# o preenchimento nunca fica menor que a altura, senao o arredondamento
	# vira um ponto e a barra parece quebrada
	var wf: float = maxf(h, w * fra)
	var cc: Color = cor.lerp(Color(1, 1, 1), 0.08)
	if flash > 0.0:
		cc = cc.lerp(Color(1, 0.82, 0.82), flash * 0.65)
	_sb_fill.bg_color = cc
	_sb_fill.set_corner_radius_all(r)
	_sb_fill.set_border_width_all(0)
	draw_style_box(_sb_fill, Rect2(0, 0, wf, h))

	# fio de brilho no topo do liquido
	var m: float = h * 0.34
	draw_line(Vector2(m, h * 0.30), Vector2(maxf(m, wf - m), h * 0.30),
		Color(1, 1, 1, 0.20), maxf(1.0, h * 0.10), true)


func _draw() -> void:
	if moderno:
		_desenha_moderno()
		return
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
	if not trilho:
		_quad(-2, -2, w + 2, h + 2, Color(bc.r, bc.g, bc.b, 0.10 + 0.22 * flash))

	# ---- fundo
	if trilho:
		# SEM NADA: o painel de vidro do HUD ja da o fundo. Desenhar
		# qualquer retangulo aqui pintava o plasma por cima dele e a barra
		# ficava parecendo uma "area verde" solida.
		pass
	else:
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
	if not trilho:
		var mold := PackedVector2Array([_pt(0, 0), _pt(w, 0), _pt(w, h), _pt(0, h), _pt(0, 0)])
		draw_polyline(mold, Color(bc.r, bc.g, bc.b, 0.9), 1.4, true)
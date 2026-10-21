extends Control
# Barra de vida do CHEFE: a moldura (assets/barra vida boss.png) com o
# FLUIDO de vida DENTRO do canal.
#
# O canal e dividido em duas metades:
#   - VERMELHA (esquerda): etapa 1. Esvazia sozinha enquanto a vida cai
#     da maxima ate a metade.
#   - AMARELA (direita): etapa 2. Comeca a esvaziar quando a vermelha
#     acaba, ate a vida zerar.
# Entao: primeiro desce a parte vermelha, depois a amarela.
#
# O desenho e: fluido primeiro, moldura por cima. Como a arte tem alpha
# de verdade, o fluido so aparece DENTRO do buraco do canal.

const TEX := "res://assets/barra vida boss.png"
# canal (buraco) em UV da arte: x, y, largura, altura
const CANAL := Rect2(0.335, 0.418, 0.545, 0.108)

const COR_VERMELHA := Color(1.0, 0.20, 0.10)
const COR_AMARELA := Color(1.0, 0.80, 0.18)
const COR_BORDA := Color(1.0, 0.90, 0.75)

var _hp := 1.0        # 0..1 (vida total)
var _v := 1.0         # suavizado (a barra "desce" suave)
var _t := 0.0
var _tex: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TEX):
		_tex = load(TEX) as Texture2D


# hp = vida atual, p_max = vida maxima
func definir(p_hp: float, p_max: float) -> void:
	_hp = clampf(p_hp / maxf(1.0, p_max), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_v = lerpf(_v, _hp, clampf(delta * 9.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var w := size.x
	var h := size.y
	# o canal, em pixels do control
	var cr := Rect2(
		CANAL.position.x * w, CANAL.position.y * h,
		CANAL.size.x * w, CANAL.size.y * h)
	var meio := cr.size.x * 0.5
	# etapa 1: vermelha (metade esquerda) - esvazia de 100% ate 50% de vida
	var f_verm := clampf((_v - 0.5) * 2.0, 0.0, 1.0)
	# etapa 2: amarela (metade direita) - esvazia de 50% ate 0% de vida
	var f_amar := clampf(_v * 2.0, 0.0, 1.0)
	_fluido(Rect2(cr.position, Vector2(meio, cr.size.y)), f_verm, COR_VERMELHA)
	_fluido(Rect2(cr.position + Vector2(meio, 0.0), Vector2(meio, cr.size.y)), f_amar, COR_AMARELA)
	# moldura por cima: o que sobrou do canal fica coberto pela arte
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


# fluido com superficie ondulante que avanca dentro do retangulo
func _fluido(r: Rect2, frac: float, cor: Color) -> void:
	if frac <= 0.002:
		return
	var larg := r.size.x * frac
	var alt := 0.10
	var pts := PackedVector2Array()
	var n := 16
	for i in range(n + 1):
		var t := float(i) / float(n)
		var x := r.position.x + larg * t
		var y := r.position.y + sin(t * 8.0 + _t * 5.0) * alt * (0.35 + 0.65 * t)
		pts.append(Vector2(x, y))
	pts.append(Vector2(r.position.x + larg, r.position.y + r.size.y))
	pts.append(Vector2(r.position.x, r.position.y + r.size.y))
	draw_colored_polygon(pts, cor)
	# frente brilhante (a onda que "desce")
	var frente := PackedVector2Array()
	for i in range(n + 1):
		frente.append(pts[i])
	draw_polyline(frente, cor.lerp(COR_BORDA, 0.6), 2.0, true)

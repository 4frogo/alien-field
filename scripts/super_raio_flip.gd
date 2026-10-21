extends Node2D
# Efeito do SUPER TIRO CARREGADO — so na nave ROXA.
#
# Flipbook de 32 quadros recortado de assets/raio roxo.png:
#    0..9   (10 de 217x217)  vortice girando na boca da nave
#    10..21 (2 faixas de 6 de 362x~157)  o feixe se formando
#    22..31 (10 de 217x192)   o feixe se desmanchando em particulas
#
# A arte do feixe e HORIZONTAL (a origem, o nucleo branco, fica na
# esquerda). Na tela o feixe sobe da nave, entao essa fase gira -90
# graus: o eixo +X local vira "para cima" no mundo.
#
# O no e top_level (como o rastro): nao herda a inclinacao da nave.

const TEX := "res://assets/raio roxo.png"

const N_VORTICE := 10
const N_FEIXE := 6
const N_DISPERSAO := 10
const L_VORTICE := 217.0
const L_FEIXE := 362.0
const H_FEIXE_A := 165.0
const H_FEIXE_B := 150.0
const H_DISPERSAO := 192.0
const Y_VORTICE := 0.0
const Y_FEIXE_A := 217.0
const Y_FEIXE_B := 382.0
const Y_DISPERSAO := 532.0

enum Fase { NADA, VORTICE, FEIXE, DISPERSAO }

var fase := Fase.NADA
var _t := 0.0
var _i := 0
var _tex: Texture2D = null
var _fps := 14.0
var _esc := 1.0
var _alfa := 1.0
var _vira := 0.0     # 1 = ao terminar o feixe, passa pra dissipacao


func _ready() -> void:
	if not ResourceLoader.exists(TEX):
		return
	_tex = load(TEX) as Texture2D
	visible = false


# a energia girando na boca enquanto o super carrega
func tocar_vortice(carga: float) -> void:
	if _tex == null:
		return
	# se o feixe ja saiu, nao mexe em nada (o vortice nao pode voltar
	# nem zerar a rotacao do feixe)
	if fase == Fase.FEIXE or fase == Fase.DISPERSAO:
		return
	if fase != Fase.VORTICE:
		fase = Fase.VORTICE
		_i = 0
		_t = 0.0
		_fps = 12.0
		rotation = 0.0
	_esc = 0.34 + 0.72 * clampf(carga, 0.0, 1.0)
	_alfa = 0.30 + 0.70 * clampf(carga, 0.0, 1.0)
	visible = true


# o feixe sai: primeiro o feixe, depois a dissipacao
func tocar_feixe() -> void:
	if _tex == null:
		return
	fase = Fase.FEIXE
	_i = 0
	_t = 0.0
	_fps = 12.0
	_vira = 1
	rotation = -PI * 0.5
	_esc = 1.15
	_alfa = 1.0
	visible = true


func parar() -> void:
	fase = Fase.NADA
	visible = false


# so interrompe o vortice (o feixe que ja saiu continua)
func parar_vortice() -> void:
	if fase == Fase.VORTICE:
		parar()


func _process(delta: float) -> void:
	if fase == Fase.NADA or _tex == null:
		return
	_t += delta
	var dur := 1.0 / _fps
	var n := _n_quadros()
	while _t >= dur:
		_t -= dur
		_i += 1
		if _i >= n:
			if fase == Fase.FEIXE and _vira > 0:
				fase = Fase.DISPERSAO
				_i = 0
				_t = 0.0
				_fps = 16.0
				rotation = 0.0
				_esc = 0.95
			elif fase == Fase.DISPERSAO:
				parar()
				return
			else:
				_i = 0   # o vortice faz loop
	queue_redraw()


func _n_quadros() -> int:
	match fase:
		Fase.VORTICE:
			return N_VORTICE
		Fase.FEIXE:
			return N_FEIXE * 2
		Fase.DISPERSAO:
			return N_DISPERSAO
	return 1


func _draw() -> void:
	if _tex == null or fase == Fase.NADA:
		return
	var src := Rect2()
	var dest := Rect2()
	match fase:
		Fase.VORTICE:
			src = Rect2(float(_i) * L_VORTICE, Y_VORTICE, L_VORTICE, L_VORTICE)
			dest = Rect2(-L_VORTICE * 0.5 * _esc, -L_VORTICE * 0.5 * _esc,
				L_VORTICE * _esc, L_VORTICE * _esc)
		Fase.FEIXE:
			var idx := _i
			var linha := 0
			if idx >= N_FEIXE:
				linha = 1
				idx -= N_FEIXE
			var alt := H_FEIXE_A if linha == 0 else H_FEIXE_B
			var yy := Y_FEIXE_A if linha == 0 else Y_FEIXE_B
			src = Rect2(float(idx) * L_FEIXE, yy, L_FEIXE, alt)
			# desenhado a partir da origem (esquerda): com rotation -90 sobe
			dest = Rect2(0.0, -alt * 0.5 * _esc, L_FEIXE * _esc, alt * _esc)
		Fase.DISPERSAO:
			src = Rect2(float(_i) * L_VORTICE, Y_DISPERSAO, L_VORTICE, H_DISPERSAO)
			dest = Rect2(-L_VORTICE * 0.5 * _esc, -H_DISPERSAO * 0.5 * _esc,
				L_VORTICE * _esc, H_DISPERSAO * _esc)
	draw_texture_rect_region(_tex, dest, src, Color(1, 1, 1, _alfa))

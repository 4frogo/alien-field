extends Node2D
# NEBLINA: camada de nevoa procedural que passa NA FRENTE do cenario e das
# naves, mas ATRAS do HUD (que e CanvasLayer e por isso sempre fica por
# cima do mundo).
#
# Fica no mundo (nao em CanvasLayer) com z_index alto, entao:
#   nebulosa do fundo (z=-20) < cenario (z=-10) < naves/tiros (0) < NEBLINA (60)
# O resultado e profundidade: o que esta no fundo fica mais apagado.
#
# A cor muda por dimensao (verde na fase 1, quente na arena do chefe) e a
# neblina respira devagar ao longo do tempo.

const SH := preload("res://assets/neblina.gdshader")

var mat: ShaderMaterial = null
var rect: ColorRect = null
var t := 0.0
var scroll := 0.0
var dimensao := 1
# velocidade do scroll do fundo (espelha o background.gd) pra dar parallax
const SCROLL_SPEED := 45.0


func _ready() -> void:
	# ENTRE o cenario e as naves: o cenario fica em z=-10/-20 e as naves
	# (player, inimigos, tiros, explosoes) em z=0. Com a nevoa em -5 ela
	# passa por cima do cenario, mas as naves ficam LIMPAS por cima dela.
	# CanvasLayers (HUD, flash, pausa) continuam acima de tudo.
	z_index = -5
	z_as_relative = false
	mat = ShaderMaterial.new()
	mat.shader = SH
	rect = ColorRect.new()
	rect.material = mat
	rect.color = Color(1, 1, 1, 1)
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# maior que a tela: a camera afastada (zoom 0.92) mostra alem de
	# 540x960, e sem isto a neblina deixava tarja preta nas bordas
	rect.size = Vector2(700, 1240)
	rect.position = Vector2(-80, -140)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_aplicar()


func trocar_dimensao(n: int) -> void:
	dimensao = n
	_aplicar()


func _aplicar() -> void:
	if mat == null:
		return
	# a nevoa segue a paleta da NAVE escolhida: verde na nave padrao,
	# violeta/rosa na nave roxa (a regra do jogo: cada nave tem a
	# sua cor). Na dimensao 2 (arena do chefe) ela esquenta.
	# A busca do autoload e segura: em teste/script solto o singleton
	# nao existe e o jogo nao pode quebrar por causa da cor.
	var esc := get_node_or_null("/root/Escolha")
	var roxa := false
	if esc != null and esc.has_method("e_roxa"):
		roxa = bool(esc.call("e_roxa"))
	if dimensao == 2:
		if roxa:
			mat.set_shader_parameter("cor_nevoa", Color(0.85, 0.25, 0.85))
			mat.set_shader_parameter("cor_luz", Color(1.0, 0.70, 1.0))
		else:
			mat.set_shader_parameter("cor_nevoa", Color(0.95, 0.40, 0.30))
			mat.set_shader_parameter("cor_luz", Color(1.0, 0.72, 0.58))
		mat.set_shader_parameter("forca", 0.95)
	else:
		if roxa:
			mat.set_shader_parameter("cor_nevoa", Color(0.55, 0.18, 0.85))
			mat.set_shader_parameter("cor_luz", Color(0.95, 0.70, 1.0))
		else:
			mat.set_shader_parameter("cor_nevoa", Color(0.26, 0.80, 0.50))
			mat.set_shader_parameter("cor_luz", Color(0.80, 1.0, 0.90))
		mat.set_shader_parameter("forca", 1.0)


func _process(delta: float) -> void:
	t += delta
	scroll += SCROLL_SPEED * delta
	if mat == null:
		return
	mat.set_shader_parameter("tempo", fmod(t, 100.0))
	mat.set_shader_parameter("scroll", fmod(scroll, 2000.0))
	# respiracao suave: a neblina engorda e murcha, nunca fica estatica
	# respiracao MUITO suave: a neblina quase nao muda de tamanho, so
	# ondula devagar (o jogo ja tem bastante movimento)
	var resp := 1.0 + 0.06 * sin(t * 0.05)
	mat.set_shader_parameter("opacidade", 0.78 * resp)

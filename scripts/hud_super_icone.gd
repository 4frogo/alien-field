extends Control
# Icone do SUPER TIRO no canto INFERIOR ESQUERDO: moldura SUPER.png com
# liquido de plasma enchendo da ESQUERDA PRA DIREITA conforme a carga
# (super_icone.gdshader). Cheio (pronta=true): o icone inteiro cicla em
# RGB ate o jogador soltar o tiro. Espelha o icone de escudo da direita.
# Se o shader nao carregar, aparece so a moldura (sem liquido).

var prog := 0.0
var pronta := false
var _pulso := 0.0
var _t := 0.0
var _mat: ShaderMaterial = null
var _tex: Texture2D = null


func _ready() -> void:
	# sem isso o Control comeria os toques na area do canto
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = load("res://assets/SUPER.png") as Texture2D
	if _tex == null:
		return
	if not ResourceLoader.exists("res://assets/super_icone.gdshader"):
		return
	var sh := load("res://assets/super_icone.gdshader") as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("tex", _tex)
	material = _mat


func _process(delta: float) -> void:
	_t += delta
	if pronta:
		_pulso = minf(1.0, _pulso + delta * 3.0)
	else:
		_pulso = maxf(0.0, _pulso - delta * 3.0)
	if _mat != null:
		_mat.set_shader_parameter("tempo", _t)
		_mat.set_shader_parameter("carga", clampf(prog, 0.0, 1.0))
		_mat.set_shader_parameter("pronto", _pulso)


func _draw() -> void:
	if _tex == null:
		return
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)

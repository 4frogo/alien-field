extends Control
# Icone do SUPER TIRO no canto INFERIOR ESQUERDO: quad 164x164 — metade
# de baixo = moldura barrasuperhold.png (verde, sem o nome) com liquido
# de plasma enchendo da ESQUERDA PRA DIREITA conforme a carga; metade de
# cima = AR, onde voam os raios REALISTAS quando a carga chega no maximo
# com o L ainda segurado (pronta=true, super_icone.gdshader). Soltou o
# tiro: o vidro ESTOURA e o liquido vira particulas no ar (explodir(),
# auto-disparado pela queda da carga cheia). Se o shader nao carregar,
# aparece so a moldura (sem liquido).

var prog := 0.0:
	set(v):
		# carga cheia caindo de uma vez = soltou o super -> estoura o vidro
		if v < 0.15 and prog > 0.85:
			explodir()
		prog = v
var pronta := false
var _pulso := 0.0
var _t := 0.0
var _exp_t := -1.0 # >=0: tempo de explosao correndo; -1 = parado
var _carga_exp := 1.0
var _mat: ShaderMaterial = null
var _tex: Texture2D = null


func explodir() -> void:
	# vidro estoura + liquido vira particulas (uma vez por disparo)
	if _exp_t >= 0.0:
		return
	_exp_t = 0.0
	_carga_exp = maxf(prog, 0.6)


func _ready() -> void:
	# sem isso o Control comeria os toques na area do canto
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = load("res://assets/barrasuperhold.png") as Texture2D
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
	var ex := 0.0
	if _exp_t >= 0.0:
		_exp_t += delta
		if _exp_t > 1.1:
			_exp_t = -1.0
		else:
			ex = clampf(_exp_t / 0.95, 0.0, 1.0)
	if _mat != null:
		_mat.set_shader_parameter("tempo", _t)
		_mat.set_shader_parameter("carga", clampf(prog, 0.0, 1.0))
		_mat.set_shader_parameter("pronto", _pulso)
		_mat.set_shader_parameter("explosao", ex)
		_mat.set_shader_parameter("carga_exp", _carga_exp)


func _draw() -> void:
	if _tex == null:
		return
	if _mat == null:
		# sem shader: so a moldura quieta na metade de baixo do quad
		draw_texture_rect(_tex,
			Rect2(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5)),
			false)
		return
	# quad INTEIRO (164x164): a metade de cima e o AR onde os raios
	# REALISTAS voam. A arte vem do uniform tex amostrado no shader,
	# entao aqui basta dar fragmentos em todo o retangulo.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.004))

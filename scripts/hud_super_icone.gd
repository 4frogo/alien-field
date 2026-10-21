extends Control
# Icone do SUPER TIRO no canto INFERIOR ESQUERDO: quad 164x164 â€” metade
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
var _arte_rect := Vector4(0.0, 0.5, 1.0, 0.5)

# PELE VERDE (nave padrao) e PELE ROXA (nave VIOLET). A roxa usa
# barra roxa super.png (2094x751, ~2,8:1, com ALPHA) numa faixa de
# 164x59 no rodape do icone, com plasma roxo e arcos eletricos.
const TEX_VERDE := "res://assets/barrasuperhold.png"
const TEX_ROXA := "res://assets/barra roxa super.png"


func explodir() -> void:
	# vidro estoura + liquido vira particulas (uma vez por disparo)
	if _exp_t >= 0.0:
		return
	_exp_t = 0.0
	_carga_exp = maxf(prog, 0.6)


func _ready() -> void:
	# sem isso o Control comeria os toques na area do canto
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var roxa := _eh_roxa()
	_tex = load(TEX_ROXA if roxa else TEX_VERDE) as Texture2D
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
	if roxa:
		# arte 2,8:1 numa faixa de 164x59 encostada no rodape do quad
		_arte_rect = Vector4(0.0, 0.64, 1.0, 0.36)
		_mat.set_shader_parameter("arte_rect", _arte_rect)
		# canal do liquido medido na arte (uv 0,40..0,61 na vertical)
		_mat.set_shader_parameter("vidro_eixo", Vector2(0.30, 0.105))
		_mat.set_shader_parameter("vidro_centro", Vector2(0.5, 0.506))
		_mat.set_shader_parameter("key_alpha", 1.0)
		# plasma roxo: violeta -> magenta -> violeta claro na carga cheia
		_mat.set_shader_parameter("cor_baixa", Color(0.45, 0.20, 0.95))
		_mat.set_shader_parameter("cor_media", Color(0.72, 0.35, 1.0))
		_mat.set_shader_parameter("cor_alta", Color(0.95, 0.70, 1.0))
		_mat.set_shader_parameter("cor_branco", Color(0.95, 0.85, 1.0))
		_mat.set_shader_parameter("cor_azul", Color(0.55, 0.40, 1.0))
		_mat.set_shader_parameter("cor_tanque", Color(0.10, 0.03, 0.18))
	material = _mat


func _eh_roxa() -> bool:
	# a nave escolhida no menu (autoload Escolha) define a pele do HUD
	return Escolha.e_roxa()


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
		# sem shader: so a moldura quieta no retangulo da arte
		var r := Rect2(
			Vector2(_arte_rect.x, _arte_rect.y) * size,
			Vector2(_arte_rect.z, _arte_rect.w) * size)
		draw_texture_rect(_tex, r, false)
		return
	# quad INTEIRO (164x164): a metade de cima e o AR onde os raios
	# REALISTAS voam. A arte vem do uniform tex amostrado no shader,
	# entao aqui basta dar fragmentos em todo o retangulo.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.004))

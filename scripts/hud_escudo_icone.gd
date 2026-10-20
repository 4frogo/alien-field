extends Control
# Icone de ESCUDO no canto INFERIOR DIREITO: quad 164x164 — metade de
# baixo = moldura escudoG.png com liquido de PARTICULAS de plasma
# (verdes + vermelhas fervendo); metade de cima = AR onde as particulas
# da EXPLOSAO voam. O dano drena o liquido da DIREITA PRA ESQUERDA ate
# sumir; ao ZERAR o vidro ESTOURA (explodir(), uma unica vez por queda).
# Escudo CRITICO (ultimo quarto): particulas ficam vermelhas e o
# liquido pulsa. definir(v, vmax) -> nivel 0..1 com lerp suave.
# Se o shader nao carregar, aparece so a moldura.

var valor := 1.0
var alvo := 1.0
var _vmax := 100.0
var _t := 0.0
var _exp_t := -1.0 # >=0: tempo de explosao correndo; -1 = parado
var _nivel_exp := 1.0
var _mat: ShaderMaterial = null
var _tex: Texture2D = null


func _ready() -> void:
	# sem isso o Control comeria os toques na area do canto
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = load("res://assets/escudoG.png") as Texture2D
	if _tex == null:
		return
	if not ResourceLoader.exists("res://assets/escudo_icone.gdshader"):
		return
	var sh := load("res://assets/escudo_icone.gdshader") as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("tex", _tex)
	material = _mat


func definir(v: float, vmax: float) -> void:
	_vmax = maxf(vmax, 1.0)
	var nv := clampf(v / _vmax, 0.0, 1.0)
	# escudo zera = estoura o vidro (uma unica vez por queda)
	if nv <= 0.001 and alvo > 0.001:
		explodir()
	alvo = nv


func explodir() -> void:
	# vidro estoura + liquido vira particulas no ar
	if _exp_t >= 0.0:
		return
	_exp_t = 0.0
	_nivel_exp = maxf(valor, 0.35)


func _process(delta: float) -> void:
	_t += delta
	valor = lerpf(valor, alvo, minf(1.0, delta * 7.0))
	var ex := 0.0
	if _exp_t >= 0.0:
		_exp_t += delta
		if _exp_t > 1.1:
			_exp_t = -1.0
		else:
			ex = clampf(_exp_t / 0.95, 0.0, 1.0)
	# critico: ultimo quarto (25 de 100) -> particulas vermelhas + pulso
	var nv := clampf(valor / _vmax, 0.0, 1.0)
	var crit := smoothstep(0.36, 0.27, nv) * (1.0 if nv >= 0.01 else 0.0)
	if _mat != null:
		_mat.set_shader_parameter("tempo", _t)
		_mat.set_shader_parameter("nivel", valor)
		_mat.set_shader_parameter("critico", crit)
		_mat.set_shader_parameter("explosao", ex)
		_mat.set_shader_parameter("nivel_exp", _nivel_exp)


func _draw() -> void:
	if _tex == null:
		return
	if _mat == null:
		# sem shader: so a moldura quieta na metade de baixo do quad
		draw_texture_rect(_tex,
			Rect2(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5)),
			false)
		return
	# quad INTEIRO: metade de cima = ar (a explosao voa pra fora da moldura)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.004))

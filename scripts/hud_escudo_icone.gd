extends Control
# Icone de ESCUDO no canto INFERIOR DIREITO: quad 164x164 â€” metade de
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
var _arte_rect := Vector4(0.0, 0.5, 1.0, 0.5)

# PELE VERDE (nave padrao) e PELE ROXA (nave VIOLET). A roxa usa
# moldura escudo roxo.png (1254x1254, quadrada, com ALPHA) no quadrado
# de 82x82 do canto do icone, e o plasma roxo com arcos eletricos.
const TEX_VERDE := "res://assets/escudoG.png"
const TEX_ROXA := "res://assets/moldura escudo roxo.png"


func _ready() -> void:
	# sem isso o Control comeria os toques na area do canto
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var roxa := _eh_roxa()
	_tex = load(TEX_ROXA if roxa else TEX_VERDE) as Texture2D
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
	if roxa:
		# arte quadrada no quadrado de 82x82 (canto inferior DIREITO do
		# quad 164x164, encostado no rodape); buraco da moldura medido
		_arte_rect = Vector4(0.5, 0.5, 0.5, 0.5)
		_mat.set_shader_parameter("arte_rect", _arte_rect)
		# o vidro e a elipse do buraco: 0.88 do raio (o smoothstep do
		# shader), entao o eixo e um pouco maior pra ENCHER o buraco
		_mat.set_shader_parameter("vidro_eixo", Vector2(0.267, 0.230))
		_mat.set_shader_parameter("vidro_centro", Vector2(0.5, 0.487))
		_mat.set_shader_parameter("key_alpha", 1.0)
		_mat.set_shader_parameter("eletrico", 1.0)
		# o plasma ilumina o interior TODO do vidro
		_mat.set_shader_parameter("leito_cor", 1.0)
		_mat.set_shader_parameter("leito_alfa", 0.85)
		# plasma roxo com nucleo quase branco e critico magenta
		_mat.set_shader_parameter("cor_liq", Color(0.62, 0.30, 1.0))
		_mat.set_shader_parameter("cor_fund", Color(0.16, 0.05, 0.30))
		_mat.set_shader_parameter("cor_part", Color(0.92, 0.80, 1.0))
		_mat.set_shader_parameter("cor_crit", Color(1.0, 0.42, 0.95))
		_mat.set_shader_parameter("cor_vidro", Color(0.08, 0.03, 0.14))
		_mat.set_shader_parameter("cor_onda", Color(0.85, 0.70, 1.0))
	material = _mat


func _eh_roxa() -> bool:
	# a nave escolhida no menu (autoload Escolha) define a pele do HUD
	return Escolha.e_roxa()


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
		# sem shader: so a moldura quieta no retangulo da arte
		var r := Rect2(
			Vector2(_arte_rect.x, _arte_rect.y) * size,
			Vector2(_arte_rect.z, _arte_rect.w) * size)
		draw_texture_rect(_tex, r, false)
		return
	# quad INTEIRO: metade de cima = ar (a explosao voa pra fora da moldura)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.004))

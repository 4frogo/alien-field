extends Control
# Icone de ESCUDO no canto INFERIOR DIREITO: moldura escudoG.png com
# liquido de plasma verde se movendo dentro (escudo_icone.gdshader).
# definir(v, vmax) -> nivel 0..1 com lerp suave (drena/engarrafa).
# Se o shader nao carregar, o icone aparece sem liquido (so a moldura).

var valor := 1.0
var alvo := 1.0
var _t := 0.0
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
	if vmax <= 0.0:
		alvo = 0.0
	else:
		alvo = clampf(v / vmax, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	valor = lerpf(valor, alvo, minf(1.0, delta * 7.0))
	if _mat != null:
		_mat.set_shader_parameter("tempo", _t)
		_mat.set_shader_parameter("nivel", valor)


func _draw() -> void:
	if _tex == null:
		return
	# draw_texture_rect garante UV 0..1 no quad; com o material, o shader
	# ignora a cor base e compoe liquido + moldura ele mesmo
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)

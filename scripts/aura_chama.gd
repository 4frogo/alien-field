extends Sprite2D
# AURA DE CHAMA — envolve a nave enquanto a arma (Gunn) esta ativa.
# Nao e um escudo: e "a nave pegando fogo" de arma equipada.
# Diferente da bolha de escudo (escudo_bolha.gd): esta dura o tempo todo
# do tiro triplo (15s). Se o shader falhar, o no simplesmente nao aparece.

var mat: ShaderMaterial = null
var t := 0.0
var dur := 15.0
var ativo := false


func _ready() -> void:
	z_index = -1   # a aura fica ATRAS do casco
	visible = false
	if not ResourceLoader.exists("res://assets/aura_chama.gdshader"):
		queue_free()
		return
	mat = ShaderMaterial.new()
	mat.shader = load("res://assets/aura_chama.gdshader") as Shader
	if mat.shader == null:
		mat = null
		queue_free()
		return
	material = mat
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	texture = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(true)


func configurar(px: float) -> void:
	centered = true
	scale = Vector2(px / 4.0, px / 4.0)


func ligar(duracao: float) -> void:
	dur = maxf(0.2, duracao)
	ativo = true
	visible = true
	if mat != null:
		mat.set_shader_parameter("ativo", 1.0)


func desligar() -> void:
	ativo = false
	visible = false
	if mat != null:
		mat.set_shader_parameter("ativo", 0.0)


func _process(delta: float) -> void:
	if mat == null:
		return
	t += delta
	mat.set_shader_parameter("tempo", fmod(t, 100.0))
	if not ativo:
		return
	# reativa enquanto dura; o main desliga no fim (mesmo tempo do power)
	var restante := dur - t
	if restante <= 1.5:
		# apaga suave nos ultimos 1.5s
		var k: float = clampf(restante / 1.5, 0.0, 1.0)
		mat.set_shader_parameter("ativo", k)
	if t >= dur:
		desligar()
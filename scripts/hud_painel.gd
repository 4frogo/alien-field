extends TextureRect
# Painel do HUD desenhado com shader (hud_painel.gdshader).
# Substitui os Panel + StyleBoxFlat que faziam moldura verde.
# A textura e branca 4x4: so a mascara/UV; a forma vem do shader.

var mat: ShaderMaterial = null
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = _tex()
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	if not ResourceLoader.exists("res://assets/hud_painel.gdshader"):
		return
	mat = ShaderMaterial.new()
	mat.shader = load("res://assets/hud_painel.gdshader") as Shader
	if mat.shader == null:
		mat = null
		return
	material = mat
	set_process(true)


func _tex() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if mat == null:
		return
	_t += delta
	mat.set_shader_parameter("tempo", fmod(_t, 100.0))


func configurar(cor_acento: Color, c_cor_fundo: Color = Color(0.015, 0.045, 0.030, 0.72),
		moldura: bool = true, fundo: bool = true) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("cor_acento", cor_acento)
	mat.set_shader_parameter("cor_borda", Color(cor_acento.r, cor_acento.g, cor_acento.b, 0.55))
	mat.set_shader_parameter("cor_fundo", c_cor_fundo)
	# `moldura=false` tira a caixa verde em volta (borda + acento + brilho de
	# canto) e `fundo=false` tira tambem o vidro atras. As barrinhas que sao
	# filhas deste painel nao sao afetadas — elas continuam com o liquido, a
	# superficie, as bolhas e o plasma intactos.
	mat.set_shader_parameter("mostrar_borda", 1.0 if moldura else 0.0)
	mat.set_shader_parameter("mostrar_fundo", 1.0 if fundo else 0.0)
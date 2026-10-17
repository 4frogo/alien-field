extends Sprite2D
# Bolha de escudo temporaria (colmeia de octogonos).
# Fica como filho do player, nao tem nada a ver com o arte da nave:
# se o shader falhar, o no simplesmente nao aparece.

var mat: ShaderMaterial = null
var t := 0.0
var dur := 5.0
var fading := false


func _ready() -> void:
	z_index = 2   # na frente do casco
	if not ResourceLoader.exists("res://assets/escudo_colmeia.gdshader"):
		queue_free()
		return
	mat = ShaderMaterial.new()
	mat.shader = load("res://assets/escudo_colmeia.gdshader") as Shader
	if mat.shader == null:
		mat = null
		queue_free()
		return
	material = mat
	# textura branca 4x4: so a mascara/UV, quem pinta e o shader
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	texture = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(true)


func configurar(px: float) -> void:
	# a bolha e um quadrado de lado px, centrado na nave
	centered = true
	scale = Vector2(px / 4.0, px / 4.0)
	if mat != null:
		mat.set_shader_parameter("raio_bolha", 1.0)


func ligar(duracao: float) -> void:
	dur = maxf(0.2, duracao)
	fading = false
	visible = true
	if mat != null:
		mat.set_shader_parameter("fade_saida", 1.0)


func _process(delta: float) -> void:
	if mat == null:
		queue_free()
		return
	t += delta
	mat.set_shader_parameter("tempo", fmod(t, 100.0))

	# fade nos ultimos 0.8s: pisca antes de sumir, avisa que ta acabando
	var restante := dur - t
	if restante <= 0.8:
		fading = true
		var blink: float = 0.25 + 0.75 * absf(sin(t * 9.0))
		mat.set_shader_parameter("fade_saida", blink)
	if t >= dur:
		queue_free()
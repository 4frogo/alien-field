extends Node2D
# SHURIKEN DE ENERGIA — tiro carregado da CAIXA VERMELHA.
#
# E energia girando, nao lamina fisica:
#   - o visual vem do shuriken_energia.gdshader (Sprite2D filho)
#   - VFX: anel de energia + rastro de particulas
#   - persegue levemente (homing suave) para nao exigir mira perfeita
#   - perfura ate PERFURAR inimigos antes de se dissolver
#
# Se o shader nao carregar, o desenho em codigo (_draw) assume como fallback.

const PERFURAR := 3
const VIDA := 3.6
const DANO := 15             # dano aumentado de 8 para 15
const GIRO := 26.0
# HOMING = 0: a shuriken vai reto, sem rastreamento de alvo

var vel := Vector2(0, -1)
var velocidade := 480.0
var vida := VIDA
var tempo := 0.0
var vivo := true
var perfurou := 0
var hits: Array = []
var rastro: Array = []
var fase := 0.0

var spr: Sprite2D = null
var mat: ShaderMaterial = null
var fx: Sprite2D = null          # anel de energia (VFX)
var fx_mat: ShaderMaterial = null
var alvo: Node2D = null


func setup(p: Vector2, ang: float = -PI / 2.0, p_alvo: Node2D = null) -> void:
	position = p
	vel = Vector2(cos(ang), sin(ang))
	fase = randf() * TAU
	alvo = p_alvo
	_criar_visual()


func _criar_visual() -> void:
	# --- shuriken com shader ---
	if ResourceLoader.exists("res://assets/shuriken_energia.gdshader"):
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		spr = Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(img)
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.z_index = 1
		mat = ShaderMaterial.new()
		mat.shader = load("res://assets/shuriken_energia.gdshader") as Shader
		if mat.shader != null:
			mat.set_shader_parameter("comprimento_ponta", 0.99)
			mat.set_shader_parameter("largura_lama", 0.20)
			mat.set_shader_parameter("curvatura", 0.30)
			mat.set_shader_parameter("giro", 28.0)
			if Escolha.e_roxa():
				mat.set_shader_parameter("cor_energia", Color(1.0, 0.42, 0.10))
				mat.set_shader_parameter("cor_quente", Color(1.0, 0.90, 0.60))
			else:
				mat.set_shader_parameter("cor_energia", Color(0.10, 0.95, 0.30))
				mat.set_shader_parameter("cor_quente", Color(0.70, 1.0, 0.75))
			spr.material = mat
			spr.scale = Vector2(120.0 / 4.0, 120.0 / 4.0)
		else:
			mat = null
		add_child(spr)

	# --- anel de energia em volta (VFX) ---
	if ResourceLoader.exists("res://assets/energy_ball.gdshader"):
		fx = Sprite2D.new()
		var img2 := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img2.fill(Color(1, 1, 1, 1))
		fx.texture = ImageTexture.create_from_image(img2)
		fx.centered = true
		fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fx.z_index = 0
		fx_mat = ShaderMaterial.new()
		fx_mat.shader = load("res://assets/energy_ball.gdshader") as Shader
		if fx_mat.shader != null:
			fx_mat.set_shader_parameter("charge", 0.35)
			fx_mat.set_shader_parameter("speed", 4.0)
			if Escolha.e_roxa():
				fx_mat.set_shader_parameter("core_color", Color(1.0, 0.95, 0.85))
				fx_mat.set_shader_parameter("mid_color", Color(1.0, 0.55, 0.20))
				fx_mat.set_shader_parameter("outer_color", Color(0.8, 0.25, 0.05))
				fx.modulate = Color(1.0, 0.45, 0.10, 0.30)
			else:
				fx_mat.set_shader_parameter("core_color", Color(0.85, 1.0, 0.90))
				fx_mat.set_shader_parameter("mid_color", Color(0.15, 0.95, 0.40))
				fx_mat.set_shader_parameter("outer_color", Color(0.02, 0.45, 0.15))
				fx.modulate = Color(0.10, 0.95, 0.30, 0.30)
			fx.material = fx_mat
			fx.scale = Vector2(190.0 / 4.0, 190.0 / 4.0)
		else:
			fx_mat = null
		add_child(fx)


func _process(delta: float) -> void:
	tempo += delta
	vida -= delta

	# gira o no (o shader tambem gira o rastro, entao nao fica parado)
	rotation += GIRO * delta + sin(tempo * 9.0 + fase) * 2.2 * delta

	# shuriken vai reto (sem homing/rastreamento)
	# perde velocidade no fim da vida (gastando energia)
	var k: float = clampf(vida / VIDA, 0.0, 1.0)
	position += vel * velocidade * (0.45 + 0.55 * k) * delta

	# rastro
	rastro.append(position)
	while rastro.size() > 10:
		rastro.pop_front()

	# alimenta os shaders
	if mat != null:
		mat.set_shader_parameter("tempo", fmod(tempo, 100.0))
	if fx_mat != null:
		fx_mat.set_shader_parameter("charge", 0.18 + 0.20 * k)
		fx_mat.set_shader_parameter("speed", 2.0 + 3.0 * k)

	if vida <= 0 or perfurou >= PERFURAR:
		_vanecer()
		return

	if position.y < -90 or position.y > 1060 or position.x < -90 or position.x > 630:
		_vanecer()
		return

	queue_redraw()


func _vanecer() -> void:
	vivo = false
	queue_free()


func registrar_hit() -> bool:
	perfurou += 1
	return perfurou < PERFURAR

func registrar_dano() -> int:
	return DANO


# --- FALLBACK: desenho em codigo, usado so se o shader falhar ---
func _draw() -> void:
	if spr != null:
		return   # com shader, o desenho e todo dele

	for i in range(1, rastro.size()):
		var f := float(i) / float(rastro.size())
		var p: Vector2 = rastro[i] - position
		draw_circle(p, 3.0 * f, Color(1.0, 0.55, 0.20, 0.22 * f))

	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.42, 0.12, 0.20))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.62, 0.20, 0.34))

	var pts := PackedVector2Array()
	var n := 4
	for i in n:
		var a := TAU * float(i) / float(n)
		var r: float = 21.0 if i % 2 == 0 else 8.5
		pts.append(Vector2(cos(a), sin(a)) * r)
	var corpo := PackedVector2Array()
	for i in n:
		corpo.append(pts[i])
		corpo.append(pts[i].lerp(pts[(i + 1) % n], 0.42))
	draw_colored_polygon(corpo, Color(0.55, 0.58, 0.62, 0.95))
	var contorno := PackedVector2Array(corpo)
	contorno.append(corpo[0])
	draw_polyline(contorno, Color(0.12, 0.12, 0.14, 0.95), 1.6, true)
	for i in n:
		var a2 := TAU * float(i) / float(n)
		var r2: float = 21.0 if i % 2 == 0 else 8.5
		var p2 := Vector2(cos(a2), sin(a2)) * r2
		draw_circle(p2, 3.4, Color(1.0, 0.45, 0.12, 0.85))
		draw_circle(p2, 1.6, Color(1.0, 0.92, 0.72, 0.95))
	draw_circle(Vector2.ZERO, 3.0, Color(0.15, 0.15, 0.18, 0.9))
	draw_circle(Vector2.ZERO, 1.4, Color(1.0, 0.60, 0.25, 0.8))
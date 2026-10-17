extends Node2D
# Explosao com faiscas que se apagam: flash + bola de fogo + onda + faiscas com fisica + fumaca

var tempo := 0.0
var dur := 0.7
var cor := Color(1, 0.4, 0.15)
var tamanho := 40.0
var faiscas: Array = []
var fumaca: Array = []
var detritos: Array = []
var rng := RandomNumberGenerator.new()
# camada de fogo procedural (shader) por cima do desenho em _draw()
var fogo: Sprite2D = null
var fogo_mat: ShaderMaterial = null

func _criar_fogo() -> void:
	# fallback seguro: se o shader nao existir, o desenho antigo assume
	if not ResourceLoader.exists("res://assets/explosao_fogo.gdshader"):
		return
	fogo_mat = ShaderMaterial.new()
	fogo_mat.shader = load("res://assets/explosao_fogo.gdshader") as Shader
	if fogo_mat.shader == null:
		fogo_mat = null
		return
	fogo = Sprite2D.new()
	# textura 1x1 branca: o shader gera tudo, so precisa de um quad
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	fogo.texture = ImageTexture.create_from_image(img)
	fogo.material = fogo_mat
	fogo.centered = true
	fogo.z_index = 1
	add_child(fogo)
	fogo_mat.set_shader_parameter("semente", randf() * 100.0)
	fogo_mat.set_shader_parameter("intensidade", 0.92)

func setup(p: Vector2, p_cor: Color, p_tam: float) -> void:
	_criar_fogo()
	position = p
	cor = p_cor
	tamanho = p_tam
	dur = 0.55 + p_tam / 220.0 # grande dura mais
	rng.seed = randi()
	# 24 faiscas rapidas
	for i in 24:
		var ang := TAU * float(i) / 24.0 + rng.randf_range(-0.2, 0.2)
		var spd := rng.randf_range(70.0, 330.0) * (0.6 + p_tam / 70.0)
		faiscas.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"life": rng.randf_range(0.35, 0.85),
			"age": 0.0,
			"w": rng.randf_range(1.5, 3.5),
		})
	# 10 brasas lentas que sobem
	for i in 10:
		faiscas.append({
			"p": Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)),
			"v": Vector2(rng.randf_range(-25, 25), rng.randf_range(-90, -30)),
			"life": rng.randf_range(0.6, 1.1),
			"age": 0.0,
			"w": rng.randf_range(1.0, 2.0),
		})
	# 7 fumacas
	for i in 7:
		var ang2 := rng.randf_range(0.0, TAU)
		fumaca.append({
			"p": Vector2(cos(ang2), sin(ang2)) * rng.randf_range(4.0, 14.0),
			"v": Vector2(cos(ang2), sin(ang2)) * rng.randf_range(15.0, 45.0) + Vector2(0, -18),
			"r": rng.randf_range(6.0, 12.0) * (0.7 + p_tam / 80.0),
			"age": 0.0,
			"life": rng.randf_range(0.5, 0.9),
		})

# 8 detritos girando (estilhacos solidos)
	for i in 8:
		var ad := rng.randf_range(0.0, TAU)
		detritos.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(ad), sin(ad)) * rng.randf_range(50.0, 190.0) * (0.7 + p_tam / 90.0),
			"rot": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-9.0, 9.0),
			"s": rng.randf_range(2.5, 6.0),
			"age": 0.0,
			"life": rng.randf_range(0.5, 0.95),
		})

func _process(delta: float) -> void:
	tempo += delta
	if tempo > dur + 0.5:
		queue_free()
		return
	for f in faiscas:
		f["age"] = float(f["age"]) + delta
		# atrito + gravidade leve pra baixo
		f["v"] = (f["v"] as Vector2) * (1.0 - 2.2 * delta)
		f["v"] = (f["v"] as Vector2) + Vector2(0, 60) * delta
		f["p"] = (f["p"] as Vector2) + (f["v"] as Vector2) * delta
	for s in fumaca:
		s["age"] = float(s["age"]) + delta
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["r"] = float(s["r"]) + 22.0 * delta
	for d in detritos:
		d["age"] = float(d["age"]) + delta
		d["v"] = (d["v"] as Vector2) * (1.0 - 3.4 * delta)
		d["v"] = (d["v"] as Vector2) + Vector2(0, 90.0) * delta
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		d["rot"] = float(d["rot"]) + float(d["spin"]) * delta
	_atualiza_fogo()
	queue_redraw()

func _atualiza_fogo() -> void:
	if fogo == null or fogo_mat == null:
		return
	var k := clampf(tempo / dur, 0.0, 1.0)
	# diametro = raio x 2, com margem pra turbulencia nao cortar
	var d := tamanho * 2.6 + 24.0
	fogo.scale = Vector2(d / 4.0, d / 4.0)
	fogo_mat.set_shader_parameter("progresso", k)
	fogo_mat.set_shader_parameter("tamanho", tamanho)
	fogo_mat.set_shader_parameter("cor_fogo", Vector3(cor.r, cor.g, cor.b))
	# no comeco (flash) o fogo some: o brilho branco vem do _draw
	fogo.visible = tempo > 0.04

func _draw() -> void:
	var k := clampf(tempo / dur, 0.0, 1.0)
	# flash branco inicial
	if tempo < 0.12:
		var fa := 1.0 - tempo / 0.12
		draw_circle(Vector2.ZERO, tamanho * 0.55, Color(1, 1, 1, fa))
	# bola de fogo com pop elastico (estoura antes de colapsar)
	var pop := sin(minf(1.0, k / 0.28) * PI) * 0.55
	var fr := tamanho * ((1.0 - k * 0.75) + pop)
	var fa2 := 1.0 - k
	if fogo == null:
		# fallback: bola de fogo classica em circulos (so usa se o shader falhou)
		draw_circle(Vector2.ZERO, fr * 1.45, Color(cor.r, cor.g, cor.b, fa2 * 0.30))
		draw_circle(Vector2.ZERO, fr, Color(cor.r, cor.g, cor.b, fa2 * 0.75))
		draw_circle(Vector2.ZERO, fr * 0.62, Color(minf(1.0, cor.r + 0.35), cor.g + 0.2, cor.b, fa2))
		draw_circle(Vector2.ZERO, fr * 0.32, Color(1, 0.95, 0.85, fa2))
	# onda de choque expandindo
	var orr := tamanho * (0.3 + 1.9 * k)
	draw_arc(Vector2.ZERO, orr, 0, TAU, 32, Color(cor.r, cor.g, cor.b, (1.0 - k) * 0.7), 3.0 * (1.0 - k) + 1.0)
	# segunda onda, atrasada
	var k2 := clampf((tempo - dur * 0.22) / dur, 0.0, 1.0)
	if k2 > 0.0:
		var orr2 := tamanho * (0.2 + 2.6 * k2)
		draw_arc(Vector2.ZERO, orr2, 0, TAU, 32,
			Color(1, 1, 1, (1.0 - k2) * 0.30), 2.0 * (1.0 - k2) + 0.5)
	# detritos girando
	for d in detritos:
		var dk := clampf(float(d["age"]) / float(d["life"]), 0.0, 1.0)
		if dk >= 1.0:
			continue
		var dp: Vector2 = d["p"]
		var dr: float = d["rot"]
		var ds: float = float(d["s"]) * (1.0 - dk * 0.6)
		var ca: float = cos(dr)
		var sa: float = sin(dr)
		var q := PackedVector2Array([
			dp + Vector2(ds * ca, ds * sa),
			dp + Vector2(-ds * sa, ds * ca),
			dp + Vector2(-ds * ca * 0.8, -ds * sa * 0.8),
			dp + Vector2(ds * sa, -ds * ca * 0.8),
		])
		draw_colored_polygon(q, Color(1.0, 0.72, 0.35, (1.0 - dk) * 0.85))
	# fumaca por baixo
	for s in fumaca:
		var sk := clampf(float(s["age"]) / float(s["life"]), 0.0, 1.0)
		if sk >= 1.0:
			continue
		draw_circle(s["p"], float(s["r"]) * (0.6 + sk), Color(0.12, 0.12, 0.13, (1.0 - sk) * 0.45))
	# faiscas com rastro se apagando: branco -> laranja -> vermelho -> some
	for f in faiscas:
		var fk := clampf(float(f["age"]) / float(f["life"]), 0.0, 1.0)
		if fk >= 1.0:
			continue
		var pp: Vector2 = f["p"]
		var vv: Vector2 = f["v"]
		var rastro := pp - vv * 0.035
		var w: float = float(f["w"]) * (1.0 - fk)
		var brilho := 1.0 - fk
		var c := Color(1, 0.95 - fk * 0.45, 0.75 - fk * 0.6, brilho)
		c.r = minf(1.0, cor.r + 0.5 * (1.0 - fk))
		draw_line(rastro, pp, c, w)
		draw_circle(pp, w * 0.8, Color(1, 0.9 - fk * 0.4, 0.7 - fk * 0.5, brilho))

extends Node2D

# Explosao de naves usando a textura "explode_nave.png" (fundo removido).
#
# A imagem e um frame unico, entao a animacao e feita por transformacao +
# camadas:
#   - pop elastico: cresce, passa do alvo e assenta
#   - flash branco no impacto -> cor original
#   - camada aditiva atras, maior e mais quente (o brilho "queima" a cena)
#   - duas ondas de choque desenhadas por codigo
#   - faiscas com rastro, atrito e gravidade
#   - leve giro e deriva pra cima

const DUR := 0.60

var t := 0.0
var dur := DUR
var tam := 150.0
var forte := false
var giro := 0.0

var _spr: Sprite2D
var _glow: Sprite2D
var _base := 1.0
var _sparks: Array = []


func setup(p: Vector2, tex: Texture2D, p_tam: float, p_forte: bool = false, p_giro: float = 0.0) -> void:
	position = p
	tam = p_tam
	forte = p_forte
	giro = p_giro
	dur = (0.92 if forte else 0.58) + p_tam / 900.0

	var rng := RandomNumberGenerator.new()
	rng.seed = randi()

	# camada de brilho (aditiva)
	_glow = Sprite2D.new()
	_glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)

	# camada principal
	_spr = Sprite2D.new()
	_spr.texture = tex
	add_child(_spr)

	_base = p_tam / float(maxi(tex.get_width(), 1))
	_spr.scale = Vector2.ONE * (_base * 0.30)
	_glow.scale = _spr.scale
	rotation = randf_range(0.0, TAU)

	var n: int = 26 if forte else 13
	for i in n:
		var a: float = rng.randf_range(0.0, TAU)
		_sparks.append({
			"v": Vector2(cos(a), sin(a)) * rng.randf_range(90.0, 330.0) * (1.5 if forte else 1.0),
			"age": 0.0,
			"life": rng.randf_range(0.3, 0.8),
			"w": rng.randf_range(1.2, 3.0),
		})


func _process(delta: float) -> void:
	t += delta
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	if k >= 1.0:
		queue_free()
		return

	for s in _sparks:
		s["age"] = float(s["age"]) + delta
		s["v"] = (s["v"] as Vector2) * (1.0 - 2.6 * delta)
		s["v"] = (s["v"] as Vector2) + Vector2(0, 80.0) * delta

	# pop elastico: cresce rapido, passa de 1, assenta, depois expande sumindo
	var s: float
	if k < 0.30:
		s = lerpf(0.30, 1.18, _ease_out(k / 0.30))
	else:
		s = lerpf(1.18, 1.00, _ease_out(minf(1.0, (k - 0.30) / 0.30)))
		s = lerpf(s, 1.22, _ease_out(maxf(0.0, (k - 0.60) / 0.40)))

	var a: float = 1.0 if k < 0.50 else 1.0 - (k - 0.50) / 0.50

	# branco no impacto -> cor original
	var br: float = clampf(k / 0.12, 0.0, 1.0)
	var col := Color(2.2, 2.0, 1.8).lerp(Color(1, 1, 1, 1), br)

	position.y -= 18.0 * delta
	rotation += giro * delta * (1.0 - k)

	_spr.scale = Vector2.ONE * (_base * s)
	_spr.modulate = Color(col.r, col.g, col.b, a)
	_glow.scale = Vector2.ONE * (_base * s * 1.22)
	_glow.modulate = Color(1.0, 0.55, 0.22, a * 0.60 * (1.0 - k))
	_glow.rotation = -rotation * 0.5

	queue_redraw()


func _draw() -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)

	# ---- onda de choque (curta e quente, some rapido)
	var a1: float = pow(1.0 - k, 3.0) * 0.85
	if a1 > 0.01:
		var o1: float = tam * (0.28 + 0.80 * _ease_out(k))
		draw_arc(Vector2.ZERO, o1, 0, TAU, 32, Color(1.0, 0.72, 0.38, a1 * 0.30), 5.0 * a1 + 1.0, true)
		draw_arc(Vector2.ZERO, o1, 0, TAU, 32, Color(1.0, 0.95, 0.88, a1 * 0.42), 1.6 * a1 + 0.5, true)

	# ---- faiscas
	for s in _sparks:
		var fk: float = clampf(float(s["age"]) / float(s["life"]), 0.0, 1.0)
		if fk >= 1.0:
			continue
		var v: Vector2 = s["v"]
		var p: Vector2 = v * float(s["age"])
		var w: float = float(s["w"]) * (1.0 - fk * 0.75)
		var br2: float = 1.0 - fk
		draw_line(p - v * 0.030, p, Color(1.0, 0.6, 0.2, br2 * 0.55), w * 2.0, true)
		draw_circle(p, w * 0.85, Color(1.0, 0.96, 0.8, br2))


func _ease_out(x: float) -> float:
	var v: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - v, 3.0)
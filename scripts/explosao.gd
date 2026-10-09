extends Node2D
# Explosao com faiscas que se apagam: flash + bola de fogo + onda + faiscas com fisica + fumaca

var tempo := 0.0
var dur := 0.7
var cor := Color(1, 0.4, 0.15)
var tamanho := 40.0
var faiscas: Array = []
var fumaca: Array = []
var rng := RandomNumberGenerator.new()

func setup(p: Vector2, p_cor: Color, p_tam: float) -> void:
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
	queue_redraw()

func _draw() -> void:
	var k := clampf(tempo / dur, 0.0, 1.0)
	# flash branco inicial
	if tempo < 0.12:
		var fa := 1.0 - tempo / 0.12
		draw_circle(Vector2.ZERO, tamanho * 0.55, Color(1, 1, 1, fa))
	# bola de fogo encolhendo
	var fr := tamanho * (1.0 - k * 0.75)
	var fa2 := 1.0 - k
	draw_circle(Vector2.ZERO, fr, Color(cor.r, cor.g, cor.b, fa2 * 0.75))
	draw_circle(Vector2.ZERO, fr * 0.62, Color(minf(1.0, cor.r + 0.35), cor.g + 0.2, cor.b, fa2))
	draw_circle(Vector2.ZERO, fr * 0.32, Color(1, 0.95, 0.85, fa2))
	# onda de choque expandindo
	var orr := tamanho * (0.3 + 1.9 * k)
	draw_arc(Vector2.ZERO, orr, 0, TAU, 32, Color(cor.r, cor.g, cor.b, (1.0 - k) * 0.7), 3.0 * (1.0 - k) + 1.0)
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

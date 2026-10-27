extends Node2D
# ESTILHACO DIRECIONAL: cacos de metal voando na direcao do tiro que
# derrubou o inimigo. Somando a bola de fogo do ExplodeSeq nao substitui.
# Tudo desenhado por codigo (triangulos + brasa), sem assets novos.
#
# Camadas de leitura:
#   - primeiros ~40% da vida: caco BRANCO-QUENTE (a energia do tiro)
#   - depois: caco laranja esfriando com uma brasa na traseira
#   - gravidade leve + arrasto: caco "cai" depois do impulso

const VIDA := 0.55

var cacos: Array = []


func setup(p: Vector2, dir: Vector2, forte: bool = false) -> void:
	position = p
	var n := 9 if forte else 6
	var ang0 := randf_range(0.0, TAU)
	for i in n:
		var ang := ang0 + (TAU / float(n)) * float(i) + randf_range(-0.45, 0.45)
		var espalha := randf_range(150.0, 270.0) * (1.35 if forte else 1.0)
		# 70% dos cacos levam a maior parte da energia na direcao do tiro,
		# 30% difundem chao (a explosao ja cobre esse espalhamento)
		var bias := randf_range(0.55, 1.0) if randf() < 0.7 else randf_range(0.1, 0.45)
		var v: Vector2 = dir * espalha * bias + Vector2(cos(ang), sin(ang)) * espalha * (1.0 - bias)
		cacos.append({
			"pos": Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"vel": v,
			"rot": randf_range(0.0, TAU),
			"rv": randf_range(-11.0, 11.0),
			"tam": randf_range(2.4, 5.4),
			"vida": VIDA * randf_range(0.65, 1.0),
		})


func _process(delta: float) -> void:
	var vivo := false
	for c in cacos:
		var vida: float = c["vida"]
		if vida <= 0.0:
			continue
		vida -= delta
		c["vida"] = vida
		vivo = vivo or vida > 0.0
		c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * delta
		# arrasto + queda: caco perde impulso e cai
		c["vel"] = ((c["vel"] as Vector2) * (1.0 - 2.4 * delta)) + Vector2(0, 300.0 * delta)
		c["rot"] = c["rot"] + (c["rv"] as float) * delta
	if not vivo:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	for c in cacos:
		var vida: float = c["vida"]
		if vida <= 0.0:
			continue
		var k: float = clampf(vida / VIDA, 0.0, 1.0)
		var r: float = c["rot"]
		var tam: float = c["tam"] * (0.55 + 0.45 * k)
		var pts := PackedVector2Array()
		pts.append(Vector2(cos(r), sin(r)) * tam * 1.7)
		pts.append(Vector2(cos(r + 2.2), sin(r + 2.2)) * tam)
		pts.append(Vector2(cos(r + 4.1), sin(r + 4.1)) * tam * 0.75)
		if k > 0.62:
			# quente: caco quase branco (energia do tiro ainda nele)
			draw_colored_polygon(pts, Color(1.0, 0.96, 0.9, 0.95 * k))
		else:
			# esfriando laranja com brasa apagando
			draw_colored_polygon(pts, Color(0.95, 0.42, 0.12, 0.8 * k + 0.15))
			draw_circle(c["pos"], tam * 0.35, Color(1.0, 0.72, 0.3, 0.55 * k))
	_draw_superaquecido()


func _draw_superaquecido() -> void:
	# carpinta pequena de rastro nos cacos quentes quemando
	for c in cacos:
		var vida: float = c["vida"]
		if vida <= 0.0:
			continue
		var k: float = clampf(vida / VIDA, 0.0, 1.0)
		if k <= 0.62:
			continue
		var q: float = (k - 0.62) / 0.38
		draw_circle(c["pos"] - (c["vel"] as Vector2) * 0.02, (c["tam"] as float) * 0.5 * q,
			Color(1.0, 0.85, 0.55, 0.4 * q))

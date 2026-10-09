extends Node2D
# Explosao buraco negro: implosao espiral + flash + estouro com aneis

var tempo := 0.0
var dur := 1.3
var tamanho := 130.0
var poeira: Array = []
var rng := RandomNumberGenerator.new()

func setup(p: Vector2, p_tam: float = 130.0) -> void:
	position = p
	tamanho = p_tam
	rng.seed = randi()
	# 40 particulas orbitando pra dentro
	for i in 40:
		poeira.append({
			"ang": rng.randf_range(0.0, TAU),
			"raio": rng.randf_range(60.0, 170.0) * (0.7 + p_tam / 150.0),
			"vel": rng.randf_range(2.5, 5.5),
			"w": rng.randf_range(1.5, 3.5),
			"quente": rng.randf() < 0.5,
		})

func _process(delta: float) -> void:
	tempo += delta
	if tempo > dur:
		queue_free()
		return
	for d in poeira:
		d["ang"] = float(d["ang"]) + float(d["vel"]) * delta * (1.0 if tempo < 0.5 else -0.6)
		var encolhe := 160.0 * delta if tempo < 0.5 else -260.0 * delta
		d["raio"] = maxf(6.0, float(d["raio"]) - encolhe)
	queue_redraw()

func _draw() -> void:
	var k := clampf(tempo / dur, 0.0, 1.0)
	if tempo < 0.5:
		# FASE 1: implosao - disco escuro crescendo + espiral caindo pra dentro
		var q := tempo / 0.5
		# espiral
		for d in poeira:
			var pp := Vector2(cos(float(d["ang"])), sin(float(d["ang"]))) * float(d["raio"]) * (0.4 + 0.6 * (1.0 - q * 0.5))
			var c := Color(1, 0.45, 0.1, 0.9) if bool(d["quente"]) else Color(0.5, 0.9, 1, 0.7)
			draw_circle(pp, float(d["w"]), c)
		# horizonte de eventos
		draw_circle(Vector2.ZERO, tamanho * 0.45 * q + 8.0, Color(0, 0, 0, 0.95))
		# anel fotonico
		draw_arc(Vector2.ZERO, tamanho * 0.45 * q + 10.0, 0, TAU, 40, Color(1, 0.35, 0.08, 0.9), 4.0)
		draw_arc(Vector2.ZERO, tamanho * 0.45 * q + 15.0, 0, TAU, 40, Color(0.4, 0.8, 1, 0.35), 2.0)
	else:
		# FASE 2: estouro - flash + onda + faiscas pra fora
		var q2 := (tempo - 0.5) / (dur - 0.5)
		if q2 < 0.25:
			draw_circle(Vector2.ZERO, tamanho * 0.9, Color(1, 1, 1, 1.0 - q2 * 4.0))
		draw_circle(Vector2.ZERO, tamanho * (1.1 - q2 * 0.7), Color(1, 0.4, 0.1, (1.0 - q2) * 0.8))
		draw_circle(Vector2.ZERO, tamanho * (0.6 - q2 * 0.4), Color(1, 0.8, 0.4, 1.0 - q2))
		draw_arc(Vector2.ZERO, tamanho * (0.5 + q2 * 2.2), 0, TAU, 40, Color(0.5, 0.9, 1, (1.0 - q2) * 0.6), 3.0)
		for d in poeira:
			var pp := Vector2(cos(float(d["ang"])), sin(float(d["ang"]))) * float(d["raio"])
			draw_line(pp * 0.85, pp, Color(1, 0.6 - q2 * 0.3, 0.2, 1.0 - q2), float(d["w"]))

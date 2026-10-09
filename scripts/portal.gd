extends Node2D
# Portal grandioso: vortice negro com raios negros/vermelhos, leva a dimensao 2

var tempo := 0.0
var raio := 95.0
var ativo := true

func _process(delta: float) -> void:
	tempo += delta
	rotation += 0.25 * delta
	queue_redraw()

func _draw() -> void:
	if not ativo:
		return
	var pulse := 0.9 + 0.1 * sin(tempo * 3.0)
	# brasa vermelha externa (suave, sem aneis chapados)
	draw_circle(Vector2.ZERO, raio * 1.5 * pulse, Color(0.45, 0.03, 0.02, 0.25))
	draw_circle(Vector2.ZERO, raio * 1.18 * pulse, Color(0.75, 0.07, 0.04, 0.30))
	_draw_vortice()
	# nucleo negro absoluto com borda vermelha quente
	draw_circle(Vector2.ZERO, raio * 0.7, Color(0, 0, 0, 1))
	draw_arc(Vector2.ZERO, raio * 0.7, 0, TAU, 48, Color(1, 0.2, 0.08, 0.95), 3.0)
	# 2 segmentos quentes orbitando (pontos de succao)
	var q1 := tempo * 2.6
	var q2 := -tempo * 1.8 + 2.0
	draw_arc(Vector2.ZERO, raio * 0.82, q1, q1 + 1.1, 20, Color(1, 0.75, 0.35, 0.95), 4.0)
	draw_arc(Vector2.ZERO, raio * 1.02, q2, q2 + 0.8, 18, Color(1, 0.25, 0.08, 0.9), 2.5)
	_draw_raios()

func _draw_vortice() -> void:
	# succao: 3 bracos espirais caindo pra dentro + aneis contraindo
	for b in 3:
		var pts := PackedVector2Array()
		var pts2 := PackedVector2Array()
		for s in 14:
			var r := raio * (1.55 - float(s) / 13.0 * 1.25)
			var a := tempo * 4.2 + TAU * float(b) / 3.0 + (raio * 1.55 - r) * 0.045
			pts.append(Vector2(cos(a), sin(a)) * r)
			pts2.append(Vector2(cos(a), sin(a)) * (r - 7.0))
		draw_polyline(pts, Color(0.6, 0.02, 0.01, 0.55), 6.0)
		draw_polyline(pts2, Color(1, 0.25, 0.08, 0.9), 2.5)
	# aneis de succao contraindo
	for i in 3:
		var ph := fmod(tempo * 0.7 + float(i) / 3.0, 1.0)
		var rr := raio * (1.6 - ph * 1.0)
		draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(1, 0.12, 0.05, (1.0 - ph) * 0.55), 2.5)
	# redemoinho interno acelerado
	for i in 5:
		var a := -tempo * 5.0 + TAU * float(i) / 5.0
		var p1 := Vector2(cos(a), sin(a)) * raio * 0.55
		var p2 := Vector2(cos(a + 0.7), sin(a + 0.7)) * raio * 0.25
		draw_line(p1, p2, Color(1, 0.15, 0.06, 0.85), 2.5)

func _draw_raios() -> void:
	# raios de energia: fio vermelho com nucleo escuro (nunca rabisco preto puro)
	var rng := RandomNumberGenerator.new()
	var passo := int(tempo / 0.09)
	for b in 6:
		rng.seed = passo * 977 + b * 131
		var a := rng.randf_range(0.0, TAU)
		var r0 := raio * rng.randf_range(0.85, 1.05)
		var pts := PackedVector2Array([Vector2(cos(a), sin(a)) * r0])
		var rr := r0
		var aa := a
		for s in 4:
			rr += rng.randf_range(18.0, 42.0)
			aa += rng.randf_range(-0.5, 0.5)
			pts.append(Vector2(cos(aa), sin(aa)) * rr)
		draw_polyline(pts, Color(1, 0.14, 0.05, 0.55), 6.0)
		draw_polyline(pts, Color(0.12, 0.0, 0.0, 0.95), 2.5)
	# faiscas vermelhas orbitando
	rng.seed = passo * 57 + 3
	for i in 10:
		var fa := rng.randf_range(0.0, TAU)
		var fr := rng.randf_range(raio * 0.8, raio * 1.5)
		draw_circle(Vector2(cos(fa), sin(fa)) * fr, rng.randf_range(1.5, 3.5), Color(1, 0.25, 0.08, 0.9))

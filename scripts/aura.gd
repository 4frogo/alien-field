extends Node2D
# Aura cosmica da nave: nebulosa, disco de acrecao, bracos de galaxia,
# estrelas orbitando, poeira estelar e a onda de choque do impacto.
#
# Desenhada com blend ADITIVO (CanvasItemMaterial no no pai): sem isso a
# aura vira uma mancha opaca. E aqui que o "cosmico" aparece de verdade.

var forca := 1.0        # 0..1, aforca do escudo
var flash := 0.0        # 0..1, clarao no impacto
var onda := 1.0         # 0..1, onda de choque (1 = nenhuma)
var tempo := 0.0
var critico := false

var _dust: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 46:
		var a := rng.randf_range(0.0, TAU)
		var r := sqrt(rng.randf()) * 165.0
		_dust.append({
			"p": Vector2(cos(a), sin(a) * 0.42) * r,
			"s": rng.randf_range(0.6, 2.2),
			"fase": rng.randf_range(0.0, TAU),
			"vel": rng.randf_range(0.4, 1.6),
		})


## Elipse inclinada, devolve os pontos no sentido horario.
func _elipse(rx: float, ry: float, incl: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ci := cos(incl)
	var si := sin(incl)
	for i in n:
		var a := TAU * float(i) / float(n)
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts.append(Vector2(x * ci - y * si, x * si + y * ci))
	return pts


func _draw() -> void:
	if forca <= 0.001:
		return
	var f: float = forca
	var fl: float = flash
	var t: float = tempo

	# ================= nebulosa (camadas de cor, respirando) =================
	var resp: float = 0.85 + 0.15 * sin(t * 1.9)
	draw_circle(Vector2.ZERO, 165.0 * resp, Color(0.30, 0.08, 0.75, 0.055 * f))
	draw_circle(Vector2.ZERO, 132.0 * resp, Color(0.65, 0.15, 0.85, 0.065 * f))
	draw_circle(Vector2.ZERO, 104.0 * resp, Color(0.95, 0.30, 0.75, 0.060 * f))
	draw_circle(Vector2.ZERO, 78.0 * resp, Color(0.30, 0.80, 1.00, 0.075 * f))
	draw_circle(Vector2.ZERO, 56.0, Color(1.0, 1.0, 1.0, 0.10 * f * (0.6 + 0.4 * resp)))

	# ================= disco de acrecao (anel inclinado) =================
	var incl: float = 0.42 + 0.05 * sin(t * 0.6)
	var rx: float = 126.0

	# disco em camadas concentricas (um anel preenchido nao triangula)
	for i in 6:
		var k: float = float(i) / 5.0
		var ry: float = lerpf(16.0, 38.0, k)
		var a: float = (0.05 + 0.13 * (1.0 - absf(k - 0.45))) * f
		draw_polyline(_elipse(rx, ry, incl, 44),
			Color(0.55, 0.25, 0.95, a), 1.8, true)

	# bordas do disco
	draw_polyline(_elipse(rx, 18.0, incl, 44), Color(1.0, 0.85, 0.95, (0.35 + 0.30 * fl) * f), 2.4, true)
	draw_polyline(_elipse(rx, 38.0, incl, 44), Color(0.60, 0.30, 1.00, (0.16 + 0.14 * fl) * f), 2.0, true)

	# brilho concentrado na parte de tras do disco (efeito de Doppler)
	for i in 10:
		var a := incl + PI * 0.75 + float(i) / 10.0 * 0.7
		var p := Vector2(cos(a) * rx, sin(a) * 30.0)
		draw_circle(p, 3.0 + 2.0 * sin(t * 5.0 + float(i)), Color(1.0, 0.95, 0.9, 0.30 * f))

	# ================= bracos de galaxia (espirais girando) =================
	for braco in 2:
		var pts := PackedVector2Array()
		var n := 22
		for i in n:
			var u: float = float(i) / float(n)
			var r: float = 42.0 + u * 105.0
			var a: float = float(braco) * PI + u * 4.6 + t * 0.28
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.34))
		var cor_b: Color = Color(0.45, 0.85, 1.0, 0.30) if braco == 0 else Color(1.0, 0.45, 0.90, 0.26)
		draw_polyline(pts, Color(cor_b.r, cor_b.g, cor_b.b, cor_b.a * 0.35), 4.5, true)
		draw_polyline(pts, Color(cor_b.r, cor_b.g, cor_b.b, cor_b.a * f), 1.6, true)

	# ================= estrelas orbitando o disco =================
	for i in 12:
		var a: float = t * 0.45 + TAU * float(i) / 12.0
		var p := Vector2(cos(a) * rx, sin(a) * 30.0)
		var tw: float = 0.6 + 0.4 * sin(t * 6.0 + float(i) * 2.1)
		draw_circle(p, 7.0 * tw, Color(0.7, 0.85, 1.0, 0.16 * f * tw))
		draw_circle(p, 2.4 * tw, Color(1, 1, 1, (0.55 + 0.35 * fl) * f * tw))

	# ================= coroas de luz (flares) =================
	for i in 4:
		var a: float = t * 0.3 + TAU * float(i) / 4.0 + PI * 0.25
		var p := Vector2(cos(a) * (rx + 6.0), sin(a) * 33.0)
		var tam: float = 3.0 + 2.5 * sin(t * 7.0 + float(i) * 1.9)
		draw_line(p - Vector2(tam * 3.0, 0), p + Vector2(tam * 3.0, 0),
			Color(1, 1, 1, 0.35 * f), 1.2, true)
		draw_line(p - Vector2(0, tam * 3.0), p + Vector2(0, tam * 3.0),
			Color(1, 1, 1, 0.35 * f), 1.2, true)
		draw_circle(p, tam * 1.4, Color(0.9, 0.95, 1.0, 0.20 * f))
		draw_circle(p, tam * 0.5, Color(1, 1, 1, 0.5 * f))

	# ================= poeira estelar =================
	for d in _dust:
		var tw2: float = 0.5 + 0.5 * sin(t * d["vel"] + float(d["fase"]))
		var a2: float = 0.10 * f * tw2
		draw_circle(d["p"], float(d["s"]) * 2.0, Color(0.8, 0.85, 1.0, a2 * 0.25))
		draw_circle(d["p"], float(d["s"]), Color(1, 1, 1, a2))

	# ================= onda de choque do impacto =================
	if onda < 1.0:
		var r: float = 46.0 + onda * 130.0
		var a3: float = (1.0 - onda) * (0.55 + 0.35 * fl)
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1.0, 0.80, 0.90, a3 * 0.55), 4.0, true)
		draw_arc(Vector2.ZERO, r * 0.82, 0, TAU, 44, Color(1, 1, 1, a3 * 0.5), 2.5, true)
		# fragmentos voando pra fora
		for i in 10:
			var fa: float = TAU * float(i) / 10.0 + float(i) * 0.7
			var fr: float = r * (0.85 + 0.3 * sin(float(i) * 3.1))
			draw_circle(Vector2(cos(fa), sin(fa) * 0.4) * fr, 2.2,
				Color(1.0, 0.9, 0.7, a3 * 0.6))
extends Node2D
# Poeira da transicao: particulas subindo que somem junto com a imagem

var intensidade := 0.0
var poeira: Array = []
var tempo := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4242
	for i in 90:
		poeira.append({
			"p": Vector2(rng.randf_range(0, 540), rng.randf_range(0, 960)),
			"v": rng.randf_range(25.0, 70.0),
			"tam": rng.randf_range(1.5, 4.0),
			"fase": rng.randf_range(0.0, TAU),
			"verde": rng.randf() < 0.7,
		})

func _process(delta: float) -> void:
	tempo += delta
	for d in poeira:
		d["p"] = (d["p"] as Vector2) + Vector2(sin(tempo * 2.0 + float(d["fase"])) * 12.0, -float(d["v"])) * delta
		if (d["p"] as Vector2).y < -10.0:
			d["p"] = Vector2(rng.randf_range(0, 540), 970.0)
	queue_redraw()

func _draw() -> void:
	for d in poeira:
		var tw := 0.4 + 0.6 * (0.5 + 0.5 * sin(tempo * 6.0 + float(d["fase"])))
		var c := Color(0.55, 1.0, 0.6, intensidade * tw) if bool(d["verde"]) else Color(1, 0.9, 0.75, intensidade * tw)
		draw_circle(d["p"], float(d["tam"]), c)

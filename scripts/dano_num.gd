extends Label
# Numero flutuante de dano/pontos (kill confirm)

var tempo := 0.0
var dur := 0.8
var sobe := 55.0

func setup(p: Vector2, texto: String, tamanho: int, cor: Color) -> void:
	position = p + Vector2(randf_range(-8, 8), -10)
	text = texto
	add_theme_font_size_override("font_size", tamanho)
	if ResourceLoader.exists("res://assets/horror.ttf"):
		add_theme_font_override("font", load("res://assets/horror.ttf") as Font)
	add_theme_color_override("font_color", cor)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	z_index = 30

func _process(delta: float) -> void:
	tempo += delta
	position.y -= sobe * delta
	sobe = lerpf(sobe, 20.0, minf(1.0, 4.0 * delta))
	var k := clampf(tempo / dur, 0.0, 1.0)
	modulate.a = 1.0 - k * k
	scale = Vector2.ONE * (1.25 - 0.25 * minf(1.0, tempo * 6.0))
	if tempo >= dur:
		queue_free()

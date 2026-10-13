extends Control
# Icone do HUD: escudo hexagonal ou raio triplo

var modo := "escudo"

func _draw() -> void:
	if modo == "escudo":
		var pts := PackedVector2Array()
		for i in 6:
			var a := TAU * float(i) / 6.0 - PI / 2.0
			pts.append(Vector2(14, 14) + Vector2(cos(a), sin(a)) * 12.0)
		draw_colored_polygon(pts, Color(0.05, 0.2, 0.08, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.35, 1.0, 0.5), 2.0)
		draw_circle(Vector2(14, 14), 3.0, Color(0.6, 1.0, 0.65))
	else:
		for i in 3:
			var x := 6.0 + float(i) * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x + 4, 10), Vector2(x, 26), Vector2(x - 4, 10)]), Color(0.4, 1.0, 0.55))

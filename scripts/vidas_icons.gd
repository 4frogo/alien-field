extends Control
# 3 mini-naves das vidas

func _draw() -> void:
	var parent = get_parent()
	var n := 3
	if parent != null and "vidas_count" in parent:
		n = int(parent.vidas_count)
	for i in 3:
		var x := 12.0 + float(i) * 36.0
		var y := 12.0
		var col := Color(0.25, 1.0, 0.45) if i < n else Color(0.12, 0.2, 0.14, 0.5)
		# mini nave
		var pts := PackedVector2Array([
			Vector2(x, y - 10), Vector2(x + 8, y + 8),
			Vector2(x + 3, y + 4), Vector2(x, y + 6),
			Vector2(x - 3, y + 4), Vector2(x - 8, y + 8)
		])
		draw_colored_polygon(pts, col)
		draw_circle(Vector2(x, y), 2.5, Color(0.7, 1.0, 0.8) if i < n else Color(0.2, 0.3, 0.22))

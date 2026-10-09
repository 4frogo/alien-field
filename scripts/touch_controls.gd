extends Node2D
# Controles touch: analogico esquerda move, circulo verde direita atira

var player: Node2D = null
var main_ref: Node = null
var joy_base := Vector2(100, 800)
var joy_pos := Vector2(100, 800)
var joy_r := 75.0
var joy_id := -1
var fire_center := Vector2(440, 790)
var fire_r := 60.0
var fire_ids := {}
var pause_center := Vector2(500, 44)
var pause_r := 34.0

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if joy_id < 0 and p.distance_to(joy_base) < 115.0:
				joy_id = event.index
				_atualiza_knob(p)
			elif p.distance_to(fire_center) < 100.0:
				fire_ids[event.index] = true
				player.set("fogo_touch", true)
			elif p.distance_to(pause_center) < 55.0:
				if main_ref != null and main_ref.has_method("_alternar_pause"):
					main_ref.call("_alternar_pause")
		else:
			if event.index == joy_id:
				joy_id = -1
				joy_pos = joy_base
				player.set("analog", Vector2.ZERO)
			if fire_ids.has(event.index):
				fire_ids.erase(event.index)
				if fire_ids.is_empty():
					player.set("fogo_touch", false)
	elif event is InputEventScreenDrag:
		if event.index == joy_id:
			_atualiza_knob(event.position)

func _atualiza_knob(p: Vector2) -> void:
	var off := (p - joy_base).limit_length(joy_r)
	joy_pos = joy_base + off
	player.set("analog", off / joy_r)

func _draw() -> void:
	# analogico
	draw_circle(joy_base, joy_r, Color(0.05, 0.2, 0.08, 0.45))
	draw_arc(joy_base, joy_r, 0, TAU, 40, Color(0.35, 1.0, 0.55, 0.8), 2.5)
	draw_circle(joy_pos, 30.0, Color(0.1, 0.35, 0.15, 0.7))
	draw_arc(joy_pos, 30.0, 0, TAU, 32, Color(0.45, 1.0, 0.6, 0.9), 2.0)
	# circulo de tiro (acende ao segurar)
	var atirando := not fire_ids.is_empty()
	draw_circle(fire_center, fire_r, Color(0.1, 0.8, 0.3, 0.35 if atirando else 0.12))
	draw_arc(fire_center, fire_r, 0, TAU, 40, Color(0.35, 1.0, 0.5, 1.0 if atirando else 0.7), 3.0)
	draw_circle(fire_center, 10.0, Color(0.5, 1.0, 0.6, 0.9 if atirando else 0.4))
	# pausa
	draw_arc(pause_center, 22.0, 0, TAU, 28, Color(0.7, 0.8, 0.75, 0.7), 2.0)
	draw_line(pause_center + Vector2(-6, -8), pause_center + Vector2(-6, 8), Color(0.8, 0.9, 0.85, 0.8), 3.0)
	draw_line(pause_center + Vector2(6, -8), pause_center + Vector2(6, 8), Color(0.8, 0.9, 0.85, 0.8), 3.0)

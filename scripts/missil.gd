extends Node2D
# Missil teleguiado: persegue o alvo e causa 36 de dano (30% do chefe)

var alvo: Node2D = null
var vel := Vector2(0, -1)
var speed := 430.0
var giro := 3.8
var vida := 7.0
var tempo := 0.0
var vivo := true
var rastro: Array = []

func setup(p: Vector2, p_alvo: Node2D) -> void:
	position = p
	alvo = p_alvo
	var a := -PI / 2.0
	if alvo != null and is_instance_valid(alvo):
		a = (alvo.position - p).angle()
	vel = Vector2(cos(a), sin(a)) * speed

func _process(delta: float) -> void:
	tempo += delta
	vida -= delta
	if vida <= 0:
		vivo = false
		queue_free()
		return
	if alvo != null and is_instance_valid(alvo):
		var quer := ((alvo as Node2D).position - position).normalized()
		var atual := vel.normalized()
		var novo := atual.lerp(quer, minf(1.0, giro * delta)).normalized()
		vel = novo * speed
	position += vel * delta
	if position.y < -60 or position.y > 1020 or position.x < -60 or position.x > 600:
		vivo = false
		queue_free()
		return
	rastro.append(position)
	while rastro.size() > 12:
		rastro.pop_front()
	queue_redraw()

func _draw() -> void:
	# fumaca do rastro
	for i in rastro.size():
		var k := float(i) / 12.0
		draw_circle(to_local(rastro[i]), 4.0 * k + 1.0, Color(0.5, 0.5, 0.52, 0.25 * k))
	# corpo apontado pro movimento
	var a := vel.angle()
	var dir := Vector2(cos(a), sin(a))
	var per := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([dir * 12.0, per * 5.0 - dir * 6.0, -dir * 8.0 + per * 5.0, -dir * 8.0 - per * 5.0, per * -5.0 - dir * 6.0]), Color(0.7, 0.72, 0.75))
	draw_circle(dir * 10.0, 3.0, Color(1, 0.25, 0.12))
	# chama tremeluzindo
	var f := 8.0 + 4.0 * sin(tempo * 43.0)
	draw_colored_polygon(PackedVector2Array([-dir * 8.0 + per * 3.5, -dir * 8.0 - per * 3.5, -dir * (8.0 + f)]), Color(1, 0.55, 0.12, 0.9))
	draw_colored_polygon(PackedVector2Array([-dir * 8.0 + per * 1.8, -dir * 8.0 - per * 1.8, -dir * (8.0 + f * 0.55)]), Color(1, 0.9, 0.6, 0.95))

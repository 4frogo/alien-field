extends Node2D
# Arma plasma: sai do icone destruido, voa ate a nave e equipa 15s de tiro triplo

signal coletada

var alvo: Node2D = null
var vel := 300.0
var vida := 9.0
var tempo := 0.0
var coletado := false

func setup(p: Vector2, p_alvo: Node2D) -> void:
	position = p
	alvo = p_alvo

func _ready() -> void:
	for bp in ["res://assets/arma plasma.png", "res://assets/arma_plasma.png"]:
		if ResourceLoader.exists(bp):
			var tex := load(bp) as Texture2D
			if tex != null:
				var sp := Sprite2D.new()
				sp.texture = tex
				var w := float(tex.get_width())
				if w > 0:
					var s := 80.0 / w
					sp.scale = Vector2(s, s)
				sp.name = "Gun"
				add_child(sp)
				break

func _process(delta: float) -> void:
	tempo += delta
	vida -= delta
	if vida <= 0 or coletado:
		queue_free()
		return
	if alvo == null or not is_instance_valid(alvo) or not alvo.visible:
		queue_free()
		return
	# persegue a nave com leve ondulacao
	var dir := (alvo.position - position)
	var dist := dir.length()
	if dist < 30.0:
		coletado = true
		coletada.emit()
		queue_free()
		return
	dir = dir.normalized()
	# wobble perpendicular
	var perp := Vector2(-dir.y, dir.x) * sin(tempo * 6.0) * 60.0
	position += (dir * vel + perp) * delta
	rotation = lerp_angle(rotation, dir.angle(), minf(1.0, 8.0 * delta))
	queue_redraw()

func _draw() -> void:
	# rastro verde + pulsacao (guia visual ate a nave)
	var pulse := 0.6 + 0.4 * sin(tempo * 10.0)
	draw_circle(Vector2.ZERO, 20 * pulse, Color(0.2, 1.0, 0.5, 0.25))
	draw_circle(Vector2.ZERO, 10 * pulse, Color(0.5, 1.0, 0.6, 0.5))

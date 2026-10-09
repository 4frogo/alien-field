extends Node2D
# Controles touch invisiveis: esquerda arrasta = direcional, direita segura = tiro

var player: Node2D = null
var main_ref: Node = null
var move_id := -1
var move_anchor := Vector2.ZERO
var fire_ids := {}

func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventScreenTouch:
		# viewport -> coordenadas do jogo
		var p: Vector2 = make_canvas_position_local(event.position)
		if event.pressed:
			if p.y < 60.0:
				if main_ref != null and main_ref.has_method("_alternar_pause"):
					main_ref.call("_alternar_pause")
			elif p.x < 270.0 and move_id < 0:
				move_id = event.index
				move_anchor = p
				player.set("analog", Vector2.ZERO)
			elif p.x >= 270.0:
				fire_ids[event.index] = true
				player.set("fogo_touch", true)
		else:
			if event.index == move_id:
				move_id = -1
				player.set("analog", Vector2.ZERO)
			if fire_ids.has(event.index):
				fire_ids.erase(event.index)
				if fire_ids.is_empty():
					player.set("fogo_touch", false)
	elif event is InputEventScreenDrag:
		if event.index == move_id:
			var p: Vector2 = make_canvas_position_local(event.position)
			player.set("analog", ((p - move_anchor) / 70.0).limit_length(1.0))

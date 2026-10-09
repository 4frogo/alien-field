extends Node2D
# Controles touch: direcional embaixo-esquerda + botao FOGO embaixo-direita

var player: Node2D = null
var main_ref: Node = null
var pad_center := Vector2(115, 785)
var pad_braco := 58.0
var pad_morto := 26.0
# indice do toque -> direcao que ele segura
var toques_dir := {}
var fire_center := Vector2(425, 785)
var fire_r := 64.0
var fire_ids := {}
var pause_center := Vector2(500, 44)
var pause_r := 34.0

func _process(_delta: float) -> void:
	queue_redraw()

func _seta_em(p: Vector2) -> Vector2:
	# so as 4 setas respondem (nada de area generica)
	for s in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		if p.distance_to(pad_center + s * pad_braco) < 44.0:
			return s
	return Vector2.ZERO

func _direcao_de(p: Vector2) -> Vector2:
	# deslize: direcao unica dominante perto do pad
	if p.distance_to(pad_center) > 120.0:
		return Vector2.ZERO
	var d := p - pad_center
	if d.length() < pad_morto:
		return Vector2.ZERO
	if absf(d.x) > absf(d.y):
		return Vector2(1.0 if d.x > 0 else -1.0, 0)
	return Vector2(0, 1.0 if d.y > 0 else -1.0)

func _atualiza_analog() -> void:
	var soma := Vector2.ZERO
	for k in toques_dir:
		soma += toques_dir[k]
	if player != null:
		player.set("analog", soma.limit_length(1.0))

# indice do toque -> zona ("dir" ou "fogo")
var zona := {}

func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventScreenTouch:
		# viewport -> coordenadas do jogo (tela do celular tem escala diferente)
		var p: Vector2 = make_canvas_position_local(event.position)
		if event.pressed:
			var s := _seta_em(p)
			if s != Vector2.ZERO:
				zona[event.index] = "dir"
				toques_dir[event.index] = s
				_atualiza_analog()
			elif p.distance_to(fire_center) < 80.0:
				zona[event.index] = "fogo"
				fire_ids[event.index] = true
				player.set("fogo_touch", true)
			# resto da tela: ignora (nao move nem atira)
			elif p.distance_to(pause_center) < 55.0:
				if main_ref != null and main_ref.has_method("_alternar_pause"):
					main_ref.call("_alternar_pause")
		else:
			if zona.get(event.index) == "dir" or toques_dir.has(event.index):
				toques_dir.erase(event.index)
				_atualiza_analog()
			if zona.get(event.index) == "fogo" or fire_ids.has(event.index):
				fire_ids.erase(event.index)
				if fire_ids.is_empty():
					player.set("fogo_touch", false)
			zona.erase(event.index)
	elif event is InputEventScreenDrag:
		if zona.get(event.index) != "dir":
			return
		var p: Vector2 = make_canvas_position_local(event.position)
		toques_dir[event.index] = _direcao_de(p)
		_atualiza_analog()

func _botao_dir(c: Vector2, r: float, ativa: bool, seta: Vector2) -> void:
	draw_circle(c, r, Color(0.08, 0.25, 0.1, 0.75 if ativa else 0.4))
	draw_arc(c, r, 0, TAU, 28, Color(0.4, 1.0, 0.55, 1.0 if ativa else 0.6), 2.5)
	var ponta := c + seta * (r * 0.45)
	var base := c - seta * (r * 0.25)
	var per := Vector2(-seta.y, seta.x) * r * 0.35
	var cor := Color(0.6, 1.0, 0.65, 1.0 if ativa else 0.55)
	draw_colored_polygon(PackedVector2Array([ponta, base + per, base - per]), cor)

func _draw() -> void:
	var cima := Vector2.ZERO
	var baixo := Vector2.ZERO
	var esq := Vector2.ZERO
	var dirc := Vector2.ZERO
	for k in toques_dir:
		var d: Vector2 = toques_dir[k]
		if d.y < 0:
			cima = Vector2(0, -1)
		if d.y > 0:
			baixo = Vector2(0, 1)
		if d.x < 0:
			esq = Vector2(-1, 0)
		if d.x > 0:
			dirc = Vector2(1, 0)
	_botao_dir(pad_center + Vector2(0, -pad_braco), 30.0, cima != Vector2.ZERO, Vector2(0, -1))
	_botao_dir(pad_center + Vector2(0, pad_braco), 30.0, baixo != Vector2.ZERO, Vector2(0, 1))
	_botao_dir(pad_center + Vector2(-pad_braco, 0), 30.0, esq != Vector2.ZERO, Vector2(-1, 0))
	_botao_dir(pad_center + Vector2(pad_braco, 0), 30.0, dirc != Vector2.ZERO, Vector2(1, 0))
	draw_circle(pad_center, 16.0, Color(0.1, 0.3, 0.14, 0.6))
	# botao de tiro
	var atirando := not fire_ids.is_empty()
	draw_circle(fire_center, fire_r, Color(0.1, 0.5, 0.18, 0.75 if atirando else 0.4))
	draw_arc(fire_center, fire_r, 0, TAU, 44, Color(0.4, 1.0, 0.55, 1.0), 3.5)
	var fnt := ThemeDB.fallback_font
	draw_string(fnt, fire_center + Vector2(-32, 8), "FOGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 1.0, 0.8, 1.0 if atirando else 0.7))
	# pausa
	draw_arc(pause_center, 22.0, 0, TAU, 28, Color(0.7, 0.8, 0.75, 0.7), 2.0)
	draw_line(pause_center + Vector2(-6, -8), pause_center + Vector2(-6, 8), Color(0.8, 0.9, 0.85, 0.8), 3.0)
	draw_line(pause_center + Vector2(6, -8), pause_center + Vector2(6, 8), Color(0.8, 0.9, 0.85, 0.8), 3.0)

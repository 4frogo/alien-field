extends Node2D
# Nave do jogador - igual parte de baixo da imagem

var speed := 300.0
var shoot_cooldown := 0.0
var invencivel := 0.0
var move_target := Vector2.ZERO
var dragging := false
var fogo_touch := false

signal atirar(pos: Vector2)
signal super_tiro(pos: Vector2)

var sprite: Sprite2D = null
var tem_sprite := false
var carregando := false
var carga := 0.0
var carga_max := 3.0
var charge_fx: Sprite2D = null
var charge_mat: ShaderMaterial = null
var danger_fx: Sprite2D = null
var danger_mat: ShaderMaterial = null
var arma_equip: Sprite2D = null
var escudo_sprite: Sprite2D = null
var escudo_base := 0.30
var escudo_val := 100.0
var escudo_flash := 0.0
var cacos: Array = []
var pontos_energia: Array = []
var tempo_escudo := 0.0
var impulso := 0.0

func escudo_atingido() -> void:
	escudo_flash = 1.0
	# espalha a nuvem
	for pt in pontos_energia:
		pt["ang"] = float(pt["ang"]) + randf_range(-1.2, 1.2)

func set_equipado(on: bool) -> void:
	if arma_equip != null:
		arma_equip.visible = on and (invencivel <= 0 or int(Time.get_ticks_msec() / 100) % 2 == 1)

func carga_progress() -> float:
	if not carregando:
		return 0.0
	return clampf((carga - 0.45) / (carga_max - 0.45), 0.0, 1.0)

func carga_pronta() -> bool:
	return carregando and carga >= carga_max

func _fazer_textura_radial(tam: int = 128) -> ImageTexture:
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := float(tam) / 2.0
	for y in tam:
		for x in tam:
			var dx := (float(x) - c + 0.5) / c
			var dy := (float(y) - c + 0.5) / c
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	position = Vector2(270, 800)
	# tenta usar a imagem real da nave (png ou jpg)
	for pp in ["res://assets/player.png", "res://assets/player.jpg"]:
		if ResourceLoader.exists(pp):
			var tex := load(pp) as Texture2D
			if tex != null:
				sprite = Sprite2D.new()
				sprite.texture = tex
				# nave ocupa ~78% da imagem quadrada, queremos nave com ~130px
				var w := float(tex.get_width())
				if w > 0:
					var s := 165.0 / w
					sprite.scale = Vector2(s, s)
				# shader tira o fundo preto e deixa so a nave + brilho
				if ResourceLoader.exists("res://assets/remove_black.gdshader"):
					var sh := load("res://assets/remove_black.gdshader") as Shader
					var mat := ShaderMaterial.new()
					mat.shader = sh
					sprite.material = mat
				add_child(sprite)
				tem_sprite = true
				break
	# fx de carga kamehameha (plasma RGB via shader, sem vetor)
	charge_fx = Sprite2D.new()
	charge_fx.texture = _fazer_textura_radial()
	charge_fx.position = Vector2(0, -70)
	charge_fx.visible = false
	if ResourceLoader.exists("res://assets/energy_ball.gdshader"):
		var sh := load("res://assets/energy_ball.gdshader") as Shader
		charge_mat = ShaderMaterial.new()
		charge_mat.shader = sh
		charge_mat.set_shader_parameter("charge", 0.0)
		charge_mat.set_shader_parameter("speed", 3.5)
		charge_fx.material = charge_mat
	add_child(charge_fx)
	# aura vermelha de perigo (aparece nos 40% finais)
	danger_fx = Sprite2D.new()
	danger_fx.texture = _fazer_textura_radial()
	danger_fx.position = Vector2(0, -70)
	danger_fx.visible = false
	danger_fx.modulate = Color(1, 0.25, 0.2, 0.8)
	if ResourceLoader.exists("res://assets/energy_ball.gdshader"):
		var sh2 := load("res://assets/energy_ball.gdshader") as Shader
		danger_mat = ShaderMaterial.new()
		danger_mat.shader = sh2
		danger_mat.set_shader_parameter("charge", 1.0)
		danger_mat.set_shader_parameter("speed", 7.0)
		danger_fx.material = danger_mat
	add_child(danger_fx)
	# canhao plasma equipado (aparece nos 15s de triplo)
	for ap in ["res://assets/arma plasma.png", "res://assets/arma_plasma.png"]:
		if ResourceLoader.exists(ap):
			var atx := load(ap) as Texture2D
			if atx != null:
				arma_equip = Sprite2D.new()
				arma_equip.texture = atx
				var aw := float(atx.get_width())
				if aw > 0:
					var asc := 96.0 / aw
					arma_equip.scale = Vector2(asc, asc)
				arma_equip.rotation = -PI / 2.0 # aponta pra cima
				arma_equip.position = Vector2(0, -52)
				arma_equip.visible = false
				add_child(arma_equip)
				break
	# escudo modular: imagem em anel girando devagar ao redor da nave
	for ep in ["res://assets/escudomodular.png", "res://assets/escudomocular.png"]:
		if ResourceLoader.exists(ep):
			var etx := load(ep) as Texture2D
			if etx != null:
				escudo_sprite = Sprite2D.new()
				escudo_sprite.texture = etx
				escudo_sprite.scale = Vector2(escudo_base, escudo_base)
				escudo_sprite.visible = false
				add_child(escudo_sprite)
				break
	# escudo dissolvido: 110 microparticulas no anel 58-92 + 4 nos de energia
	for i in 110:
		var rol := randf()
		pontos_energia.append({
			"ang": randf_range(0.0, TAU),
			"base": randf_range(58.0, 92.0),
			"raio": 70.0,
			"vel": randf_range(0.7, 1.8) * (1.0 if i % 2 == 0 else -1.0),
			"tam": randf_range(1.0, 2.6),
			"kind": 0 if rol < 0.6 else (1 if rol < 0.85 else 2),
			"fase": randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	shoot_cooldown -= delta
	invencivel -= delta
	tempo_escudo += delta
	escudo_flash = maxf(0.0, escudo_flash - delta * 2.5)
	# anel estatico desligado: escudo agora e so nuvem de microparticulas
	if escudo_sprite != null:
		escudo_sprite.visible = false
	for pt in pontos_energia:
		pt["ang"] = float(pt["ang"]) + float(pt["vel"]) * delta
		pt["raio"] = float(pt["base"]) + sin(tempo_escudo * 3.0 + float(pt["fase"])) * 4.0
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	position += dir.normalized() * speed * delta

	if dragging and move_target != Vector2.ZERO:
		var antes := position
		position = position.lerp(move_target, 12.0 * delta)
		var arrasto := (position - antes) / maxf(delta, 0.001) / speed
		if arrasto.length() > 0.15:
			dir = arrasto.limit_length(1.0)

	position.x = clamp(position.x, 95.0, 445.0)
	position.y = clamp(position.y, 400.0, 900.0)
	# impulso pros propulsores (0 parado, 1 movendo)
	impulso = lerpf(impulso, clampf(dir.length(), 0.0, 1.0), minf(1.0, 6.0 * delta))

	# efeito 3D: inclina (bank) pros lados, arfagem vertical leve
	var alvo_rot := dir.x * 0.32
	rotation = lerpf(rotation, alvo_rot, minf(1.0, 10.0 * delta))
	var alvo_sx := 1.0 + absf(dir.x) * 0.10
	var alvo_sy := 1.0 - dir.y * 0.04 - absf(dir.x) * 0.03
	scale = scale.lerp(Vector2(alvo_sx, alvo_sy), minf(1.0, 8.0 * delta))

	# tiro manual na tecla L / botao touch + super carregado 3s
	var segurando := Input.is_key_pressed(KEY_L) or fogo_touch
	if segurando:
		if not carregando:
			carregando = true
			carga = 0.0
		carga += delta
		if carga < 0.45:
			# rajada normal no inicio
			if shoot_cooldown <= 0:
				shoot_cooldown = 0.18
				var offset_y := -60.0 if tem_sprite else -38.0
				atirar.emit(position + Vector2(0, offset_y))
		# depois de 0.45s para de atirar e so carrega
	else:
		if carregando:
			if carga >= carga_max:
				var offset_y := -70.0 if tem_sprite else -48.0
				super_tiro.emit(position + Vector2(0, offset_y))
			carregando = false
			carga = 0.0
	# atualiza fx plasma + tremor de perigo
	if charge_fx != null:
		if carregando and carga >= 0.45:
			var k := clampf((carga - 0.45) / (carga_max - 0.45), 0.0, 1.0)
			charge_fx.visible = invencivel <= 0 or int(Time.get_ticks_msec() / 100) % 2 == 1
			var sc := 0.35 + 0.95 * k
			charge_fx.scale = Vector2(sc, sc)
			if charge_mat != null:
				charge_mat.set_shader_parameter("charge", k)
				charge_mat.set_shader_parameter("speed", 3.5 + 4.0 * k)
			# tremor cresce com a carga (perigo)
			var tremor := k * k * 7.0
			position.x = clamp(position.x + randf_range(-tremor, tremor), 95.0, 445.0)
			position.y = clamp(position.y + randf_range(-tremor, tremor) * 0.6, 400.0, 900.0)
			# aura vermelha nos 40% finais
			if danger_fx != null:
				if k > 0.6:
					danger_fx.visible = charge_fx.visible
					var dk := (k - 0.6) / 0.4
					var dsc := (0.8 + 1.3 * dk) * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 70.0))
					danger_fx.scale = Vector2(dsc, dsc)
					if danger_mat != null:
						danger_mat.set_shader_parameter("charge", dk)
				else:
					danger_fx.visible = false
		else:
			charge_fx.visible = false
			if danger_fx != null:
				danger_fx.visible = false

	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		dragging = event.pressed
		if event.pressed:
			move_target = get_global_mouse_position()
	elif event is InputEventMouseMotion and dragging:
		move_target = get_global_mouse_position()
	elif event is InputEventScreenTouch:
		dragging = event.pressed
		if event.pressed:
			move_target = event.position
	elif event is InputEventScreenDrag:
		move_target = event.position

func _draw() -> void:
	_draw_escudo_fundo()
	if invencivel > 0 and int(Time.get_ticks_msec() / 100) % 2 == 0:
		if sprite != null:
			sprite.visible = false
		_draw_escudo_particulas()
		return # piscando
	if sprite != null:
		sprite.visible = true
	if tem_sprite:
		# arte vem do PNG (aura verde removida)
		_chama_motor(Vector2(-32, 30))
		_chama_motor(Vector2(32, 30))
		_draw_escudo_particulas()
		return
	# glow verde em volta
	draw_circle(Vector2.ZERO, 42, Color(0.1, 1.0, 0.4, 0.12))
	# asas laterais
	var asa_esq := PackedVector2Array([Vector2(-8, 5), Vector2(-58, 18), Vector2(-48, 0), Vector2(-12, -18)])
	var asa_dir := PackedVector2Array([Vector2(8, 5), Vector2(58, 18), Vector2(48, 0), Vector2(12, -18)])
	draw_colored_polygon(asa_esq, Color(0.18, 0.2, 0.2))
	draw_colored_polygon(asa_dir, Color(0.18, 0.2, 0.2))
	# contorno neon
	draw_line(Vector2(-8, 5), Vector2(-58, 18), Color(0.3, 1.0, 0.5), 2.0)
	draw_line(Vector2(8, 5), Vector2(58, 18), Color(0.3, 1.0, 0.5), 2.0)
	draw_circle(Vector2(-58, 18), 3, Color(0.4, 1.0, 0.6))
	draw_circle(Vector2(58, 18), 3, Color(0.4, 1.0, 0.6))
	# corpo central metalico
	var corpo := PackedVector2Array([Vector2(0, -52), Vector2(14, -20), Vector2(16, 20), Vector2(0, 44), Vector2(-16, 20), Vector2(-14, -20)])
	draw_colored_polygon(corpo, Color(0.22, 0.24, 0.24))
	draw_colored_polygon(corpo, Color(0, 0, 0, 0)) # keep
	draw_polyline(corpo + PackedVector2Array([corpo[0]]), Color(0.4, 1.0, 0.55), 2.0)
	# motores laterais
	for sx in [-26, 26]:
		draw_rect(Rect2(sx - 7, -18, 14, 44), Color(0.15, 0.17, 0.17))
		draw_rect(Rect2(sx - 7, -18, 14, 44), Color(0.3, 1.0, 0.5, 0.9), false, 1.5)
		draw_circle(Vector2(sx, -18), 4, Color(0.2, 0.8, 0.35))
		draw_circle(Vector2(sx, 26), 5, Color(0.15, 0.6, 0.25))
		draw_circle(Vector2(sx, 26), 2.5, Color(0.5, 1.0, 0.6))
	# nucleo central verde (igual imagem)
	draw_ellipse(Vector2(0, 8), 11, 17, Color(0.02, 0.15, 0.06))
	draw_ellipse(Vector2(0, 8), 8, 13, Color(0.1, 0.7, 0.28))
	draw_ellipse(Vector2(0, 8), 4, 9, Color(0.6, 1.0, 0.7))
	# antena topo
	draw_line(Vector2(0, -52), Vector2(0, -62), Color(0.4, 1.0, 0.6), 2.0)
	draw_circle(Vector2(0, -64), 3, Color(0.5, 1.0, 0.65))
	_draw_escudo_particulas()

func _draw_escudo_fundo() -> void:
	# desativado: anel usa a imagem escudomodular.png
	return

func _draw_escudo_particulas() -> void:
	if escudo_val <= 0.0:
		return
	var forca := clampf(escudo_val / 100.0, 0.0, 1.0)
	for pt in pontos_energia:
		var pp := Vector2(cos(float(pt["ang"])), sin(float(pt["ang"]))) * float(pt["raio"])
		var tw := 0.45 + 0.55 * (0.5 + 0.5 * sin(tempo_escudo * 7.0 + float(pt["fase"])))
		var w: float = float(pt["tam"])
		var a := (0.25 + 0.75 * forca) * tw + escudo_flash * 0.5
		if int(pt["kind"]) == 0:
			draw_circle(pp, w, Color(0.35, 1.0, 0.5, a))
		elif int(pt["kind"]) == 1:
			draw_circle(pp, w, Color(0.95, 1.0, 0.95, a))
		else:
			draw_circle(pp, w, Color(0.75, 0.85, 0.9, a))
	# 4 nos de energia nos pontos cardeais (concentracao)
	for i in 4:
		var na := tempo_escudo * 0.5 + TAU * float(i) / 4.0
		var np := Vector2(cos(na), sin(na)) * 75.0
		var pulse := 0.7 + 0.3 * sin(tempo_escudo * 5.0 + float(i) * 1.7)
		draw_circle(np, 6.0 * pulse, Color(0.4, 1.0, 0.55, 0.3 * forca))
		draw_circle(np, 2.6 * pulse, Color(1, 1, 1, 0.55 + 0.4 * forca))

func _draw_carga() -> void:
	# desativado: carga agora e shader RGB (charge_fx), sem vetor
	return

func _chama_motor(bico: Vector2) -> void:
	# labareda do propulsor pra tras (+y) com tremor
	var t := Time.get_ticks_msec() / 1000.0
	var comp := 13.0 + impulso * 15.0 + sin(t * 31.0 + bico.x) * 3.5 + sin(t * 57.0) * 2.0
	var larg := 7.0
	var ponta := bico + Vector2(sin(t * 41.0 + bico.x * 2.0) * 2.5, comp)
	# brasa externa
	draw_colored_polygon(PackedVector2Array([bico + Vector2(-larg, 0), bico + Vector2(larg, 0), ponta]), Color(0.1, 0.85, 0.3, 0.35))
	# nucleo verde
	var larg2 := larg * 0.6
	var ponta2 := bico + Vector2(0, comp * 0.7)
	draw_colored_polygon(PackedVector2Array([bico + Vector2(-larg2, 0), bico + Vector2(larg2, 0), ponta2]), Color(0.35, 1.0, 0.5, 0.85))
	# filete branco quente
	var larg3 := larg * 0.28
	var ponta3 := bico + Vector2(0, comp * 0.45)
	draw_colored_polygon(PackedVector2Array([bico + Vector2(-larg3, 0), bico + Vector2(larg3, 0), ponta3]), Color(0.9, 1.0, 0.92, 0.95))
	# boca do motor acesa
	draw_circle(bico, 4.5, Color(0.15, 0.6, 0.25))
	draw_circle(bico, 2.5, Color(0.6, 1.0, 0.7))

func draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

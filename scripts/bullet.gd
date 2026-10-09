extends Node2D
# Tiro verde do jogador e orbe laranja do inimigo

var vel := Vector2(0, -620)
var amigo := true
var raio := 8.0
var vivo := true
var tempo := 0.0
var dano := 1
var e_super := false
var e_triplo := false
var e_laser := false
var perfurante := false
var vida_perfurante := 99
var fx: Sprite2D = null
var fx_base := Vector2.ONE
var fx_fase := 0.0

func _fazer_textura_feixe(w: int = 64, h: int = 256) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			var a := clampf(1.0 - dx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _fazer_textura_radial(tam: int = 128) -> ImageTexture:
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := float(tam) / 2.0
	for y in tam:
		for x in tam:
			var dx := (float(x) - c + 0.5) / c
			var dy := (float(y) - c + 0.5) / c
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.3)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func setup(p: Vector2, v: Vector2, e_amigo: bool, p_dano: int = 1, p_super: bool = false) -> void:
	position = p
	vel = v
	amigo = e_amigo
	dano = p_dano
	e_super = p_super
	if e_super:
		raio = 30.0
		perfurante = true
		vida_perfurante = 99
		fx = Sprite2D.new()
		fx.texture = _fazer_textura_radial()
		fx.scale = Vector2(1.15, 1.15)
		if ResourceLoader.exists("res://assets/energy_ball.gdshader"):
			var sh := load("res://assets/energy_ball.gdshader") as Shader
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("charge", 1.0)
			mat.set_shader_parameter("speed", 5.0)
			fx.material = mat
		add_child(fx)
	elif not amigo:
		# plasma vermelho dos inimigos (tema do jogo)
		raio = 10.0
		fx = Sprite2D.new()
		fx.texture = _fazer_textura_radial()
		fx.scale = Vector2(0.30, 0.30)
		_aplicar_shader_inimigo(fx, 0.8, 4.5)
		add_child(fx)
	else:
		raio = 8.0

func _aplicar_shader_inimigo(sp: Sprite2D, carga: float, vel: float) -> void:
	if ResourceLoader.exists("res://assets/enemy_ball.gdshader"):
		var sh := load("res://assets/enemy_ball.gdshader") as Shader
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("charge", carga)
		mat.set_shader_parameter("speed", vel)
		sp.material = mat

func setup_triplotiro(p: Vector2, v: Vector2, p_dano: int = 6) -> void:
	# leque triplo: imagem cheia, bocas na base encostando no bico da nave
	position = p
	vel = v
	amigo = true
	dano = p_dano
	e_super = false
	e_triplo = true
	perfurante = false
	raio = 40.0
	fx_fase = randf() * TAU
	for bp in ["res://assets/triplotiro.jpg", "res://assets/triplotiro.png", "res://assets/tirotriplo.png", "res://assets/tirotriplo.jpg"]:
		if ResourceLoader.exists(bp):
			var tex := load(bp) as Texture2D
			if tex != null:
				fx = Sprite2D.new()
				fx.texture = tex
				var tw := float(tex.get_width())
				if tw > 0:
					var s := 170.0 / tw
					# variacao por rajada pra nao parecer carimbo
					s *= randf_range(0.94, 1.06)
					fx_base = Vector2(s, s)
					fx.scale = fx_base
					fx.rotation = randf_range(-0.05, 0.05)
				if ResourceLoader.exists("res://assets/remove_black.gdshader"):
					var sh := load("res://assets/remove_black.gdshader") as Shader
					var mat := ShaderMaterial.new()
					mat.shader = sh
					fx.material = mat
				add_child(fx)
				break

func setup_gigante(p: Vector2, v: Vector2) -> void:
	# bola do chefao - gigante, maior que a nave
	position = p
	vel = v
	amigo = false
	dano = 2
	e_super = false
	e_triplo = false
	e_laser = false
	perfurante = false
	raio = 42.0
	fx = Sprite2D.new()
	fx.texture = _fazer_textura_radial()
	fx.scale = Vector2(2.6, 2.6)
	_aplicar_shader_inimigo(fx, 1.0, 2.5)
	add_child(fx)

func setup_laser(p: Vector2, v: Vector2, p_dano: int = 25) -> void:
	# super laser RGB branco/rosa/roxo de longo alcance
	position = p
	vel = v
	amigo = true
	dano = p_dano
	e_super = false
	e_triplo = false
	e_laser = true
	perfurante = true
	vida_perfurante = 99
	raio = 90.0
	fx = Sprite2D.new()
	fx.texture = _fazer_textura_feixe()
	fx.scale = Vector2(1.0, 2.8)
	fx.position = Vector2(0, -330) # feixe estende pra cima a partir do bico
	if ResourceLoader.exists("res://assets/laser_rgb.gdshader"):
		var sh := load("res://assets/laser_rgb.gdshader") as Shader
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("speed", 6.0)
		fx.material = mat
	add_child(fx)

func _process(delta: float) -> void:
	tempo += delta
	position += vel * delta
	if e_laser:
		if position.y < -800:
			vivo = false
			queue_free()
		queue_redraw()
		return
	if e_triplo and fx != null:
		# rajada viva: pulso + tremor + cintilacao (nada congelado)
		var t := tempo + fx_fase
		fx.scale = fx_base * (1.0 + 0.07 * sin(t * 21.0))
		fx.rotation += sin(t * 13.0) * 0.012
		fx.modulate = Color(1.0, 1.0, 1.0, 0.9 + 0.1 * sin(t * 27.0))
	if position.y < -40 or position.y > 1000 or position.x < -20 or position.x > 560:
		vivo = false
		queue_free()
	queue_redraw()

func _draw() -> void:
	if e_laser and fx != null:
		_draw_vortice()
		_draw_raios()
		return
	if fx != null:
		# 100% shader (super verde, plasma vermelho, gigante), zero vetor
		return
	if amigo:
		# rastro
		var dir := -vel.normalized()
		for i in 3:
			var tp := dir * float(i + 1) * 10.0
			var a := 0.35 - float(i) * 0.1
			draw_circle(tp, 4.0 - float(i), Color(0.1, 1.0, 0.4, a))
		# laser verde triplo igual imagem
		draw_circle(Vector2.ZERO, 11, Color(0.1, 1.0, 0.4, 0.3))
		draw_circle(Vector2.ZERO, 6, Color(0.15, 0.9, 0.35))
		draw_circle(Vector2.ZERO, 3.0, Color(0.9, 1.0, 0.92))
		draw_rect(Rect2(-1.5, -18, 3, 14), Color(0.7, 1.0, 0.75))
	else:
		# fallback sem shader (nunca deve aparecer)
		var pulse := 1.0 + 0.18 * sin(tempo * 14.0)
		draw_circle(Vector2.ZERO, 12 * pulse, Color(1.0, 0.15, 0.1, 0.35))
		draw_circle(Vector2.ZERO, 7.5 * pulse, Color(0.95, 0.2, 0.08))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.6, 0.2))

func _draw_vortice() -> void:
	# boca do canhao: aneis girando laranja/ciano/roxo + flash (igual ref)
	var base := Vector2(0, 20)
	var flash := 0.7 + 0.3 * sin(tempo * 31.0)
	draw_circle(base, 16.0 * flash + 4.0, Color(1, 1, 1, 0.85))
	draw_circle(base, 24.0 * flash + 6.0, Color(1, 0.85, 0.4, 0.5))
	var r1 := tempo * 3.2
	var r2 := -tempo * 2.3 + 1.0
	var r3 := tempo * 4.1 + 2.0
	draw_arc(base, 26.0, r1, r1 + 4.4, 24, Color(1, 0.6, 0.12, 0.9), 3.5)
	draw_arc(base, 36.0, r2, r2 + 3.8, 24, Color(0.25, 0.95, 1.0, 0.85), 2.5)
	draw_arc(base, 47.0, r3, r3 + 4.9, 28, Color(0.7, 0.3, 1.0, 0.7), 2.0)
	draw_arc(base, 47.0, -r3, -r3 + 2.2, 20, Color(1, 0.3, 0.8, 0.5), 1.5)

func _draw_raios() -> void:
	# relampagos ciano/magenta subindo pelas bordas do feixe + faiscas
	var passo := int(tempo / 0.07)
	var rng := RandomNumberGenerator.new()
	for lado in [-1, 1]:
		for linha in 2:
			rng.seed = passo * 131 + lado * 17 + linha * 101
			var pts := PackedVector2Array()
			var x := float(lado) * (16.0 + float(linha) * 8.0)
			var y := 20.0
			pts.append(Vector2(x, y))
			while y > -660.0:
				y -= rng.randf_range(28.0, 52.0)
				x = float(lado) * rng.randf_range(10.0, 34.0)
				pts.append(Vector2(x, y))
			var cor := Color(0.3, 1.0, 1.0, 0.9) if (linha + (1 if lado > 0 else 0)) % 2 == 0 else Color(1.0, 0.3, 1.0, 0.9)
			draw_polyline(pts, cor, 2.0)
	# faiscas subindo pelo feixe
	rng.seed = passo * 57 + 7
	for i in 12:
		var fx_ := rng.randf_range(-26.0, 26.0)
		var fy := rng.randf_range(-650.0, 10.0)
		var tam := rng.randf_range(1.5, 3.5)
		var cc := Color(1, 0.9, 0.4, 0.9) if i % 3 == 0 else (Color(0.4, 1, 1, 0.9) if i % 3 == 1 else Color(1, 0.4, 1, 0.9))
		draw_circle(Vector2(fx_, fy), tam, cc)

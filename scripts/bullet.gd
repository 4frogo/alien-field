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
var e_disparo := false
var perfurante := false
var vida_perfurante := 99
var fx: Sprite2D = null
var fx_base := Vector2.ONE
var fx_fase := 0.0
# Rastro de plasma por SHADER (tiro_plasma.gdshader). Sprite2D separado,
# rotacionado para a velocidade do projetil, com UV.y = cauda..ponta.
# Se o shader nao carregar, _rastro_plasma fica null e o desenho antigo
# em _draw() assume sem erro.
var fx_plasma: Sprite2D = null
var _plasma_mat: ShaderMaterial = null

# escala do projetil: a caixa VERDE aumenta os disparos normais, entao
# o raio de colisao e o tamanho desenhado crescem junto (area maior).
var escala := 1.0

func setup_disparo(p: Vector2, v: Vector2, qual: int = 0, p_escala: float = 1.0) -> void:
	# tiro normal desenhado a mao: raio de energia (sem imagem)
	position = p
	vel = v
	amigo = true
	dano = 2
	e_disparo = true
	escala = clampf(p_escala, 0.5, 4.0)
	raio = 9.0 * escala
	fx = null
	fx_fase = float(qual) * 2.1 + randf() * 0.6

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
		_criar_rastro_plasma()


# Cria o rastro procedural do tiro normal do jogador. O Sprite2D fica
# com a origem no CENTRO e e rotacionado toda frame para a velocidade,
# de modo que o UV.y do shader corre da cauda (0) ate a ponta (1).
func _criar_rastro_plasma() -> void:
	if not ResourceLoader.exists("res://assets/tiro_plasma.gdshader"):
		return
	var img := Image.create(4, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	fx_plasma = Sprite2D.new()
	fx_plasma.texture = ImageTexture.create_from_image(img)
	fx_plasma.centered = true
	fx_plasma.z_index = -1
	_plasma_mat = ShaderMaterial.new()
	_plasma_mat.shader = load("res://assets/tiro_plasma.gdshader") as Shader
	if _plasma_mat.shader == null:
		_plasma_mat = null
		fx_plasma.queue_free()
		fx_plasma = null
		return
	_plasma_mat.set_shader_parameter("semente", randf() * 30.0)
	_plasma_mat.set_shader_parameter("comprimento", 0.82)
	_plasma_mat.set_shader_parameter("largura", 0.42)
	fx_plasma.material = _plasma_mat
	add_child(fx_plasma)


func _atualiza_rastro_plasma() -> void:
	if fx_plasma == null or _plasma_mat == null:
		return
	var v := vel
	var comp: float = 74.0
	var larg: float = 15.0
	if v.length() > 0.01:
		# rotaciona para que o eixo Y local (UV.y) aponte no sentido da
		# velocidade: local +Y == vel.normalizado() -> r = atan2(-x, y)
		fx_plasma.rotation = atan2(-v.x, v.y)
	# o quad e centrado: desloca metade pra tras, pra ponta ficar na
	# posicao do projetil
	var d := v.normalized()
	fx_plasma.position = -d * comp * 0.42
	fx_plasma.scale = Vector2(larg / 4.0, comp / 8.0)
	_plasma_mat.set_shader_parameter("tempo", fmod(tempo, 100.0))

func _aplicar_shader_inimigo(sp: Sprite2D, carga: float, vel: float) -> void:
	if ResourceLoader.exists("res://assets/enemy_ball.gdshader"):
		var sh := load("res://assets/enemy_ball.gdshader") as Shader
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("charge", carga)
		mat.set_shader_parameter("speed", vel)
		sp.material = mat

func setup_triplotiro(p: Vector2, v: Vector2, p_dano: int = 6) -> void:
	# triplo 100% procedural: orbe de plasma + 3 raios desenhados
	position = p
	vel = v
	amigo = true
	dano = p_dano
	e_super = false
	e_triplo = true
	perfurante = false
	raio = 40.0
	fx = null
	fx_fase = randf() * TAU

func setup_gigante(p: Vector2, v: Vector2) -> void:
	# bola do chefao - gigante, maior que a nave
	position = p
	vel = v
	amigo = false
	dano = 2
	e_super = false
	e_triplo = false
	perfurante = false
	raio = 42.0
	fx = Sprite2D.new()
	fx.texture = _fazer_textura_radial()
	fx.scale = Vector2(2.6, 2.6)
	_aplicar_shader_inimigo(fx, 1.0, 2.5)
	add_child(fx)

func _process(delta: float) -> void:
	tempo += delta
	position += vel * delta
	_atualiza_rastro_plasma()
	if e_triplo and fx != null:
		# rajada viva: pulso + tremor + cintilacao (nada congelado)
		var t := tempo + fx_fase
		fx.scale = fx_base * (1.0 + 0.07 * sin(t * 21.0))
		fx.rotation += sin(t * 13.0) * 0.012
		fx.modulate = Color(1.0, 1.0, 1.0, 0.9 + 0.1 * sin(t * 27.0))
	if e_disparo and fx != null:
		# cristal vivo: pulso suave + cintilacao (mantem o tom verde)
		var td := tempo + fx_fase
		fx.scale = fx_base * (1.0 + 0.06 * sin(td * 19.0))
		fx.modulate = Color(0.82, 1.0, 0.88, 0.92 + 0.08 * sin(td * 25.0))
	if position.y < -40 or position.y > 1000 or position.x < -20 or position.x > 560:
		vivo = false
		queue_free()
	queue_redraw()

## Tracer: fita fina atras do projetil. Como as balas voam em linha reta,
## da pra desenhar so do sentido da velocidade — sem historico de posicoes,
## e sem no extra: morre junto com o projetil.
func _rastro(dir: Vector2, comp: float, larg: float, cor: Color) -> void:
	if dir.length() < 0.01:
		return
	var d := dir.normalized()
	var ponta := d * comp
	var per := Vector2(-d.y, d.x)
	# halo largo e translucido
	draw_colored_polygon(PackedVector2Array([
		per * larg * 2.4, ponta + per * larg * 0.5,
		ponta - per * larg * 0.5, -per * larg * 2.4,
	]), Color(cor.r, cor.g, cor.b, 0.16))
	# corpo
	draw_colored_polygon(PackedVector2Array([
		per * larg, ponta + per * larg * 0.12,
		ponta - per * larg * 0.12, -per * larg,
	]), Color(cor.r, cor.g, cor.b, 0.45))
	# nucleo claro
	draw_line(Vector2.ZERO, ponta, Color(1, 1, 1, 0.5), maxf(0.8, larg * 0.35), true)
	# pulsos de energia rolando pelo rastro
	for i in 3:
		var f: float = fmod(tempo * 2.4 + float(i) / 3.0, 1.0)
		var w: float = larg * (1.0 - f) * 0.85
		if w > 0.4:
			draw_circle(d * comp * f, w, Color(1, 1, 1, 0.30 * (1.0 - f)))

func _raio_plasma(base: Vector2, ang: float, comp: float, fase: float) -> void:
	# raio de plasma em 3 camadas com tremor eletrico
	var c := comp * (1.0 + 0.09 * sin(tempo * 21.0 + fase))
	var dir := Vector2(sin(ang), -cos(ang))
	var bal := sin(tempo * 37.0 + fase * 2.0) * 2.0
	var ponta := base + dir * c + Vector2(bal, 0)
	var per := Vector2(-dir.y, dir.x)
	var w := 8.0
	draw_colored_polygon(PackedVector2Array([base + per * w, base - per * w, ponta]), Color(0.12, 0.85, 0.3, 0.40))
	var w2 := w * 0.55
	var ponta2 := base + dir * (c * 0.82)
	draw_colored_polygon(PackedVector2Array([base + per * w2, base - per * w2, ponta2]), Color(0.35, 1.0, 0.5, 0.9))
	var w3 := w * 0.25
	var ponta3 := base + dir * (c * 0.6)
	draw_colored_polygon(PackedVector2Array([base + per * w3, base - per * w3, ponta3]), Color(0.92, 1.0, 0.94, 0.95))
	# lingua eletrica na ponta
	var zig := ponta + Vector2(sin(tempo * 47.0 + fase * 3.0) * 5.0, -8.0)
	draw_line(ponta, zig, Color(0.7, 1.0, 0.75, 0.8), 1.5)

func _draw() -> void:
	if e_disparo:
		# raio de energia desenhado a mao, tremeluzindo
		var t := tempo * 25.0 + fx_fase
		var pul := 1.0 + 0.12 * sin(t)
		var s := escala     # caixa verde deixa o tiro maior (area maior)
		# rastro: glow na base + tracer atras
		draw_circle(Vector2(0, 12 * s), 5.0 * s, Color(0.15, 0.9, 0.35, 0.25))
		draw_circle(Vector2(0, 8 * s), 3.0 * s, Color(0.4, 1.0, 0.5, 0.4))
		_rastro(Vector2.DOWN, 34.0 * s, 3.6 * s, Color(0.3, 1.0, 0.5))
		# corpo: losango alongado em 3 camadas
		var w := 6.5 * pul * s
		var tip := -24.0 * pul * s
		draw_colored_polygon(PackedVector2Array([Vector2(0, tip), Vector2(w, -4 * s), Vector2(0, 12 * s), Vector2(-w, -4 * s)]), Color(0.15, 0.85, 0.32, 0.55))
		var w2 := w * 0.55
		var tip2 := -19.0 * pul * s
		draw_colored_polygon(PackedVector2Array([Vector2(0, tip2), Vector2(w2, -3 * s), Vector2(0, 9 * s), Vector2(-w2, -3 * s)]), Color(0.4, 1.0, 0.55, 0.9))
		var w3 := w * 0.25
		draw_colored_polygon(PackedVector2Array([Vector2(0, tip2 + 3.0 * s), Vector2(w3, -2 * s), Vector2(0, 7 * s), Vector2(-w3, -2 * s)]), Color(0.93, 1.0, 0.94, 0.95))
		# faisca na ponta
		draw_circle(Vector2(sin(t * 1.7) * 2.0 * s, tip), 2.0 * s, Color(0.9, 1.0, 0.9, 0.8))
		return
	if e_triplo:
		# brasa na boca
		var brasa := 0.7 + 0.3 * sin(tempo * 23.0 + fx_fase)
		draw_circle(Vector2(0, 20), 20.0 * brasa, Color(0.2, 1.0, 0.45, 0.35))
		draw_circle(Vector2(0, 20), 10.0 * brasa, Color(0.7, 1.0, 0.75, 0.6))
		# 3 raios de plasma em leque
		_raio_plasma(Vector2(-26, 14), -0.20, 56.0, fx_fase)
		_raio_plasma(Vector2(0, 10), 0.0, 70.0, fx_fase + 2.1)
		_raio_plasma(Vector2(26, 14), 0.20, 56.0, fx_fase + 4.2)
		# faiscas orbitando o orbe de plasma
		for i in 7:
			var a := tempo * 4.5 + TAU * float(i) / 7.0
			var pp := Vector2(cos(a), sin(a)) * 62.0
			var tw := 0.5 + 0.5 * sin(tempo * 11.0 + float(i) * 2.2)
			draw_circle(pp, 3.2 * tw + 1.0, Color(0.5, 1.0, 0.6, 0.85))
		return
	if fx != null:
		# 100% shader (super verde, plasma vermelho, gigante), zero vetor
		# + tracer atras pra deixar o tiro legivel
		var tras := -vel.normalized()
		if e_super:
			_rastro(tras, 70.0, 9.0, Color(0.35, 1.0, 0.55))
		elif raio > 25.0:
			# bola gigante do chefao
			_rastro(tras, 64.0, 11.0, Color(1.0, 0.30, 0.16))
		else:
			_rastro(tras, 42.0, 4.5, Color(1.0, 0.45, 0.20))
		return
	if amigo:
		# Tiro do player.
		if fx_plasma != null:
			# COM shader: o rastro vem do tiro_plasma.gdshader. Aqui so
			# o nucleo incandescente, pra marcar o ponto de luz na frente.
			var pl := 1.0 + 0.10 * sin(tempo * 18.0)
			draw_circle(Vector2.ZERO, 7.0 * pl, Color(0.55, 1.0, 0.70, 0.75))
			draw_circle(Vector2.ZERO, 4.0 * pl, Color(0.90, 1.0, 0.95, 0.95))
			# bico brilhante
			draw_rect(Rect2(-1.6, -22, 3.2, 15), Color(0.80, 1.0, 0.85, 0.85))
			return
		# SEM shader: o desenho antigo em codigo (fallback)
		_rastro(-vel.normalized(), 62.0, 4.6, Color(0.25, 1.0, 0.45))
		var pl2 := 1.0 + 0.10 * sin(tempo * 18.0)
		draw_circle(Vector2.ZERO, 14.0 * pl2, Color(0.08, 1.0, 0.38, 0.26))
		draw_circle(Vector2.ZERO, 8.5 * pl2, Color(0.18, 1.0, 0.45, 0.60))
		draw_circle(Vector2.ZERO, 4.2 * pl2, Color(0.80, 1.0, 0.88, 0.95))
		draw_rect(Rect2(-2.0, -24, 4, 17), Color(0.75, 1.0, 0.80, 0.85))
	else:
		# fallback sem shader (nunca deve aparecer)
		_rastro(-vel.normalized(), 52.0, 6.0, Color(1.0, 0.35, 0.15))
		var pulse := 1.0 + 0.18 * sin(tempo * 14.0)
		draw_circle(Vector2.ZERO, 14 * pulse, Color(1.0, 0.15, 0.1, 0.32))
		draw_circle(Vector2.ZERO, 8.5 * pulse, Color(0.95, 0.2, 0.08))
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.55, 0.18))
		draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 0.95))

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
var e_disparo := false
var perfurante := false
var vida_perfurante := 99
var fx: Sprite2D = null
# camadas extras do super laser (plasma vivo)
var _sway_laser := 0.0
var _halo_largo: Sprite2D = null
var _halo_med: Sprite2D = null
var _vortice_boca: Sprite2D = null
var fx_base := Vector2.ONE
var fx_fase := 0.0
var plasma: Sprite2D = null

func setup_disparo(p: Vector2, v: Vector2, qual: int = 0) -> void:
	# tiro normal desenhado a mao: raio de energia (sem imagem)
	position = p
	vel = v
	amigo = true
	dano = 1
	e_disparo = true
	raio = 9.0
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
	# base: orbe de plasma verde animado por tras dos raios
	plasma = Sprite2D.new()
	plasma.texture = _fazer_textura_radial()
	plasma.scale = Vector2(1.55, 1.55)
	if ResourceLoader.exists("res://assets/energy_ball.gdshader"):
		var psh := load("res://assets/energy_ball.gdshader") as Shader
		var pmat := ShaderMaterial.new()
		pmat.shader = psh
		pmat.set_shader_parameter("charge", 1.0)
		pmat.set_shader_parameter("speed", 7.0)
		plasma.material = pmat
	add_child(plasma)

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
	# super laser VERDE TRIPLO de longo alcance
	position = p
	vel = v
	amigo = true
	dano = p_dano
	e_super = false
	e_triplo = false
	e_laser = true
	perfurante = true
	vida_perfurante = 99
	raio = 110.0

	# ---- 3 camadas do feixe, de fora pra dentro.
	# A arte dos 3 feixes verdes (GREENLIGHT) e a base; o shader da vida.
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tex_f: Texture2D = _fazer_textura_feixe()
	if ResourceLoader.exists("res://assets/laser_verde.png"):
		tex_f = load("res://assets/laser_verde.png")
	var sh: Shader = null
	if ResourceLoader.exists("res://assets/laser_verde.gdshader"):
		sh = load("res://assets/laser_verde.gdshader") as Shader

	# A arte JÁ traz 3 feixes com núcleo branco. Empilhar 3 copias
	# ADITIVAS daria 9 feixes e satura tudo pra branco. Então: 1 halo
	# aditivo bem tênue + o feixe principal em blend normal.
	# A arte é alta E larga (1126x2318); esprememos no X e esticamos no Y
	# pra dar 3 feixes finos e altos em vez de uma coluna gigante.
	const SX := 0.30
	const SY := 0.40
	const PY := -445.0 # centro do sprite: a base fica na boca do canhão

	# halo largo (verde difuso)
	var halo := Sprite2D.new()
	halo.texture = tex_f
	halo.scale = Vector2(SX * 2.4, SY)
	halo.position = Vector2(0, PY)
	halo.material = mat_add
	halo.modulate = Color(0.08, 0.90, 0.26, 0.13)
	halo.z_index = -2
	if sh != null:
		var mh := ShaderMaterial.new()
		mh.shader = sh
		mh.set_shader_parameter("speed", 5.0)
		mh.set_shader_parameter("intensidade", 0.28)
		halo.material = mh
	add_child(halo)
	_halo_largo = halo

	# halo medio (verde vivo, ainda discreto)
	var halo2 := Sprite2D.new()
	halo2.texture = tex_f
	halo2.scale = Vector2(SX * 1.3, SY)
	halo2.position = Vector2(0, PY)
	halo2.material = mat_add
	halo2.modulate = Color(0.28, 1.0, 0.40, 0.12)
	halo2.z_index = -1
	add_child(halo2)
	_halo_med = halo2

	# boca do canhao: nucleo de plasma que pulsa (desenhado por codigo)
	var vb := Sprite2D.new()
	vb.texture = _fazer_textura_radial()
	vb.scale = Vector2(0.7, 0.7)
	vb.position = Vector2(0, 14)
	vb.modulate = Color(0.25, 1.0, 0.38, 0.40)
	vb.z_index = 1
	add_child(vb)
	_vortice_boca = vb

	# feixe principal: blend NORMAL, a arte manda
	fx = Sprite2D.new()
	fx.texture = tex_f
	fx.scale = Vector2(SX, SY)
	fx.position = Vector2(0, PY)
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("speed", 6.0)
		mat.set_shader_parameter("intensidade", 0.62)
		fx.material = mat
	add_child(fx)

func _process(delta: float) -> void:
	tempo += delta
	position += vel * delta
	if e_laser:
		if position.y < -800:
			vivo = false
			queue_free()
		# plasma vivo: o feixe inteiro BALANCA no sentido da propulsao, e
		# o nucleo pulsa largura. O shader ja distorce as bordas; aqui o
		# movimento da base da o que faltava pra nao parecer tubo rigido.
		_sway_laser += delta * 3.1
		var bal: float = 1.0 + 0.10 * sin(_sway_laser) + 0.06 * sin(_sway_laser * 1.9 + 1.0)
		if fx != null:
			fx.scale = Vector2(0.30 * bal, 0.40)
		if _halo_med != null:
			_halo_med.scale = Vector2(0.39 * (1.0 + 0.08 * sin(_sway_laser * 1.4)), 0.40)
		if _halo_largo != null:
			_halo_largo.scale = Vector2(0.72 * (1.0 + 0.12 * sin(_sway_laser * 0.8 + 2.0)), 0.40)
		# boca do canhao acompanha
		if _vortice_boca != null:
			_vortice_boca.scale = Vector2.ONE * (1.0 + 0.10 * sin(_sway_laser * 2.2))
		queue_redraw()
		return
	if e_triplo and fx != null:
		# rajada viva: pulso + tremor + cintilacao (nada congelado)
		var t := tempo + fx_fase
		fx.scale = fx_base * (1.0 + 0.07 * sin(t * 21.0))
		fx.rotation += sin(t * 13.0) * 0.012
		fx.modulate = Color(1.0, 1.0, 1.0, 0.9 + 0.1 * sin(t * 27.0))
	if e_triplo and plasma != null:
		plasma.rotation -= delta * 2.5
		var ps := 1.55 * (1.0 + 0.09 * sin((tempo + fx_fase) * 17.0))
		plasma.scale = Vector2(ps, ps)
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
		# rastro: glow na base + tracer atras
		draw_circle(Vector2(0, 12), 5.0, Color(0.15, 0.9, 0.35, 0.25))
		draw_circle(Vector2(0, 8), 3.0, Color(0.4, 1.0, 0.5, 0.4))
		_rastro(Vector2.DOWN, 34.0, 3.6, Color(0.3, 1.0, 0.5))
		# corpo: losango alongado em 3 camadas
		var w := 6.5 * pul
		var tip := -24.0 * pul
		draw_colored_polygon(PackedVector2Array([Vector2(0, tip), Vector2(w, -4), Vector2(0, 12), Vector2(-w, -4)]), Color(0.15, 0.85, 0.32, 0.55))
		var w2 := w * 0.55
		var tip2 := -19.0 * pul
		draw_colored_polygon(PackedVector2Array([Vector2(0, tip2), Vector2(w2, -3), Vector2(0, 9), Vector2(-w2, -3)]), Color(0.4, 1.0, 0.55, 0.9))
		var w3 := w * 0.25
		draw_colored_polygon(PackedVector2Array([Vector2(0, tip2 + 3.0), Vector2(w3, -2), Vector2(0, 7), Vector2(-w3, -2)]), Color(0.93, 1.0, 0.94, 0.95))
		# faisca na ponta
		draw_circle(Vector2(sin(t * 1.7) * 2.0, tip), 2.0, Color(0.9, 1.0, 0.9, 0.8))
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
			draw_circle(pp, 1.4, Color(0.95, 1.0, 0.95, 0.95))
		return
	if e_laser and fx != null:
		_draw_vortice()
		_draw_raios()
		return
	if fx != null:
		# 100% shader (super verde, plasma vermelho, gigante), zero vetor
		# + tracer atras pra deixar o tiro legivel
		var tras := -vel.normalized()
		if e_super:
			_rastro(tras, 70.0, 9.0, Color(0.35, 1.0, 0.55))
		elif e_laser:
			pass
		elif raio > 25.0:
			# bola gigante do chefao
			_rastro(tras, 64.0, 11.0, Color(1.0, 0.30, 0.16))
		else:
			_rastro(tras, 42.0, 4.5, Color(1.0, 0.45, 0.20))
		return
	if amigo:
		# tracer + laser verde triplo
		_rastro(-vel.normalized(), 40.0, 3.2, Color(0.25, 1.0, 0.45))
		draw_circle(Vector2.ZERO, 11, Color(0.1, 1.0, 0.4, 0.3))
		draw_circle(Vector2.ZERO, 6, Color(0.15, 0.9, 0.35))
		draw_circle(Vector2.ZERO, 3.0, Color(0.9, 1.0, 0.92))
		draw_rect(Rect2(-1.5, -18, 3, 14), Color(0.7, 1.0, 0.75))
	else:
		# fallback sem shader (nunca deve aparecer)
		_rastro(-vel.normalized(), 40.0, 5.0, Color(1.0, 0.35, 0.15))
		var pulse := 1.0 + 0.18 * sin(tempo * 14.0)
		draw_circle(Vector2.ZERO, 12 * pulse, Color(1.0, 0.15, 0.1, 0.35))
		draw_circle(Vector2.ZERO, 7.5 * pulse, Color(0.95, 0.2, 0.08))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.6, 0.2))

func _draw_vortice() -> void:
	# Boca do canhao: tudo em verde, sem nenhum resto do laser antigo
	# (roxo/rosa/branco). Aneis girando + faiscas + nucleo quente.
	var base := Vector2(0, 18)
	var flash := 0.7 + 0.3 * sin(tempo * 31.0)
	draw_circle(base, 96.0, Color(0.08, 0.75, 0.22, 0.14))
	draw_circle(base, 62.0, Color(0.15, 1.0, 0.32, 0.18))
	draw_circle(base, 32.0 * flash + 6.0, Color(0.55, 1.0, 0.60, 0.45))
	draw_circle(base, 15.0 * flash + 4.0, Color(0.92, 1.0, 0.90, 0.80))
	var r1 := tempo * 3.2
	var r2 := -tempo * 2.3 + 1.0
	var r3 := tempo * 4.1 + 2.0
	draw_arc(base, 30.0, r1, r1 + 4.4, 24, Color(0.65, 1.0, 0.55, 0.85), 5.0)
	draw_arc(base, 44.0, r2, r2 + 3.8, 24, Color(0.20, 0.95, 0.35, 0.80), 3.5)
	draw_arc(base, 58.0, r3, r3 + 4.9, 28, Color(0.10, 0.80, 0.25, 0.65), 3.0)
	draw_arc(base, 72.0, -r3, -r3 + 2.2, 20, Color(0.35, 1.0, 0.45, 0.45), 2.0)
	# faiscas saltando da boca
	for i in 8:
		var a := tempo * 6.0 + TAU * float(i) / 8.0
		var d := 34.0 + 10.0 * sin(tempo * 9.0 + float(i))
		draw_circle(base + Vector2(cos(a), sin(a)) * d, 2.6,
			Color(0.70, 1.0, 0.65, 0.8))

func _draw_raios() -> void:
	# ---- Arcos eletricos verdes serpenteando pelos 3 feixes.
	# Tudo em verde: o laser antigo branco/quente foi removido.
	var rng_t := RandomNumberGenerator.new()
	for i in 8:
		rng_t.seed = i * 7919
		var faixa := float(i % 3) - 1.0      # -1, 0, 1 = os 3 feixes
		var x0 := faixa * 62.0
		var freq := rng_t.randf_range(0.020, 0.050)
		var amp := rng_t.randf_range(4.0, 15.0) * (1.0 + 0.4 * sin(tempo * 1.6 + float(i)))
		var vel := rng_t.randf_range(1.4, 3.8)
		var fase := rng_t.randf_range(0.0, TAU)
		var pts := PackedVector2Array()
		var y := 4.0
		var guarda := 0
		while y > -900.0 and guarda < 260:
			var f := -y / 900.0
			var x := x0 + sin(-y * freq + tempo * vel + fase) * amp * (0.35 + f)
			pts.append(Vector2(x, y))
			y -= 22.0
			guarda += 1
		if pts.size() < 2:
			continue
		var quent := fmod(tempo * 0.6 + float(i) * 0.17, 1.0)
		var cor := Color(0.18, 0.95, 0.32).lerp(Color(0.80, 1.0, 0.75), quent)
		draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.14), 7.0)
		draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.42), 2.2)

	# ---- bolhas de plasma subindo no miolo dos feixes
	for i in 9:
		var faixa2 := float(i % 3) - 1.0
		var f2: float = fmod(tempo * 0.40 + float(i) * 0.11, 1.0)
		var y2: float = lerpf(4.0, -900.0, f2)
		var bal := sin(f2 * PI)
		var x2 := faixa2 * 62.0 + sin(y2 * 0.02 + tempo * 1.9 + float(i)) * 7.0
		draw_circle(Vector2(x2, y2), 4.0 + 3.4 * bal, Color(0.22, 1.0, 0.36, 0.20 * bal))
		draw_circle(Vector2(x2, y2), 1.8 + 1.5 * bal, Color(0.85, 1.0, 0.88, 0.55 * bal))

	# ---- aneis de energia subindo pelo feixe
	for i in 5:
		var f3: float = fmod(tempo * 0.55 + float(i) / 5.0, 1.0)
		var y3: float = 4.0 - f3 * 900.0
		var larg: float = 96.0 - 26.0 * f3
		var a3: float = sin(f3 * PI) * 0.5
		draw_arc(Vector2(0, y3), larg, 0.0, TAU, 30,
			Color(0.22, 1.0, 0.36, a3 * 0.16), 6.0, true)
		draw_arc(Vector2(0, y3), larg * 0.55, 0.0, TAU, 24,
			Color(0.75, 1.0, 0.80, a3 * 0.24), 2.5, true)

	# ---- bloom verde na ponta (onde o feixe acerta)
	var tp := 0.6 + 0.4 * sin(tempo * 23.0)
	draw_circle(Vector2(0, -900), 92.0 * tp, Color(0.15, 0.90, 0.28, 0.13))
	draw_circle(Vector2(0, -900), 40.0 * tp, Color(0.40, 1.0, 0.50, 0.20))
	draw_circle(Vector2(0, -900), 15.0, Color(0.90, 1.0, 0.92, 0.42))

	# ---- faiscas verdes subindo pelo feixe
	var passo := int(tempo / 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = passo * 57 + 7
	for i in 22:
		var fx_ := rng.randf_range(-95.0, 95.0)
		var fy := rng.randf_range(-890.0, 4.0)
		var tam := rng.randf_range(1.6, 4.0)
		var cc := Color(0.75, 1.0, 0.80, 0.85) if i % 2 == 0 else Color(0.20, 1.0, 0.36, 0.85)
		draw_circle(Vector2(fx_, fy), tam * 2.2, Color(cc.r, cc.g, cc.b, 0.16))
		draw_circle(Vector2(fx_, fy), tam, cc)

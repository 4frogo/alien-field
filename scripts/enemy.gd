extends Node2D
# Inimigos: small | guard | turret | boss

var tipo := "small" # small | guard | turret | boss | bonus | bonus2
var hp := 9
var hp_max := 9
var tempo := 0.0
var vel_x := 0.0
var base_x := 270.0
var vivo := true
var sprite: Sprite2D = null
var tem_sprite := false
var dir_entrada := Vector2(0, 1)
var vel_base := 65.0
var entrando := false
var flash := 0.0
var escala0 := Vector2.ONE
var t_entrada := 0.0
# atordoamento pelo raio triplo: o chefe treme e nao atira
var atordoado := 0.0
var pe0 := Vector2.ZERO
var pe1 := Vector2.ZERO
var pec := Vector2.ZERO
var brilho_nucleo: Sprite2D = null
# Barra de vida sobre a nave. Hoje SO o chefe usa (via HUD); a protetora
# ficou sem barra a pedido do jogador, mas a variavel continua aqui para
# nao quebrar as referencias antigas.
var barra_hp: Control = null
# --- nave protetora do portal ("guard") -------------------------------
# Ela e o unico alvo que os tiros NORMAIS nao furam: levar_dano vira
# deflector. A unica coisa que machuca e o super raio, via levar_dano_super.
var imune := false
# sai de dentro do portal: nasce la dentro e desliza ate a posicao de
# cruzeiro antes de comecar a brigar
var saindo_do_portal := false
var t_portal := 0.0
var pos_portal := Vector2(270, 310)
var pos_cruzeiro := Vector2(270, 300)
# quanto de tiro normal bateu nela e foi devolvido (faisca do escudo)
var deflection := 0.0
# o player sobreviveu a ultima onda? (so pra msg de vitoria)

signal quer_atirar(pos: Vector2, grande: bool)

func _criar_sprite(path: String, largura_alvo: float, shader_path: String = "res://assets/remove_black.gdshader") -> void:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			sprite = Sprite2D.new()
			sprite.texture = tex
			var w := float(tex.get_width())
			if w > 0:
				var s := largura_alvo / w
				sprite.scale = Vector2(s, s)
			if shader_path != "" and ResourceLoader.exists(shader_path):
				var sh := load(shader_path) as Shader
				var mat := ShaderMaterial.new()
				mat.shader = sh
				sprite.material = mat
			# contorno: o inimigo precisa se destacar dos asteroides, que tem
			# valor parecido. Aro escuro + um fio quente na borda.
			if ResourceLoader.exists("res://assets/contorno.gdshader"):
				var cm := ShaderMaterial.new()
				cm.shader = load("res://assets/contorno.gdshader") as Shader
				cm.set_shader_parameter("cor", Color(0.03, 0.01, 0.01, 1.0))
				cm.set_shader_parameter("espessura", 0.007)
				cm.set_shader_parameter("brilho_borda", 0.70)
				cm.set_shader_parameter("cor_brilho", Color(1.0, 0.42, 0.12, 1.0))
				sprite.material = cm
			add_child(sprite)
			tem_sprite = true

func setup(p_tipo: String, p_pos: Vector2, p_dir: Vector2 = Vector2(0, 1)) -> void:
	tipo = p_tipo
	position = p_pos
	base_x = p_pos.x
	dir_entrada = p_dir.normalized()
	vel_base = randf_range(55.0, 95.0)
	if tipo == "small":
		hp = 9
		hp_max = 9
		# inimigo_r.png: nave vermelha com o nariz pra baixo (1189x1323).
		# A arte e quase quadrada, entao encolhendo pela LARGURA nao
		# funciona igual: 99 de largura deixa com 110 de altura, perto da
		# proporcao da capanga antiga (78x117).
		if ResourceLoader.exists("res://assets/inimigo_r.png"):
			_criar_sprite("res://assets/inimigo_r.png", 99.0, "")
		elif ResourceLoader.exists("res://assets/capanga2.png"):
			_criar_sprite("res://assets/capanga2.png", 78.0, "")
		elif ResourceLoader.exists("res://assets/capanga2.jpg"):
			_criar_sprite("res://assets/capanga2.jpg", 78.0, "")
		elif ResourceLoader.exists("res://assets/capangaV.jpg"):
			_criar_sprite("res://assets/capangaV.jpg", 78.0, "res://assets/remove_white.gdshader")
		elif ResourceLoader.exists("res://assets/capangaV.png"):
			_criar_sprite("res://assets/capangaV.png", 78.0, "res://assets/remove_white.gdshader")
		elif ResourceLoader.exists("res://assets/enemy_small.png"):
			_criar_sprite("res://assets/enemy_small.png", 70.0)
		# entrada em curva: bezier ate a formacao
		entrando = true
		t_entrada = 0.0
		pe0 = p_pos
		pe1 = Vector2(clampf(base_x, 100.0, 440.0), randf_range(90.0, 170.0))
		pec = (pe0 + pe1) * 0.5 + Vector2(randf_range(-160.0, 160.0), -40.0)
	elif tipo == "guard":
		# NAVE PROTETORA DO PORTAL. Forte, desvia e e imune a tiro normal:
		# so o super raio triplo furla ela. Nasce DENTRO do portal e sai.
		hp = 260
		hp_max = 260
		vel_base = 0.0
		# Agora o tiro NORMAL tambâ”œÂ®m machuca. A imunidade cai de proposito:
		# o jogador pediu esse comportamento. A nave continua desviando
		# (senoides) e o super ainda â”œÂ® a rota mais râ”œÃ­pida, mas nâ”œÃºo a
		# â”œâ•‘nica Ã”Ã‡Ã¶ quando ela se aproxima da morte o leque de 3 tiros vira.
		imune = false
		saindo_do_portal = true
		t_portal = 0.0
		pos_portal = p_pos
		# ela para ACIMA e NA FRENTE do portal (o portal esta em y=230), de
		# modo que o vortice aparece atras dela na tela
		pos_cruzeiro = Vector2(clampf(p_pos.x, 120.0, 420.0), p_pos.y + 66.0)
		base_x = pos_cruzeiro.x
		if ResourceLoader.exists("res://assets/protetor.png"):
			_criar_sprite("res://assets/protetor.png", 210.0, "")
			if sprite != null and sprite.material is ShaderMaterial:
				var cm := sprite.material as ShaderMaterial
				cm.set_shader_parameter("cor", Color(0.03, 0.03, 0.04, 1.0))
				cm.set_shader_parameter("espessura", 0.008)
				cm.set_shader_parameter("brilho_borda", 0.85)
				cm.set_shader_parameter("cor_brilho", Color(0.88, 0.94, 1.0, 1.0))
		# SEM BARRA DE VIDA na protetora (pedido do jogador): barra e painel
		# de vidro sairam daqui. As barras ficam so nos CHEFOES. A protetora
		# mostra o estado pelas faiscas de escudo a cada acerto do super.
	elif tipo == "boss":
		# cheche ha mais tank: 120 era pouco, morria com 4-6 tiros do super
		# ou com um burst de 3 projeteis triplexos. 240 deixa o tempo de
		# combate pelo menos ~12-15s como esperado.
		hp = 240
		hp_max = 240
		_criar_sprite_boss()
	elif tipo == "turret":
		hp = 6
		hp_max = 6
		vel_base = 14.0
	elif tipo == "bonus":
		hp = 6
		hp_max = 6
		vel_base = 32.0
		_criar_sprite_bonus()
	elif tipo == "bonus2":
		# caixa vermelha do missil (so depois do chefe)
		hp = 6
		hp_max = 6
		vel_base = 36.0
		_criar_sprite_bonus2()
	if sprite != null:
		escala0 = sprite.scale

func _criar_sprite_boss() -> void:
	# boss001_clean.png: fundo removido de verdade, alfa real
	for bp in ["res://assets/boss001_clean.png", "res://assets/boss1_clean.png", "res://assets/boss1.png", "res://assets/boss1.jpg", "res://assets/naveguerreira.png", "res://assets/naveguerreira.jpg"]:
		if ResourceLoader.exists(bp):
			var tex := load(bp) as Texture2D
			if tex == null:
				continue
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			if tw <= 0 or th <= 0:
				continue
			sprite = Sprite2D.new()
			if bp.ends_with("_clean.png"):
				sprite.texture = tex
			elif bp.ends_with("boss1.png"):
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(0, 0, tw, th * 0.925)
				sprite.texture = atlas
			else:
				sprite.texture = tex
			var s := 300.0 / tw
			sprite.scale = Vector2(s, s)
			if ResourceLoader.exists("res://assets/boss_cut.gdshader"):
				var csh := load("res://assets/boss_cut.gdshader") as Shader
				var cmat := ShaderMaterial.new()
				cmat.shader = csh
				sprite.material = cmat
			elif not bp.ends_with("_clean.png") and ResourceLoader.exists("res://assets/remove_black.gdshader"):
				var sh := load("res://assets/remove_black.gdshader") as Shader
				var mat := ShaderMaterial.new()
				mat.shader = sh
				sprite.material = mat
			add_child(sprite)
			tem_sprite = true
			break
	# brilho do nucleo: pulsa e cresce com o dano (boca abrindo)
	if sprite != null:
		brilho_nucleo = Sprite2D.new()
		brilho_nucleo.texture = _fazer_brilho()
		brilho_nucleo.position = Vector2(0, 30)
		brilho_nucleo.modulate = Color(1, 0.3, 0.15, 0.4)
	# barra de vida vive NO HUD, acima do nome DRAGAO DO VAZIO
	# (handle em hud.gd via boss_vida). Aqui nao plantamos nada
	# acima da nave.
	barra_hp = null

func _fazer_brilho() -> ImageTexture:
	var tam := 64
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := float(tam) / 2.0
	for y in tam:
		for x in tam:
			var d := Vector2(float(x) - c + 0.5, float(y) - c + 0.5).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _criar_sprite_bonus() -> void:
	# CAIXA VERDE (tipo "bonus"): arte propria (caixaGREN.png, 1254x1254).
	_prite_bonus("res://assets/caixaGREN.png", Rect2(0, 0, 1254, 1254), 78.0)


func _criar_sprite_bonus2() -> void:
	# CAIXA VERMELHA (tipo "bonus2"): da missil teleguiado, entao mostra
	# o icone do missil vermelho.
	_prite_bonus("res://assets/missil_vermelho.png", Rect2(100, 560, 1270, 1510), 74.0)


# helper: monta a caixa a partir de uma textura (com recorte opcional) e
# aplica o bonus_ring (recorte circular que remove os cantos do JPG)
func _prite_bonus(caminho: String, region: Rect2, largura_alvo: float) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var tex := load(caminho) as Texture2D
	if tex == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	sprite = Sprite2D.new()
	sprite.texture = atlas
	var rw := maxf(region.size.x, 1.0)
	sprite.scale = Vector2(largura_alvo / rw, largura_alvo / rw)
	if ResourceLoader.exists("res://assets/bonus_ring.gdshader"):
		var sh := load("res://assets/bonus_ring.gdshader") as Shader
		var mat := ShaderMaterial.new()
		mat.shader = sh
		sprite.material = mat
	add_child(sprite)
	tem_sprite = true

func _process(delta: float) -> void:
	tempo += delta
	flash = maxf(0.0, flash - delta * 5.0)
	if sprite != null:
		var f := flash
		sprite.modulate = Color(1.0, 1.0 - 0.75 * f, 1.0 - 0.75 * f)
		if tipo != "boss":
			sprite.scale = sprite.scale.lerp(escala0 * (1.0 + 0.12 * f), minf(1.0, 10.0 * delta))
	if tipo == "small":
		if entrando:
			# bezier de entrada com ease-out
			t_entrada += delta / 1.8
			var k := minf(1.0, t_entrada)
			var e := 1.0 - pow(1.0 - k, 3.0)
			var a := pe0.lerp(pec, e)
			var b := pec.lerp(pe1, e)
			position = a.lerp(b, e)
			base_x = pe1.x
			if k >= 1.0:
				entrando = false
			queue_redraw()
			return
		position += dir_entrada * vel_base * delta
		# ondulacao lateral
		var perp := Vector2(-dir_entrada.y, dir_entrada.x)
		position += perp * sin(tempo * 2.2) * 30.0 * delta
		if randf() < delta * 0.22 and position.y > 0 and position.y < 750 and position.x > 60 and position.x < 480:
			quer_atirar.emit(position + Vector2(0, 18), false)
		if position.y > 1020 or position.x < -90 or position.x > 630 or position.y < -140:
			if tempo > 2.0:
				vivo = false
				queue_free()
	elif tipo == "guard":
		deflection = maxf(0.0, deflection - delta * 3.0)
		if saindo_do_portal:
			# emerge do portal: nasce dentro do vortice e desliza ate a
			# posicao de cruzeiro. O scale vai de 0.25 a 1 (ela "materializa")
			t_portal += delta / 1.3
			var k := minf(1.0, t_portal)
			var e := 1.0 - pow(1.0 - k, 2.0)
			position = pos_portal.lerp(pos_cruzeiro, e)
			if sprite != null:
				sprite.scale = escala0 * (0.25 + 0.75 * e)
				sprite.modulate.a = e
			rotation = (1.0 - e) * 0.6
			if k >= 1.0:
				saindo_do_portal = false
				if sprite != null:
					sprite.scale = escala0
					sprite.modulate = Color(1, 1, 1, 1)
				rotation = 0.0
			queue_redraw()
			return
		# ja saiu: fica perto do portal e DESVIA. Tres senoides somados
		# (lenta + media + rapida) nao dao um padrao legivel, dai a
		# sensaâ”œÂºâ”œÃºo de que ela esta esquivando de proposito.
		position.x = pos_cruzeiro.x + sin(tempo * 1.5) * 82.0 + sin(tempo * 2.9 + 1.1) * 34.0
		position.y = pos_cruzeiro.y + sin(tempo * 1.9) * 20.0
		rotation = cos(tempo * 1.5) * 0.11 + sin(tempo * 2.9) * 0.05
		# SEM barra de vida na protetora (so os chefes tem). O bloco abaixo
		# ficava so para atualizar a barra; as faiscas de escudo no
		# super raio ja mostram que o tiro esta pegando.
		if sprite != null:
			var resp := 1.0 + 0.02 * sin(tempo * 4.0)
			sprite.scale = escala0 * resp
			# piscada branca no instante em que o tiro e devolvido (o
			# escudo verde foi removido, mas o jogador precisa ver que o
			# tiro NAO entrou)
			if deflection > 0.0:
				var i2 := int(tempo * 30.0) % 2
				sprite.modulate = Color(1.6, 1.6, 1.6) if i2 == 0 else Color(1, 1, 1)
			else:
				sprite.modulate = Color(1, 1, 1, 1)
		# atira no player; leque de 3 quando esta ferida
		if randf() < delta * 0.85:
			quer_atirar.emit(position + Vector2(0, 70), false)
		if hp < hp_max * 0.5 and randf() < delta * 0.55:
			quer_atirar.emit(position + Vector2(-60, 64), false)
			quer_atirar.emit(position + Vector2(60, 64), false)
		queue_redraw()
		return
	elif tipo == "turret":
		position.y += vel_base * delta
		if position.y > 40 and position.y < 820 and randf() < delta * 0.55:
			quer_atirar.emit(position + Vector2(0, 22), false)
		if position.y > 1020:
			vivo = false
			queue_free()
	elif tipo == "boss":
		if entrando:
			queue_redraw()
			return
		# fases: 3 (>66%) tiro mirado | 2 (>33%) leque triplo | 1 enfurecido
		var fase := 3 if hp > 80 else (2 if hp > 40 else 1)
		var mult := 1.0 if fase == 3 else (1.35 if fase == 2 else 1.8)
		var tremor := Vector2.ZERO
		var resp := 1.0 + 0.02 * sin(tempo * 3.1)
		if atordoado > 0.0:
			# ATORDOADO pelo raio triplo: treme sem parar e nao atira
			atordoado = maxf(0.0, atordoado - delta)
			tremor = Vector2(
				sin(tempo * 47.0) * 7.0 + sin(tempo * 83.0) * 3.0,
				cos(tempo * 53.0) * 5.0 + sin(tempo * 91.0) * 2.5)
			resp = 1.0 + 0.05 * sin(tempo * 41.0)
		position.y = 152.0 + sin(tempo * 2.0 * mult) * 16.0 + tremor.y
		position.x = 270.0 + sin(tempo * 1.35 * mult) * (135.0 if fase > 1 else 160.0) + tremor.x
		rotation = cos(tempo * 1.35 * mult) * 0.07 + tremor.x * 0.012
		scale = Vector2(resp, resp)
		# nucleo abre conforme apanha
		if brilho_nucleo != null:
			var falta := 1.0 - clampf(float(hp) / 120.0, 0.0, 1.0)
			var pb := 0.8 + 2.2 * falta + 0.25 * sin(tempo * 6.0)
			brilho_nucleo.scale = Vector2(pb, pb)
			brilho_nucleo.modulate.a = 0.3 + 0.6 * falta + 0.15 * sin(tempo * 6.0)
		# enquanto atordoado o casco fica esverdeado (eletrocutado)
		if sprite != null:
			if atordoado > 0.0:
				sprite.modulate = Color(0.55, 1.0, 0.60) if int(tempo * 24.0) % 2 == 0 \
					else Color(0.85, 1.0, 0.88)
			elif fase == 1:
				sprite.modulate = Color(1.0, 0.72, 0.72)
			else:
				sprite.modulate = Color(1, 1, 1)
		if atordoado > 0.0:
			# nao atira enquanto estiver eletrocutado
			queue_redraw()
			return
		if fase == 3:
			if randf() < delta * 1.1:
				quer_atirar.emit(position + Vector2(randf_range(-40, 40), 80), true)
		elif fase == 2:
			if randf() < delta * 1.5:
				quer_atirar.emit(position + Vector2(-55, 70), true)
				quer_atirar.emit(position + Vector2(0, 85), true)
				quer_atirar.emit(position + Vector2(55, 70), true)
		else:
			if randf() < delta * 2.0:
				quer_atirar.emit(position + Vector2(randf_range(-70, 70), 80), true)
	else:
		# bonus e caixa vermelha: descem devagar no meio, sem atirar
		position.y += vel_base * delta
		position.x = base_x + sin(tempo * 1.2) * 25.0
		if position.y > 1020:
			vivo = false
			queue_free()
	queue_redraw()

func atordoar(segundos: float = 2.0) -> void:
	# Chamado quando o raio triplo encosta. O chefe treme e fica 2s sem atirar.
	# Nao acumula: se ja estiver atordoado, so garante o tempo restante.
	atordoado = maxf(atordoado, segundos)
	flash = maxf(flash, 0.5)


func levar_dano(d: int) -> bool:
	# A NAVE PROTETORA e imune a tiro normal. O tiro acerta, faz faisca e
	# some Ã”Ã‡Ã¶ e isso DE PROPONTO: so o super raio triplo a machuca, e o
	# jogador precisa descobrir isso.
	if imune:
		deflection = 1.0
		flash = maxf(flash, 0.55)
		return false
	hp -= d
	flash = 1.0
	if sprite != null and tipo != "boss":
		sprite.scale = escala0 * 1.12
	if hp <= 0:
		vivo = false
		queue_free()
		return true
	return false


# unico caminho que tira vida da nave protetora: o super raio.
func levar_dano_super(d: int) -> bool:
	var era_imune := imune
	imune = false
	var morreu := levar_dano(d)
	imune = era_imune
	return morreu

func _draw() -> void:
	if tem_sprite and sprite != null:
		if tipo == "boss":
			draw_circle(Vector2.ZERO, 100, Color(1.0, 0.15, 0.1, 0.12))
			return
		elif tipo == "guard":
			# SEM escudo verde: era um aro de energia com dois arcos
			# girando, e tirava a leitura da nave. A unica coisa que fica
			# e o disco escuro atras do casco (sem ele a nave preta some
			# dentro do vortice laranja) e a barrinha de vida.
			draw_circle(Vector2.ZERO, 108, Color(0.02, 0.03, 0.06, 0.62))
			# barrinha de vida: so aparece depois que ela saiu do portal.
			# Contra-rotacionada, senao ela gira junto com a nave e vira
			# um risco torto em cima da nave.
			# barrinha de vida agora e um FILHO (hud_bar) - desenha por conta
			# propria, com as ondas e o liquido. O contra-tilt esta no
			# _process guard, para ela continuar horizontal mesmo quando a
			# nave entorna.
			return
		elif tipo == "bonus":
			# sprite do upgrade + glow + barrinha de vida
			var pulse := 0.7 + 0.3 * sin(tempo * 4.0)
			draw_circle(Vector2.ZERO, 34 * pulse, Color(0.15, 1.0, 0.45, 0.20))
			_draw_barra_bonus()
			return
		else:
			draw_circle(Vector2.ZERO, 26, Color(0.1, 1.0, 0.4, 0.12))
			return
	if tipo == "small":
		_draw_small()
	elif tipo == "guard":
		return
	elif tipo == "turret":
		_draw_turret()
	elif tipo == "bonus":
		_draw_bonus()
	elif tipo == "bonus2":
		_draw_bonus2()
	else:
		_draw_boss()

func _draw_barra_bonus() -> void:
	var w := 44.0
	var k := clampf(float(hp) / float(maxi(1, hp_max)), 0.0, 1.0)
	draw_rect(Rect2(-w / 2 - 1, -52, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -51, w * k, 5), Color(0.25, 1.0, 0.45))

func _draw_barra_bonus2() -> void:
	var w := 44.0
	var k := clampf(float(hp) / float(maxi(1, hp_max)), 0.0, 1.0)
	draw_rect(Rect2(-w / 2 - 1, -52, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -51, w * k, 5), Color(1.0, 0.25, 0.1))

func _draw_bonus() -> void:
	# icone bonus: capsula verde com 3 setas + barrinha de vida em cima
	var pulse := 0.7 + 0.3 * sin(tempo * 4.0)
	draw_circle(Vector2.ZERO, 30 * pulse, Color(0.15, 1.0, 0.45, 0.20))
	# corpo
	var corpo := PackedVector2Array([Vector2(0, -24), Vector2(16, -10), Vector2(16, 14), Vector2(0, 24), Vector2(-16, 14), Vector2(-16, -10)])
	draw_colored_polygon(corpo, Color(0.08, 0.22, 0.12))
	draw_polyline(corpo + PackedVector2Array([corpo[0]]), Color(0.35, 1.0, 0.5), 2.0)
	# simbolo 3 tiros
	for i in 3:
		var x := -10.0 + float(i) * 10.0
		draw_rect(Rect2(x - 2, -8, 4, 14), Color(0.4, 1.0, 0.55))
		draw_circle(Vector2(x, -10), 3.0, Color(0.8, 1.0, 0.85))
	# barrinha de vida
	var w := 44.0
	var k := clampf(float(hp) / float(maxi(1, hp_max)), 0.0, 1.0)
	draw_rect(Rect2(-w / 2 - 1, -36, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -35, w * k, 5), Color(0.25, 1.0, 0.45))

func _draw_bonus2() -> void:
	# caixa vermelha do missil + barrinha de vida em cima
	var pulse := 0.7 + 0.3 * sin(tempo * 4.0)
	draw_circle(Vector2.ZERO, 30 * pulse, Color(1.0, 0.15, 0.1, 0.20))
	var corpo := PackedVector2Array([Vector2(0, -24), Vector2(16, -10), Vector2(16, 14), Vector2(0, 24), Vector2(-16, 14), Vector2(-16, -10)])
	draw_colored_polygon(corpo, Color(0.22, 0.06, 0.05))
	draw_polyline(corpo + PackedVector2Array([corpo[0]]), Color(1.0, 0.3, 0.12), 2.0)
	# simbolo missil
	draw_colored_polygon(PackedVector2Array([Vector2(0, -14), Vector2(5, -2), Vector2(0, 10), Vector2(-5, -2)]), Color(0.85, 0.87, 0.9))
	draw_circle(Vector2(0, -8), 2.5, Color(1, 0.3, 0.1))
	for sx in [-9.0, 9.0]:
		draw_line(Vector2(sx, 2), Vector2(sx, 12), Color(1, 0.5, 0.15, 0.9), 2.0)
	var w := 44.0
	var k := clampf(float(hp) / float(maxi(1, hp_max)), 0.0, 1.0)
	draw_rect(Rect2(-w / 2 - 1, -36, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -35, w * k, 5), Color(1.0, 0.25, 0.1))

func _draw_turret() -> void:
	# base rochosa + canhao vermelho mirando pra baixo
	draw_circle(Vector2.ZERO, 24, Color(0.08, 0.08, 0.1))
	draw_circle(Vector2.ZERO, 19, Color(0.14, 0.13, 0.14))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0))
	# cristais laterais
	draw_circle(Vector2(-14, -6), 3, Color(0.9, 0.2, 0.12))
	draw_circle(Vector2(14, -6), 3, Color(0.9, 0.2, 0.12))
	# canhao
	draw_rect(Rect2(-6, 0, 12, 24), Color(0.16, 0.15, 0.16))
	draw_rect(Rect2(-6, 0, 12, 24), Color(0.9, 0.25, 0.12), false, 1.5)
	var pulse := 0.6 + 0.4 * sin(tempo * 5.0)
	draw_circle(Vector2(0, 24), 6.0 * pulse + 2.0, Color(1.0, 0.25, 0.1, 0.5))
	draw_circle(Vector2(0, 24), 4.0, Color(1.0, 0.3, 0.1))
	draw_circle(Vector2(0, 24), 2.0, Color(1.0, 0.7, 0.3))

func _draw_small() -> void:
	draw_circle(Vector2.ZERO, 26, Color(0.1, 1.0, 0.4, 0.12))
	var corpo := PackedVector2Array([Vector2(0, -22), Vector2(10, -6), Vector2(26, 2), Vector2(18, 14), Vector2(8, 10), Vector2(0, 18), Vector2(-8, 10), Vector2(-18, 14), Vector2(-26, 2), Vector2(-10, -6)])
	draw_colored_polygon(corpo, Color(0.2, 0.22, 0.22))
	draw_polyline(corpo + PackedVector2Array([corpo[0]]), Color(0.35, 0.9, 0.5), 1.5)
	# olho verde central
	draw_circle(Vector2(0, 0), 7, Color(0.05, 0.3, 0.12))
	draw_circle(Vector2(0, 0), 4.5, Color(0.2, 0.9, 0.4))
	draw_circle(Vector2(0, 0), 2, Color(0.85, 1.0, 0.9))
	# luzes laterais
	draw_circle(Vector2(-16, 4), 2.5, Color(0.4, 1.0, 0.55))
	draw_circle(Vector2(16, 4), 2.5, Color(0.4, 1.0, 0.55))

func _draw_boss() -> void:
	# glow
	draw_circle(Vector2.ZERO, 95, Color(0.1, 1.0, 0.4, 0.1))
	# corpo principal
	var main := PackedVector2Array([
		Vector2(0, -110), Vector2(22, -70), Vector2(30, -40),
		Vector2(78, -30), Vector2(95, -10), Vector2(88, 40),
		Vector2(60, 70), Vector2(30, 80), Vector2(12, 95),
		Vector2(0, 100), Vector2(-12, 95), Vector2(-30, 80),
		Vector2(-60, 70), Vector2(-88, 40), Vector2(-95, -10),
		Vector2(-78, -30), Vector2(-30, -40), Vector2(-22, -70)
	])
	draw_colored_polygon(main, Color(0.16, 0.18, 0.18))
	draw_polyline(main + PackedVector2Array([main[0]]), Color(0.35, 0.8, 0.45), 2.0)
	# torres laterais
	for sx in [-105, 105]:
		draw_rect(Rect2(sx - 12, -30, 24, 70), Color(0.14, 0.16, 0.16))
		draw_rect(Rect2(sx - 12, -30, 24, 70), Color(0.35, 0.9, 0.5), false, 1.5)
		draw_circle(Vector2(sx, -32), 5, Color(0.25, 0.9, 0.4))
		draw_circle(Vector2(sx, 42), 6, Color(0.15, 0.6, 0.25))
	# detalhes metalicos
	for i in 4:
		var y := -60.0 + float(i) * 30.0
		draw_circle(Vector2(-42, y), 6, Color(0.1, 0.12, 0.12))
		draw_circle(Vector2(-42, y), 3, Color(0.2, 0.8, 0.35))
		draw_circle(Vector2(42, y), 6, Color(0.1, 0.12, 0.12))
		draw_circle(Vector2(42, y), 3, Color(0.2, 0.8, 0.35))
	# nucleo central grande verde
	var c := Vector2(0, 10)
	draw_circle(c, 32, Color(0.03, 0.1, 0.05))
	draw_circle(c, 26, Color(0.08, 0.25, 0.12))
	# octogono
	var oct := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		oct.append(c + Vector2(cos(a), sin(a)) * 26.0)
	draw_polyline(oct + PackedVector2Array([oct[0]]), Color(0.4, 0.9, 0.55), 2.5)
	var pulse := 0.7 + 0.3 * sin(tempo * 4.0)
	draw_circle(c, 16.0 * pulse, Color(0.15, 0.9, 0.35))
	draw_circle(c, 8.0 * pulse, Color(0.7, 1.0, 0.8))

extends Node2D
# Inimigos: small | turret | boss

var tipo := "small" # small | turret | boss | bonus
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
var pe0 := Vector2.ZERO
var pe1 := Vector2.ZERO
var pec := Vector2.ZERO
var brilho_nucleo: Sprite2D = null

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
		if ResourceLoader.exists("res://assets/capanga2.png"):
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
	elif tipo == "boss":
		hp = 120
		hp_max = 120
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
		add_child(brilho_nucleo)

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
	# icone Upgrade1: recorte central + mascara circular (adeus quadrado)
	for bp in ["res://assets/Upgrade1.jpg", "res://assets/upgrade1.jpg", "res://assets/Upgrade1.png", "res://assets/upgrade1.png"]:
		if ResourceLoader.exists(bp):
			var tex := load(bp) as Texture2D
			if tex == null:
				continue
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			if tw <= 0 or th <= 0:
				continue
			var lado := minf(tw, th) * 0.86
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2((tw - lado) / 2.0, (th - lado) / 2.0 - th * 0.03, lado, lado)
			sprite = Sprite2D.new()
			sprite.texture = atlas
			var s := 74.0 / lado
			sprite.scale = Vector2(s, s)
			if ResourceLoader.exists("res://assets/bonus_ring.gdshader"):
				var sh := load("res://assets/bonus_ring.gdshader") as Shader
				var mat := ShaderMaterial.new()
				mat.shader = sh
				sprite.material = mat
			add_child(sprite)
			tem_sprite = true
			break

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
		# boss vivo: desliza, inclina nas curvas e respira
		# fases: 3 (>66%) tiro mirado | 2 (>33%) leque triplo | 1 enfurecido
		var fase := 3 if hp > 80 else (2 if hp > 40 else 1)
		var mult := 1.0 if fase == 3 else (1.35 if fase == 2 else 1.8)
		position.y = 152.0 + sin(tempo * 2.0 * mult) * 16.0
		position.x = 270.0 + sin(tempo * 1.35 * mult) * (135.0 if fase > 1 else 160.0)
		rotation = cos(tempo * 1.35 * mult) * 0.07
		var resp := 1.0 + 0.02 * sin(tempo * 3.1)
		scale = Vector2(resp, resp)
		# nucleo abre conforme apanha
		if brilho_nucleo != null:
			var falta := 1.0 - clampf(float(hp) / 120.0, 0.0, 1.0)
			var pb := 0.8 + 2.2 * falta + 0.25 * sin(tempo * 6.0)
			brilho_nucleo.scale = Vector2(pb, pb)
			brilho_nucleo.modulate.a = 0.3 + 0.6 * falta + 0.15 * sin(tempo * 6.0)
		if fase == 1 and flash <= 0.0 and sprite != null:
			sprite.modulate = Color(1.0, 0.72, 0.72)
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
		# bonus: desce devagar no meio, sem atirar
		position.y += vel_base * delta
		position.x = base_x + sin(tempo * 1.2) * 25.0
		if position.y > 1020:
			vivo = false
			queue_free()
	queue_redraw()

func levar_dano(d: int) -> bool:
	hp -= d
	flash = 1.0
	if sprite != null and tipo != "boss":
		sprite.scale = escala0 * 1.12
	if hp <= 0:
		vivo = false
		queue_free()
		return true
	return false

func _draw() -> void:
	if tem_sprite and sprite != null:
		if tipo == "boss":
			draw_circle(Vector2.ZERO, 100, Color(1.0, 0.15, 0.1, 0.12))
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
	elif tipo == "turret":
		_draw_turret()
	elif tipo == "bonus":
		_draw_bonus()
	else:
		_draw_boss()

func _draw_barra_bonus() -> void:
	var w := 44.0
	var k := clampf(float(hp) / float(maxi(1, hp_max)), 0.0, 1.0)
	draw_rect(Rect2(-w / 2 - 1, -52, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -51, w * k, 5), Color(0.25, 1.0, 0.45))

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

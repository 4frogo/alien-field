extends Node2D
# Nave do jogador - igual parte de baixo da imagem

var speed := 300.0
var shoot_cooldown := 0.0
var invencivel := 0.0
var fogo_touch := false
var analog := Vector2.ZERO
var usa_analogico := false

signal atirar(pos: Vector2)
signal super_tiro(pos: Vector2)
signal shuriken_tiro(pos: Vector2)

# Topo da faixa reservada ao HUD (barras de escudo + super tiro).
# A nave e mantida acima desse valor.
const TOPO_HUD := 888.0

var sprite: Sprite2D = null
var tem_sprite := false
var usa_propulsor_png := false
# (A ideia de trocar a labareda por shader foi tentada e revertida: as
#  chamas saiam como cunhas chapadas, sem o gradiente e o nuclei branco
#  do desenho em codigo. _draw_propulsores() continua sendo o dono do
#  visual dos propulsores.)
var carregando := false
var carga := 0.0
var carga_max := 3.0
# SHURIKEN (caixa vermelha): municao + carga propria (mais rapida que o
# super). Enquanto houver municao, segurar L carrega a SHURIKEN em vez do
# super tiro; soltar lanca ela.
var shuriken_cargas := 999   # shuriken sempre disponível, sem precisar de caixa
var carga_max_shuriken := 2.0   # shuriken carrega em 2s ao segurar L
var carga_max_super := 3.0   # super tiro triplo carrega em 3s (só com caixa verde)
var usando_shuriken := true
var power_ativo := false
var super_tiros_restantes := 0
var carga_alvo_atual := 0.0   # alvo de carga atual (2s shuriken)
var trail: Node2D = null
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.ZERO
var charge_fx: Sprite2D = null
var charge_mat: ShaderMaterial = null
var danger_fx: Sprite2D = null
var aura: Node2D = null
var danger_mat: ShaderMaterial = null
var arma_equip: Sprite2D = null
var escudo_sprite: Sprite2D = null
# Bolha de escudo TEMPORARIA (colmeia de octogonos). Diferente do
# escudo_sprite acima, que esta desligado: esta dura 5s ao coletar a
# caixa verde e some sozinha.
var _bolha_escudo = null
# Aura de chama enquanto a arma (Gunn) esta equipada (mesma duracao do
# tiro triplo). Fica atras do casco, como a chama de motor.
var _aura_arma = null
var _bbc: BackBufferCopy = null
# Distorcao de calor (heat haze) atras dos propulsores quando a nave se move
var heat_haze: Sprite2D = null
var thruster_particles: Array = []


func ligar_escudo_temporario(duracao: float = 5.0) -> void:
	if _bolha_escudo == null or not is_instance_valid(_bolha_escudo):
		return
	_bolha_escudo.call("configurar", 300.0)
	_bolha_escudo.call("ligar", duracao)


func ligar_aura_arma(duracao: float = 15.0) -> void:
	if _aura_arma == null or not is_instance_valid(_aura_arma):
		return
	_aura_arma.call("configurar", 340.0)
	_aura_arma.call("ligar", duracao)


func desligar_aura_arma() -> void:
	if _aura_arma != null and is_instance_valid(_aura_arma):
		_aura_arma.call("desligar")
var escudo_base := 0.30
var escudo_val := 100.0
var escudo_flash := 0.0
var cacos: Array = []
var pontos_energia: Array = []
var tempo_escudo := 0.0
var impulso := 0.0
var dir_suave := Vector2.ZERO # direcao suavizada (reage o propulsor)
var surgindo := false
var onda := 99.0

func escudo_atingido() -> void:
	escudo_flash = 1.0
	onda = 0.0
	# espalha a nuvem
	for pt in pontos_energia:
		pt["ang"] = float(pt["ang"]) + randf_range(-1.2, 1.2)

func set_equipado(on: bool) -> void:
	if arma_equip != null:
		arma_equip.visible = on and (invencivel <= 0 or int(Time.get_ticks_msec() / 100) % 2 == 1)
	power_ativo = on
	if on:
		super_tiros_restantes = 3

func carga_progress() -> float:
	if not carregando:
		return 0.0
	return clampf((carga - 0.45) / (carga_alvo_atual - 0.45), 0.0, 1.0)

func carga_pronta() -> bool:
	return carregando and carga >= carga_alvo_atual


# mutacao para a UI saber quantas shurikens restam
func shuriken_restantes() -> int:
	return shuriken_cargas

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
	# tenta usar a imagem real da nave. Estas ja vem com alpha e com os
	# proprios propulsores, entao nao usam o shader remove_black nem o
	# _chama_motor desenhado a mao.
	# (o que vier DEPOIS destas e imagem antiga, com fundo preto assado)
	for pp in ["res://assets/nave_verde001.png", "res://assets/nave_duende.png",
			"res://assets/hulk_nave.png", "res://assets/player.png",
			"res://assets/player.jpg"]:
		if ResourceLoader.exists(pp):
			var tex := load(pp) as Texture2D
			if tex != null:
				sprite = Sprite2D.new()
				sprite.texture = tex
				# escala pela ALTURA, mas cada arte tem sua propria altura
				# alvo: a VERDE001 e quase quadrada (1230x1278), entao
				# 191 de altura daria 184 de largura e ela ficaria enorme.
				# A do duende e alta e estreita (1024x1536) e precisa de mais.
				var h := float(tex.get_height())
				if h > 0:
					var alvo := 185.0
					if pp.contains("nave_duende"):
						alvo = 191.0
					elif pp.contains("nave_verde001"):
						alvo = 170.0
					sprite.scale = Vector2(alvo / h, alvo / h)
				# shader so nas imagens antigas (fundo preto assado)
				var ja_tem_alpha: bool = (pp.contains("hulk_nave")
						or pp.contains("nave_duende")
						or pp.contains("nave_verde001"))
				if not ja_tem_alpha and ResourceLoader.exists("res://assets/remove_black.gdshader"):
					var sh := load("res://assets/remove_black.gdshader") as Shader
					var mat := ShaderMaterial.new()
					mat.shader = sh
					sprite.material = mat
				# contorno escuro: silhueta para a nave nao se perder no fundo
				if ResourceLoader.exists("res://assets/contorno.gdshader"):
					var cm := ShaderMaterial.new()
					cm.shader = load("res://assets/contorno.gdshader") as Shader
					cm.set_shader_parameter("cor", Color(0.01, 0.02, 0.03, 1.0))
					cm.set_shader_parameter("espessura", 0.006)
					cm.set_shader_parameter("brilho_borda", 0.55)
					cm.set_shader_parameter("cor_brilho", Color(0.25, 1.0, 0.45, 1.0))
					sprite.material = cm
				add_child(sprite)
				tem_sprite = true
				# Hulk2 nao tem chama assada na arte (motores escuros), entao
				# o propulsor verde e desenhado em codigo.
				usa_propulsor_png = false
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
	# rastro da nave (top_level: nao herda rotacao/escala da nave)
	var tr := Node2D.new()
	tr.set_script(preload("res://scripts/trail.gd"))
	tr.set("alvo", self)
	add_child(tr)
	tr.top_level = true
	trail = tr
	# canhao plasma equipado (aparece nos 15s de triplo)
	for ap in ["res://assets/arma_plasma.png"]:
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
		# BOLHA TEMPORARIA: escudo de 5s ao coletar a caixa verde, desenhado
		# como colmeia de octogonos (escudo_colmeia.gdshader). Separate do
		# escudo_sprite acima, que continua desligado de proposito.
		_bolha_escudo = preload("res://scripts/escudo_bolha.gd").new()
		add_child(_bolha_escudo)
		# AURA DE CHAMA: envolve a nave enquanto a arma (Gunn) esta equipada.
		# Diferente da bolha, que dura 5s no maximo.
		_aura_arma = preload("res://scripts/aura_chama.gd").new()
		add_child(_aura_arma)
	# distorcao de calor (heat haze) atras dos propulsores, visivel so quando se move
	_bbc = BackBufferCopy.new()
	add_child(_bbc)
	heat_haze = Sprite2D.new()
	if ResourceLoader.exists("res://assets/heat_haze.gdshader"):
		var hh := load("res://assets/heat_haze.gdshader") as Shader
		var hm := ShaderMaterial.new()
		hm.shader = hh
		hm.set_shader_parameter("intensity", 0.0)
		heat_haze.material = hm
	# textura vazia pequena (apenas pra ter algo para renderizar o shader)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	heat_haze.texture = ImageTexture.create_from_image(img)
	heat_haze.position = Vector2(0, 40)  # atras da boca dos propulsores
	heat_haze.scale = Vector2(2.0, 2.0)
	heat_haze.visible = false
	add_child(heat_haze)
	# --- Particulas de propulsor (chama verde + fumaca) ---
	thruster_particles = []
	for bp in _bicos_motor():
		var gp := GPUParticles2D.new()
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 18.0
		mat.initial_velocity_min = 40.0
		mat.initial_velocity_max = 90.0
		mat.gravity = Vector3(0, 40, 0)
		mat.scale_min = 0.6
		mat.scale_max = 1.4
		mat.color = Color(0.3, 1.0, 0.5, 0.9)
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		gp.process_material = mat
		gp.amount = 24
		gp.lifetime = 0.5
		gp.explosiveness = 0.0
		gp.randomness = 0.4
		gp.position = bp
		gp.emitting = true
		add_child(gp)
		thruster_particles.append(gp)
# escudo sem efeito visual: a nave ficou limpa para receber o novo modelo.
# O no 'aura' e a funcao _draw_escudo_particulas foram desligados de proposito.
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
	onda = minf(99.0, onda + delta * 1.8)
	# anel estatico desligado: o escudo agora e a AURA COSMICA (no no 'aura')
	if escudo_sprite != null:
		escudo_sprite.visible = false
# escudo desligado (sem visual): nada a atualizar
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
	dir += analog

	# ---- dash (SHIFT ou ESPACO): impulso curto na direcao atual
	dash_cd = maxf(0.0, dash_cd - delta)
	if dash_t > 0.0:
		dash_t -= delta
		position += dash_dir * 900.0 * delta
		if dash_t <= 0.0:
			dash_cd = 1.1
	else:
		var quer_dash := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE)
		if quer_dash and dash_cd <= 0.0 and dir.length() > 0.05:
			dash_t = 0.16
			dash_dir = dir.normalized()
		position += dir.normalized() * speed * delta if dir.length() > 0.05 else Vector2.ZERO

	# ---- limites de tela: a nave nao pode invadir a faixa do HUD.
	# O clamp usa a posicao do no (centro), mas a sprite e grande, entao
	# compensamos pela metade da altura/largura real ja escalada.
	# COM a camera afastada (CAM_ZOOM 0.92 no main.gd) a area visivel
	# grew ~4.6% para cada lado: o topo pode ir ate y=340 e a base
	# continua presa no topo do HUD em 888.
	var meia_h := _meia_altura_px()
	var meia_w := _meia_largura_px()
	position.x = clamp(position.x, meia_w + 8.0, 540.0 - meia_w - 8.0)
	position.y = clamp(position.y, 340.0, minf(900.0, TOPO_HUD - meia_h - 6.0))
	# impulso pros propulsores (0 parado, 1 movendo)
	var forca_imp: float = 1.0 if dash_t > 0.0 else clampf(dir.length(), 0.0, 1.0)
	impulso = lerpf(impulso, forca_imp, minf(1.0, (12.0 if dash_t > 0.0 else 6.0) * delta))
	# direcao suavizada: o propulsor reage a ela com atraso, dando peso
	dir_suave = dir_suave.lerp(dir.limit_length(1.0), minf(1.0, 9.0 * delta))
	if trail != null:
		trail.set("intensidade", impulso)

	# distorcao de calor atras dos propulsores: so quando se move
	if heat_haze != null:
		heat_haze.visible = impulso > 0.05
		if heat_haze.visible and heat_haze.material != null:
			var mat := heat_haze.material as ShaderMaterial
			mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
			mat.set_shader_parameter("intensity", clampf(impulso, 0.0, 1.0) * 1.5)
			# acompanha o eixo do jato: inclina contra o movimento lateral
			heat_haze.rotation = atan2(dir_suave.x * 0.62, 1.0)

	# ---- EFEITO 3D: banking (inclinar ao virar) + arfagem vertical
	# Usa dir_suave (a direcao JA suavizada) em vez de dir crua: assim a
	# nave nao "dobra" no primeiro frame do input e depois volta — ela
	# entra na curva com atraso, que e o que da peso.
	var bank: float = dir_suave.x * 0.26
	# arfagem (pitch): leve, e para o lado OPOSTO da subida/descida.
	# Sobe -> nariz cai um pouco (arfagem); desce -> nariz sobe.
	var pitch: float = -dir_suave.y * 0.06
	# quando accelerate (dash), a nave mergulha um pouco mais
	if dash_t > 0.0:
		pitch -= 0.05
	var alvo_rot: float = bank + pitch
	# overshoot: lerp rapido, mas com uma " Elasticidade" no ganho — a
	# nave chega rapido no angulo final e ainda tem um leve retorno.
	rotation = lerpf(rotation, alvo_rot, minf(1.0, 12.0 * delta))
	if not surgindo:
		var alvo_sx := 1.0 + absf(dir.x) * 0.10
		var alvo_sy := 1.0 - dir.y * 0.04 - absf(dir.x) * 0.03
		scale = scale.lerp(Vector2(alvo_sx, alvo_sy), minf(1.0, 8.0 * delta))

	# tiro manual na tecla L / botao touch + shuriken (2s) ou super tiro triplo (3s, so com caixa verde)
	var segurando := Input.is_key_pressed(KEY_L) or fogo_touch
	if segurando:
		if not carregando:
			carregando = true
			carga = 0.0
			usando_shuriken = not (power_ativo and super_tiros_restantes > 0)
			carga_alvo_atual = carga_max_super if not usando_shuriken else carga_max_shuriken
		carga += delta
		if carga < 0.45:
			# rajada normal no início
			if shoot_cooldown <= 0:
				shoot_cooldown = 0.18
				var offset_y := -60.0 if tem_sprite else -38.0
				atirar.emit(position + Vector2(0, offset_y))
		# depois de 0.45s para de atirar e só carrega
	else:
		if carregando:
			var offset_y := -70.0 if tem_sprite else -48.0
			if not usando_shuriken and power_ativo and super_tiros_restantes > 0:
				# super tiro triplo (FeixeScript) - 3 raios serpenteantes
				if carga >= carga_alvo_atual:
					super_tiro.emit(position + Vector2(0, offset_y))
					super_tiros_restantes -= 1
			else:
				# shuriken: sempre disponível ao segurar L (2s), sem precisar de caixa
				if carga >= carga_alvo_atual:
					shuriken_tiro.emit(position + Vector2(0, offset_y))
					shuriken_cargas = max(0, shuriken_cargas - 1)
			carregando = false
			carga = 0.0
	# atualiza fx plasma + tremor de perigo
	if charge_fx != null:
		if carregando and carga >= 0.45:
			var k := clampf((carga - 0.45) / (carga_alvo_atual - 0.45), 0.0, 1.0)
			charge_fx.visible = invencivel <= 0 or int(Time.get_ticks_msec() / 100) % 2 == 1
			var sc := 0.35 + 0.95 * k
			charge_fx.scale = Vector2(sc, sc)
			if charge_mat != null:
				charge_mat.set_shader_parameter("charge", k)
				charge_mat.set_shader_parameter("speed", 3.5 + 4.0 * k)
				# cor da carga: verde para super tiro triplo, laranja para shuriken
				if not usando_shuriken and power_ativo and super_tiros_restantes > 0:
					charge_mat.set_shader_parameter("cor_a", Color(0.10, 0.95, 0.28))
					charge_mat.set_shader_parameter("cor_b", Color(0.45, 1.0, 0.60))
				else:
					charge_mat.set_shader_parameter("cor_a", Color(1.0, 0.45, 0.10))
					charge_mat.set_shader_parameter("cor_b", Color(1.0, 0.92, 0.60))
			# tremor cresce com a carga (perigo), respeitando a faixa do HUD
			var tremor := k * k * 7.0
			position.x = clamp(position.x + randf_range(-tremor, tremor),
				meia_w + 8.0, 540.0 - meia_w - 8.0)
			position.y = clamp(position.y + randf_range(-tremor, tremor) * 0.6,
				400.0, minf(900.0, TOPO_HUD - meia_h - 6.0))
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

# Metade da altura da nave em pixels de tela (sprite ja escalada + scale do no).
func _meia_altura_px() -> float:
	var h := 70.0 # fallback do desenho a mao
	if sprite != null and sprite.texture != null:
		h = float(sprite.texture.get_height()) * absf(sprite.scale.y)
	return absf(h * scale.y) * 0.5


# Mesma coisa para a largura (usado no limite lateral).
func _meia_largura_px() -> float:
	var w := 64.0
	if sprite != null and sprite.texture != null:
		w = float(sprite.texture.get_width()) * absf(sprite.scale.x)
	return absf(w * scale.x) * 0.5


func _input(event: InputEvent) -> void:
	# PC: somente WASD (sem mouse). Celular: TouchControls assume.
	if usa_analogico and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return

func _draw() -> void:
	# o anel verde antigo saiu de uso: o escudo agora e a aura cosmica
	# (desenhada no no 'aura', com blend aditivo). Aqui ficam so as
	# particulas estelares por cima.
	if invencivel > 0 and int(Time.get_ticks_msec() / 100) % 2 == 0:
		if sprite != null:
			sprite.visible = false
		return # piscando
	if sprite != null:
		sprite.visible = true
	if tem_sprite:
		if not usa_propulsor_png:
			_draw_propulsores()
		return
	# glow de escudo removido: nave limpa
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
	_ellipse_poly(Vector2(0, 8), 11, 17, Color(0.02, 0.15, 0.06))
	_ellipse_poly(Vector2(0, 8), 8, 13, Color(0.1, 0.7, 0.28))
	_ellipse_poly(Vector2(0, 8), 4, 9, Color(0.6, 1.0, 0.7))
	# antena topo
	draw_line(Vector2(0, -52), Vector2(0, -62), Color(0.4, 1.0, 0.6), 2.0)
	draw_circle(Vector2(0, -64), 3, Color(0.5, 1.0, 0.65))

func _draw_escudo_fundo() -> void:
	# desligado: nave sem efeitos de escudo
	return
	if escudo_val <= 0.0:
		return
	var forca := clampf(escudo_val / 100.0, 0.0, 1.0)
	var critico := forca < 0.3
	var base_c := Color(1, 0.45, 0.15) if critico else Color(0.25, 1.0, 0.5)
	var flick := 0.75 + 0.25 * sin(tempo_escudo * (14.0 if critico else 4.0))
	# halo
	draw_circle(Vector2.ZERO, 88, Color(base_c.r, base_c.g, base_c.b, 0.06 * forca))
	# anel base cobre conforme a forca (anel quebrado = escudo fraco)
	var comp := TAU * (0.25 + 0.75 * forca)
	var g1 := tempo_escudo * 1.4
	draw_arc(Vector2.ZERO, 68.0, g1, g1 + comp, 48, Color(base_c.r, base_c.g, base_c.b, (0.30 + 0.25 * forca) * flick), 2.0)
	# faixa brilhante contraria
	var g2 := -tempo_escudo * 0.9 + 2.0
	draw_arc(Vector2.ZERO, 68.0, g2, g2 + comp * 0.45, 32, Color(0.9, 1.0, 0.92, (0.5 + 0.3 * forca) * flick), 3.0)
	# ticks runicos orbitando
	for i in 24:
		var a := tempo_escudo * 0.6 + TAU * float(i) / 24.0
		var p1 := Vector2(cos(a), sin(a)) * 74.0
		var p2 := Vector2(cos(a), sin(a)) * (74.0 + 5.0 + 2.0 * sin(tempo_escudo * 5.0 + float(i)))
		draw_line(p1, p2, Color(base_c.r, base_c.g, base_c.b, 0.55 * forca * flick), 2.0)
	# 8 cacos cristalinos orbitando + girando
	for i in 8:
		var a := -tempo_escudo * 0.8 + TAU * float(i) / 8.0 + 0.4
		var pp := Vector2(cos(a), sin(a)) * 60.0
		_draw_caco(pp, 7.0, tempo_escudo * 2.0 + float(i) * 1.3, forca)
	# onda de choque do impacto
	if onda < 1.0:
		var r := 40.0 + onda * 90.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.8, 1.0, 0.85, (1.0 - onda) * 0.7), 3.0)

func _draw_escudo_particulas() -> void:
	# desligado: nave sem efeitos de escudo
	return
	if escudo_val <= 0.0:
		return
	var forca := clampf(escudo_val / 100.0, 0.0, 1.0)
	for pt in pontos_energia:
		var pp := Vector2(cos(float(pt["ang"])), sin(float(pt["ang"]))) * float(pt["raio"])
		var tw := 0.45 + 0.55 * (0.5 + 0.5 * sin(tempo_escudo * 7.0 + float(pt["fase"])))
		var w: float = float(pt["tam"])
		var a := (0.25 + 0.75 * forca) * tw + escudo_flash * 0.5
		# particulas estelares (combinam com a aura cosmica)
		if int(pt["kind"]) == 0:
			draw_circle(pp, w * 2.0, Color(0.7, 0.85, 1.0, a * 0.25))
			draw_circle(pp, w, Color(0.85, 0.95, 1.0, a))
		elif int(pt["kind"]) == 1:
			draw_circle(pp, w * 2.0, Color(1.0, 0.6, 0.95, a * 0.25))
			draw_circle(pp, w, Color(1.0, 0.85, 0.95, a))
		else:
			draw_circle(pp, w * 2.0, Color(0.6, 0.95, 1.0, a * 0.25))
			draw_circle(pp, w, Color(0.8, 1.0, 0.95, a))
	# 4 nos de energia nos pontos cardeais (concentracao)
	for i in 4:
		var na := tempo_escudo * 0.5 + TAU * float(i) / 4.0
		var np := Vector2(cos(na), sin(na)) * 75.0
		var pulse := 0.7 + 0.3 * sin(tempo_escudo * 5.0 + float(i) * 1.7)
		draw_circle(np, 6.0 * pulse, Color(0.6, 0.8, 1.0, 0.22 * forca))
		draw_circle(np, 2.6 * pulse, Color(1, 1, 1, 0.55 + 0.4 * forca))

func _draw_caco(pos: Vector2, tam: float, rot: float, forca: float) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var per := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		pos + dir * tam,
		pos + per * tam * 0.38,
		pos - dir * tam * 0.7,
		pos - per * tam * 0.38,
	])
	draw_colored_polygon(pts, Color(0.65, 0.7, 0.72, 0.35 + 0.6 * forca))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.4, 1.0, 0.55, 0.5 + 0.5 * forca), 1.5)
	draw_circle(pos + dir * tam * 0.4, 1.4, Color(1, 1, 1, 0.4 + 0.6 * forca))

func _draw_carga() -> void:
	# desativado: carga agora e shader RGB (charge_fx), sem vetor
	return

func _bicos_motor() -> Array:
	# bocas dos 5 propulsores, em pixels do jogo (nave com 185px de altura)
	return [
		Vector2(-38.0, 62.0),
		Vector2(38.0, 62.0),
		Vector2(-19.0, 82.0),
		Vector2(19.0, 82.0),
		Vector2(0.0, 90.0),
	]

# Visibilidade das chamas perto do HUD: 1.0 longe da faixa reservada,
# 0.0 quando a base da nave encosta nela. Evita que a labareda invada
# as barras sem precisar empurrar a nave pra cima.
func _fade_hud() -> float:
	var folga: float = TOPO_HUD - (position.y + _meia_altura_px())
	return clampf(folga / 64.0, 0.0, 1.0)


func _draw_propulsores() -> void:
	# Plasma verde vivo e REATIVO:
	#  - o motor do lado pra onde a nave inclina queima mais forte
	#  - subindo a chama se espalha, descendo ela se alonga
	#  - o eixo da chama INCLINA contra o movimento lateral (empuxo real)
	var t := float(Time.get_ticks_msec()) / 1000.0
	# forca base: parado quase nao queima, acelerando ate o dash
	var base := 0.42 + impulso * 1.15
	var dx := clampf(dir_suave.x, -1.0, 1.0)   # -1 = esquerda, +1 = direita
	var dy := clampf(dir_suave.y, -1.0, 1.0)   # -1 = subindo,  +1 = descendo
	var vis := _fade_hud()                     # some perto das barras do HUD
	if vis <= 0.01:
		return
	# eixo do jato: inclina CONTRA o movimento lateral (empuxo real) —
	# indo pra direita a chama aponta pra baixo-esquerda, e vice-versa
	var eixo := Vector2(-dx * 0.62, 1.0).normalized()
	var bicos := _bicos_motor()
	for i in bicos.size():
		var bico: Vector2 = bicos[i]
		var fase := float(i) * 1.7

		# --- quanto este motor trabalha: lado que a nave vira carrega mais ---
		var lado := signf(bico.x) if absf(bico.x) > 0.01 else 0.0
		var ganho := 1.0
		if lado != 0.0:
			ganho += dx * lado * 0.85          # motor do lado da curva grava
		ganho -= dy * 0.30                     # descendo forca, subindo alivia
		ganho = clampf(ganho, 0.30, 2.10)

		var cintila := 0.78 + 0.22 * sin(t * 27.0 + fase) + 0.12 * sin(t * 51.0 + fase * 2.3)
		# descendo -> chama longa e estreita; subindo -> curta e aberta
		var comp := (30.0 + 34.0 * base) * cintila * ganho * (1.0 + dy * 0.34)
		var larg := (7.5 + 5.0 * impulso) * ganho * (1.0 - dy * 0.26)
		var vib := Vector2(sin(t * 37.0 + fase) * 1.6, 0)
		# perto do HUD a labareda encolhe e apaga
		comp *= vis
		larg *= vis

		# --- halo suave: desenhado em ANEIS concentricos com alpha
		# decrescente. Antes eram 2 draw_circle com alpha fixo, o que
		# aparecia como um disco chapado em volta de cada motor.
		var halo_r: float = larg * 2.4
		var halo_c: Vector2 = bico + eixo * (comp * 0.18)
		for anel in 5:
			var fr := 1.0 - float(anel) / 5.0          # 1.0 -> 0.2
			var a_h: float = (0.030 + 0.022 * fr) * cintila * ganho * vis
			draw_circle(halo_c, halo_r * fr, Color(0.10, 0.95, 0.45, a_h))
		var halo2_r: float = larg * 1.5
		var halo2_c: Vector2 = bico + eixo * (comp * 0.10)
		for anel2 in 4:
			var fr2 := 1.0 - float(anel2) / 4.0
			var a_h2: float = (0.040 + 0.030 * fr2) * cintila * ganho * vis
			draw_circle(halo2_c, halo2_r * fr2, Color(0.25, 1.0, 0.55, a_h2))

		# --- camadas da labareda, da mais larga pra mais brilhante ---
		var perfil := [
			[1.00, 1.00, Color(0.05, 0.75, 0.30, 0.30)],
			[0.74, 0.86, Color(0.18, 1.00, 0.45, 0.55)],
			[0.46, 0.68, Color(0.55, 1.00, 0.62, 0.80)],
			[0.22, 0.44, Color(0.88, 1.00, 0.90, 0.95)],
		]
		for c in perfil.size():
			var cx: float = float(perfil[c][0])
			var cy: float = float(perfil[c][1])
			var cor: Color = perfil[c][2]
			cor.a *= vis
			var ponta := bico + eixo * (comp * cy) + vib * (1.0 - cx * 0.5)
			draw_colored_polygon(PackedVector2Array([
				bico + Vector2(-larg * cx, -2.0),
				bico + Vector2(larg * cx, -2.0),
				ponta,
			]), cor)

		# --- diamantes de choque flutuando na labareda ---
		for d in 3:
			var dyq := comp * (0.30 + 0.28 * float(d))
			var pulso := 0.55 + 0.45 * sin(t * 16.0 - dyq * 0.22 + fase)
			var dw := larg * (0.60 - 0.13 * float(d)) * (0.8 + 0.2 * pulso)
			var dc := bico + eixo * dyq + vib * 0.5
			draw_colored_polygon(PackedVector2Array([
				dc + Vector2(-dw, 0), dc + Vector2(0, -dw * 0.42),
				dc + Vector2(dw, 0), dc + Vector2(0, dw * 0.42),
			]), Color(0.75, 1.0, 0.85, 0.30 * pulso * vis))

		# --- faiscas subindo e se apagando ---
		for s in 4:
			var ciclo := fmod(t * 1.7 + float(s) * 0.25 + fase * 0.15, 1.0)
			var sa := (1.0 - ciclo) * 0.85 * vis
			var lateral := sin(float(s) * 2.1 + fase) * larg * 0.9 + ciclo * ciclo * 5.0 * sin(fase + t)
			# sobem pelo eixo inclinado do jato, espalhando na perpendicular
			var pos_s := bico + eixo * (ciclo * comp * 1.35) + Vector2(-eixo.y, eixo.x) * lateral
			draw_circle(pos_s, 1.9 * (1.0 - ciclo * 0.5), Color(0.55, 1.0, 0.70, sa))

		# --- boca do motor acesa (mais quente quanto mais ganho) ---
		draw_circle(bico, 4.4 * vis, Color(0.10, 0.55, 0.22, 0.9 * vis))
		draw_circle(bico, 2.7 * vis, Color(0.45, 1.0, 0.60, 0.95 * vis))
		draw_circle(bico, 1.4 * ganho * vis, Color(0.92, 1.0, 0.95, clampf(cintila * ganho * vis, 0.0, 1.0)))

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

func _ellipse_poly(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

extends Node2D
# Alien field - main

const BulletScript := preload("res://scripts/bullet.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BgScript := preload("res://scripts/background.gd")
const HudScript := preload("res://scripts/hud.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const ExplosaoScript := preload("res://scripts/explosao.gd")
const MusicScript := preload("res://scripts/music.gd")
const ArmaScript := preload("res://scripts/arma.gd")
const BuracoScript := preload("res://scripts/buraco_negro.gd")
const FeixeScript := preload("res://scripts/feixe.gd")

var player: Node2D
var hud: CanvasLayer
var boss: Node2D = null
var sfx: Node = null
var musica: Node = null
var turret_timer := 3.0

var tiros: Array = []
var tiros_inimigos: Array = []
var inimigos: Array = []
var armas: Array = []
var feixes: Array = []
var feixe_tick := 0.0

var pontos := 2350
var vidas := 1
var escudo := 100.0
var fase := "1-3"
var spawn_timer := 0.0
var game_over_timer := -1.0
var tempo_batalha := 0.0
var boss_ja_entrou := false
var aviso_label: Label = null
var aviso_tex: TextureRect = null
var aviso_tempo := 0.0
var aviso_dragao := false
var power_timer := 0.0
var bonus_timer := 20.0
var power_label: Label = null
var gameover_layer: CanvasLayer = null
var gameover_anim := 0.0
var menu_layer: CanvasLayer = null
var em_menu := false
var fonte_horror: Font = null
var charge_bar: ProgressBar = null
var charge_txt: Label = null
var pause_layer: CanvasLayer = null
var last_beep := 0
var abates := 0
var chefe_sem_escudo := 0

func _registrar_abate() -> void:
	abates += 1
	if abates % 5 == 0 and vidas > 0:
		escudo = minf(100.0, escudo + 25.0)
		if escudo > 0.0:
			chefe_sem_escudo = 0

func _fonte() -> Font:
	if fonte_horror == null and ResourceLoader.exists("res://assets/horror.ttf"):
		fonte_horror = load("res://assets/horror.ttf") as Font
	return fonte_horror

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = Node.new()
	sfx.set_script(SfxScript)
	add_child(sfx)
	musica = Node.new()
	musica.set_script(MusicScript)
	add_child(musica)

	var bg := Node2D.new()
	bg.set_script(BgScript)
	add_child(bg)

	player = Node2D.new()
	player.set_script(PlayerScript)
	add_child(player)
	player.connect("atirar", _on_player_atirar)
	player.connect("super_tiro", _on_super_tiro)

	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	# hud._ready ja roda no add_child, espera 1 frame
	await get_tree().process_frame
	hud.atualizar(pontos, vidas, escudo)

	# aviso de chefao: degrade vermelho pulsante + BOSS ALERT
	aviso_label = Label.new()
	aviso_label.text = "BOSS ALERT"
	aviso_label.add_theme_font_size_override("font_size", 52)
	if _fonte() != null:
		aviso_label.add_theme_font_override("font", _fonte())
	aviso_label.add_theme_color_override("font_color", Color(1, 0.12, 0.08))
	aviso_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	aviso_label.add_theme_constant_override("shadow_offset_x", 3)
	aviso_label.add_theme_constant_override("shadow_offset_y", 3)
	aviso_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_label.position = Vector2(0, 380)
	aviso_label.size = Vector2(540, 90)
	aviso_label.visible = false
	aviso_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(aviso_label)
	# vinheta vermelha pulsante por tras do aviso
	aviso_tex = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.08, 0.06, 0.0))
	grad.set_color(1, Color(1, 0.05, 0.04, 0.9))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 540
	gtex.height = 960
	aviso_tex.texture = gtex
	aviso_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	aviso_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aviso_tex.stretch_mode = TextureRect.STRETCH_SCALE
	aviso_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_tex.modulate.a = 0.0
	aviso_tex.visible = false
	hud.add_child(aviso_tex)

	power_label = Label.new()
	power_label.text = ""
	power_label.add_theme_font_size_override("font_size", 22)
	if _fonte() != null:
		power_label.add_theme_font_override("font", _fonte())
	power_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	power_label.position = Vector2(18, 70)
	power_label.visible = false
	hud.add_child(power_label)

	# barrinha de carga do super tiro (segue a nave)
	charge_bar = ProgressBar.new()
	charge_bar.min_value = 0
	charge_bar.max_value = 100
	charge_bar.value = 0
	charge_bar.show_percentage = false
	charge_bar.custom_minimum_size = Vector2(110, 12)
	charge_bar.size = Vector2(110, 12)
	charge_bar.visible = false
	hud.add_child(charge_bar)
	var cbg := StyleBoxFlat.new()
	cbg.bg_color = Color(0, 0, 0, 0.7)
	cbg.border_color = Color(0.4, 1.0, 0.55)
	cbg.set_border_width_all(1)
	cbg.set_corner_radius_all(3)
	charge_bar.add_theme_stylebox_override("background", cbg)
	var cfill := StyleBoxFlat.new()
	cfill.bg_color = Color(0.3, 1.0, 0.5)
	cfill.set_corner_radius_all(2)
	charge_bar.add_theme_stylebox_override("fill", cfill)

	charge_txt = Label.new()
	charge_txt.text = "SUPER"
	charge_txt.add_theme_font_size_override("font_size", 14)
	if _fonte() != null:
		charge_txt.add_theme_font_override("font", _fonte())
	charge_txt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	charge_txt.visible = false
	hud.add_child(charge_txt)

	# controles touch (celular): analogico + circulo de tiro (sem botoes)
	if DisplayServer.is_touchscreen_available():
		var tc := Node2D.new()
		tc.set_script(preload("res://scripts/touch_controls.gd"))
		add_child(tc)
		tc.set("player", player)
		tc.set("main_ref", self)
		player.set("usa_analogico", true)

	# camada de pause (sempre ativa pra responder no P)
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 60
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var pl := Label.new()
	pl.text = "PAUSADO"
	pl.add_theme_font_size_override("font_size", 56)
	if _fonte() != null:
		pl.add_theme_font_override("font", _fonte())
	pl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
	pl.position = Vector2(150, 420)
	pause_layer.add_child(pl)
	var ph := Label.new()
	ph.text = "P continua"
	ph.add_theme_font_size_override("font_size", 22)
	if _fonte() != null:
		ph.add_theme_font_override("font", _fonte())
	ph.add_theme_color_override("font_color", Color(0.8, 0.85, 0.82))
	ph.position = Vector2(200, 500)
	pause_layer.add_child(ph)

	for i in 3:
		_spawn_small()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_alternar_pause()

func _alternar_pause() -> void:
	if em_menu or vidas <= 0:
		return
	get_tree().paused = not get_tree().paused
	if pause_layer != null:
		pause_layer.visible = get_tree().paused
	if musica != null and musica.has_method("set_pausado"):
		musica.call("set_pausado", get_tree().paused)

func _spawn_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return
	boss = Node2D.new()
	boss.set_script(EnemyScript)
	add_child(boss)
	boss.call("setup", "boss", Vector2(270, 148), Vector2(0, 1))
	boss.connect("quer_atirar", _on_enemy_atirar)
	inimigos.append(boss)
	if sfx != null:
		sfx.call("boss")
	if musica != null and musica.has_method("trocar_para_boss"):
		musica.call("trocar_para_boss")

func _spawn_turret() -> void:
	var n := 0
	for e in inimigos:
		if is_instance_valid(e) and e.get("tipo") == "turret":
			n += 1
	if n >= 4:
		return
	for lado in [0, 1]:
		if randf() < 0.6:
			var e := Node2D.new()
			e.set_script(EnemyScript)
			add_child(e)
			var x := 62.0 if lado == 0 else 478.0
			e.call("setup", "turret", Vector2(x + randf_range(-8, 8), -30), Vector2(0, 1))
			e.connect("quer_atirar", _on_enemy_atirar)
			inimigos.append(e)

func _spawn_small() -> void:
	var e := Node2D.new()
	e.set_script(EnemyScript)
	add_child(e)
	var r := randf()
	var pos := Vector2.ZERO
	var dir := Vector2(0, 1)
	if r < 0.55:
		# topo aleatorio
		pos = Vector2(randf_range(100, 440), randf_range(-50, 20))
		dir = Vector2(randf_range(-0.35, 0.35), 1.0)
	elif r < 0.75:
		# esquerda
		pos = Vector2(-35, randf_range(80, 500))
		dir = Vector2(1.0, randf_range(0.2, 0.7))
	elif r < 0.95:
		# direita
		pos = Vector2(575, randf_range(80, 500))
		dir = Vector2(-1.0, randf_range(0.2, 0.7))
	else:
		# topo cantos em diagonal
		var esquerda := randf() < 0.5
		pos = Vector2(-30 if esquerda else 570, -30)
		dir = Vector2(1.0 if esquerda else -1.0, 1.0)
	e.call("setup", "small", pos, dir)
	e.connect("quer_atirar", _on_enemy_atirar)
	inimigos.append(e)

func _spawn_bonus() -> void:
	for e in inimigos:
		if is_instance_valid(e) and e.get("tipo") == "bonus":
			return # so 1 por vez
	var e := Node2D.new()
	e.set_script(EnemyScript)
	add_child(e)
	e.call("setup", "bonus", Vector2(randf_range(140, 400), -40), Vector2(0, 1))
	inimigos.append(e)

func _spawn_arma(pos: Vector2) -> void:
	# arma plasma sai do icone e voa ate a nave
	var a := Node2D.new()
	a.set_script(ArmaScript)
	add_child(a)
	a.call("setup", pos, player)
	a.connect("coletada", _equipar_power)
	armas.append(a)

func _equipar_power() -> void:
	if vidas <= 0:
		return
	pontos += 500
	power_timer = 15.0
	if player != null and is_instance_valid(player):
		_fx_bonus(player.position)
		player.call("set_equipado", true)
	if sfx != null:
		sfx.call("boss")

func _on_player_atirar(pos: Vector2) -> void:
	if vidas <= 0:
		return
	if power_timer > 0:
		# melhorado 15s: leque triplo unico saindo do bico (bocas na base do sprite)
		var b := Node2D.new()
		b.set_script(BulletScript)
		add_child(b)
		b.call("setup_triplotiro", pos + Vector2(0, -26), Vector2(0, -640), 6)
		tiros.append(b)
		# clarão verde no cano a cada rajada (só visual)
		var flash := Node2D.new()
		flash.set_script(ExplosaoScript)
		add_child(flash)
		flash.call("setup", pos, Color(0.45, 1.0, 0.6), 30.0)
	else:
		# tiro triplo normal
		for off in [Vector2(0, 0), Vector2(-10, 8), Vector2(10, 8)]:
			var b := Node2D.new()
			b.set_script(BulletScript)
			add_child(b)
			b.call("setup", pos + off, Vector2(0, -620), true, 1, false)
			tiros.append(b)
	_fx_tiro(pos)
	# som do tiro do player mutado por enquanto

func _on_super_tiro(pos: Vector2) -> void:
	if vidas <= 0:
		return
	if power_timer > 0:
		# com triplo: feixe sustentado 2s grudado na nave ate o topo
		var f := Node2D.new()
		f.set_script(FeixeScript)
		add_child(f)
		f.call("setup", player)
		feixes.append(f)
	else:
		var b := Node2D.new()
		b.set_script(BulletScript)
		add_child(b)
		b.call("setup", pos, Vector2(0, -520), true, 10, true)
		tiros.append(b)
	_fx_explosao(pos, false)
	if sfx != null:
		sfx.call("explosao")
		sfx.call("boss")

func _on_enemy_atirar(pos: Vector2, grande: bool = false) -> void:
	var b := Node2D.new()
	b.set_script(BulletScript)
	add_child(b)
	var dir := Vector2.ZERO
	if player != null and is_instance_valid(player):
		dir = (player.position - pos).normalized()
		# mistura queda + mira
		dir = (dir * 0.6 + Vector2(0, 1) * 0.4).normalized()
	else:
		dir = Vector2(0, 1)
	if grande:
		# bola gigante do chefao - maior que a nave
		b.call("setup_gigante", pos, dir * 130.0)
	else:
		b.call("setup", pos, dir * 180.0, false)
	tiros_inimigos.append(b)
	_fx_tiro_inimigo(pos)
	# som do tiro inimigo mutado por enquanto

func _fx_tiro(pos: Vector2) -> void:
	var e := Node2D.new()
	e.set_script(ExplosaoScript)
	add_child(e)
	e.call("setup", pos, Color(0.3, 1.0, 0.5), 14.0)

func _fx_tiro_inimigo(pos: Vector2) -> void:
	var e := Node2D.new()
	e.set_script(ExplosaoScript)
	add_child(e)
	e.call("setup", pos, Color(1.0, 0.2, 0.1), 12.0)

func _morte_buraco() -> void:
	# morte instantanea com buraco negro (2 tiros do chefao sem escudo)
	if vidas <= 0:
		return
	var pp := player.position
	player.visible = false
	vidas = 0
	escudo = 0.0
	game_over_timer = 0.0
	var bh := Node2D.new()
	bh.set_script(BuracoScript)
	add_child(bh)
	bh.call("setup", pp, 130.0)
	if sfx != null:
		sfx.call("explosao")
		sfx.call("boss")

func _fx_explosao(pos: Vector2, grande: bool) -> void:
	var e := Node2D.new()
	e.set_script(ExplosaoScript)
	add_child(e)
	if grande:
		e.call("setup", pos, Color(1.0, 0.25, 0.1), 110.0)
	else:
		e.call("setup", pos, Color(1.0, 0.45, 0.15), 42.0)
	if sfx != null:
		sfx.call("explosao")

func _fx_bonus(pos: Vector2) -> void:	# explosao verde em 2 camadas: flash branco + onda verde
	var n1 := Node2D.new()
	n1.set_script(ExplosaoScript)
	add_child(n1)
	n1.call("setup", pos, Color(0.35, 1.0, 0.55), 85.0)
	var n2 := Node2D.new()
	n2.set_script(ExplosaoScript)
	add_child(n2)
	n2.call("setup", pos, Color(0.9, 1.0, 0.92), 40.0)
	if sfx != null:
		sfx.call("explosao")

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if em_menu:
		return
	if vidas <= 0:
		game_over_timer += delta
		_mostrar_gameover(delta)
		# atalho R / Enter tenta de novo
		if game_over_timer > 1.2 and (Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER)):
			_reiniciar()
		return

	# 37s alerta vermelho 3s antes, 40s chefao entra
	tempo_batalha += delta
	if not aviso_dragao and tempo_batalha >= 37.0:
		aviso_dragao = true
		if aviso_label != null:
			aviso_label.visible = true
			aviso_tempo = 5.0
		if aviso_tex != null:
			aviso_tex.visible = true
		if sfx != null:
			sfx.call("boss")
	if not boss_ja_entrou and tempo_batalha >= 40.0:
		boss_ja_entrou = true
		_spawn_boss()
	if aviso_label != null and aviso_label.visible:
		aviso_tempo -= delta
		# pisca texto + pulsa o degrade vermelho
		aviso_label.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		if aviso_tex != null:
			aviso_tex.modulate.a = 0.45 + 0.35 * sin(Time.get_ticks_msec() / 120.0)
		if aviso_tempo <= 0:
			aviso_label.visible = false
			if aviso_tex != null:
				aviso_tex.visible = false

	# escudo 0-100: -10 por tiro sofrido, +10 a cada 3 abates (sem recarga por tempo)

	# torres desativadas por enquanto

	# bonus a cada 30s
	bonus_timer -= delta
	if bonus_timer <= 0:
		bonus_timer = 30.0
		_spawn_bonus()

	# power-up 15s
	if power_timer > 0:
		power_timer -= delta
		if power_label != null:
			power_label.visible = true
			power_label.text = "POWER x%d" % int(ceil(power_timer))
			power_label.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 150.0)
		if power_timer <= 0:
			power_timer = 0.0
			if power_label != null:
				power_label.visible = false
			if player != null and is_instance_valid(player):
				player.call("set_equipado", false)

	# barrinha de carga do super + bipes de perigo
	if player != null and is_instance_valid(player) and charge_bar != null:
		var prog: float = player.call("carga_progress")
		var pronta: bool = player.call("carga_pronta")
		if prog > 0.0:
			charge_bar.visible = true
			charge_txt.visible = true
			charge_bar.value = prog * 100.0
			# segue a nave (mundo = tela, sem camera)
			var pp: Vector2 = player.position
			charge_bar.position = Vector2(pp.x - 55, pp.y - 130)
			charge_txt.position = Vector2(pp.x - 28, pp.y - 150)
			var fill := charge_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if pronta:
				charge_txt.text = "SOLTE!"
				charge_txt.add_theme_color_override("font_color", Color(1, 0.25, 0.15))
				if fill != null:
					fill.bg_color = Color(1, 0.2, 0.1)
				charge_bar.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
			elif prog > 0.6:
				charge_txt.text = "PERIGO"
				charge_txt.add_theme_color_override("font_color", Color(1, 0.45, 0.15))
				if fill != null:
					fill.bg_color = Color(1, 0.55, 0.15)
				charge_bar.modulate.a = 1.0
			else:
				charge_txt.text = "SUPER"
				charge_txt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
				if fill != null:
					fill.bg_color = Color(0.3, 1.0, 0.5)
				charge_bar.modulate.a = 1.0
			# bipes subindo: 1s, 2s, pronto
			var seg := int(player.get("carga"))
			if seg > last_beep and prog < 1.0 and sfx != null:
				last_beep = seg
				sfx.call("hit")
			if pronta and last_beep < 99 and sfx != null:
				last_beep = 99
				sfx.call("boss")
		else:
			charge_bar.visible = false
			charge_txt.visible = false
			last_beep = 0

	# feixe 2s: tick de dano na coluna a cada 0.15s
	feixes = feixes.filter(func(x): return is_instance_valid(x))
	if feixes.size() > 0:
		feixe_tick += delta
		if feixe_tick >= 0.15:
			feixe_tick = 0.0
			for f in feixes:
				if not is_instance_valid(f):
					continue
				var fx: float = (f as Node2D).position.x
				var fy: float = (f as Node2D).position.y
				for e in inimigos:
					if not is_instance_valid(e) or not e.get("vivo"):
						continue
					var ep: Vector2 = (e as Node2D).position
					if absf(ep.x - fx) < 58.0 and ep.y < fy + 20.0 and ep.y > -60.0:
						var morreu: bool = e.call("levar_dano", 4)
						if morreu:
							if str(e.get("tipo")) == "boss":
								pontos += 2000
								_registrar_abate()
								_fx_explosao(ep, true)
								boss = null
								# renasce boss apos 5s
								await get_tree().create_timer(5.0).timeout
								if vidas > 0:
									_spawn_boss()
							elif str(e.get("tipo")) == "bonus":
								pontos += 200
								_fx_bonus(ep)
								_spawn_arma(ep)
							else:
								pontos += 100
								_registrar_abate()
								_fx_explosao(ep, false)
						else:
							if str(e.get("tipo")) == "boss":
								pontos += 40
							_fx_tiro(ep)

	# spawn continuo
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = 1.6
		# conta vivos small
		var n_small := 0
		for e in inimigos:
			if is_instance_valid(e) and e.get("tipo") == "small":
				n_small += 1
		if n_small < 5:
			_spawn_small()

	_colisoes()
	_limpar_listas()
	hud.atualizar(pontos, vidas, escudo)
	if player != null and is_instance_valid(player):
		player.set("escudo_val", escudo)
	# invencivel do player cai junto
	if player != null and player.get("invencivel") == null:
		pass

func _colisoes() -> void:
	# tiro amigo x inimigo (normal dano 1, super dano 10 perfurante)
	for b in tiros:
		if not is_instance_valid(b) or not b.get("vivo"):
			continue
		for e in inimigos:
			if not is_instance_valid(e) or not e.get("vivo"):
				continue
			var raio_b: float = float(b.get("raio"))
			var tipo_e := str(e.get("tipo"))
			var raio_e := 115.0 if tipo_e == "boss" else (22.0 if tipo_e == "turret" else (26.0 if tipo_e == "bonus" else 30.0))
			if b.position.distance_to(e.position) < raio_e + raio_b * 0.5:
				var dano: int = int(b.get("dano"))
				var perfurante: bool = bool(b.get("perfurante"))
				if not perfurante:
					b.set("vivo", false)
					b.queue_free()
				else:
					# super atravessa mas perde 1 de vida util por acerto para nao ficar infinito
					var vp: int = int(b.get("vida_perfurante")) - 1
					b.set("vida_perfurante", vp)
					if vp <= 0:
						b.set("vivo", false)
						b.queue_free()
				var morreu: bool = e.call("levar_dano", dano)
				if morreu:
					if e.get("tipo") == "boss":
						pontos += 2000
						_registrar_abate()
						_fx_explosao(e.position, true)
						boss = null
						# renasce boss apos 5s
						await get_tree().create_timer(5.0).timeout
						if vidas > 0:
							_spawn_boss()
					elif e.get("tipo") == "bonus":
						pontos += 200
						_fx_bonus(e.position)
						_spawn_arma(e.position)
						if sfx != null:
							sfx.call("explosao")
					else:
						pontos += 100
						_registrar_abate()
						_fx_explosao(e.position, false)
				else:
					if e.get("tipo") == "boss":
						pontos += 10 * dano
					_fx_tiro(e.position)
				if perfurante:
					continue # continua atravessando
				break
	# bola gigante do chefao: COM escudo zera tudo, SEM escudo 2 tiros = game over
	if player != null and is_instance_valid(player) and player.visible:
		for b in tiros_inimigos:
			if not is_instance_valid(b) or not b.get("vivo"):
				continue
			if float(b.get("raio")) > 20.0:
				if b.position.distance_to(player.position) < float(b.get("raio")) + 16.0:
					b.set("vivo", false)
					b.queue_free()
					if escudo > 0.0:
						escudo = 0.0
						chefe_sem_escudo = 0
						player.set("invencivel", 1.2)
						player.call("escudo_atingido")
						_fx_explosao(player.position, false)
						if sfx != null:
							sfx.call("explosao")
					else:
						chefe_sem_escudo += 1
						if chefe_sem_escudo >= 2:
							_morte_buraco()
						else:
							player.set("invencivel", 1.2)
							_fx_explosao(player.position, false)
							if sfx != null:
								sfx.call("hit")
					return
	# tiro inimigo normal x player
	if player != null and is_instance_valid(player) and player.get("invencivel") <= 0:
		for b in tiros_inimigos:
			if not is_instance_valid(b) or not b.get("vivo"):
				continue
			if float(b.get("raio")) > 20.0:
				continue # gigante ja tratado acima
			var br: float = float(b.get("raio"))
			if b.position.distance_to(player.position) < br + 14.0:
				b.set("vivo", false)
				b.queue_free()
				_dano_no_player(25.0)
				_fx_explosao(player.position, false)
				break
		# encostou no inimigo (bonus coleta em vez de dano)
		if vidas <= 0:
			return
		for e in inimigos:
			if not is_instance_valid(e):
				continue
			var te := str(e.get("tipo"))
			var r := 115.0 if te == "boss" else (22.0 if te == "turret" else (26.0 if te == "bonus" else 26.0))
			if player.position.distance_to(e.position) < r:
				if te == "bonus":
					_equipar_power()
					_fx_bonus(e.position)
					e.set("vivo", false)
					e.queue_free()
				else:
					_dano_no_player(25.0)
				break

func _dano_no_player(qtd: float) -> void:
	if player.get("invencivel") > 0:
		return
	if escudo > 0:
		escudo -= qtd
		player.set("invencivel", 1.2)
		player.call("escudo_atingido")
		if escudo <= 0:
			escudo = 0.0 # escudo some, volta +10 a cada 3 abates
		return
	# sem escudo: mais 1 tiro perde a vida e recarrega cheio
	vidas -= 1
	escudo = 100.0
	player.set("invencivel", 1.5)
	if vidas <= 0:
		game_over_timer = 0.0
		player.visible = false
	else:
		player.visible = true
	# revive player visivel
	if vidas > 0:
		player.visible = true

func _limpar_listas() -> void:
	tiros = tiros.filter(func(x): return is_instance_valid(x))
	tiros_inimigos = tiros_inimigos.filter(func(x): return is_instance_valid(x))
	inimigos = inimigos.filter(func(x): return is_instance_valid(x))
	armas = armas.filter(func(x): return is_instance_valid(x))
	feixes = feixes.filter(func(x): return is_instance_valid(x))

func _mostrar_gameover(delta: float) -> void:
	gameover_anim += delta
	var f := _fonte()
	if gameover_layer == null:
		gameover_layer = CanvasLayer.new()
		gameover_layer.layer = 50
		add_child(gameover_layer)
		var center := Vector2(270, 480) # coordenadas fixas do projeto (stretch resolve a escala)
		# arte inteira sem cortar (contain): titulo GAME OVER nunca sai da tela
		for p in ["res://assets/gameoverv2.png", "res://assets/gameover.png", "res://assets/game_over.png", "res://assets/gameover.jpg"]:
			if ResourceLoader.exists(p):
				var tex := load(p) as Texture2D
				if tex != null:
					var sp := Sprite2D.new()
					sp.texture = tex
					var sc := minf(540.0 / float(tex.get_width()), 960.0 / float(tex.get_height())) * 0.94
					sp.scale = Vector2(sc, sc)
					sp.set_meta("fit", sc)
					sp.position = center
					sp.name = "Art"
					sp.modulate.a = 0.0
					gameover_layer.add_child(sp)
					break
		# pontos com fonte horror, centralizado
		var pts := Label.new()
		pts.text = "PONTOS %06d" % pontos
		pts.add_theme_font_size_override("font_size", 26)
		if f != null:
			pts.add_theme_font_override("font", f)
		pts.add_theme_color_override("font_color", Color(1, 0.85, 0.7))
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pts.position = Vector2(0, center.y + 130)
		pts.size = Vector2(540, 36)
		pts.name = "Pts"
		pts.modulate.a = 0.0
		gameover_layer.add_child(pts)
		# botao tentar novamente (vermelho neon igual imagem)
		var b1 := Button.new()
		b1.text = "TENTAR NOVAMENTE"
		b1.add_theme_font_size_override("font_size", 24)
		if f != null:
			b1.add_theme_font_override("font", f)
		b1.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
		b1.add_theme_color_override("font_hover_color", Color(1, 0.6, 0.5))
		var sb1 := StyleBoxFlat.new()
		sb1.bg_color = Color(0.05, 0.0, 0.0, 0.85)
		sb1.border_color = Color(1, 0.2, 0.12)
		sb1.set_border_width_all(2)
		sb1.set_corner_radius_all(4)
		b1.add_theme_stylebox_override("normal", sb1)
		var sb1h := sb1.duplicate() as StyleBoxFlat
		sb1h.bg_color = Color(0.15, 0.02, 0.02, 0.95)
		b1.add_theme_stylebox_override("hover", sb1h)
		b1.add_theme_stylebox_override("pressed", sb1h)
		b1.position = Vector2(120, center.y + 180)
		b1.size = Vector2(300, 52)
		b1.name = "Retry"
		b1.modulate.a = 0.0
		b1.pressed.connect(_reiniciar)
		gameover_layer.add_child(b1)
		# botao sair para o menu (cinza igual imagem)
		var b2 := Button.new()
		b2.text = "SAIR PARA O MENU"
		b2.add_theme_font_size_override("font_size", 22)
		if f != null:
			b2.add_theme_font_override("font", f)
		b2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
		b2.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.02, 0.02, 0.03, 0.85)
		sb2.border_color = Color(0.45, 0.45, 0.48)
		sb2.set_border_width_all(1)
		sb2.set_corner_radius_all(4)
		b2.add_theme_stylebox_override("normal", sb2)
		var sb2h := sb2.duplicate() as StyleBoxFlat
		sb2h.bg_color = Color(0.1, 0.1, 0.12, 0.95)
		b2.add_theme_stylebox_override("hover", sb2h)
		b2.add_theme_stylebox_override("pressed", sb2h)
		b2.position = Vector2(120, center.y + 244)
		b2.size = Vector2(300, 48)
		b2.name = "MenuBtn"
		b2.modulate.a = 0.0
		b2.pressed.connect(_ir_para_menu)
		gameover_layer.add_child(b2)
		if sfx != null:
			sfx.call("boss")
	# animacao epica: zoom da arte + fade dos botoes
	var art := gameover_layer.get_node_or_null("Art") as Sprite2D
	if art != null:
		# aproxima suave 0.94 -> 1.0 do fit (sem nunca cortar)
		var k := minf(1.0, gameover_anim * 1.2)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var fit: float = float(art.get_meta("fit", 1.0))
		var s: float = fit * (0.94 + 0.06 * e)
		art.scale = Vector2(s, s)
		art.modulate.a = minf(1.0, gameover_anim * 1.8)
	for n in ["Pts", "Retry", "MenuBtn"]:
		var c := gameover_layer.get_node_or_null(n) as Control
		if c != null:
			c.modulate.a = minf(1.0, maxf(0.0, gameover_anim - 0.6) * 1.6)

func _reiniciar() -> void:
	get_tree().paused = false
	if pause_layer != null:
		pause_layer.visible = false
	pontos = 0
	vidas = 1
	escudo = 100.0
	abates = 0
	chefe_sem_escudo = 0
	tempo_batalha = 0.0
	boss_ja_entrou = false
	aviso_dragao = false
	power_timer = 0.0
	bonus_timer = 20.0
	boss = null
	em_menu = false
	if player != null and is_instance_valid(player):
		player.call("set_equipado", false)
	for a in armas:
		if is_instance_valid(a):
			a.queue_free()
	armas.clear()
	for fx2 in feixes:
		if is_instance_valid(fx2):
			fx2.queue_free()
	feixes.clear()
	feixe_tick = 0.0
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	game_over_timer = -1.0
	gameover_anim = 0.0
	if gameover_layer != null:
		gameover_layer.queue_free()
		gameover_layer = null
	for e in inimigos:
		if is_instance_valid(e):
			e.queue_free()
	inimigos.clear()
	for b in tiros + tiros_inimigos:
		if is_instance_valid(b):
			b.queue_free()
	tiros.clear()
	tiros_inimigos.clear()
	player.visible = true
	player.position = Vector2(270, 800)
	player.set("rotation", 0.0)
	player.set("scale", Vector2.ONE)
	player.set("carga", 0.0)
	player.set("carregando", false)
	if hud != null:
		hud.call("atualizar", pontos, vidas, escudo)
	if musica != null and musica.has_method("trocar_para_normal"):
		musica.call("trocar_para_normal")

func _ir_para_menu() -> void:
	get_tree().paused = false
	if pause_layer != null:
		pause_layer.visible = false
	# limpa campo e mostra menu simples com a mesma fonte horror
	for e in inimigos:
		if is_instance_valid(e):
			e.queue_free()
	inimigos.clear()
	for b in tiros + tiros_inimigos:
		if is_instance_valid(b):
			b.queue_free()
	tiros.clear()
	tiros_inimigos.clear()
	boss = null
	if player != null and is_instance_valid(player):
		player.call("set_equipado", false)
	for a in armas:
		if is_instance_valid(a):
			a.queue_free()
	armas.clear()
	for fx2 in feixes:
		if is_instance_valid(fx2):
			fx2.queue_free()
	feixes.clear()
	if gameover_layer != null:
		gameover_layer.queue_free()
		gameover_layer = null
	em_menu = true
	if player != null:
		player.visible = false
	if menu_layer != null:
		menu_layer.queue_free()
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 40
	add_child(menu_layer)
	var center := Vector2(270, 480) # fixo do projeto
	var f := _fonte()
	var bg := ColorRect.new()
	bg.color = Color(0.005, 0.015, 0.01, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)
	var t := Label.new()
	t.text = "ALIEN FIELD"
	t.add_theme_font_size_override("font_size", 56)
	if f != null:
		t.add_theme_font_override("font", f)
	t.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, center.y - 120)
	t.size = Vector2(540, 80)
	menu_layer.add_child(t)
	var s := Label.new()
	s.text = "FASE 1-3  -  NIVEL DRAGAO"
	s.add_theme_font_size_override("font_size", 22)
	if f != null:
		s.add_theme_font_override("font", f)
	s.add_theme_color_override("font_color", Color(0.8, 0.85, 0.82))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, center.y - 40)
	s.size = Vector2(540, 34)
	menu_layer.add_child(s)
	var bj := Button.new()
	bj.text = "JOGAR"
	bj.add_theme_font_size_override("font_size", 30)
	if f != null:
		bj.add_theme_font_override("font", f)
	bj.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.1, 0.05, 0.95)
	sb.border_color = Color(0.3, 1.0, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	bj.add_theme_stylebox_override("normal", sb)
	bj.position = Vector2(140, center.y + 40)
	bj.size = Vector2(260, 60)
	bj.pressed.connect(_reiniciar)
	menu_layer.add_child(bj)
	var h := Label.new()
	h.text = "WASD move  -  L atira / segura 3s super"
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.6, 0.65, 0.62))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(0, center.y + 130)
	h.size = Vector2(540, 26)
	menu_layer.add_child(h)

extends Node2D
# Alien field - main

const BulletScript := preload("res://scripts/bullet.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BgScript := preload("res://scripts/background.gd")
const HudScript := preload("res://scripts/hud.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const ExplosaoScript := preload("res://scripts/explosao.gd")
const ExplodeNaveScript := preload("res://scripts/explode_nave.gd")
const ExplodeSeqScript := preload("res://scripts/explode_seq.gd")
const TELA_CENTRO := Vector2(270, 480)
var tex_explode_nave: Texture2D = null
var tex_explode_seq: Array = []
const MusicScript := preload("res://scripts/music.gd")
const ArmaScript := preload("res://scripts/arma.gd")
const BuracoScript := preload("res://scripts/buraco_negro.gd")
const FeixeScript := preload("res://scripts/feixe.gd")
const PortalScript := preload("res://scripts/portal.gd")
const DanoNumScript := preload("res://scripts/dano_num.gd")
const MissilScript := preload("res://scripts/missil.gd")

var player: Node2D
var hud: CanvasLayer
var boss: Node2D = null
var sfx: Node = null
var musica: Node = null
var bg_no: Node2D = null
var cam: Camera2D = null
var trauma := 0.0
var hitstop_id := 0
var dimensao := 1
var tempo_fase := 0.0
var portal: Node2D = null
var portal_label: Label = null
var transicao_layer: CanvasLayer = null
var transicao_anim := 0.0
var em_transicao := false
var transicao_trocou := false
var portal_chegada: Node2D = null
var turret_timer := 3.0

var tiros: Array = []
var tiros_inimigos: Array = []
var inimigos: Array = []
var armas: Array = []
var feixes: Array = []
var feixe_tick := 0.0
var misseis: Array = []
var bonus2_timer := 20.0

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
var charge_bar: Control = null
var charge_txt: Label = null
var flash_layer: CanvasLayer = null
var flash_rect: ColorRect = null
var flash_t := 0.0
var flash_forca := 0.0
var pause_layer: CanvasLayer = null
var last_beep := 0
var abates := 0
var chefe_sem_escudo := 0
var combo := 0
var combo_timer := 0.0

func _num(pos: Vector2, texto: String, tamanho: int, cor: Color) -> void:
	var n := Label.new()
	n.set_script(DanoNumScript)
	n.call("setup", pos, texto, tamanho, cor)
	hud.add_child(n)

func _kill_confirm(pos: Vector2, pts: int, cor: Color) -> void:
	combo += 1
	combo_timer = 2.5
	_num(pos, "+%d" % pts, 26, cor)
	if combo >= 3:
		_num(pos + Vector2(0, -28), "COMBO x%d" % combo, 20, Color(1, 0.85, 0.3))
	# som de impacto mutado por enquanto
var frames_boom: SpriteFrames = null
var morto_id := 0
var dano_no_chefe := false

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

func _gerar_flipbook_boom() -> SpriteFrames:
	# 7 frames procedurais 64px: nucleo branco -> laranja -> fumaca
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 14)
	sf.set_animation_loop("default", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for f in 7:
		var tam := 64
		var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
		var c := float(tam) / 2.0
		var k := float(f) / 6.0
		for y in tam:
			for x in tam:
				var d := Vector2(float(x) - c + 0.5, float(y) - c + 0.5).length() / c
				var corpo := clampf((1.0 - k) * 1.1 - d, 0.0, 1.0)
				var anel := clampf(1.0 - absf(d - k * 0.9) * 3.0, 0.0, 1.0) * (1.0 - k * 0.6)
				var r := clampf(corpo * 1.2 + anel, 0.0, 1.0)
				var g := clampf(corpo * (1.0 - k * 0.7) + anel * 0.5, 0.0, 1.0)
				var b := clampf(corpo * (1.0 - k) * (1.0 - k) + anel * 0.15, 0.0, 1.0)
				var a := clampf(maxf(corpo, anel * 0.9) + (0.25 if k > 0.5 else 0.0), 0.0, 1.0)
				if d < 1.0:
					img.set_pixel(x, y, Color(r, g, b, a))
		sf.add_frame("default", ImageTexture.create_from_image(img))
	return sf

func _boom_flipbook(pos: Vector2, escala: float) -> void:
	if frames_boom == null:
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames_boom
	a.position = pos
	a.scale = Vector2(escala, escala)
	add_child(a)
	a.play("default")
	a.animation_finished.connect(a.queue_free)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	frames_boom = _gerar_flipbook_boom()
	if ResourceLoader.exists("res://assets/explode_nave.png"):
		tex_explode_nave = load("res://assets/explode_nave.png") as Texture2D
	# sequencia de 4 frames (preferida)
	for i in 4:
		var caminho := "res://assets/explode_seq_%d.png" % i
		if ResourceLoader.exists(caminho):
			var t := load(caminho) as Texture2D
			if t != null:
				tex_explode_seq.append(t)
	sfx = Node.new()
	sfx.set_script(SfxScript)
	add_child(sfx)
	musica = Node.new()
	musica.set_script(MusicScript)
	add_child(musica)

	var bg := Node2D.new()
	bg.set_script(BgScript)
	add_child(bg)
	bg_no = bg

	# camera do jogo (shake/hit-stop); HUD fica parado
	cam = Camera2D.new()
	cam.position = Vector2(270, 480)
	add_child(cam)
	cam.make_current()

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

	portal_label = Label.new()
	portal_label.text = "ATRAVESSE O PORTAL"
	portal_label.add_theme_font_size_override("font_size", 24)
	if _fonte() != null:
		portal_label.add_theme_font_override("font", _fonte())
	portal_label.add_theme_color_override("font_color", Color(1, 0.3, 0.12))
	portal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal_label.position = Vector2(0, 630)
	portal_label.size = Vector2(540, 36)
	portal_label.visible = false
	hud.add_child(portal_label)

	# barrinha de carga do super tiro — FIXA no rodape, logo abaixo da barra de
	# escudo. Antes ela seguia a nave e cobria o casco.
	charge_bar = preload("res://scripts/super_bar.gd").new()
	charge_bar.custom_minimum_size = Vector2(248, 22)
	charge_bar.size = Vector2(248, 22)
	charge_bar.position = Vector2(46, 910)
	charge_bar.visible = false
	hud.add_child(charge_bar)

	charge_txt = Label.new()
	charge_txt.text = "SUPER"
	charge_txt.add_theme_font_size_override("font_size", 13)
	if _fonte() != null:
		charge_txt.add_theme_font_override("font", _fonte())
	charge_txt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	charge_txt.visible = false
	hud.add_child(charge_txt)

	# flash de tela (impactos/explosoes)
	flash_layer = CanvasLayer.new()
	flash_layer.layer = 40
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.name = "FlashTela"
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash_rect)

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
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.position = Vector2(0, 420)
	pl.size = Vector2(540, 80)
	pause_layer.add_child(pl)
	var ph := Label.new()
	ph.text = "P continua"
	ph.add_theme_font_size_override("font_size", 22)
	if _fonte() != null:
		ph.add_theme_font_override("font", _fonte())
	ph.add_theme_color_override("font_color", Color(0.8, 0.85, 0.82))
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.position = Vector2(0, 500)
	ph.size = Vector2(540, 32)
	pause_layer.add_child(ph)

	for i in 3:
		_spawn_small()
	_cartao_fase()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_alternar_pause()

func _botao_vivo(b: Button, cor_texto: Color, cor_borda: Color) -> void:
	b.pivot_offset = b.size / 2.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.06, 0.03, 0.88)
	normal.border_color = cor_borda
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.06, 0.18, 0.08, 0.95)
	hover.border_color = Color(1, 1, 1)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.1, 0.3, 0.12, 1.0)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", cor_texto)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.mouse_entered.connect(_ui_tick)
	b.pressed.connect(_soco_botao.bind(b))

func _ui_tick() -> void:
	if sfx != null:
		sfx.call("ui")

func _soco_botao(b: Button) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size / 2.0
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.07)
	tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _alternar_pause() -> void:
	if em_menu or vidas <= 0:
		return
	get_tree().paused = not get_tree().paused
	if pause_layer != null:
		pause_layer.visible = get_tree().paused
	if musica != null and musica.has_method("set_pausado"):
		musica.call("set_pausado", get_tree().paused)

func _cartao_fase() -> void:
	# cartao FASE 1-3 deslizando com tween
	var card := Label.new()
	card.text = "FASE 1-3"
	card.add_theme_font_size_override("font_size", 64)
	if _fonte() != null:
		card.add_theme_font_override("font", _fonte())
	card.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.position = Vector2(560, 420)
	card.size = Vector2(540, 90)
	card.modulate.a = 0.0
	hud.add_child(card)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.4)
	tw.chain().tween_interval(1.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)

func _spawn_portal() -> void:
	if portal != null and is_instance_valid(portal):
		return
	portal = Node2D.new()
	portal.set_script(PortalScript)
	add_child(portal)
	# Portal grande, posicionado na metade de cima da tela sem encostar no topo.
	# Centro em y=310 e raio 265 => o vortice vai de y=45 a y=575.
	portal.position = Vector2(270, 310)
	portal.set("raio", 265.0)
	if portal_label != null:
		portal_label.visible = true
	# sem som ao abrir o portal (a transicao visual e o suficiente)

func _entrar_dimensao2() -> void:
	if dimensao == 2 or em_transicao:
		return
	# congela e mostra a transicao dramatica antes do mundo novo
	em_transicao = true
	transicao_anim = 0.0
	transicao_trocou = false
	if portal != null and is_instance_valid(portal):
		portal.queue_free()
	portal = null
	if portal_label != null:
		portal_label.visible = false
	if player != null and is_instance_valid(player):
		player.visible = false
	for e in inimigos:
		if is_instance_valid(e):
			_fx_explosao((e as Node2D).position, false)
			e.queue_free()
	inimigos.clear()
	_mostrar_transicao()
	if musica != null and musica.has_method("trocar_para_transicao"):
		musica.call("trocar_para_transicao")

func _mostrar_transicao() -> void:
	transicao_layer = CanvasLayer.new()
	transicao_layer.layer = 45
	add_child(transicao_layer)
	var center := Vector2(270, 480) # fixo: nunca corta nem sai do centro
	# cutscene primeiro (nave voando pro vortice), com a ancora do vortice
	# em coordenadas normalizadas da imagem; depois cai pra imagem antiga
	for p in ["res://assets/cutscene.jpg", "res://assets/transicao.jpg", "res://assets/transicao.png"]:
		if ResourceLoader.exists(p):
			var tex := load(p) as Texture2D
			if tex != null:
				var sp := Sprite2D.new()
				sp.texture = tex
				# escala de "cobrir": a maior das duas, pra nunca aparecer barra
				var sc := maxf(540.0 / float(tex.get_width()), 960.0 / float(tex.get_height()))
				sp.scale = Vector2(sc, sc)
				sp.set_meta("fit", sc)
				# ponto de interesse: onde esta o vortice na imagem
				var ancora := Vector2(0.5, 0.5)
				if p.contains("cutscene"):
					ancora = Vector2(0.72, 0.34)
				sp.set_meta("ancora", ancora)
				sp.position = center
				sp.name = "Art"
				sp.modulate.a = 0.0
				transicao_layer.add_child(sp)
				break
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.name = "Flash"
	transicao_layer.add_child(flash)
	# quadrinhos da travessia
	var falas := ["O PORTAL SE ABRIU...", "A FROTA FICOU PARA TRAS", "SO RESTOU VOCE"]
	for i in 3:
		var q := Label.new()
		q.text = falas[i]
		q.add_theme_font_size_override("font_size", 26)
		if _fonte() != null:
			q.add_theme_font_override("font", _fonte())
		q.add_theme_color_override("font_color", Color(0.92, 1.0, 0.94))
		q.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		q.add_theme_constant_override("shadow_offset_x", 2)
		q.add_theme_constant_override("shadow_offset_y", 2)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.position = Vector2(0, 180.0 + float(i) * 300.0)
		q.size = Vector2(540, 40)
		q.name = "Q%d" % i
		q.modulate.a = 0.0
		transicao_layer.add_child(q)
	# poeira subindo (mantem: da profundidade sem competir com o zoom)
	var poe := Node2D.new()
	poe.set_script(preload("res://scripts/poeira.gd"))
	poe.name = "Poeira"
	transicao_layer.add_child(poe)
	# SEM dissolve e SEM glitch: a transicao agora e so o dolly de zoom na
	# imagem da nave. O shader de dissolve e o overlay de glitch foram
	# desativados de proposito.

func _fim_transicao() -> void:
	# mundo novo perigoso (imagem ainda se desfazendo por cima)
	dimensao = 2
	tempo_fase = 0.0
	boss_ja_entrou = false
	aviso_dragao = false
	if bg_no != null and is_instance_valid(bg_no):
		bg_no.call("trocar_dimensao", 2)
	# portal de chegada onde a nave vai surgir
	if portal_chegada != null and is_instance_valid(portal_chegada):
		portal_chegada.queue_free()
	portal_chegada = Node2D.new()
	portal_chegada.set_script(PortalScript)
	add_child(portal_chegada)
	portal_chegada.position = Vector2(270, 780)
	portal_chegada.set("raio", 265.0)
	portal_chegada.scale = Vector2(0.62, 0.62)
	if player != null and is_instance_valid(player):
		player.position = Vector2(270, 800)
		player.set("scale", Vector2(0.15, 0.15))
		player.set("surgindo", true)
	for i in 2:
		_spawn_small()

# Reinvoca o chefe depois de 'atraso' segundos SEM travar quem chamou.
# Usar 'await' dentro de _colisoes/_colisoes_misseis suspendia o loop no meio
# da varredura: ao voltar, as referencias (tiros/inimigos) ja tinham sido
# liberadas -> "Attempt to call function 'get' in base 'previously freed'".
func _respawn_boss_apos(atraso: float) -> void:
	var t := get_tree().create_timer(atraso, true, false, true)
	await t.timeout
	if is_inside_tree() and vidas > 0 and boss == null:
		_spawn_boss()

func _spawn_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return
	boss = Node2D.new()
	boss.set_script(EnemyScript)
	add_child(boss)
	boss.call("setup", "boss", Vector2(270, -180), Vector2(0, 1))
	boss.set("entrando", true)
	boss.connect("quer_atirar", _on_enemy_atirar)
	inimigos.append(boss)
	# descida cinematica com ease-out
	var tw := create_tween()
	tw.tween_property(boss, "position:y", 148.0, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_chegada_boss)
	if sfx != null:
		sfx.call("boss")
	if musica != null and musica.has_method("trocar_para_boss"):
		musica.call("trocar_para_boss")

func _chegada_boss() -> void:
	if boss != null and is_instance_valid(boss):
		boss.set("entrando", false)
		_fx_explosao(boss.position + Vector2(0, 60), false, false)
	add_trauma(0.45)
	dano_no_chefe = false
	# soco de zoom na chegada
	if cam != null and is_instance_valid(cam):
		var tw := create_tween()
		tw.tween_property(cam, "zoom", Vector2(1.09, 1.09), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(cam, "zoom", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_intro_chefe()

func _intro_chefe() -> void:
	# cartaz com letterbox: nome do chefao
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 1)
	top.anchor_right = 1.0
	top.offset_bottom = 0.0
	layer.add_child(top)
	var bot := ColorRect.new()
	bot.color = Color(0, 0, 0, 1)
	bot.anchor_left = 0.0
	bot.anchor_top = 1.0
	bot.anchor_right = 1.0
	bot.anchor_bottom = 1.0
	bot.offset_top = 0.0
	layer.add_child(bot)
	var nome := Label.new()
	nome.text = "DRAGAO DO VAZIO"
	nome.add_theme_font_size_override("font_size", 58)
	if _fonte() != null:
		nome.add_theme_font_override("font", _fonte())
	nome.add_theme_color_override("font_color", Color(1, 0.15, 0.08))
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.position = Vector2(0, 430)
	nome.size = Vector2(540, 90)
	nome.modulate.a = 0.0
	layer.add_child(nome)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(top, "offset_bottom", 90.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bot, "offset_top", -90.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(nome, "modulate:a", 1.0, 0.5)
	tw.chain().tween_interval(1.8)
	tw.tween_property(top, "offset_bottom", 0.0, 0.4)
	tw.tween_property(bot, "offset_top", 0.0, 0.4)
	tw.tween_property(nome, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)

func add_trauma(qtd: float) -> void:
	trauma = minf(1.0, trauma + qtd)

func hitstop(dur: float, escala: float = 0.05) -> void:
	hitstop_id += 1
	var meu := hitstop_id
	Engine.time_scale = escala
	await get_tree().create_timer(dur, true, false, true).timeout
	if meu == hitstop_id:
		Engine.time_scale = 1.0

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

func _spawn_bonus2() -> void:
	# caixa vermelha: so com o chefao vivo, 1 por vez
	if boss == null or not is_instance_valid(boss):
		return
	for e in inimigos:
		if is_instance_valid(e) and str(e.get("tipo")) == "bonus2":
			return
	var e := Node2D.new()
	e.set_script(EnemyScript)
	add_child(e)
	e.call("setup", "bonus2", Vector2(randf_range(140, 400), -40), Vector2(0, 1))
	inimigos.append(e)

func _disparar_missil() -> void:
	# missil teleguiado mira o chefao (ou o capanga mais proximo)
	var alvo: Node2D = null
	if boss != null and is_instance_valid(boss):
		alvo = boss
	else:
		var melhor := 1e9
		for e in inimigos:
			if is_instance_valid(e) and str(e.get("tipo")) == "small":
				var d: float = player.position.distance_to((e as Node2D).position)
				if d < melhor:
					melhor = d
					alvo = e
	var m := Node2D.new()
	m.set_script(MissilScript)
	add_child(m)
	m.call("setup", player.position + Vector2(0, -50), alvo)
	misseis.append(m)
	_num(player.position + Vector2(0, -100), "MISSIL!", 26, Color(1, 0.45, 0.15))

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
	_num(player.position + Vector2(0, -90), "POWER!", 30, Color(0.45, 1.0, 0.6))
	if player != null and is_instance_valid(player):
		_fx_bonus(player.position)
		player.call("set_equipado", true)
	if sfx != null:
		sfx.call("pickup")

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
		# tiro normal novo: 3 cristais da imagem disparo.png
		var noffs := [Vector2(-12, 8), Vector2(0, 0), Vector2(12, 8)]
		var nvels := [Vector2(-35, -615), Vector2(0, -630), Vector2(35, -615)]
		for i in 3:
			var b := Node2D.new()
			b.set_script(BulletScript)
			add_child(b)
			b.call("setup_disparo", pos + noffs[i], nvels[i], i)
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

func _slowmo_morte() -> void:
	morto_id += 1
	var meu := morto_id
	Engine.time_scale = 0.25
	await get_tree().create_timer(1.0, true, false, true).timeout
	if meu == morto_id:
		Engine.time_scale = 1.0

func _killcam_boss(pos: Vector2) -> void:
	# camera cola no chefao em slow-mo
	morto_id += 1
	var meu := morto_id
	Engine.time_scale = 0.3
	if cam != null and is_instance_valid(cam):
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cam, "zoom", Vector2(1.4, 1.4), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(cam, "position", Vector2(270, clampf(pos.y, 200.0, 480.0)), 0.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.4, true, false, true).timeout
	if meu != morto_id:
		return
	if cam != null and is_instance_valid(cam):
		cam.zoom = Vector2.ONE
		cam.position = Vector2(270, 480)
	Engine.time_scale = 1.0

func _rank_chefe() -> void:
	# S sem sofrer dano no chefao, A escudo alto, B resto
	var rank := "S"
	var extra := 5000
	if dano_no_chefe and escudo < 50.0:
		rank = "B"
		extra = 500
	elif dano_no_chefe:
		rank = "A"
		extra = 2000
	pontos += extra
	var cor := Color(1, 0.85, 0.2) if rank == "S" else (Color(0.7, 0.85, 1.0) if rank == "A" else Color(0.8, 0.5, 0.3))
	var lbl := Label.new()
	lbl.text = "RANK " + rank
	lbl.add_theme_font_size_override("font_size", 96)
	if _fonte() != null:
		lbl.add_theme_font_override("font", _fonte())
	lbl.add_theme_color_override("font_color", cor)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 400)
	lbl.size = Vector2(540, 130)
	lbl.scale = Vector2(2.2, 2.2)
	lbl.pivot_offset = Vector2(270, 65)
	lbl.modulate.a = 0.0
	hud.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)
	if sfx != null:
		sfx.call("boss")

func _morte_buraco() -> void:
	# morte instantanea com buraco negro (2 tiros do chefao sem escudo)
	if vidas <= 0:
		return
	combo = 0
	_slowmo_morte()
	if sfx != null:
		sfx.call("stinger")
	var pp := player.position
	player.visible = false
	vidas = 0
	escudo = 0.0
	game_over_timer = 0.0
	var bh := Node2D.new()
	bh.set_script(BuracoScript)
	add_child(bh)
	bh.call("setup", pp, 130.0)
	add_trauma(0.8)
	if sfx != null:
		sfx.call("explosao")
		sfx.call("boss")

func flash_tela(forca: float, cor: Color = Color(1, 1, 1)) -> void:
	flash_t = 1.0
	flash_forca = maxf(flash_forca * 0.4, clampf(forca, 0.0, 1.0))
	if flash_rect != null:
		flash_rect.color = Color(cor.r, cor.g, cor.b, flash_forca)

func _atualizar_flash(delta: float) -> void:
	if flash_rect == null:
		return
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta * 4.5)
		flash_rect.color.a = flash_forca * flash_t * flash_t
		if flash_t <= 0.0:
			flash_forca = 0.0

func _fx_explosao(pos: Vector2, grande: bool, com_som: bool = true) -> void:
	if tex_explode_seq.size() == 4:
		# sequencia de 4 frames
		var es := Node2D.new()
		es.set_script(ExplodeSeqScript)
		add_child(es)
		es.call("setup", pos, tex_explode_seq, 300.0 if grande else 155.0, grande)
	elif tex_explode_nave != null:
		var en := Node2D.new()
		en.set_script(ExplodeNaveScript)
		add_child(en)
		en.call("setup", pos, tex_explode_nave,
			300.0 if grande else 150.0, grande, randf_range(-1.1, 1.1))
	else:
		var e := Node2D.new()
		e.set_script(ExplosaoScript)
		add_child(e)
		e.call("setup", pos, Color(1.0, 0.25, 0.1) if grande else Color(1.0, 0.55, 0.18),
			110.0 if grande else 46.0, grande)
	if grande:
		_boom_flipbook(pos, 2.2)
		flash_tela(0.42, Color(1.0, 0.88, 0.75))
	else:
		flash_tela(0.12, Color(1.0, 0.95, 0.85))
	if com_som and sfx != null:
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
	_atualizar_flash(delta)
	if get_tree().paused:
		return
	if em_menu:
		return
	if em_transicao:
		transicao_anim += delta
		var art := transicao_layer.get_node_or_null("Art") as Sprite2D if transicao_layer != null else null
		var flash := transicao_layer.get_node_or_null("Flash") as ColorRect if transicao_layer != null else null
		var poe := transicao_layer.get_node_or_null("Poeira") if transicao_layer != null else null
		# dissolve 0.4 -> 2.2 com poeira subindo
		var prog := clampf((transicao_anim - 0.4) / 1.8, 0.0, 1.0)
		if art != null:
			# ---- dolly: a camera acelera CONTRA o vortice da imagem
			# a ancora fica parada no centro da tela enquanto o zoom cresce,
			# dando a sensacao de estar sendo sugado pelo portal
			var zk: float = clampf((transicao_anim - 0.05) / 1.75, 0.0, 1.0)
			# easeIn: comeca devagar e acelera (como uma queda)
			var ze: float = zk * zk
			var fit: float = float(art.get_meta("fit", 1.0))
			var anc: Vector2 = art.get_meta("ancora", Vector2(0.5, 0.5))
			var tw := 1.0
			var th := 1.0
			if art.texture != null:
				tw = float(art.texture.get_width())
				th = float(art.texture.get_height())
			# offset da ancora em relacao ao centro da imagem
			var off := Vector2((anc.x - 0.5) * tw, (anc.y - 0.5) * th)
			var zoom: float = lerpf(1.0, 2.15, ze)
			var s: float = fit * zoom
			art.scale = Vector2(s, s)
			# Comeca centralizado e SÓ deriva durante o zoom. Se a imagem
			# ja nascesse deslocada pra manter a ancora no centro, sobraria
			# faixa preta na borda oposta (a escala de "cobrir" nao cobre o
			# deslocamento). Com o lerp, no fim a ancora chega ao centro.
			var p_fim := TELA_CENTRO - off * fit * zoom
			var p_alvo := TELA_CENTRO.lerp(p_fim, ze)
			# tremor crescente da camera
			var tremor: float = ze * 9.0
			var tx := sin(transicao_anim * 61.0) * tremor + sin(transicao_anim * 37.0) * tremor * 0.6
			var ty := cos(transicao_anim * 53.0) * tremor + cos(transicao_anim * 29.0) * tremor * 0.5
			art.position = p_alvo + Vector2(tx, ty)
			art.modulate.a = minf(1.0, transicao_anim * 3.0)
		if poe != null and poe.has_method("set"):
			poe.set("intensidade", prog)
		if flash != null:
			# clarão curto, só pra cobrir o corte da entrada
			flash.color.a = maxf(0.0, 0.85 - transicao_anim * 3.4)
		# quadrinhos entram em sequencia
		for i in 3:
			var q := transicao_layer.get_node_or_null("Q%d" % i) as Label if transicao_layer != null else null
			if q != null:
				var ini := 0.25 + float(i) * 0.65
				var fim := ini + 0.9
				if transicao_anim < ini:
					q.modulate.a = 0.0
				elif transicao_anim < ini + 0.25:
					q.modulate.a = (transicao_anim - ini) / 0.25
				elif transicao_anim < fim:
					q.modulate.a = 1.0
				else:
					q.modulate.a = maxf(0.0, 1.0 - (transicao_anim - fim) / 0.3)
		if not transicao_trocou and transicao_anim >= 1.8:
			transicao_trocou = true
			_fim_transicao()
		# 2.0: nave surge do portal crescendo
		if transicao_anim >= 2.0 and player != null and is_instance_valid(player) and not player.visible:
			player.visible = true
			player.set("invencivel", 3.0)
			# som da entrada removido de proposito: a transicao agora e
			# so o dolly de zoom, sem barulho por cima
		if player != null and is_instance_valid(player) and bool(player.get("surgindo")):
			var ks := clampf((transicao_anim - 2.0) / 0.8, 0.15, 1.0)
			player.set("scale", Vector2(ks, ks))
		if portal_chegada != null and is_instance_valid(portal_chegada):
			var kp := clampf(1.0 - (transicao_anim - 2.0) / 0.8, 0.0, 1.0)
			portal_chegada.scale = Vector2(0.62 * kp, 0.62 * kp)
		if transicao_anim >= 3.0:
			em_transicao = false
			if player != null and is_instance_valid(player):
				player.set("surgindo", false)
				player.set("scale", Vector2.ONE)
			if portal_chegada != null and is_instance_valid(portal_chegada):
				portal_chegada.queue_free()
			portal_chegada = null
			if transicao_layer != null:
				transicao_layer.queue_free()
				transicao_layer = null
		return
	if vidas <= 0:
		game_over_timer += delta
		_mostrar_gameover(delta)
		# atalho R / Enter tenta de novo
		if game_over_timer > 1.2 and (Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER)):
			_reiniciar()
		return

	# FASE 1: portal abre aos 18s | DIMENSAO 2: chefao 35s depois de entrar
	tempo_batalha += delta
	tempo_fase += delta
	if dimensao == 1:
		if portal == null and tempo_batalha >= 18.0:
			_spawn_portal()
		if portal != null and is_instance_valid(portal) and player != null and is_instance_valid(player):
			# dispara quando a nave ENTRA no vortice (distancia do centro menor
		# que o raio do portal), e nao quando chega a 80px do centro exato:
		# com o portal grande e la em cima, 80px seria impossivel de alcancar
			if player.position.distance_to(portal.position) < float(portal.get("raio")):
				_entrar_dimensao2()
		if tempo_batalha >= 100.0:
			_entrar_dimensao2() # fallback: nunca trava
	else:
		if not aviso_dragao and tempo_fase >= 32.0:
			aviso_dragao = true
			if aviso_label != null:
				aviso_label.visible = true
				aviso_tempo = 5.0
			if aviso_tex != null:
				aviso_tex.visible = true
			if sfx != null:
				sfx.call("boss")
		if not boss_ja_entrou and tempo_fase >= 35.0:
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

	# escudo 0-100: -25 por dano, +25 a cada 5 abates

	# torres desativadas por enquanto

	# bonus a cada 30s
	bonus_timer -= delta
	if bonus_timer <= 0:
		bonus_timer = 30.0
		_spawn_bonus()

	# caixa vermelha a cada 25s (so com chefao)
	bonus2_timer -= delta
	if bonus2_timer <= 0:
		bonus2_timer = 25.0
		_spawn_bonus2()

	# combo some sem matar por 2.5s
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo = 0

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
			charge_bar.set("prog", prog)
			charge_bar.set("pronta", pronta)
			# posicao fixa no rodape (definida no _ready). O texto fica na
			# ponta direita da barra, sem cobrir a nave.
			charge_txt.position = Vector2(302, 914)
			if pronta:
				charge_txt.text = "SOLTE!"
				charge_txt.add_theme_color_override("font_color", Color(1, 0.25, 0.15))
			elif prog > 0.6:
				charge_txt.text = "PERIGO"
				charge_txt.add_theme_color_override("font_color", Color(1, 0.45, 0.15))
			else:
				charge_txt.text = "SUPER"
				charge_txt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			# som de carga mutado por enquanto
			var seg := int(player.get("carga"))
			if seg > last_beep and prog < 1.0:
				last_beep = seg
			if pronta and last_beep < 99:
				last_beep = 99
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
								_kill_confirm(ep, 2000, Color(1, 0.85, 0.3))
								_fx_explosao(ep, true, false)
								_rank_chefe()
								_killcam_boss(ep)
								add_trauma(0.7)
								boss = null
								# renasce boss apos 5s
								await get_tree().create_timer(5.0).timeout
								if vidas > 0:
									_spawn_boss()
							elif str(e.get("tipo")) == "bonus":
								pontos += 200
								_fx_bonus(ep)
								_spawn_arma(ep)
							elif str(e.get("tipo")) == "bonus2":
								pontos += 200
								_fx_explosao(ep, false, false)
								_disparar_missil()
							else:
								pontos += 100
								_registrar_abate()
								_kill_confirm(ep, 100, Color(0.5, 1.0, 0.55))
								_fx_explosao(ep, false, false)
								hitstop(0.06)
								add_trauma(0.22)
						else:
							if str(e.get("tipo")) == "boss":
								pontos += 40
							_num(ep, "4", 18, Color(1, 1, 1))
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
	_colisoes_misseis()
	_limpar_listas()
	hud.atualizar(pontos, vidas, escudo)
	if boss != null and is_instance_valid(boss):
		hud.call("boss_vida", int(boss.get("hp")), 120)
	else:
		hud.call("boss_fora")
	# camera shake com decaimento
	if cam != null and is_instance_valid(cam):
		trauma = maxf(0.0, trauma - delta * 1.6)
		var sh := trauma * trauma * 22.0
		cam.offset = Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
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
			# o tiro pode ter sido liberado dentro da iteracao interna
			if not is_instance_valid(b) or not b.get("vivo"):
				break
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
						_kill_confirm(e.position, 2000, Color(1, 0.85, 0.3))
						_fx_explosao(e.position, true, false)
						_rank_chefe()
						_killcam_boss(e.position)
						add_trauma(0.7)
						boss = null
						# renasce boss apos 5s (nao usar await aqui)
						_respawn_boss_apos(5.0)
					elif e.get("tipo") == "bonus":
						pontos += 200
						_fx_bonus(e.position)
						_spawn_arma(e.position)
						if sfx != null:
							sfx.call("explosao")
					elif e.get("tipo") == "bonus2":
						pontos += 200
						_fx_explosao(e.position, false, false)
						_disparar_missil()
					else:
						pontos += 100
						_registrar_abate()
						_kill_confirm(e.position, 100, Color(0.5, 1.0, 0.55))
						_fx_explosao(e.position, false, false)
						hitstop(0.06)
						add_trauma(0.22)
				else:
					if e.get("tipo") == "boss":
						pontos += 10 * dano
					_num(e.position, str(dano), 18, Color(1, 1, 1))
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
						_fx_explosao(player.position, false, false)
					else:
						chefe_sem_escudo += 1
						if chefe_sem_escudo >= 2:
							_morte_buraco()
						else:
							player.set("invencivel", 1.2)
							_fx_explosao(player.position, false, false)
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
				_fx_explosao(player.position, false, false)
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
				elif te == "bonus2":
					pontos += 200
					_fx_explosao(e.position, false, false)
					_disparar_missil()
					e.set("vivo", false)
					e.queue_free()
				else:
					_dano_no_player(25.0)
				break

func _colisoes_misseis() -> void:
	# missil causa 36 (30% do chefe) e some no impacto
	for m in misseis:
		if not is_instance_valid(m) or not m.get("vivo"):
			continue
		for e in inimigos:
			if not is_instance_valid(e) or not e.get("vivo"):
				continue
			if not is_instance_valid(m) or not m.get("vivo"):
				break
			var te := str(e.get("tipo"))
			if te == "bonus" or te == "bonus2" or te == "turret":
				continue
			var raio_e := 115.0 if te == "boss" else 30.0
			if (m as Node2D).position.distance_to((e as Node2D).position) < raio_e + 10.0:
				m.set("vivo", false)
				m.queue_free()
				var morreu: bool = e.call("levar_dano", 36)
				if morreu:
					if te == "boss":
						pontos += 2000
						_registrar_abate()
						_kill_confirm((e as Node2D).position, 2000, Color(1, 0.85, 0.3))
						_fx_explosao((e as Node2D).position, true, false)
						_rank_chefe()
						_killcam_boss((e as Node2D).position)
						add_trauma(0.7)
						boss = null
						_respawn_boss_apos(5.0)
					else:
						pontos += 100
						_registrar_abate()
						_kill_confirm((e as Node2D).position, 100, Color(0.5, 1.0, 0.55))
						_fx_explosao((e as Node2D).position, false, false)
						hitstop(0.06)
						add_trauma(0.22)
				else:
					if te == "boss":
						pontos += 360
					_fx_tiro((e as Node2D).position)
				break

func _dano_no_player(qtd: float) -> void:
	if player.get("invencivel") > 0:
		return
	if boss != null and is_instance_valid(boss):
		dano_no_chefe = true
	if escudo > 0:
		escudo -= qtd
		player.set("invencivel", 1.2)
		player.call("escudo_atingido")
		add_trauma(0.5)
		if escudo <= 0:
			escudo = 0.0 # escudo some, volta +25 a cada 5 abates
		return
	# sem escudo: mais 1 tiro perde a vida e recarrega cheio
	vidas -= 1
	escudo = 100.0
	player.set("invencivel", 1.5)
	if vidas <= 0:
		game_over_timer = 0.0
		player.visible = false
		combo = 0
		_slowmo_morte()
		if sfx != null:
			sfx.call("stinger")
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
	misseis = misseis.filter(func(x): return is_instance_valid(x))

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
		b1.position = Vector2(120, center.y + 180)
		b1.size = Vector2(300, 52)
		b1.name = "Retry"
		b1.modulate.a = 0.0
		_botao_vivo(b1, Color(1, 0.35, 0.25), Color(1, 0.2, 0.12))
		b1.pressed.connect(_reiniciar)
		gameover_layer.add_child(b1)
		# botao sair para o menu (cinza igual imagem)
		var b2 := Button.new()
		b2.text = "SAIR PARA O MENU"
		b2.add_theme_font_size_override("font_size", 22)
		if f != null:
			b2.add_theme_font_override("font", f)
		b2.position = Vector2(120, center.y + 244)
		b2.size = Vector2(300, 48)
		b2.name = "MenuBtn"
		b2.modulate.a = 0.0
		_botao_vivo(b2, Color(0.7, 0.7, 0.72), Color(0.45, 0.45, 0.48))
		b2.pressed.connect(_ir_para_menu)
		gameover_layer.add_child(b2)
		b1.grab_focus()
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
	Engine.time_scale = 1.0
	trauma = 0.0
	hitstop_id += 1
	morto_id += 1
	if cam != null and is_instance_valid(cam):
		cam.offset = Vector2.ZERO
		cam.zoom = Vector2.ONE
		cam.position = Vector2(270, 480)
	dano_no_chefe = false
	_cartao_fase()
	if pause_layer != null:
		pause_layer.visible = false
	pontos = 0
	vidas = 1
	escudo = 100.0
	abates = 0
	chefe_sem_escudo = 0
	combo = 0
	combo_timer = 0.0
	dimensao = 1
	tempo_fase = 0.0
	em_transicao = false
	transicao_anim = 0.0
	transicao_trocou = false
	if transicao_layer != null:
		transicao_layer.queue_free()
		transicao_layer = null
	if portal_chegada != null and is_instance_valid(portal_chegada):
		portal_chegada.queue_free()
	portal_chegada = null
	if player != null and is_instance_valid(player):
		player.set("surgindo", false)
	if portal != null and is_instance_valid(portal):
		portal.queue_free()
	portal = null
	if portal_label != null:
		portal_label.visible = false
	if bg_no != null and is_instance_valid(bg_no):
		bg_no.call("trocar_dimensao", 1)
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
	for mm in misseis:
		if is_instance_valid(mm):
			mm.queue_free()
	misseis.clear()
	bonus2_timer = 25.0
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
	if portal != null and is_instance_valid(portal):
		portal.queue_free()
	portal = null
	if portal_label != null:
		portal_label.visible = false
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
	for mm in misseis:
		if is_instance_valid(mm):
			mm.queue_free()
	misseis.clear()
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
	# arte cheia de fundo (bg da fase 1) + véu escuro pra leitura
	for mp in ["res://assets/bg.png", "res://assets/bg.jpg", "res://assets/VENOM.png"]:
		if ResourceLoader.exists(mp):
			var mtex := load(mp) as Texture2D
			if mtex != null:
				var msp := Sprite2D.new()
				msp.texture = mtex
				var msc := maxf(540.0 / float(mtex.get_width()), 960.0 / float(mtex.get_height()))
				msp.scale = Vector2(msc, msc)
				msp.position = center
				msp.modulate = Color(0.55, 0.6, 0.58)
				menu_layer.add_child(msp)
				break
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	bj.position = Vector2(140, center.y + 40)
	bj.size = Vector2(260, 60)
	_botao_vivo(bj, Color(0.4, 1.0, 0.55), Color(0.3, 1.0, 0.5))
	bj.pressed.connect(_reiniciar)
	menu_layer.add_child(bj)
	bj.grab_focus()
	var h := Label.new()
	h.text = "WASD move  -  L atira / segura 3s super"
	h.add_theme_font_size_override("font_size", 16)
	if f != null:
		h.add_theme_font_override("font", f)
	h.add_theme_color_override("font_color", Color(0.6, 0.65, 0.62))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(0, center.y + 130)
	h.size = Vector2(540, 26)
	menu_layer.add_child(h)

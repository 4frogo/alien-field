extends CanvasLayer
# HUD igual imagem: PONTOS, VIDAS, FASE, ESCUDO, ARMA LASER

var lbl_pontos_val: Label
var lbl_fase: Label
var vidas_icons: Control
var bar_escudo: Control
var vidas_count := 3
var lbl_boss: Label
var bar_boss: Control
var retrato_boss: Sprite2D

var verde := Color(0.25, 1.0, 0.45)
var verde_escuro := Color(0.1, 0.6, 0.25)
var fonte_horror: Font = null

func _ready() -> void:
	if ResourceLoader.exists("res://assets/horror.ttf"):
		fonte_horror = load("res://assets/horror.ttf") as Font
	# PONTOS
	var lbl_pontos := Label.new()
	lbl_pontos.text = "PONTOS"
	lbl_pontos.position = Vector2(18, 12)
	lbl_pontos.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_pontos.add_theme_font_override("font", fonte_horror)
	lbl_pontos.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	add_child(lbl_pontos)

	lbl_pontos_val = Label.new()
	lbl_pontos_val.text = "000000"
	lbl_pontos_val.position = Vector2(18, 34)
	lbl_pontos_val.add_theme_font_size_override("font_size", 30)
	if fonte_horror != null:
		lbl_pontos_val.add_theme_font_override("font", fonte_horror)
	lbl_pontos_val.add_theme_color_override("font_color", verde)
	add_child(lbl_pontos_val)

	# VIDAS
	var lbl_vidas := Label.new()
	lbl_vidas.text = "VIDAS"
	lbl_vidas.position = Vector2(410, 12)
	lbl_vidas.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_vidas.add_theme_font_override("font", fonte_horror)
	lbl_vidas.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	add_child(lbl_vidas)

	vidas_icons = preload("res://scripts/vidas_icons.gd").new()
	vidas_icons.position = Vector2(400, 38)
	vidas_icons.size = Vector2(120, 32)
	add_child(vidas_icons)

	# FASE
	lbl_fase = Label.new()
	lbl_fase.text = "FASE 1-3"
	lbl_fase.position = Vector2(390, 72)
	lbl_fase.add_theme_font_size_override("font_size", 24)
	if fonte_horror != null:
		lbl_fase.add_theme_font_override("font", fonte_horror)
	lbl_fase.add_theme_color_override("font_color", Color(0.85, 0.9, 0.88))
	add_child(lbl_fase)

	# ESCUDO: icone + barra (sem texto). Fica na faixa de cima da rodape, pra
	# deixar espaco logo abaixo pro liquido do super tiro.
	var ico_esc = preload("res://scripts/hud_icon.gd").new()
	ico_esc.set("modo", "escudo")
	ico_esc.position = Vector2(14, 876)
	ico_esc.size = Vector2(28, 28)
	add_child(ico_esc)

	bar_escudo = preload("res://scripts/hud_bar.gd").new()
	bar_escudo.set("cor", verde)
	bar_escudo.set("cor_fundo", Color(0.04, 0.14, 0.07))
	bar_escudo.position = Vector2(46, 880)
	bar_escudo.size = Vector2(248, 22)
	bar_escudo.set("liquido", true)
	bar_escudo.set("valor", 1.0)
	bar_escudo.set("alvo", 1.0)
	add_child(bar_escudo)

	# ARMA: icone triplo (sem texto)
	var ico_arma = preload("res://scripts/hud_icon.gd").new()
	ico_arma.set("modo", "laser")
	ico_arma.position = Vector2(440, 876)
	ico_arma.size = Vector2(28, 28)
	add_child(ico_arma)

	# barra de vida do chefao (topo centro, escondida)
	lbl_boss = Label.new()
	lbl_boss.text = "DRAGAO DO VAZIO"
	lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_boss.position = Vector2(0, 108)
	lbl_boss.size = Vector2(540, 28)
	lbl_boss.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_boss.add_theme_font_override("font", fonte_horror)
	lbl_boss.add_theme_color_override("font_color", Color(1, 0.25, 0.15))
	lbl_boss.visible = false
	lbl_boss.name = "BossNome"
	add_child(lbl_boss)

	bar_boss = preload("res://scripts/hud_bar.gd").new()
	bar_boss.set("cor", Color(0.95, 0.16, 0.10))
	bar_boss.set("cor_fundo", Color(0.14, 0.02, 0.02))
	bar_boss.set("mostrar_segmentos", true)
	bar_boss.set("segmentos", 12)
	bar_boss.position = Vector2(120, 136)
	bar_boss.size = Vector2(300, 14)
	bar_boss.set("valor", 1.0)
	bar_boss.set("alvo", 1.0)
	bar_boss.visible = false
	bar_boss.name = "bar_boss"
	add_child(bar_boss)

	# retrato do chefão (recorte do rosto, escondido junto)
	retrato_boss = Sprite2D.new()
	for bp in ["res://assets/boss001_clean.png", "res://assets/boss1_clean.png"]:
		if ResourceLoader.exists(bp):
			var btex := load(bp) as Texture2D
			if btex != null:
				var bw := float(btex.get_width())
				var bh := float(btex.get_height())
				var batlas := AtlasTexture.new()
				batlas.atlas = btex
				batlas.region = Rect2(bw * 0.30, bh * 0.24, bw * 0.40, bh * 0.22)
				retrato_boss.texture = batlas
				var bsc := 64.0 / (bw * 0.40)
				retrato_boss.scale = Vector2(bsc, bsc)
				break
	retrato_boss.position = Vector2(82, 143)
	retrato_boss.visible = false
	add_child(retrato_boss)

func atualizar(pontos: int, vidas: int, escudo: float) -> void:
	lbl_pontos_val.text = "%06d" % pontos
	vidas_count = vidas
	vidas_icons.queue_redraw()
	bar_escudo.call("definir", escudo, 100.0)

func boss_vida(hp: int, hp_max: int) -> void:
	lbl_boss.visible = true
	bar_boss.visible = true
	retrato_boss.visible = true
	bar_boss.call("definir", maxf(0.0, float(hp)), float(hp_max))

func boss_fora() -> void:
	lbl_boss.visible = false
	bar_boss.visible = false
	retrato_boss.visible = false

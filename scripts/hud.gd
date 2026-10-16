extends CanvasLayer
# HUD: no rodape, escudo + super a esquerda e PONTOS a direita. Os cantos
# SUPERIORES ficam vazios de proposito (nada de "VIDAS", "FASE" nem icones
# de vida), para nao competir com o cenario.

var lbl_pontos_val: Label
var bar_escudo: Control
# ultimo valor de vidas recebido. Os icones do canto da tela sairam, mas
# o main.gd continua mandando esse numero e o game over depende dele.
var _vidas_atual := 3
var lbl_boss: Label
var bar_boss: Control
var retrato_boss: Sprite2D

var verde := Color(0.25, 1.0, 0.45)
var verde_escuro := Color(0.1, 0.6, 0.25)
var fonte_horror: Font = null

func _ready() -> void:
	if ResourceLoader.exists("res://assets/horror.ttf"):
		fonte_horror = load("res://assets/horror.ttf") as Font
	# ---------------------------------------------------------------
	# PONTOS — canto INFERIOR DIREITO, num painel arredondado.
	# Antes ficava no canto superior esquerdo com a horror.ttf (que tem
	# pingos de tinta) e nao combinava com o resto. Agora: painel escuro
	# com cantos redondos, filete verde na esquerda, rotulo pequeno com
	# espacamento entre letras e o numero grande alinhado a direita.
	# ---------------------------------------------------------------
	var painel := Panel.new()
	painel.position = Vector2(348, 890)
	painel.size = Vector2(176, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.04, 0.62)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 1.0, 0.45, 0.22)
	# filete de cor a esquerda: da o acento de "painel ativo"
	sb.border_width_left = 3
	sb.border_color = Color(0.25, 1.0, 0.45, 0.75)
	painel.add_theme_stylebox_override("panel", sb)
	add_child(painel)

	var lbl_pontos := Label.new()
	lbl_pontos.text = "P O N T O S"
	lbl_pontos.position = Vector2(362, 897)
	lbl_pontos.size = Vector2(150, 16)
	lbl_pontos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_pontos.add_theme_font_size_override("font_size", 11)
	lbl_pontos.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55, 0.85))
	add_child(lbl_pontos)

	lbl_pontos_val = Label.new()
	lbl_pontos_val.text = "000000"
	lbl_pontos_val.position = Vector2(352, 913)
	lbl_pontos_val.size = Vector2(160, 30)
	lbl_pontos_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_pontos_val.add_theme_font_size_override("font_size", 28)
	lbl_pontos_val.add_theme_color_override("font_color", verde)
	# SEM a horror.ttf aqui de proposito: a fonte de pingos e o que
	# deixava o HUD com cara de coisa antiga.
	add_child(lbl_pontos_val)

	# CANTO SUPERIOR DIREITO VAZIO DE PROPOSITO.
	# Antes ficava aqui a palavra "VIDAS" e embaixo dela as 3 mini-naves
	# de vida. Os dois foram removidos: o jogador pediu a area limpa, e
	# o canto competia com o portal, que e a cena mais importante da
	# fase. A quantidade de vidas agora so aparece quando acaba.
	# (o script vidas_icons.gd continua no projeto, so nao e instanciado)

	# PAINEL DO RODAPE ESQUERDO: mesmo visual do painel de PONTOS, para os
	# dois blocos de status lerem como um sistema so.
	var painel_esc := Panel.new()
	painel_esc.position = Vector2(8, 886)
	painel_esc.size = Vector2(204, 60)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.02, 0.06, 0.04, 0.62)
	sb2.set_corner_radius_all(10)
	sb2.set_border_width_all(1)
	sb2.border_color = Color(0.25, 1.0, 0.45, 0.22)
	sb2.border_width_left = 3
	sb2.border_color = Color(0.25, 1.0, 0.45, 0.75)
	painel_esc.add_theme_stylebox_override("panel", sb2)
	add_child(painel_esc)

	# ESCUDO: icone + barra (sem texto). Fica na faixa de cima da rodape, pra
	# deixar espaco logo abaixo pro liquido do super tiro.
	var ico_esc = preload("res://scripts/hud_icon.gd").new()
	ico_esc.set("modo", "escudo")
	ico_esc.position = Vector2(18, 894)
	ico_esc.size = Vector2(24, 24)
	add_child(ico_esc)

	bar_escudo = preload("res://scripts/hud_bar.gd").new()
	bar_escudo.set("cor", verde)
	bar_escudo.set("cor_fundo", Color(0.04, 0.14, 0.07))
	bar_escudo.position = Vector2(46, 898)
	bar_escudo.size = Vector2(160, 16)
	bar_escudo.set("liquido", true)
	bar_escudo.set("valor", 1.0)
	bar_escudo.set("alvo", 1.0)
	add_child(bar_escudo)

	# SEM O ICONE DO LASER no rodape direito. Era aquele trio de setas
	# verdes; removido a pedido do jogador. O estado do super tiro continua
	# visivel pela barra liquida logo abaixo (super_bar.gd), que e o que
	# importa na hora de disparar.
	# (o modo "laser" do hud_icon.gd continua no script, so nao e usado)

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
	# `vidas` chegou a ser usado so pelos icones de vida, que foram
	# removidos do canto da tela. O parametro continua na assinatura
	# porque o main.gd chama assim; dar valor a ele evita o aviso de
	# parametro sem uso.
	_vidas_atual = vidas
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

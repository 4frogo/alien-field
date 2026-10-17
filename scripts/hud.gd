extends CanvasLayer
# HUD: so o rodape esquerdo (escudo + super tiro) dentro de um painel de
# vidro. O contador de PONTOS foi removido, os icones de vida sairam antes
# e os cantos SUPERIORES ficam vazios de proposito — a nao compete com o
# cenario.

var bar_escudo: Control
# ultimo valor de vidas recebido. Os icones do canto da tela sairam, mas
# o main.gd continua mandando esse numero e o game over depende dele.
var _vidas_atual := 3
# idem para os pontos: o contador saiu da tela, mas a pontuacao continua
# sendo calculada e mostrada no fim da fase.
var _pontos_atual := 0
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
	# CONTADOR DE PONTOS REMOVIDO a pedido do jogador. O painel da direita
	# (348,884) e o label do numero sairam juntos. A pontuacao continua
	# sendo calculada e salva no fim da fase — so nao e mais mostrado.
	# Para voltar, basta recriar o painel + labels aqui.
	# ---------------------------------------------------------------
	# Antes ficava aqui a palavra "VIDAS" e embaixo dela as 3 mini-naves
	# de vida. Os dois foram removidos: o jogador pediu a area limpa, e
	# o canto competia com o portal, que e a cena mais importante da
	# fase. A quantidade de vidas agora so aparece quando acaba.
	# (o script vidas_icons.gd continua no projeto, so nao e instanciado)

	# PAINEL DO RODAPE ESQUERDO: mesmo visual do painel de PONTOS, para os
	# dois blocos de status lerem como um sistema so.
	var painel_esc = preload("res://scripts/hud_painel.gd").new()
	painel_esc.position = Vector2(16, 884)
	painel_esc.size = Vector2(208, 64)
	add_child(painel_esc)
	painel_esc.call("configurar", verde, Color(0.015, 0.045, 0.030, 0.70))

	# SEM O ICONE DE ESCUDO: era aquele hexagono verde a esquerda da barra.
	# O jogador pediu pra remover — a barra liquida sozinha ja comunica o
	# estado do escudo. (o script hud_icon.gd continua no projeto, sem uso)

	bar_escudo = preload("res://scripts/hud_bar.gd").new()
	bar_escudo.set("cor", verde)
	bar_escudo.set("cor_fundo", Color(0.04, 0.14, 0.07))
	# sem moderno: agora a barra de escudo usa o modo LIQUIDO igual ao
	# super tiro (escudo = plasma/líquido), como o jogador pediu. 'moderne'
	# daria uma barra lisa sem a animacao do liquido.
	bar_escudo.set("moderno", false)
	bar_escudo.set("liquido", true)
	bar_escudo.set("trilho", true)
	# GRADE DO RODAPE: painel em (16,884) 208x64. As duas barras ocupam
	# x=28..204 (176px) e ficam centradas verticalmente com 8px de gap.
	bar_escudo.position = Vector2(28, 898)
	bar_escudo.size = Vector2(176, 16)
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
	lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_boss.position = Vector2(8, 8)
	lbl_boss.size = Vector2(220, 20)
	lbl_boss.add_theme_font_size_override("font_size", 14)
	if fonte_horror != null:
		lbl_boss.add_theme_font_override("font", fonte_horror)
	lbl_boss.add_theme_color_override("font_color", Color(1, 0.25, 0.15))
	lbl_boss.visible = false
	lbl_boss.name = "BossNome"
	add_child(lbl_boss)

	bar_boss = preload("res://scripts/hud_bar.gd").new()
	bar_boss.set("cor", Color(1.0, 0.30, 0.12))
	bar_boss.set("cor_fundo", Color(0.18, 0.04, 0.02))
	bar_boss.set("liquido", true)
	bar_boss.set("mostrar_segmentos", false)
	bar_boss.size = Vector2(150, 12)
	bar_boss.position = Vector2(8, 32)
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
	retrato_boss.position = Vector2(24, 14)
	retrato_boss.visible = false
	add_child(retrato_boss)

func atualizar(pontos: int, vidas: int, escudo: float) -> void:
	# `pontos` e `vidas` nao sao mais exibidos (contador removido e icones
	# de vida sairam antes). Os parametros continuam na assinatura porque
	# o main.gd chama assim; dar valor a eles evita o aviso de parametro
	# sem uso.
	_pontos_atual = pontos
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

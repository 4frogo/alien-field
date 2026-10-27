extends CanvasLayer
# HUD: so o rodape esquerdo (escudo + super tiro) dentro de um painel de
# vidro. O contador de PONTOS foi removido, os icones de vida sairam antes
# e os cantos SUPERIORES ficam vazios de proposito — a nao compete com o
# cenario.

var icone_escudo: Control
# ultimo valor de vidas recebido. Os icones do canto da tela sairam, mas
# o main.gd continua mandando esse numero e o game over depende dele.
var _vidas_atual := 3
# idem para os pontos: o contador saiu da tela, mas a pontuacao continua
# sendo calculada e mostrada no fim da fase.
var _pontos_atual := 0
var bar_boss: Control

# PULSO DE DANO na barra da vida do chefe: quando ele apanha, a barra
# pisca branca por um instante (feedback de hit no HUD).
var _boss_last := 1.0
var _pulse := 0.0

var verde := Color(0.25, 1.0, 0.45)
var verde_escuro := Color(0.1, 0.6, 0.25)
var fonte_horror: Font = null

func _ready() -> void:
	if ResourceLoader.exists("res://assets/horror.ttf"):
		fonte_horror = load("res://assets/horror.ttf") as Font
	# Com stretch "expand" o viewport alarga em telas largas, mas o mundo
	# continua centralizado nos 540 px do design. O HUD se ancora na borda
	# do viewport, entao sem isso os icones iam parar fora da area de jogo.
	get_viewport().size_changed.connect(_alinhar_com_o_jogo)
	_alinhar_com_o_jogo()
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

	# PAINEL DO RODAPE ESQUERDO REMOVIDO: com a barra de escudo virando o
	# icone da direita e a do super virando o icone SUPER da esquerda, o
	# painel de vidro ficou vazio. (o script hud_painel.gd continua no
	# projeto, sem uso)

	# NOVO ICONE DE ESCUDO: escudoG.png no canto INFERIOR DIREITO, com
	# liquido de plasma verde se movendo dentro (hud_escudo_icone.gd +
	# escudo_icone.gdshader). Substituiu a barra liquida do rodape esquerdo
	# e o texto de carga (as 3 frases SUPER/PERIGO/SOLTE!, que sairam do
	# canto direito junto com a barra do escudo).
	# (o script hud_bar.gd continua no projeto, usado pelo chefao e pelo super)
	icone_escudo = preload("res://scripts/hud_escudo_icone.gd").new()
	icone_escudo.position = Vector2(360, 784)
	icone_escudo.size = Vector2(164, 164)
	add_child(icone_escudo)

	# SEM O ICONE DO LASER no rodape direito. Era aquele trio de setas
	# verdes; removido a pedido do jogador. O estado do super tiro continua
	# visivel pela barra liquida logo abaixo (super_bar.gd), que e o que
	# importa na hora de disparar.
	# (o modo "laser" do hud_icon.gd continua no script, so nao e usado)

	# barra de vida do chefe: a barra VERMELHA de sempre (hud_bar.gd com
	# liquido + plasma), maior e centralizada no topo central. O nome
	# (DRAGAO DO VAZIO) e o retrato pequeno sairam a pedido do jogador.
	# DUAS ETAPAS: a barra e vermelha na primeira metade da vida e vira
	# AMARELA na segunda (o fluido vai descendo ate zerar).
	bar_boss = preload("res://scripts/hud_bar.gd").new()
	bar_boss.set("cor", Color(1.0, 0.26, 0.10))
	bar_boss.set("cor_fundo", Color(0.16, 0.03, 0.02))
	bar_boss.set("liquido", true)
	bar_boss.set("mostrar_segmentos", false)
	bar_boss.size = Vector2(300, 16)
	bar_boss.position = Vector2(120, 10)
	bar_boss.set("valor", 1.0)
	bar_boss.set("alvo", 1.0)
	bar_boss.visible = false
	bar_boss.name = "bar_boss"
	# pivot no centro: a barra cresce/encolhe do meio quando sofre hit
	bar_boss.pivot_offset = Vector2(150.0, 8.0)
	add_child(bar_boss)

func atualizar(pontos: int, vidas: int, escudo: float) -> void:
	# `pontos` e `vidas` nao sao mais exibidos (contador removido e icones
	# de vida sairam antes). Os parametros continuam na assinatura porque
	# o main.gd chama assim; dar valor a eles evita o aviso de parametro
	# sem uso.
	_pontos_atual = pontos
	_vidas_atual = vidas
	icone_escudo.call("definir", escudo, 100.0)

func boss_vida(hp: int, hp_max: int) -> void:
	bar_boss.visible = true
	var mx := maxf(1.0, float(hp_max))
	var v := clampf(float(hp) / mx, 0.0, 1.0)
	# perdeu vida desde o ultimo valor = HIT na cara do chefe: liga o pulso
	if v < _boss_last - 0.004:
		_pulse = 1.0
	_boss_last = v
	# etapa 1 (vermelha) ate a metade da vida; etapa 2 (amarela) depois
	var cor := Color(1.0, 0.26, 0.10) if v > 0.5 else Color(1.0, 0.80, 0.18)
	bar_boss.set("cor", cor)
	# o plasma do shader tem cor propria: tem que acompanhar a da barra
	var pm := bar_boss.get("material") as ShaderMaterial
	if pm != null:
		pm.set_shader_parameter("cor_plasma", cor)
		pm.set_shader_parameter("cor_quente", cor.lerp(Color(1, 1, 1), 0.45))
	bar_boss.call("definir", v, 1.0)

func boss_fora() -> void:
	bar_boss.visible = false
	# reset: proximo chefe comeca sem pulso e com valor "cheio" na memoria
	_pulse = 0.0
	_boss_last = 1.0

func _process(delta: float) -> void:
	# pulso de dano: barra pisca branca e volta a cor normal em ~0.25s
	if not bar_boss.visible or _pulse <= 0.0:
		if _pulse <= 0.0 and bar_boss.modulate != Color(1, 1, 1, 1):
			bar_boss.modulate = Color(1, 1, 1, 1)
		return
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	var k := _pulse
	# clareia pro branco conforme apagar (modulate acima de 1 clareia o shader)
	bar_boss.modulate = Color(1.0 + 2.2 * k, 1.0 + 1.2 * k, 1.0 + 1.2 * k, 1.0)

func _alinhar_com_o_jogo() -> void:
	# Desloca o HUD pra ele ficar em cima da coluna de 540 px do jogo,
	# em vez de colado na borda esquerda da janela.
	var w: float = get_viewport().get_visible_rect().size.x
	offset = Vector2(round((w - 540.0) * 0.5), 0.0)

extends Control
# Tela ESCOLHER NAVE: arte da tela ao fundo, a nave selecionada no centro
# e os NOMES das naves lado a lado embaixo como BOTOES de escolha direta
# (tocar em POISON = verde, VIOLET = roxa).
# As setas laterais foram removidas: agora so se troca de nave clicando
# no nome (ou com <- -> do teclado). Enter (ou toque na nave) comeca o jogo.

const CENA_JOGO := "res://scenes/Main.tscn"
const BG := "res://assets/imagem do menu.png"
const CENTRO := Vector2(270.0, 470.0)   # centro da nave
const PAINEL := Vector2(430.0, 390.0)   # area de clique pra comecar (invisivel)
const Y_ICONE := 720.0                  # banner do nome, abaixo da nave
const LARG_ICONE := 240.0                # largura de cada nome (lado a lado)
const NOME_APAGADO := 0.42                # alfa do nome da nave NAO selecionada
# tela de transicao antes da partida: arte da nave escolhida em tela cheia
# com zoom lento (1.0 -> 1.28) e fade rapido no comeco
const ZOOM_FINAL := 1.28
const ZOOM_TEMPO := 1.6
const FADE_TEMPO := 0.18
const SEGURA_TEMPO := 0.15

var _nave: Sprite2D = null
var _icones: Array[TextureRect] = []
var _saindo := false


func _ready() -> void:
	# fundo: arte nova (imagem do menu.png, 1024x1536 ~ 2:3). A tela e
	# 540x960 (9:16), entao STRETCH_SCALE amassaria a arte; com
	# KEEP_ASPECT_COVERED ela preenche a tela sem distorcer (corta so um
	# pouquinho das laterais).
	if ResourceLoader.exists(BG):
		var bg := TextureRect.new()
		bg.texture = load(BG) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	# nave selecionada (sem painel: a arte do fundo ja da contexto e o
	# quadrado escuro atrapalhava — PAINEL so define a area de clique)
	_nave = Sprite2D.new()
	_nave.position = CENTRO
	add_child(_nave)

	# nomes das naves lado a lado embaixo: sao BOTOES de escolha direta
	# (clique/toque no nome = seleciona aquela nave)
	var n := Escolha.total()
	var larg := LARG_ICONE
	var gap := 16.0
	var x0 := (540.0 - (larg * n + gap * (n - 1))) * 0.5
	for i in n:
		var ic := TextureRect.new()
		ic.texture = Escolha.icone(i)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		# IGNORE: o clique no nome NAO e engolido pelo GUI — cai no
		# _unhandled_input e a zona do nome vira "escolher esta nave"
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ic.texture != null and ic.texture.get_width() > 0:
			var ih := larg * float(ic.texture.get_height()) / float(ic.texture.get_width())
			ic.size = Vector2(larg, ih)
			ic.pivot_offset = ic.size * 0.5
			ic.position = Vector2(x0 + float(i) * (larg + gap), Y_ICONE - ih * 0.5)
		_icones.append(ic)
		add_child(ic)

	_atualizar_nave(false)


func _unhandled_input(event: InputEvent) -> void:
	if _saindo:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_comecar()
		elif event.keycode == KEY_LEFT:
			_trocar(-1)
		elif event.keycode == KEY_RIGHT:
			_trocar(1)
		return
	# clique/toque: o NOME da nave e botao de escolha direta (POISON =
	# verde, VIOLET = roxa) e o painel da nave comeca o jogo.
	# So MOUSE: no celular o toque ja chega EMULADO como mouse (mesmo
	# canal do botao da intro, que la funciona) — tratar ScreenTouch
	# junto trocava DUAS vezes por toque.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		if _icone_em(p) >= 0:
			# clique no NOME: escolha direta daquela nave (botao)
			var alvo := _icone_em(p)
			if alvo != Escolha.indice:
				Escolha.escolher(alvo)
				_atualizar_nave(true)
		elif Rect2(CENTRO - PAINEL * 0.5, PAINEL).has_point(p):
			_comecar()


func _icone_em(p: Vector2) -> int:
	for i in _icones.size():
		var ic := _icones[i]
		if ic.texture != null and Rect2(ic.position, ic.size).has_point(p):
			return i
	return -1


func _trocar(passo: int) -> void:
	if _saindo:
		return   # partida ja comecando: sinal de botao nao pode mais trocar
	Escolha.trocar(passo)
	_atualizar_nave(true)


func _atualizar_nave(animar: bool) -> void:
	_nave.texture = Escolha.textura()
	if _nave.texture == null:
		return
	var w := float(_nave.texture.get_width())
	var h := float(_nave.texture.get_height())
	var esc_v := Vector2(minf(340.0 / w, 300.0 / h), minf(340.0 / w, 300.0 / h))
	_nave.scale = esc_v
	if animar:
		# pop de troca: chega um pouco menor e "encaixa" no lugar
		_nave.scale = esc_v * 0.86
		var tw := create_tween()
		tw.tween_property(_nave, "scale", esc_v, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# nomes: o selecionado em cheio (com pop), os outros apagados
	for i in _icones.size():
		var ic := _icones[i]
		if ic.texture == null:
			continue
		var sel := i == Escolha.indice
		ic.modulate = Color(1, 1, 1, 1.0) if sel else Color(1, 1, 1, NOME_APAGADO)
		if sel and animar:
			ic.scale = Vector2(0.86, 0.86)
			var tw2 := create_tween()
			tw2.tween_property(ic, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _comecar() -> void:
	if _saindo:
		return
	_saindo = true
	# tela de transicao: arte da nave escolhida em tela cheia com zoom
	await _transicao()
	# a musica da intro veio da raiz junto com a gente: fade e some
	# antes de a musica da partida assumir (sem sobrepor)
	var mi := get_tree().root.get_node_or_null("MusicaIntro") as AudioStreamPlayer
	if mi != null and mi.playing:
		var tw := create_tween()
		tw.tween_property(mi, "volume_db", -50.0, 0.45)
		await tw.finished
		mi.stop()
		mi.queue_free()
	get_tree().change_scene_to_file(CENA_JOGO)


func _transicao() -> void:
	# arte em tela cheia com zoom lento; se o arquivo nao existir, pula
	var caminho := Escolha.arte()
	if caminho == "" or not ResourceLoader.exists(caminho):
		return
	var tex := load(caminho) as Texture2D
	if tex == null:
		return

	var camada := CanvasLayer.new()
	camada.layer = 200
	add_child(camada)

	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# zoom a partir do centro da tela
	img.pivot_offset = Vector2(270.0, 480.0)
	img.scale = Vector2.ONE
	img.modulate.a = 0.0
	camada.add_child(img)

	# aparece rapido e ja comeca a aproximar
	var tw := create_tween()
	tw.tween_property(img, "modulate:a", 1.0, FADE_TEMPO)
	var tz := create_tween()
	tz.tween_property(img, "scale", Vector2(ZOOM_FINAL, ZOOM_FINAL), ZOOM_TEMPO)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tz.finished
	await get_tree().create_timer(SEGURA_TEMPO).timeout

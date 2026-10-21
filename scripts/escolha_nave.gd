extends Control
# Tela ESCOLHER NAVE: arte da tela ao fundo, a nave selecionada no centro,
# setas LATERAIS pulsando e os NOMES das naves lado a lado embaixo como
# BOTOES de escolha direta (tocar em POISON = verde, VIOLET = roxa).
# Troca por seta/clique/toque na seta, clique no nome ou <- -> do teclado.
# Enter (ou toque na nave) comeca o jogo.

const CENA_JOGO := "res://scenes/Main.tscn"
const BG := "res://assets/tela escolha nave.png"
const SETAS := "res://assets/botões esquerdo direito.png"
const CENTRO := Vector2(270.0, 470.0)   # centro da nave
const PAINEL := Vector2(430.0, 390.0)   # area de clique pra comecar (invisivel)
const Y_SETAS := 310.0                  # setas no alto, na linha do bico da nave
const Y_ICONE := 720.0                  # banner do nome, abaixo da nave
const TAM_SETA := 148.0
const LARG_ICONE := 240.0                # largura de cada nome (lado a lado)
const ZONA_SETA := 180.0                  # zona de toque generosa em volta da seta
const NOME_APAGADO := 0.42                # alfa do nome da nave NAO selecionada
const PULSO_VEL := 4.0                  # mesma respiracao do botao da intro
const PULSO_ESCALA := 0.045
const PULSO_ALFA_MIN := 0.8

var _nave: Sprite2D = null
var _icones: Array[TextureRect] = []
var _setas: Array[TextureButton] = []
var _t_pulso := 0.0
var _saindo := false


func _ready() -> void:
	# fundo: arte 941x1672 (~9:16), encaixa certinho nos 540x960
	if ResourceLoader.exists(BG):
		var bg := TextureRect.new()
		bg.texture = load(BG) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
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

	# setas laterais: metades do par (1774x887) com fundo transparente
	if ResourceLoader.exists(SETAS):
		var atlas_src := load(SETAS) as Texture2D
		if atlas_src != null:
			var metade := atlas_src.get_width() / 2
			var altura := atlas_src.get_height()
			_criar_seta(atlas_src, Rect2(0, 0, metade, altura), Vector2(82.0, Y_SETAS), -1)
			_criar_seta(atlas_src, Rect2(metade, 0, metade, altura), Vector2(458.0, Y_SETAS), 1)


func _process(delta: float) -> void:
	# respiracao das setas (escala + alfa em fase, igual ao botao da intro)
	_t_pulso += delta
	var s := sin(_t_pulso * PULSO_VEL)
	var k := 1.0 + s * PULSO_ESCALA
	var a := PULSO_ALFA_MIN + (s * 0.5 + 0.5) * (1.0 - PULSO_ALFA_MIN)
	for b in _setas:
		b.scale = Vector2(k, k)
		b.modulate.a = a


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
	# clique/toque nas ZONAS da tela: seta esquerda e direita trocam a
	# nave, o NOME da nave e botao de escolha direta (POISON = verde,
	# VIOLET = roxa) e o painel da nave comeca o jogo.
	# So MOUSE: no celular o toque ja chega EMULADO como mouse (mesmo
	# canal do botao da intro, que la funciona) — tratar ScreenTouch
	# junto trocava DUAS vezes por toque.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		if _na_zona(Vector2(82.0, Y_SETAS), p):
			_trocar(-1)
		elif _na_zona(Vector2(458.0, Y_SETAS), p):
			_trocar(1)
		elif _icone_em(p) >= 0:
			# clique no NOME: escolha direta daquela nave (botao)
			var alvo := _icone_em(p)
			if alvo != Escolha.indice:
				Escolha.escolher(alvo)
				_atualizar_nave(true)
		elif Rect2(CENTRO - PAINEL * 0.5, PAINEL).has_point(p):
			_comecar()


func _criar_seta(src: Texture2D, reg: Rect2, centro: Vector2, dir: int) -> void:
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = reg
	var b := TextureButton.new()
	b.texture_normal = at
	b.ignore_texture_size = true
	# FOCUS_NONE: sem isso o ENTER do teclado "aperta" a seta que estiver
	# com foco (as setas <- -> do teclado andam o foco entre botoes) e o
	# trocava a nave ENQUANTO o jogo ja estava comecando — a escolhida
	# virava outra na hora de entrar na partida
	b.focus_mode = Control.FOCUS_NONE
	# sem isso o padrao STRETCH_KEEP desenha a textura no tamanho ORIGINAL
	# (887px) saindo do botao — as setas viravam gigantes cortadas no rodape
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.size = Vector2(TAM_SETA, TAM_SETA)
	b.pivot_offset = b.size * 0.5
	b.position = centro - b.size * 0.5
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_trocar.bind(dir))
	_setas.append(b)
	add_child(b)


func _na_zona(centro_seta: Vector2, p: Vector2) -> bool:
	return Rect2(centro_seta - Vector2(ZONA_SETA, ZONA_SETA) * 0.5,
			Vector2(ZONA_SETA, ZONA_SETA)).has_point(p)


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
	Escolha.dbg("menu sai -> indice=%d" % Escolha.indice)
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

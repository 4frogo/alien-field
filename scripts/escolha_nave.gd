extends Control
# Tela ESCOLHER NAVE: arte da tela ao fundo, a nave selecionada num painel
# escuro no centro e as setas LATERAIS pulsando. Troca por clique/toque nas
# setas ou pelas setas <- -> do teclado. Enter (ou toque na nave/painel)
# comeca o jogo.

const CENA_JOGO := "res://scenes/Main.tscn"
const BG := "res://assets/tela escolha nave.png"
const SETAS := "res://assets/botões esquerdo direito.png"
const CENTRO := Vector2(270.0, 470.0)   # centro da nave
const PAINEL := Vector2(430.0, 390.0)   # area de clique pra comecar (invisivel)
const Y_SETAS := 310.0                  # setas no alto, na linha do bico da nave
const Y_ICONE := 720.0                  # banner do nome, abaixo da nave
const TAM_SETA := 148.0
const LARG_ICONE := 320.0
const PULSO_VEL := 4.0                  # mesma respiracao do botao da intro
const PULSO_ESCALA := 0.045
const PULSO_ALFA_MIN := 0.8

var _nave: Sprite2D = null
var _icone: TextureRect = null
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

	# banner com o nome da nave, abaixo dela (troca junto com a nave)
	_icone = TextureRect.new()
	_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone.stretch_mode = TextureRect.STRETCH_SCALE
	# STOP: o clique no banner nao atravessa pro "comecar o jogo"
	_icone.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_icone)

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
	# clique/toque fora das setas (na nave/painel) comeca o jogo —
	# o clique NAS setas nao chega aqui, a propria seta consome
	if event is InputEventMouseButton and event.pressed:
		var p: Vector2 = (event as InputEventMouseButton).position
		if Rect2(CENTRO - PAINEL * 0.5, PAINEL).has_point(p):
			_comecar()
	elif event is InputEventScreenTouch and event.pressed:
		var pt: Vector2 = (event as InputEventScreenTouch).position
		if Rect2(CENTRO - PAINEL * 0.5, PAINEL).has_point(pt):
			_comecar()


func _criar_seta(src: Texture2D, reg: Rect2, centro: Vector2, dir: int) -> void:
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = reg
	var b := TextureButton.new()
	b.texture_normal = at
	b.ignore_texture_size = true
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


func _trocar(passo: int) -> void:
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
	# banner do nome: troca junto, com o mesmo pop
	_icone.texture = Escolha.icone()
	if _icone.texture != null and _icone.texture.get_width() > 0:
		var iw := LARG_ICONE
		var ih := iw * float(_icone.texture.get_height()) / float(_icone.texture.get_width())
		_icone.size = Vector2(iw, ih)
		_icone.pivot_offset = Vector2(iw, ih) * 0.5
		_icone.position = Vector2(270.0 - iw * 0.5, Y_ICONE - ih * 0.5)
		if animar:
			_icone.scale = Vector2(0.86, 0.86)
			var tw2 := create_tween()
			tw2.tween_property(_icone, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _comecar() -> void:
	if _saindo:
		return
	_saindo = true
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

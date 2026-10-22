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
# Tela de TRANSICAO antes da partida: arte da nave escolhida em tela cheia
# com flash branco, glitch de RGB/scanlines, vinheta, barras de cinema e
# zoom lento. Tudo com som de varredura.
const SHADER := "res://assets/transicao.gdshader"
const ZOOM_FINAL := 1.24
const ZOOM_TEMPO := 1.25
const FLASH_TEMPO := 0.30          # brilho branco apaga
const GLITCH_TEMPO := 1.15         # o glitch decai pra zero
const BARRA_H := 118.0             # altura da barra de cinema (12% de 960)
const BARRA_TEMPO := 0.20
const NOME_LARG := 330.0           # arte do nome da nave, embaixo
const NOME_Y := 742.0
const SAIDA_TEMPO := 0.28          # arte some no final
# som da turbina: entra junto com a imagem de transicao e continua
# rodando na partida (fica na raiz, como a musica da intro)
const SOM_MOTOR := "res://assets/NAVE SAINDO effect.mp3"
const VOL_MOTOR := -10.0
const VOL_MUSICA_NA_TRANSIÇÃO := -26.0

var _nave: Sprite2D = null
var _icones: Array[TextureRect] = []
var _saindo := false
var _ui: AudioStreamPlayer = null
var _motor: AudioStreamPlayer = null


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

	# som de navegacao entre as naves: click curto e discreto
	# (Interface SFX Pack 1, ObsydianX - CC0)
	_ui = AudioStreamPlayer.new()
	_ui.stream = load("res://assets/click nave.ogg") as AudioStream
	_ui.volume_db = -10.0
	add_child(_ui)

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
				_tocar_click()
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
	_tocar_click()
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
	# arte em tela cheia com flash, glitch, vinheta, barras de cinema e
	# zoom; se o arquivo nao existir, pula direto pro jogo
	var caminho := Escolha.arte()
	if caminho == "" or not ResourceLoader.exists(caminho):
		return
	var tex := load(caminho) as Texture2D
	if tex == null:
		return

	var camada := CanvasLayer.new()
	camada.layer = 200
	add_child(camada)

	# ---------- arte com shader de glitch ----------
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.pivot_offset = Vector2(270.0, 480.0)
	img.scale = Vector2.ONE
	var mat: ShaderMaterial = null
	if ResourceLoader.exists(SHADER):
		var sh := load(SHADER) as Shader
		if sh != null:
			mat = ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("glitch", 1.0)
			mat.set_shader_parameter("sep", 0.022)
			mat.set_shader_parameter("scan", 0.8)
			mat.set_shader_parameter("vinheta", 0.45)
			mat.set_shader_parameter("fade", 1.0)
			img.material = mat
	camada.add_child(img)

	# ---------- nome da nave (arte), embaixo ----------
	var nome := TextureRect.new()
	var tex_nome := Escolha.icone()
	nome.texture = tex_nome
	nome.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nome.stretch_mode = TextureRect.STRETCH_SCALE
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex_nome != null and tex_nome.get_width() > 0:
		var nh := NOME_LARG * float(tex_nome.get_height()) / float(tex_nome.get_width())
		nome.size = Vector2(NOME_LARG, nh)
		nome.pivot_offset = nome.size * 0.5
		nome.position = Vector2(270.0 - NOME_LARG * 0.5, NOME_Y - nh * 0.5)
	nome.modulate.a = 0.0
	nome.scale = Vector2(0.8, 0.8)
	camada.add_child(nome)

	# ---------- barras de cinema ----------
	var topo := ColorRect.new()
	topo.color = Color(0, 0, 0, 1)
	topo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	topo.size = Vector2(540.0, BARRA_H)
	topo.position = Vector2(0.0, -BARRA_H)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(topo)
	var baixo := ColorRect.new()
	baixo.color = Color(0, 0, 0, 1)
	baixo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	baixo.size = Vector2(540.0, BARRA_H)
	baixo.position = Vector2(0.0, 960.0)
	baixo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(baixo)

	# ---------- flash branco (por cima de tudo) ----------
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.92)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(flash)

	# o motor da nave liga junto com a imagem de transicao
	_tocar_motor()

	# a musica da intro abaixa pra dar espaco pro motor
	var mi := get_tree().root.get_node_or_null("MusicaIntro") as AudioStreamPlayer
	if mi != null and mi.playing:
		var twm := create_tween()
		twm.tween_property(mi, "volume_db", VOL_MUSICA_NA_TRANSIÇÃO, 0.25)

	# ---------- fase 1: flash, zoom, glitch, barras, nome ----------
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "color:a", 0.0, FLASH_TEMPO)
	tw.tween_property(img, "scale", Vector2(ZOOM_FINAL, ZOOM_FINAL), ZOOM_TEMPO)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(topo, "position:y", 0.0, BARRA_TEMPO)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(baixo, "position:y", 960.0 - BARRA_H, BARRA_TEMPO)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mat != null:
		tw.tween_method(func(v: float): mat.set_shader_parameter("glitch", v), 1.0, 0.0, GLITCH_TEMPO)
		tw.tween_method(func(v: float): mat.set_shader_parameter("sep", v), 0.022, 0.0, GLITCH_TEMPO)
		tw.tween_method(func(v: float): mat.set_shader_parameter("scan", v), 0.8, 0.0, GLITCH_TEMPO)
	# nome entra com um pouco de atraso e um "pop"
	tw.tween_property(nome, "modulate:a", 1.0, 0.22).set_delay(0.32)
	tw.tween_property(nome, "scale", Vector2.ONE, 0.28).set_delay(0.32)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	# ---------- fase 2: saida com flash e arte sumindo ----------
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(nome, "modulate:a", 0.0, 0.18)
	if mat != null:
		tw2.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, SAIDA_TEMPO)
	tw2.tween_property(flash, "color:a", 0.85, 0.14)
	tw2.tween_property(topo, "position:y", -BARRA_H, SAIDA_TEMPO)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.tween_property(baixo, "position:y", 960.0, SAIDA_TEMPO)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw2.finished


func _tocar_motor() -> void:
	# som da turbina saindo: entra com a imagem de transicao e continua
	# na partida. Fica na RAIZ (como a musica) pra sobreviver a troca de
	# cena; o player se libera sozinho quando o som acaba.
	if not ResourceLoader.exists(SOM_MOTOR):
		return
	var s := load(SOM_MOTOR) as AudioStream
	if s == null:
		return
	_motor = AudioStreamPlayer.new()
	_motor.name = "MotorNave"
	_motor.stream = s
	_motor.bus = "Master"
	_motor.volume_db = VOL_MOTOR
	call_deferred("_ligar_motor")


func _ligar_motor() -> void:
	if _motor == null or not is_instance_valid(_motor):
		return
	get_tree().root.add_child(_motor)
	_motor.finished.connect(_motor.queue_free)
	_motor.play()




func _tocar_click() -> void:
	if _ui == null:
		return
	# pitch levemente varia: dois cliques nunca saem identicos
	_ui.stop()   # o arquivo tem 6 s: corta a cauda antes de tocar de novo
	_ui.pitch_scale = randf_range(0.97, 1.04)
	_ui.play()



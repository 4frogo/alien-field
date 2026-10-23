extends Control
# Tela inicial em duas partes:
#   1) tela preta (o frame 01 ja e praticamente um ponto no escuro)
#   2) o logo ALIEN FIELD crescendo, quadro a quadro (24 imagens)
# Depois da animacao o botao ESCOLHER NAVE aparece pulsando abaixo do logo;
# Enter (teclado) ou toque/clique no proprio botao entra no jogo.
#
# Os quadros ficam em res://frames field/ e sao opacos (fundo preto), entao
# basta desenhar por cima do fundo preto — sem chroma key nem shader.

const PASTA := "res://frames field/alien_field_%02d.png"
const TOTAL := 24
const FPS := 18.0          # 24 quadros / 18 = ~1,3 s de animacao
const ESCALA := 1.6        # 512 px -> ~819 px (logo final com ~76% da largura)
const CENA_SEGUINTE := "res://scenes/EscolherNave.tscn"
const CENTRO := Vector2(270.0, 480.0)  # centro do design 540x960

# Botao ESCOLHER NAVE (assets/escolher nave.png, ~2000x780 com fundo preto —
# o preto do PNG funde com o fundo da tela, entao nao precisa de shader)
const IMG_BOTAO := "res://assets/escolher nave.png"
const MUSICA := "res://assets/alien field intro.ogg"
const MUSICA_DB := -14.0              # mesmo volume da musica do jogo
const BOTAO_LARGURA := 460.0           # cabe com folga nos 540 de largura
const CENTRO_BOTAO := Vector2(270.0, 760.0)  # logo termina ~y615, botao 690..870
const ESPERA_BOTAO := 2.0              # espera com o logo grande antes do botao
const PULSO_VEL := 4.0                 # velocidade da "respiracao"
const PULSO_ESCALA := 0.045            # +/- 4,5% de escala
const PULSO_ALFA_MIN := 0.8            # o neon respira de 0.8 a 1.0 de alfa

var _tex: Array[Texture2D] = []
var _sprite: Sprite2D
var _t := 0.0
var _acabou := false
var _saindo := false

var _botao: TextureButton = null
var _t_pulso := 0.0
var _escala_botao := 1.0

var _musica: AudioStreamPlayer = null
var _mudou := false


func _ready() -> void:
	_tocar_musica()
	# fundo preto cobre a tela toda (inclusive as bordas do logo)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 1)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# animacao de frames removida: vai direto ao botao ESCOLHER NAVE
	_acabou = true
	call_deferred("_mostrar_botao")


func _process(delta: float) -> void:
	if _acabou:
		_pulsar_botao(delta)
		return
	if _tex.is_empty():
		return
	_t += delta
	var idx := int(_t * FPS)
	if idx >= _tex.size():
		_sprite.texture = _tex[_tex.size() - 1]
		_finalizar()
		return
	_sprite.texture = _tex[idx]


func _unhandled_input(event: InputEvent) -> void:
	if _saindo:
		return
	# fase do botao: soh Enter (ou numerico do teclado) comeca o jogo;
	# no celular o toque chega pelo proprio botao (sinal pressed)
	# (soh depois que o botao apareceu — durante a espera de 2 s nada vale)
	if _acabou:
		if _botao != null and event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_ir_para_o_jogo()
		return
	# durante a animacao, clique/toque/tecla pula direto pro botao
	var pulou := false
	if event is InputEventMouseButton and event.pressed:
		pulou = true
	elif event is InputEventScreenTouch and event.pressed:
		pulou = true
	elif event is InputEventKey and event.pressed and not event.echo:
		pulou = true
	if pulou:
		_finalizar()


func _finalizar() -> void:
	if _saindo:
		return
	_saindo = true
	_acabou = true
	if _tex.size() > 0:
		_sprite.texture = _tex[_tex.size() - 1]
	# deixa o logo grande sozinho por uns instantes; o botao entra depois
	await get_tree().create_timer(ESPERA_BOTAO).timeout
	_mostrar_botao()


func _mostrar_botao() -> void:
	var tex := load(IMG_BOTAO) as Texture2D
	if tex == null:
		# sem a imagem nao ha menu: mantem o comportamento antigo
		_ir_para_o_jogo()
		return
	_botao = TextureButton.new()
	_botao.texture_normal = tex
	_botao.size = tex.get_size()
	_escala_botao = BOTAO_LARGURA / float(tex.get_width())
	_botao.pivot_offset = _botao.size * 0.5
	_botao.position = CENTRO_BOTAO - _botao.size * 0.5
	_botao.scale = Vector2(_escala_botao, _escala_botao)
	_botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# clique (desktop) ou toque (celular) no botao comeca o jogo
	_botao.pressed.connect(_ir_para_o_jogo)
	add_child(_botao)


func _pulsar_botao(delta: float) -> void:
	if _botao == null:
		return
	# respiracao: escala +/- 4,5% e alfa 0.8 -> 1.0, em fase
	_t_pulso += delta
	var s := sin(_t_pulso * PULSO_VEL)
	var esc := _escala_botao * (1.0 + s * PULSO_ESCALA)
	_botao.scale = Vector2(esc, esc)
	_botao.modulate.a = PULSO_ALFA_MIN + (s * 0.5 + 0.5) * (1.0 - PULSO_ALFA_MIN)


func _tocar_musica() -> void:
	if not ResourceLoader.exists(MUSICA):
		return
	var s := load(MUSICA) as AudioStream
	if s == null:
		return
	# deixa em loop enquanto o jogador fica no botao pulsando
	if s is AudioStreamMP3:
		s.loop = true
	_musica = AudioStreamPlayer.new()
	_musica.name = "MusicaIntro"
	_musica.bus = "Master"
	_musica.volume_db = MUSICA_DB
	_musica.stream = s
	# filha da RAIZ, nao da intro: sobrevive a troca de cena e toca ate a
	# tela de escolher nave (quem desliga e ela, antes de ir pro jogo).
	# add_child na raiz soh aceita DURANTE o _ready (raiz ocupada montando
	# a cena), entao entra deferido, no fim do frame.
	call_deferred("_entrar_na_arvore_e_tocar")


func _entrar_na_arvore_e_tocar() -> void:
	if _musica == null:
		return
	get_tree().root.add_child(_musica)
	_musica.play()


func _ir_para_o_jogo() -> void:
	if _mudou:
		return
	_mudou = true
	# a musica continua tocando (ela e filha da raiz) — ela atravessa a
	# tela de escolher nave e soh cai la na frente, antes da partida
	get_tree().change_scene_to_file(CENA_SEGUINTE)

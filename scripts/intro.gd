extends Control
# Tela inicial em duas partes:
#   1) tela preta (o frame 01 ja e praticamente um ponto no escuro)
#   2) o logo ALIEN FIELD crescendo, quadro a quadro (24 imagens)
# No fim espera um instante com o logo grande e entra no jogo.
#
# Os quadros ficam em res://frames field/ e sao opacos (fundo preto), entao
# basta desenhar por cima do fundo preto — sem chroma key nem shader.

const PASTA := "res://frames field/alien_field_%02d.png"
const TOTAL := 24
const FPS := 18.0          # 24 quadros / 18 = ~1,3 s de animacao
const ESCALA := 1.6        # 512 px -> ~819 px (logo final com ~76% da largura)
const ESPERA := 0.7        # pausa com o logo grande antes de entrar no jogo
const CENA_SEGUINTE := "res://scenes/Main.tscn"
const CENTRO := Vector2(270.0, 480.0)  # centro do design 540x960

var _tex: Array[Texture2D] = []
var _sprite: Sprite2D
var _t := 0.0
var _acabou := false
var _saindo := false


func _ready() -> void:
	# fundo preto cobre a tela toda (inclusive as bordas do logo)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 1)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	_sprite = Sprite2D.new()
	_sprite.position = CENTRO
	_sprite.scale = Vector2(ESCALA, ESCALA)
	_sprite.visible = false
	add_child(_sprite)

	for i in range(1, TOTAL + 1):
		var caminho := PASTA % i
		if not ResourceLoader.exists(caminho):
			continue
		var t := load(caminho) as Texture2D
		if t != null:
			_tex.append(t)

	# sem os frames: nao trava o jogo, cai direto na cena principal
	if _tex.is_empty():
		_ir_para_o_jogo()
		return

	_sprite.texture = _tex[0]
	_sprite.visible = true


func _process(delta: float) -> void:
	if _acabou or _tex.is_empty():
		return
	_t += delta
	var idx := int(_t * FPS)
	if idx >= _tex.size():
		_sprite.texture = _tex[_tex.size() - 1]
		_finalizar()
		return
	_sprite.texture = _tex[idx]


func _unhandled_input(event: InputEvent) -> void:
	# clique/toque/tecla pula a intro (util no navegador)
	if _saindo or _acabou:
		return
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
	await get_tree().create_timer(ESPERA).timeout
	_ir_para_o_jogo()


func _ir_para_o_jogo() -> void:
	get_tree().change_scene_to_file(CENA_SEGUINTE)

extends Node2D

# Rastro da nave: guarda as ultimas posicoes e desenha uma fita que
# afina e apaga com o tempo. Brilho proporcional a velocidade (impulso).

const MAX := 26            # segmentos guardados
const VIDA := 0.42         # segundos ate apagar
# cor do rastro: verde na nave padrao, VIOLETA na nave roxa (o player
# ajusta esse valor no _ready conforme a nave escolhida)
var cor := Color(0.30, 1.0, 0.72)

var alvo: Node2D = null
var intensidade := 0.0     # 0 parado, 1 no maximo

var _buf: Array[Vector2] = []
var _idade: Array[float] = []


func _ready() -> void:
	z_index = -1
	set_process(true)


func _process(delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var p: Vector2 = alvo.global_position
	# so grava se andou o suficiente (evita pilha de pontos iguais)
	if _buf.is_empty() or p.distance_to(_buf[0]) > 0.8:
		_buf.push_front(p)
		_idade.push_front(0.0)
		if _buf.size() > MAX:
			_buf.resize(MAX)
			_idade.resize(MAX)

	for i in _idade.size():
		_idade[i] += delta

	# limpa os velhos
	while _idade.size() > 0 and _idade[_idade.size() - 1] > VIDA:
		_idade.pop_back()
		_buf.pop_back()

	queue_redraw()


func _draw() -> void:
	if _buf.size() < 2:
		return
	for i in _buf.size() - 1:
		var a: Vector2 = _buf[i]
		var b: Vector2 = _buf[i + 1]
		var t: float = clampf(1.0 - _idade[i] / VIDA, 0.0, 1.0)
		if t <= 0.01:
			continue
		var f: float = (float(i) / float(_buf.size())) * t
		var larg: float = 2.0 + 7.0 * f * (0.45 + 0.55 * intensidade)
		var v: Vector2 = b - a
		if v.length() < 0.001:
			continue
		var n: Vector2 = v.normalized().orthogonal()
		var quad := PackedVector2Array([
			a + n * larg, b + n * larg, b - n * larg, a - n * larg,
		])
		# halo largo
		draw_colored_polygon(PackedVector2Array([
			a + n * (larg * 2.6), b + n * (larg * 2.6),
			b - n * (larg * 2.6), a - n * (larg * 2.6),
		]), Color(cor.r, cor.g, cor.b, 0.10 * t))
		# corpo
		draw_colored_polygon(quad, Color(cor.r, cor.g, cor.b, 0.55 * t))
		# nucleo claro
		var ln: Vector2 = n * (larg * 0.35)
		draw_colored_polygon(PackedVector2Array([
			a + ln, b + ln, b - ln, a - ln,
		]), Color(1, 1, 1, 0.35 * t))
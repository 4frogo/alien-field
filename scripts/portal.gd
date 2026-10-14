extends Node2D
# Portal de vortice: loop de 4 frames do tileset, com succao girando pra dentro.
#
# Camadas (por z_index):
#   -2  brilho aditivo (frame 0, maior, contra-rotativo)
#   -1  sprite principal (frames trocados em loop)
#    0  nucleo negro + faiscas sendo sugadas pra dentro (desenhado aqui)

const TEMPO_FRAME := 0.11
const FONTES := [
	"res://assets/portal_seq_0.png",
	"res://assets/portal_seq_1.png",
	"res://assets/portal_seq_2.png",
	"res://assets/portal_seq_3.png",
]

# Proporcoes relativas ao DIAMETRO desenhado, para o portal poder mudar de
# tamanho sem desconfigurar as camadas.
const NUCLEO := 0.19         # raio do disco negro
const FAI_RAIO_EXT := 0.82   # onde as faiscas nascem
const FAI_RAIO_INT := 0.26   # onde somem
const ANEL_EXT := 0.90       # anel de succao, raio maximo
const ANEL_INT := 0.34       # anel de succao, raio minimo

var tempo := 0.0
var ativo := true

# `raio` e o raio VISUAL do portal. E property com setter de proposito: o
# main.gd atribui o raio DEPOIS do add_child (ou seja, depois do _ready). Se a
# escala fosse calculada so no _ready, o vortice sairia com o raio padrao e o
# nucleo (calculado por frame) cobriria ele inteiro.
var raio := 95.0:
	set(v):
		raio = maxf(1.0, v)
		_ajusta_escala()

var _frames: Array = []
var _idx := 0
var _t_frame := 0.0

var _spr: Sprite2D
var _glow: Sprite2D
var _base := 1.0


func _ready() -> void:
	for caminho in FONTES:
		if ResourceLoader.exists(caminho):
			var t := load(caminho) as Texture2D
			if t != null:
				_frames.append(t)
	if _frames.is_empty():
		return

	_glow = Sprite2D.new()
	_glow.texture = _frames[0]
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.z_index = -2
	# o jogo usa filtro nearest; como o portal e ampliado bastante,
	# forcamos interpolacao linear para nao ficar serrilhado
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_glow)

	_spr = Sprite2D.new()
	_spr.texture = _frames[0]
	_spr.z_index = -1
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_spr)

	rotation = randf_range(0.0, TAU)
	_ajusta_escala()


# A textura e 576x576, entao escala = raio/288 faz o diametro sair em 2*raio.
func _ajusta_escala() -> void:
	_base = raio / 288.0
	var resp: float = 1.0 + 0.035 * sin(tempo * 2.1)
	if _spr != null:
		_spr.scale = Vector2.ONE * (_base * resp)
	if _glow != null:
		_glow.scale = Vector2.ONE * (_base * 1.18)


func _process(delta: float) -> void:
	if not ativo:
		return
	tempo += delta

	if _spr != null:
		_t_frame += delta
		while _t_frame >= TEMPO_FRAME:
			_t_frame -= TEMPO_FRAME
			_idx = (_idx + 1) % _frames.size()
			_spr.texture = _frames[_idx]

		# rotacao lenta do conjunto (a arte ja tem espiral, isso da vida)
		rotation += 0.20 * delta

		# respiracao de escala
		var resp: float = 1.0 + 0.035 * sin(tempo * 2.1)
		_spr.scale = Vector2.ONE * (_base * resp)
		# brilho aditivo pulsa e gira ao contrario
		var pulso: float = 0.85 + 0.15 * sin(tempo * 3.3)
		_glow.scale = Vector2.ONE * (_base * resp * 1.20)
		_glow.modulate = Color(1.0, 0.45, 0.18, 0.34 * pulso)
		_glow.rotation = -rotation * 1.6
	queue_redraw()


func _draw() -> void:
	if not ativo:
		return
	if _frames.is_empty():
		_draw_fallback()
		return

	var d: float = raio * 2.0   # diametro desenhado

	# ---- nucleo negro (o "buraco"): a chave de alpha removeu o preto do
	# centro do portal, entao redesenhamos para dar leitura de buraco
	var pulso := 0.95 + 0.05 * sin(tempo * 2.6)
	var r_nuc: float = d * NUCLEO * pulso
	draw_circle(Vector2.ZERO, r_nuc * 1.12, Color(0.15, 0.01, 0.0, 0.55))
	draw_circle(Vector2.ZERO, r_nuc, Color(0, 0, 0, 0.96))
	draw_arc(Vector2.ZERO, r_nuc, 0, TAU, 64, Color(1.0, 0.35, 0.10, 0.85), 4.0, true)
	draw_arc(Vector2.ZERO, r_nuc * 1.05, 0, TAU, 64, Color(1.0, 0.75, 0.35, 0.45), 2.0, true)

	# ---- faiscas sendo sugadas para dentro
	var n := 14
	for i in n:
		var f: float = float(i) / float(n)
		var ph: float = fmod(tempo * 0.42 + f, 1.0)
		var ang: float = f * TAU * 3.0 + tempo * 1.6
		var rr: float = d * lerpf(FAI_RAIO_EXT, FAI_RAIO_INT, _ease_in(ph))
		var a: float = 1.0 - ph
		var sz: float = 2.0 + 2.4 * a
		draw_circle(Vector2(cos(ang), sin(ang)) * rr, sz,
			Color(1.0, 0.62, 0.22, a * 0.9))
		# rastro curto na direcao do movimento
		var ant := ang - 0.16
		draw_line(Vector2(cos(ang), sin(ang)) * rr,
			Vector2(cos(ant), sin(ant)) * (rr + sz * 4.0),
			Color(1.0, 0.45, 0.12, a * 0.35), sz * 0.9, true)

	# ---- anel de succao contraindo
	for i in 2:
		var ph2: float = fmod(tempo * 0.55 + float(i) * 0.5, 1.0)
		var r2: float = d * lerpf(ANEL_EXT, ANEL_INT, ph2)
		draw_arc(Vector2.ZERO, r2, 0, TAU, 64,
			Color(1.0, 0.30, 0.08, (1.0 - ph2) * 0.35), 3.0, true)


func _draw_fallback() -> void:
	for b in 3:
		var pts := PackedVector2Array()
		for s in 16:
			var r: float = raio * (1.7 - float(s) / 15.0 * 1.15)
			var a: float = tempo * 3.2 + TAU * float(b) / 3.0 + (raio * 1.7 - r) * 0.05
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Color(1.0, 0.25, 0.06, 0.7), 5.0)
	draw_circle(Vector2.ZERO, raio * 0.38, Color(0, 0, 0, 0.95))
	draw_arc(Vector2.ZERO, raio * 0.38, 0, TAU, 64, Color(1.0, 0.3, 0.08, 0.9), 3.0, true)


func _ease_in(x: float) -> float:
	var v: float = clampf(x, 0.0, 1.0)
	return v * v
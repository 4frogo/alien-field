extends Control
# Texto de carga do super tiro — canto INFERIOR DIREITO da tela.
#
# Estados (main.gd manda via set_estado):
#   SUPER  — verde, carregando
#   PERIGO — laranja, piscando (carga > 60%)
#   SOLTE! — vermelho, PULSANDO (carga cheia)
#
# Quando o tiro carregado sai, explodir() estilhaça a ULTIMA PALAVRA:
# cada letra vira um caco que voa, gira, cai e some, com um flash branco
# na origem. A explosao termina sozinha e o main esconde o no depois.

var texto := "SUPER"
var cor := Color(0.5, 1.0, 0.6)
var pronta := false
var explodindo := false

const TAM := 34.0

var _t := 0.0
var _flash := 0.0          # 1 -> 0: clarao da explosao
var _letras: Array = []    # cacos: {ch, pos, vel, rot, rv, vida, w}
var _fonte: Font = null


func _f() -> Font:
	if _fonte == null:
		if ResourceLoader.exists("res://assets/horror.ttf"):
			_fonte = load("res://assets/horror.ttf") as Font
		if _fonte == null:
			_fonte = ThemeDB.fallback_font
	return _fonte


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# sem isso o painel comeria os toques na area do canto direito
	if custom_minimum_size.x < 1.0:
		custom_minimum_size = Vector2(300, 46)
		size = custom_minimum_size


func set_estado(txt: String, p_cor: Color, p_pronta: bool) -> void:
	texto = txt
	cor = p_cor
	pronta = p_pronta
	queue_redraw()


func explodir() -> void:
	# congela a palavra ATUAL em particulas (antes do main trocar/esconder)
	if explodindo or texto.length() == 0:
		return
	var f := _f()
	var total := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x
	var x := size.x - total          # layout igual ao draw (alinhado a direita)
	var base_y := size.y * 0.5 + f.get_ascent(TAM) * 0.5
	_letras.clear()
	for i in texto.length():
		var ch := texto[i]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x
		var centro := Vector2(x + w * 0.5, base_y - TAM * 0.35)
		x += w
		# voa pra fora em funcao de onde stava na palavra + sorte
		_letras.append({
			"ch": ch,
			"pos": centro,
			"vel": Vector2((centro.x - size.x * 0.5) * 2.4 + randf_range(-50, 50),
					randf_range(-230, -90)),
			"rot": 0.0,
			"rv": randf_range(-9.0, 9.0),
			"vida": randf_range(0.55, 0.95),
			"w": w,
		})
	explodindo = true
	_flash = 1.0
	_t = 0.0
	visible = true


func _process(delta: float) -> void:
	_t += delta
	if explodindo:
		_flash = maxf(0.0, _flash - delta * 4.5)
		var vivo := false
		for L in _letras:
			L["vida"] = float(L["vida"]) - delta
			if float(L["vida"]) <= 0.0:
				continue
			vivo = true
			L["vel"] = (L["vel"] as Vector2) + Vector2(0, 460.0 * delta)  # gravidade
			L["pos"] = (L["pos"] as Vector2) + (L["vel"] as Vector2) * delta
			L["rot"] = float(L["rot"]) + float(L["rv"]) * delta
		_letras = _letras.filter(func(L): return float(L["vida"]) > 0.0)
		if not vivo and _flash <= 0.0:
			explodindo = false
			_letras.clear()
		queue_redraw()
		return
	queue_redraw()


func _draw() -> void:
	var f := _f()
	var base_y := size.y * 0.5 + f.get_ascent(TAM) * 0.5

	# ---------------- explosao da ultima palavra ----------------
	if explodindo:
		if _flash > 0.0:
			var k := 1.0 - _flash
			draw_circle(Vector2(size.x - 60.0, size.y * 0.5),
				12.0 + k * 70.0, Color(1, 0.85, 0.7, 0.55 * _flash))
		var alfa_t := Color(cor.r, cor.g, cor.b, 1.0)
		for L in _letras:
			var vida := float(L["vida"])
			var a := clampf(vida / 0.35, 0.0, 1.0)
			var w: float = L["w"]
			var esc := 1.0 + (1.0 - a) * 0.35          # inchando ao sumir
			draw_set_transform(L["pos"], float(L["rot"]), Vector2(esc, esc))
			# contorno escuro + corpo: caco legivel mesmo girando
			draw_string(f, Vector2(-w * 0.5 + 2, TAM * 0.35 + 2), L["ch"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Color(0, 0, 0, 0.75 * a))
			draw_string(f, Vector2(-w * 0.5, TAM * 0.35), L["ch"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Color(alfa_t.r, alfa_t.g, alfa_t.b, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# ---------------- estado normal ----------------
	var tam := TAM
	var alfa := 1.0
	if pronta:
		# pulso forte: a palavra "respira" quando da pra disparar
		tam = TAM * (1.0 + 0.09 * absf(sin(_t * 7.5)))
		alfa = 0.72 + 0.28 * sin(_t * 11.0)
	elif texto == "PERIGO":
		alfa = 0.45 + 0.55 * absf(sin(_t * 6.0))       # pisca
		tam = TAM * (1.0 + 0.04 * sin(_t * 6.0))

	var cor_atual := Color(cor.r, cor.g, cor.b, alfa)
	# sombra: legivel sobre o cenario vermelho/escuro
	draw_string(f, Vector2(2, base_y + 2), texto, HORIZONTAL_ALIGNMENT_RIGHT,
		size.x, tam, Color(0, 0, 0, 0.8 * alfa))
	# halo quando pronta
	if pronta:
		draw_string_outline(f, Vector2(0, base_y), texto,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x, int(tam), 7,
			Color(cor.r, cor.g, cor.b, 0.45 * alfa))
	draw_string(f, Vector2(0, base_y), texto, HORIZONTAL_ALIGNMENT_RIGHT,
		size.x, tam, cor_atual)

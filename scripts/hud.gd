extends CanvasLayer
# HUD igual imagem: PONTOS, VIDAS, FASE, ESCUDO, ARMA LASER

var lbl_pontos_val: Label
var lbl_fase: Label
var vidas_icons: Control
var bar_escudo: ProgressBar
var vidas_count := 3

var verde := Color(0.25, 1.0, 0.45)
var verde_escuro := Color(0.1, 0.6, 0.25)
var fonte_horror: Font = null

func _ready() -> void:
	if ResourceLoader.exists("res://assets/horror.ttf"):
		fonte_horror = load("res://assets/horror.ttf") as Font
	# PONTOS
	var lbl_pontos := Label.new()
	lbl_pontos.text = "PONTOS"
	lbl_pontos.position = Vector2(18, 12)
	lbl_pontos.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_pontos.add_theme_font_override("font", fonte_horror)
	lbl_pontos.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	add_child(lbl_pontos)

	lbl_pontos_val = Label.new()
	lbl_pontos_val.text = "000000"
	lbl_pontos_val.position = Vector2(18, 34)
	lbl_pontos_val.add_theme_font_size_override("font_size", 30)
	if fonte_horror != null:
		lbl_pontos_val.add_theme_font_override("font", fonte_horror)
	lbl_pontos_val.add_theme_color_override("font_color", verde)
	add_child(lbl_pontos_val)

	# VIDAS
	var lbl_vidas := Label.new()
	lbl_vidas.text = "VIDAS"
	lbl_vidas.position = Vector2(410, 12)
	lbl_vidas.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_vidas.add_theme_font_override("font", fonte_horror)
	lbl_vidas.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	add_child(lbl_vidas)

	vidas_icons = preload("res://scripts/vidas_icons.gd").new()
	vidas_icons.position = Vector2(400, 38)
	vidas_icons.size = Vector2(120, 32)
	add_child(vidas_icons)

	# FASE
	lbl_fase = Label.new()
	lbl_fase.text = "FASE 1-3"
	lbl_fase.position = Vector2(390, 72)
	lbl_fase.add_theme_font_size_override("font_size", 24)
	if fonte_horror != null:
		lbl_fase.add_theme_font_override("font", fonte_horror)
	lbl_fase.add_theme_color_override("font_color", Color(0.85, 0.9, 0.88))
	add_child(lbl_fase)

	# ESCUDO
	var lbl_esc := Label.new()
	lbl_esc.text = "ESCUDO"
	lbl_esc.position = Vector2(18, 896)
	lbl_esc.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_esc.add_theme_font_override("font", fonte_horror)
	lbl_esc.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	add_child(lbl_esc)

	bar_escudo = ProgressBar.new()
	bar_escudo.position = Vector2(18, 920)
	bar_escudo.size = Vector2(180, 18)
	bar_escudo.min_value = 0
	bar_escudo.max_value = 100
	bar_escudo.value = 100
	bar_escudo.show_percentage = false
	add_child(bar_escudo)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.25, 0.1)
	sb.border_color = verde
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	bar_escudo.add_theme_stylebox_override("background", sb)
	var fill := StyleBoxFlat.new()
	fill.bg_color = verde
	fill.set_corner_radius_all(2)
	bar_escudo.add_theme_stylebox_override("fill", fill)

	# ARMA
	var lbl_arma := Label.new()
	lbl_arma.text = "ARMA\nLASER"
	lbl_arma.position = Vector2(430, 898)
	lbl_arma.add_theme_font_size_override("font_size", 20)
	if fonte_horror != null:
		lbl_arma.add_theme_font_override("font", fonte_horror)
	lbl_arma.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	add_child(lbl_arma)

func atualizar(pontos: int, vidas: int, escudo: float) -> void:
	lbl_pontos_val.text = "%06d" % pontos
	vidas_count = vidas
	vidas_icons.queue_redraw()
	bar_escudo.value = escudo

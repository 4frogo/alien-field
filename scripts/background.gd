extends Node2D
# Fundo com varios trechos verticais em sequencia (bg.png, bg2.png, bg3.png...)

var scroll := 0.0
var scroll_speed := 45.0
var stars: Array = []
var rocks_left: Array = []
var rocks_right: Array = []
var crystals_left: Array = []
var crystals_right: Array = []
var asteroids: Array = []
var use_image := false
var bg_sprites: Array = []
var bg_h_list: Array = []
var total_cover := 0.0
var texs_dim1: Array = []
var texs_dim2: Array = []
var dimensao := 1
# camada infinita: poeira, meteoros e filetes (nunca repete)
var poeira_inf: Array = []
var spawn_t := 0.0
var meteoros: Array = []
var met_t := 4.0
var tempo_total := 0.0
var rng_inf := RandomNumberGenerator.new()
# véu: escurece as bordas e dessatura o fundo, pra nave/inimigos/TIROS
# saltarem contra a arte. Aplicado SO nos sprites do fundo.
var veu_mat: ShaderMaterial = null
# parallax: camadas de destroços em velocidades diferentes
var parallax: Array = []
# camada procedural: nebulosa + estrelas geradas por shader (z=-20,
# fica ATRAS das artes de cenario e preenche o vazio preto)
var nebulosa_mat: ShaderMaterial = null
var nebulosa_scr: ColorRect = null


func _criar_nebulosa() -> void:
	# desliga se o shader nao existir (fallback seguro)
	if not ResourceLoader.exists("res://assets/nebulosa_fundo.gdshader"):
		return
	nebulosa_mat = ShaderMaterial.new()
	nebulosa_mat.shader = load("res://assets/nebulosa_fundo.gdshader") as Shader
	if nebulosa_mat.shader == null:
		nebulosa_mat = null
		return
	nebulosa_scr = ColorRect.new()
	nebulosa_scr.material = nebulosa_mat
	nebulosa_scr.color = Color(1, 1, 1, 1)
	# ColorRect e um Control: ancoras iguais (top-left) + size explicito.
	# Nao usar FULL_RECT aqui — o size e sobrescrito depois do _ready.
	nebulosa_scr.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nebulosa_scr.size = Vector2(540, 960)
	nebulosa_scr.position = Vector2.ZERO
	nebulosa_scr.z_index = -20
	nebulosa_scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Node2D wrapper: z_index do Control nao affects o draw order do mundo
	var holder := Node2D.new()
	holder.z_index = -20
	holder.add_child(nebulosa_scr)
	add_child(holder)


func _atualizar_nebulosa() -> void:
	if nebulosa_mat == null:
		return
	# scroll e acumulado e sempre crescente -> usa fmod pra nao estourar
	nebulosa_mat.set_shader_parameter("scroll",
		fmod(tempo_total * scroll_speed * 0.30, 2000.0))
	nebulosa_mat.set_shader_parameter("tempo", fmod(tempo_total, 100.0))


func _criar_veu() -> ShaderMaterial:
	if ResourceLoader.exists("res://assets/veu_fundo.gdshader"):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/veu_fundo.gdshader") as Shader
		m.set_shader_parameter("vinheta", 1.00)
		m.set_shader_parameter("dessat", 0.22)
		m.set_shader_parameter("escurecer", 0.10)
		m.set_shader_parameter("raio", 0.82)
		m.set_shader_parameter("realce", 0.35)
		return m
	return null


func _criar_parallax() -> void:
	# 3 profundidades: o fundo lento e grande, o medio, o frontal rapido e pequeno
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 90210
	for i in 26:
		var prof := float(i % 3)          # 0 lento, 1 medio, 2 rapido
		parallax.append({
			"pos": Vector2(rng2.randf_range(20, 520), rng2.randf_range(-200, 1000)),
			"r": [16.0, 10.0, 6.0][int(prof)] * rng2.randf_range(0.75, 1.3),
			"spd": [16.0, 38.0, 82.0][int(prof)] * rng2.randf_range(0.85, 1.15),
			"prof": prof,
			"rot": rng2.randf_range(0.0, TAU),
			"rv": rng2.randf_range(-0.4, 0.4),
			"pontos": rng2.randi_range(5, 7),
		})

func _montar_coluna(lista: Array) -> void:
	for sp in bg_sprites:
		if is_instance_valid(sp):
			sp.queue_free()
	bg_sprites.clear()
	bg_h_list.clear()
	total_cover = 0.0
	if lista.is_empty():
		use_image = false
		return
	use_image = true
	if veu_mat == null:
		veu_mat = _criar_veu()
	var y_cursor := 1400.0
	var idx := 0
	while y_cursor > -1400.0 and idx < 12:
		var tex: Texture2D = lista[idx % lista.size()]
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		if tw <= 0 or th <= 0:
			idx += 1
			continue
		var s := 540.0 / tw
		var h := th * s
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2(s, s)
		sp.position = Vector2(270, y_cursor - h / 2.0)
		sp.z_index = -10
		if veu_mat != null:
			sp.material = veu_mat
		add_child(sp)
		bg_sprites.append(sp)
		bg_h_list.append(h)
		total_cover += h
		y_cursor -= h
		idx += 1

func trocar_dimensao(n: int) -> void:
	# 1 = fase inicial (bg), 2 = outra dimensao (bg2+; cai pra bg se nao existir)
	dimensao = n
	if n == 2 and not texs_dim2.is_empty():
		_montar_coluna(texs_dim2)
	else:
		_montar_coluna(texs_dim1)

func _ready() -> void:
	z_index = -10
	veu_mat = _criar_veu()
	_criar_nebulosa()
	_criar_parallax()
	var paths1: Array = ["res://assets/pinkpoison_seamless.png"]
	if not ResourceLoader.exists("res://assets/pinkpoison_seamless.png"):
		paths1 = ["res://assets/pinkpoison_loop.png", "res://assets/pinkpoison.png", "res://assets/bg.png", "res://assets/bg.jpg"]
	# arena do boss: loop seamless unico = infinito de verdade
	var paths2: Array = ["res://assets/cenarioV_seamless.png"]
	if not ResourceLoader.exists("res://assets/cenarioV_seamless.png"):
		paths2 = [
			"res://assets/cenarioV.png",
			"res://assets/redfuture.png",
			"res://assets/bg2.png", "res://assets/bg2.jpg",
			"res://assets/bg3.png", "res://assets/bg3.jpg",
			"res://assets/bg4.png", "res://assets/bg4.jpg",
			"res://assets/bg5.png", "res://assets/bg5.jpg",
			"res://assets/fase.png", "res://assets/background.png"
		]
	for p in paths1:
		if ResourceLoader.exists(p):
			var t := load(p) as Texture2D
			if t != null:
				texs_dim1.append(t)
	for p in paths2:
		if ResourceLoader.exists(p):
			var t := load(p) as Texture2D
			if t != null:
				texs_dim2.append(t)
	if texs_dim1.is_empty() and not texs_dim2.is_empty():
		texs_dim1 = texs_dim2.duplicate()
	if not texs_dim1.is_empty():
		_montar_coluna(texs_dim1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 120:
		stars.append(Vector2(rng.randf_range(60, 480), rng.randf_range(0, 960)))
	for i in 28:
		var y := float(i) * 36.0
		rocks_left.append(Vector2(rng.randf_range(0, 70), y))
		rocks_right.append(Vector2(rng.randf_range(470, 540), y))
	for i in 22:
		crystals_left.append(Vector2(rng.randf_range(8, 70), rng.randf_range(0, 960)))
		crystals_right.append(Vector2(rng.randf_range(470, 532), rng.randf_range(0, 960)))
	for i in 14:
		asteroids.append({
			"pos": Vector2(rng.randf_range(90, 450), rng.randf_range(0, 960)),
			"r": rng.randf_range(4.0, 11.0),
			"spd": rng.randf_range(30.0, 90.0)
		})

func _process(delta: float) -> void:
	tempo_total += delta
	var resp := 1.0 + 0.15 * sin(tempo_total * 0.13) # respiracao: voo vivo, nao mecanico
	_atualizar_nebulosa()
	_atualiza_parallax(delta)
	if use_image:
		for i in bg_sprites.size():
			var sp: Sprite2D = bg_sprites[i]
			sp.position.y += scroll_speed * resp * delta
			var h: float = bg_h_list[i]
			if sp.position.y - h / 2.0 > 1100:
				sp.position.y -= total_cover
		_atualiza_infinito(delta, resp)
		queue_redraw()
		return
	scroll += scroll_speed * delta
	if scroll > 36.0:
		scroll -= 36.0
	for a in asteroids:
		a["pos"].y += float(a["spd"]) * delta
		if a["pos"].y > 990:
			a["pos"].y = -20
			a["pos"].x = randf_range(90, 450)
	queue_redraw()

func _atualiza_parallax(delta: float) -> void:
	for p in parallax:
		var pos: Vector2 = p["pos"]
		pos.y += float(p["spd"]) * delta
		p["rot"] = float(p["rot"]) + float(p["rv"]) * delta
		if pos.y > 1010.0:
			pos.y = -60.0
			pos.x = rng_inf.randf_range(20, 520)
		p["pos"] = pos


func _draw_parallax() -> void:
	# destrocos em 3 profundidades: quanto mais frontal, mais rapido, maior
	# e mais claro (da sensacao de passar rapido pela camera)
	for p in parallax:
		var pos: Vector2 = p["pos"]
		var prof: int = int(p["prof"])
		var r: float = float(p["r"])
		var val: float = [0.07, 0.13, 0.22][prof]
		var pts := PackedVector2Array()
		var n: int = int(p["pontos"])
		var rot: float = float(p["rot"])
		for i in n:
			var a := TAU * float(i) / float(n) + rot
			var rr := r * (0.78 + 0.22 * sin(float(i) * 2.1 + prof))
			pts.append(pos + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color(val * 0.9, val * 0.95, val * 1.15))
		# luz de cima, pra dar volume
		draw_circle(pos - Vector2(r * 0.28, r * 0.30), r * 0.24,
			Color(val * 1.9, val * 2.0, val * 2.3))


func _atualiza_infinito(delta: float, resp: float) -> void:
	# clima sutil: brasas lentas + meteoros finos raros (nada solido)
	spawn_t -= delta
	if spawn_t <= 0 and poeira_inf.size() < 42:
		spawn_t = 0.35
		poeira_inf.append({
			"pos": Vector2(rng_inf.randf_range(30, 510), -12.0),
			"spd": rng_inf.randf_range(22.0, 55.0) * resp,
			"drift": rng_inf.randf_range(-10, 10),
			"tam": rng_inf.randf_range(1.0, 2.2),
			"fase": rng_inf.randf_range(0.0, TAU),
			"verde": rng_inf.randf() < 0.65,
		})
	for d in poeira_inf:
		d["pos"] = (d["pos"] as Vector2) + Vector2(float(d["drift"]), float(d["spd"])) * delta
	poeira_inf = poeira_inf.filter(func(x): return (x["pos"] as Vector2).y < 990.0)
	met_t -= delta
	if met_t <= 0:
		met_t = rng_inf.randf_range(6.0, 12.0)
		var mx := rng_inf.randf_range(80, 460)
		meteoros.append({"pos": Vector2(mx, -20), "vel": Vector2(rng_inf.randf_range(-120, 120), rng_inf.randf_range(650, 900))})
	for m in meteoros:
		m["pos"] = (m["pos"] as Vector2) + (m["vel"] as Vector2) * delta
	meteoros = meteoros.filter(func(x): return (x["pos"] as Vector2).y < 1020.0)

func _draw() -> void:
	_draw_parallax()
	if use_image:
		_draw_infinito()
		return
	# ceu
	draw_rect(Rect2(0, 0, 540, 960), Color(0.008, 0.03, 0.02))
	# nebulosa central verde
	draw_circle(Vector2(270, 400), 220, Color(0.02, 0.12, 0.07, 0.55))
	draw_circle(Vector2(270, 400), 120, Color(0.05, 0.22, 0.11, 0.5))
	# estrelas
	for s in stars:
		var y: float = fmod(float(s.y) + scroll * 0.4, 960.0)
		var tw: float = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 500.0 + float(s.x)))
		draw_circle(Vector2(float(s.x), y), 1.2, Color(0.6, 1.0, 0.7, 0.5 * tw + 0.2))
	# planeta canto superior esquerdo (crescente verde)
	var pp := Vector2(55, 55)
	draw_circle(pp, 78, Color(0.03, 0.12, 0.07))
	draw_circle(pp + Vector2(-12, -6), 70, Color(0.02, 0.08, 0.05))
	draw_arc(pp, 78, -0.6, 1.8, 32, Color(0.45, 1.0, 0.6, 0.9), 4.0)
	draw_arc(pp, 72, -0.5, 1.6, 32, Color(0.2, 0.6, 0.35, 0.6), 8.0)
	# asteroides
	for a in asteroids:
		var p: Vector2 = a["pos"]
		draw_circle(p, float(a["r"]) + 2.0, Color(0.05, 0.07, 0.07))
		draw_circle(p, float(a["r"]), Color(0.14, 0.16, 0.16))
		draw_circle(p + Vector2(-2, -2), 2.0, Color(0.25, 0.28, 0.27))
	# paredes do canyon
	_draw_wall(true)
	_draw_wall(false)

func _draw_infinito() -> void:
	# nebulosa viva: deriva + respiracao
	var nx1 := 270.0 + sin(tempo_total * 0.07) * 60.0
	var nx2 := 270.0 + sin(tempo_total * 0.05 + 2.0) * 80.0
	var br := 0.85 + 0.15 * sin(tempo_total * 0.4)
	draw_circle(Vector2(nx1, 330), 200, Color(0.03, 0.14, 0.07, 0.30 * br))
	draw_circle(Vector2(nx2, 680), 240, Color(0.02, 0.10, 0.06, 0.28 * br))
	# brasas subindo devagar
	for d in poeira_inf:
		var tw := 0.35 + 0.65 * (0.5 + 0.5 * sin(tempo_total * 3.0 + float(d["fase"])))
		var c := Color(0.4, 1.0, 0.55, 0.5 * tw) if bool(d["verde"]) else Color(0.9, 0.95, 0.9, 0.4 * tw)
		draw_circle(d["pos"], float(d["tam"]), c)
	# meteoros finos com rastro curto
	for m in meteoros:
		var p: Vector2 = m["pos"]
		var dir: Vector2 = (m["vel"] as Vector2).normalized()
		draw_line(p - dir * 46.0, p, Color(0.5, 1.0, 0.6, 0.35), 1.5)
		draw_circle(p, 1.8, Color(1, 1, 1, 0.8))

func _draw_wall(is_left: bool) -> void:
	var rocks := rocks_left if is_left else rocks_right
	for r in rocks:
		var y: float = float(r.y) - scroll
		# wrap
		if y < -40: y += 1008.0
		if y > 1000: y -= 1008.0
		var base_x: float = float(r.x)
		# rocha escura
		draw_circle(Vector2(base_x, y), 28, Color(0.07, 0.08, 0.09))
		draw_circle(Vector2(base_x, y), 22, Color(0.11, 0.12, 0.13))
		draw_circle(Vector2(base_x + 6, y - 6), 8, Color(0.16, 0.18, 0.18))
	# cristais verdes brilhantes
	var crys := crystals_left if is_left else crystals_right
	for c in crys:
		var y: float = fmod(float(c.y) + scroll * 1.2, 960.0)
		var p := Vector2(float(c.x), y)
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0 + float(c.y))
		draw_circle(p, 10.0 * pulse, Color(0.1, 1.0, 0.4, 0.15))
		draw_circle(p, 5.0, Color(0.05, 0.35, 0.15))
		draw_circle(p, 2.5 * pulse + 1.0, Color(0.4, 1.0, 0.55))
		draw_circle(p + Vector2(-1, -1), 1.0, Color.WHITE)
	# borda escura para fechar o corredor
	if is_left:
		draw_rect(Rect2(0, 0, 12, 960), Color(0.02, 0.02, 0.03))
	else:
		draw_rect(Rect2(528, 0, 12, 960), Color(0.02, 0.02, 0.03))

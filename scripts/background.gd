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

func _ready() -> void:
	z_index = -10
	var paths: Array = [
		"res://assets/bg.png", "res://assets/bg.jpg",
		"res://assets/bg2.png", "res://assets/bg2.jpg",
		"res://assets/bg3.png", "res://assets/bg3.jpg",
		"res://assets/bg4.png", "res://assets/bg4.jpg",
		"res://assets/bg5.png", "res://assets/bg5.jpg",
		"res://assets/fase.png", "res://assets/background.png"
	]
	var texs: Array = []
	for p in paths:
		if ResourceLoader.exists(p):
			var t := load(p) as Texture2D
			if t != null:
				texs.append(t)
	if texs.size() > 0:
		use_image = true
		# monta uma coluna longa (~3200px) ciclando as texturas para variar
		var y_cursor := 1400.0
		var idx := 0
		while y_cursor > -1400.0 and idx < 12:
			var tex: Texture2D = texs[idx % texs.size()]
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
			add_child(sp)
			bg_sprites.append(sp)
			bg_h_list.append(h)
			total_cover += h
			y_cursor -= h
			idx += 1
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
	if use_image:
		for i in bg_sprites.size():
			var sp: Sprite2D = bg_sprites[i]
			sp.position.y += scroll_speed * delta
			var h: float = bg_h_list[i]
			if sp.position.y - h / 2.0 > 1100:
				sp.position.y -= total_cover
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

func _draw() -> void:
	if use_image:
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

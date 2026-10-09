extends Node2D
# Super laser sustentado: sai da nave ate o topo por 2s, segue o bico

var player: Node2D = null
var life := 2.0
var age := 0.0
var fx: Sprite2D = null

func setup(p: Node2D) -> void:
	player = p

func _ready() -> void:
	fx = Sprite2D.new()
	fx.texture = _fazer_textura_feixe()
	if ResourceLoader.exists("res://assets/laser_rgb.gdshader"):
		var sh := load("res://assets/laser_rgb.gdshader") as Shader
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("speed", 7.0)
		fx.material = mat
	add_child(fx)

func _fazer_textura_feixe() -> ImageTexture:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - dx, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func base_y() -> float:
	if player != null and is_instance_valid(player):
		return player.position.y - 60.0
	return 800.0

func _process(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0 or player == null or not is_instance_valid(player) or not player.visible:
		queue_free()
		return
	position = Vector2(player.position.x, base_y())
	var comp := maxf(100.0, position.y)
	fx.scale = Vector2(1.1, comp / 256.0)
	fx.position = Vector2(0, -comp / 2.0)
	# fade in/out
	var a := 1.0
	if age < 0.15:
		a = age / 0.15
	elif life < 0.4:
		a = maxf(0.0, life / 0.4)
	modulate.a = a
	queue_redraw()

func _draw() -> void:
	var comp := maxf(100.0, position.y if position.y > 0.0 else 800.0)
	# vortice na boca
	var base := Vector2.ZERO
	var flash := 0.7 + 0.3 * sin(age * 31.0)
	draw_circle(base, 16.0 * flash + 4.0, Color(1, 1, 1, 0.85))
	draw_circle(base, 24.0 * flash + 6.0, Color(1, 0.85, 0.4, 0.5))
	draw_arc(base, 26.0, age * 3.2, age * 3.2 + 4.4, 24, Color(1, 0.6, 0.12, 0.9), 3.5)
	draw_arc(base, 36.0, -age * 2.3 + 1.0, -age * 2.3 + 4.8, 24, Color(0.25, 0.95, 1.0, 0.85), 2.5)
	draw_arc(base, 47.0, age * 4.1 + 2.0, age * 4.1 + 6.9, 28, Color(0.7, 0.3, 1.0, 0.7), 2.0)
	# relampagos pela coluna toda (regerados a cada frame)
	var rng := RandomNumberGenerator.new()
	var passo := int(age / 0.07)
	for lado in [-1, 1]:
		for linha in 2:
			rng.seed = passo * 131 + lado * 17 + linha * 101 + 999
			var pts := PackedVector2Array()
			var x := float(lado) * (16.0 + float(linha) * 8.0)
			var y := 0.0
			pts.append(Vector2(x, y))
			while y > -comp:
				y -= rng.randf_range(30.0, 60.0)
				x = float(lado) * rng.randf_range(10.0, 34.0)
				pts.append(Vector2(x, y))
			var cor := Color(0.3, 1.0, 1.0, 0.9) if (linha + (1 if lado > 0 else 0)) % 2 == 0 else Color(1.0, 0.3, 1.0, 0.9)
			draw_polyline(pts, cor, 2.0)
	rng.seed = passo * 57 + 7
	for i in 14:
		var fxp := rng.randf_range(-26.0, 26.0)
		var fyp := -rng.randf_range(0.0, comp)
		var cc := Color(1, 0.9, 0.4, 0.9) if i % 3 == 0 else (Color(0.4, 1, 1, 0.9) if i % 3 == 1 else Color(1, 0.4, 1, 0.9))
		draw_circle(Vector2(fxp, fyp), rng.randf_range(1.5, 3.5), cc)

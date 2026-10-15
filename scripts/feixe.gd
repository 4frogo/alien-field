extends Node2D
# Super laser VERDE SUSTENTADO: sai da nave ate o topo por 2s, seguindo o
# bico. Usa a arte dos 3 feixes (GREENLIGHT) + shader verde animado.
# Nao ha mais nenhum vestigio do feixe branco/roxo antigo.

var player: Node2D = null
var life := 2.0
var age := 0.0
var fx: Sprite2D = null
var fx_mat: ShaderMaterial = null
var halo: Sprite2D = null

# Proporcao do feixe: fino e alto (a arte e larga, esprememos no X)
const SX := 0.26
const SY := 0.36
const REF := 800.0


func setup(p: Node2D) -> void:
	player = p


func _ready() -> void:
	var tex: Texture2D = _textura_feixe()
	var sh: Shader = null
	if ResourceLoader.exists("res://assets/laser_verde.gdshader"):
		sh = load("res://assets/laser_verde.gdshader") as Shader

	# halo aditivo largo e tênue (esverdeia o fundo em volta do feixe)
	halo = Sprite2D.new()
	halo.texture = tex
	halo.position = Vector2(0, -REF * 0.5)
	halo.scale = Vector2(SX * 1.5, SY)
	halo.modulate = Color(0.08, 0.90, 0.26, 0.10)
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = mat_add
	if sh != null:
		var mh := ShaderMaterial.new()
		mh.shader = sh
		mh.set_shader_parameter("speed", 5.0)
		mh.set_shader_parameter("intensidade", 0.30)
		halo.material = mh
	add_child(halo)

	# feixe principal (blend normal)
	fx = Sprite2D.new()
	fx.texture = tex
	fx.position = Vector2(0, -REF * 0.5)
	fx.scale = Vector2(SX, SY)
	if sh != null:
		fx_mat = ShaderMaterial.new()
		fx_mat.shader = sh
		fx_mat.set_shader_parameter("speed", 6.5)
		fx_mat.set_shader_parameter("intensidade", 0.72)
		fx.material = fx_mat
	add_child(fx)


func _textura_feixe() -> Texture2D:
	if ResourceLoader.exists("res://assets/laser_verde.png"):
		return load("res://assets/laser_verde.png")
	# fallback: coluna verde simples (nunca deve aparecer)
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			img.set_pixel(x, y, Color(0.15, 1.0, 0.35, clampf(1.0 - dx, 0.0, 1.0)))
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
	# escala proporcional: o feixe sempre cobre da boca ate o topo
	var k := comp / REF
	var bal := 1.0 + 0.06 * sin(age * 5.5) + 0.04 * sin(age * 9.3 + 1.0)
	fx.scale = Vector2(SX * k * bal, SY * k)
	fx.position = Vector2(0, -comp * 0.5)
	if halo != null:
		halo.scale = Vector2(SX * 1.5 * k * (1.0 + 0.10 * sin(age * 2.2)),
			SY * k)
		halo.position = Vector2(0, -comp * 0.5)
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

	# ---- boca do canhao: tudo verde
	var base := Vector2.ZERO
	var flash := 0.7 + 0.3 * sin(age * 31.0)
	draw_circle(base, 54.0, Color(0.08, 0.80, 0.24, 0.16))
	draw_circle(base, 34.0, Color(0.18, 1.0, 0.34, 0.20))
	draw_circle(base, 16.0 * flash + 4.0, Color(0.60, 1.0, 0.60, 0.50))
	draw_circle(base, 8.0 * flash + 3.0, Color(0.90, 1.0, 0.88, 0.70))
	draw_arc(base, 26.0, age * 3.2, age * 3.2 + 4.4, 24, Color(0.60, 1.0, 0.55, 0.85), 3.5)
	draw_arc(base, 36.0, -age * 2.3 + 1.0, -age * 2.3 + 4.8, 24, Color(0.18, 0.95, 0.34, 0.80), 2.5)
	draw_arc(base, 47.0, age * 4.1 + 2.0, age * 4.1 + 6.9, 28, Color(0.10, 0.80, 0.25, 0.65), 2.0)

	# ---- relampagos verdes serpenteando pelos 3 feixes
	var rng := RandomNumberGenerator.new()
	var passo := int(age / 0.06)
	for i in 9:
		rng.seed = passo * 131 + i * 613
		var faixa := float(i % 3) - 1.0      # -1, 0, 1 = os 3 feixes
		var pts := PackedVector2Array()
		var y := 0.0
		pts.append(Vector2(faixa * 62.0, y))
		var guarda := 0
		while y > -comp and guarda < 300:
			y -= rng.randf_range(28.0, 62.0)
			pts.append(Vector2(faixa * 62.0 + rng.randf_range(-16.0, 16.0), y))
			guarda += 1
		if pts.size() < 2:
			continue
		var cor := Color(0.20, 1.0, 0.36, 0.85) if i % 2 == 0 else Color(0.70, 1.0, 0.70, 0.80)
		draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.16), 6.0)
		draw_polyline(pts, cor, 2.0)

	# ---- bolhas subindo no miolo
	for i in 9:
		var faixa2 := float(i % 3) - 1.0
		rng.seed = passo * 77 + i * 149
		var f := fmod(age * 0.55 + float(i) * 0.11, 1.0)
		var by := -f * comp
		var bal := sin(f * PI)
		draw_circle(Vector2(faixa2 * 62.0 + rng.randf_range(-10.0, 10.0), by),
			3.4 + 3.0 * bal, Color(0.22, 1.0, 0.36, 0.22 * bal))
		draw_circle(Vector2(faixa2 * 62.0, by), 1.6 + 1.4 * bal,
			Color(0.85, 1.0, 0.88, 0.55 * bal))

	# ---- aneis de energia subindo
	for i in 5:
		var f2: float = fmod(age * 0.6 + float(i) / 5.0, 1.0)
		var y2 := -f2 * comp
		var larg: float = 96.0 - 26.0 * f2
		var a2: float = sin(f2 * PI) * 0.5
		draw_arc(Vector2(0, y2), larg, 0.0, TAU, 30,
			Color(0.22, 1.0, 0.36, a2 * 0.15), 6.0, true)
		draw_arc(Vector2(0, y2), larg * 0.55, 0.0, TAU, 24,
			Color(0.72, 1.0, 0.78, a2 * 0.22), 2.5, true)

	# ---- faiscas verdes pela coluna
	rng.seed = passo * 57 + 7
	for i in 18:
		var fx2 := rng.randf_range(-92.0, 92.0)
		var fy := -rng.randf_range(0.0, comp)
		var cc := Color(0.72, 1.0, 0.78, 0.85) if i % 2 == 0 else Color(0.20, 1.0, 0.36, 0.85)
		var tam := rng.randf_range(1.5, 3.6)
		draw_circle(Vector2(fx2, fy), tam * 2.2, Color(cc.r, cc.g, cc.b, 0.15))
		draw_circle(Vector2(fx2, fy), tam, cc)

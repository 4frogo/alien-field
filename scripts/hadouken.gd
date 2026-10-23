extends Node2D
# HADOUKEN - super tiro carregado da nave ROXA
#
# Estilo Akuma (Marvel vs Capcom): a nave carrega a energia na boca
# (bola crescendo com fumaca rastejando) e ao soltar cuspe um FEIXE
# GROSSO de plasma: miolo branco-quente, cascas de violeta em volta,
# vibrando como se tivesse peso. O feixe vai RETO (a direcao trava no
# momento do disparo, mirando o inimigo mais proximo) e atravessa a
# tela inteira.
#
# Tudo desenhado por codigo, em camadas — igual os propulsores.
# O dano e aplicado pelo _dano_do_raio() do main.gd atraves de
# atingido(), entao segue a MESMA regra do raio triplo: nave pequena
# eletrocucada na hora, protetora morre no raio, chefe so atordoa.

var player: Node2D = null
var life := 1.15
var age := 0.0
var alvo := Vector2(0, -600)
var tem_alvo := false
var alvo_nodo: Node2D = null
var glow: Sprite2D = null

# direcao do feixe: trava no primeiro frame com alvo (estilo hadouken:
# o disparo sai uma vez e vai reto, nao acompanha o alvo)
var _dir := Vector2(0, -1)
var _travado := false
# rastro de particulas que se desfaz pra frente quando o raio termina
var _particulas: Array = []
# comprimento total do feixe (chega longe da tela)
const ALCANCE := 1100.0

# paleta: na nave ROXA a labareda e violeta com nucleo branco (a versao
# verde existe so como fallback da nave padrao)
var roxo := false


func _t(c: Color) -> Color:
	# paleta agora e rosa -> branco, desenhada direto (sem remapeamento)
	return c


func setup(p: Node2D) -> void:
	player = p
	roxo = Escolha.e_roxa()


func _ready() -> void:
	glow = Sprite2D.new()
	glow.texture = _textura_radial()
	glow.modulate = Color(1.0, 0.30, 0.65, 0.40)
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat_add
	add_child(glow)


func _textura_radial(tam: int = 128) -> ImageTexture:
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := float(tam) * 0.5
	for y in tam:
		for x in tam:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 0.35, 0.70, a))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ feixe

func comprimento() -> float:
	return ALCANCE


func _travar_direcao() -> void:
	# feixe RETO pra cima: nao persegue o inimigo, vai vertical sempre
	_dir = Vector2(0, -1)


func _process(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0 or player == null or not is_instance_valid(player) or not player.visible:
		queue_free()
		return
	# a boca do canhao acompanha a nave (o jogador desliza o feixe na tela)
	position = Vector2(player.position.x, player.position.y - 40.0)
	if alvo_nodo != null and is_instance_valid(alvo_nodo):
		alvo = alvo_nodo.position
		tem_alvo = true
	if not _travado and tem_alvo:
		_travar_direcao()
		_travado = true
	if glow != null:
		var gs := 120.0 + 12.0 * sin(age * 24.0)
		glow.scale = Vector2(gs / 64.0, gs / 64.0)
	var a := 1.0
	if age < 0.08:
		a = age / 0.08
	elif life < 0.30:
		a = maxf(0.0, life / 0.30)
	modulate.a = a

	# (rastro de particulas removido: feixe puro de luz)
	queue_redraw()


# colisao: um feixe RETO nessa direcao, faixa de largura ~46 + tol
func atingido(p: Vector2, tol: float = 26.0) -> bool:
	if not _travado:
		var pv := alvo if tem_alvo else Vector2(0, -600)
		_dir = (pv - position).normalized()
		if _dir.length() < 0.01 or is_nan(_dir.x):
			_dir = Vector2(0, -1)
	var lp := p - position
	var proj: float = lp.dot(_dir)
	if proj < -20.0 or proj > comprimento() + 40.0:
		return false
	return absf(lp.cross(_dir)) <= (40.0 + tol)


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	var pulsa: float = 0.88 + 0.12 * sin(age * 31.0)
	# o feixe tremer na largura: energia "viva"
	var larg := 1.0 + 0.05 * sin(age * 47.0 + 1.0)
	# pequena ondulacao perpendicular na boca (arrepio do jato)
	var voa: float = sin(age * 53.0) * 1.6

	# ---- camadas de casca, da mais larga fumaca ao nucleo BRANCO
	var camadas := [
		[1.00, Color(0.55, 0.05, 0.35, 0.16)],
		[0.86, Color(0.75, 0.12, 0.45, 0.30)],
		[0.70, Color(0.90, 0.25, 0.55, 0.52)],
		[0.50, Color(0.98, 0.40, 0.65, 0.74)],
		[0.32, Color(1.00, 0.70, 0.82, 0.90)],
		[0.18, Color(1.00, 1.00, 1.00, 1.00)],
	]
	for cam in camadas:
		var w: float = 78.0 * cam[0] * larg * pulsa
		var fim := _dir * comprimento()
		# leve tremor perpendicular so no comeco do feixe
		var ini := _dir.orthogonal() * voa
		draw_line(ini, fim, _t(cam[1]), w, false)

	# ---- branco extra no miolo perto da boca (o "cuspe" mais quente)
	var boca := _dir * 60.0
	draw_circle(boca, 11.0 * pulsa, Color(1.0, 1.0, 1.0, 0.55))
	# ---- faiscas saltando da boca
	var rng := RandomNumberGenerator.new()
	rng.seed = int(age * 30.0) * 37 + 11
	for k in 4:
		var f0: float = fmod(age * 2.2 + float(k) * 0.27, 1.0)
		var sp := _dir * (40.0 + f0 * 140.0) + _dir.orthogonal() * rng.randf_range(-26.0, 26.0)
		draw_circle(sp, 2.0, Color(1.0, 0.92, 1.0, 0.6 * (1.0 - f0)))

	# ---- raios negros: relampagos pretos saltando do feixe (estilo Akuma)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = int(age * 14.0) * 7919 + 3
	var L := comprimento()
	for a in 7:
		var t0: float = rng2.randf_range(0.06, 0.88)
		var base_pt := _dir * (t0 * L)
		var perp := _dir.orthogonal()
		var segs := PackedVector2Array()
		segs.append(base_pt)
		var cur := base_pt
		for s in 6:
			cur = cur + _dir * rng2.randf_range(10.0, 26.0) + perp * rng2.randf_range(-22.0, 22.0)
			segs.append(cur)
		draw_polyline(segs, Color(0.0, 0.0, 0.0, 0.85), 2.6, false)
		draw_polyline(segs, Color(1.0, 0.7, 0.85, 0.30), 1.0, false)

	# (sem rastro de particulas)

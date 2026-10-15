extends Node2D
# SUPER LASER VERDE — TRIPLO SERPENTE
#
# Tres raios verdes independentes saem dos 3 motores da nave e sobem em
# direcao ao inimigo mais proximo, ondulando como cobras de energia que
# convergem no alvo. Tudo desenhado por codigo (a arte estatica nao daria
# para serpentear), em camadas: halo -> corpo -> nucleo.
#
# Nao ha mais nenhum vestigio do feixe branco/roxo antigo.

var player: Node2D = null
var life := 2.0
var age := 0.0
var alvo := Vector2(0, -600)     # ponto de convergencia (inimigo)
var tem_alvo := false
var glow: Sprite2D = null

# Os 3 raios saem do MESMO ponto (centro/nucleo da nave) e abrem em leque
# conforme sobem. Depois eles serpenteiam e se cruzam (entrelacados).
const ABERTURA := 52.0   # quanto o leque abre ate a largura final
const SEG := 34          # segmentos por raio


func setup(p: Node2D) -> void:
	player = p


func _ready() -> void:
	# halo aditivo na boca do canhao
	glow = Sprite2D.new()
	glow.texture = _textura_radial()
	glow.modulate = Color(0.10, 0.95, 0.28, 0.30)
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
			img.set_pixel(x, y, Color(0.20, 1.0, 0.40, a))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ caminho

# Ponto do raio na altura y (y<0 = acima da boca).
# O raio vai em LINHA RETA (sobe reto) mas serpenteia: a amplitude e
# constante do inicio ao fim, entao ele nunca "converge" — atravessa a tela
# inteira. As 3 fases sao defasadas, entao eles se CRUZAM o caminho todo
# (efeito de tranca entrelacada).
func _ponto(i: int, f: float) -> Vector2:
	var total: float = comprimento()

	# leque: nasce tudo em x=0 (nucleo da nave) e abre nos 22% primeiros
	var abre: float = smoothstep(0.0, 0.22, f)
	var leque: float = (float(i) - 1.0)      # -1, 0, +1
	var base_x := leque * ABERTURA * abre

	# direcao base: se ha alvo, inclina levemente na direcao dele
	if tem_alvo:
		base_x += lerpf(0.0, clampf(alvo.x - position.x, -70.0, 70.0), 0.35) * abre

	# amplitude: zero na boca (nasce juntinho) e cheia depois
	var amp: float = (34.0 + 16.0 * impulso_local()) * (0.85 + 0.15 * float(i)) * abre

	# a serpente corre pelo caminho; fases separadas => os 3 se cruzam
	var corr := age * (5.0 + 0.8 * float(i)) + float(i) * 2.1
	var ondul: float = sin(f * 11.0 - corr) * amp
	# segunda harmonica: da o jeito de cobra, nao de seno
	ondul += sin(f * 21.0 - corr * 1.7 + 1.1) * amp * 0.32

	return Vector2(base_x + ondul, -total * f)


# Comprimento do raio: da boca ate ACIMA do topo da tela (y = -60).
# Assim ele sempre atravessa a tela inteira, tenha alvo ou nao.
func comprimento() -> float:
	return maxf(160.0, position.y + 100.0)


# Quanto mais recente o disparo, mais aberto o leque (0..1)
func impulso_local() -> float:
	return clampf(age / 0.25, 0.0, 1.0)


# Testa se um ponto do mundo esta sobre alguma das 3 mechas.
# Precisa disso porque o raio serpenteia e se espalha: a caixa de colisao
# antiga era um retangulo em volta da nave e errava o visual.
func atingido(p: Vector2, tol: float = 26.0) -> bool:
	var total := comprimento()
	var lp := p - position
	# so vale na faixa vertical do raio (da boca ate passar do topo)
	if lp.y > 30.0 or lp.y < -total - 40.0:
		return false
	var f: float = clampf(-lp.y / maxf(total, 1.0), 0.0, 1.0)
	for i in 3:
		if lp.distance_to(_ponto(i, f)) <= tol:
			return true
	return false


# ------------------------------------------------------------------ desenho

func _process(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0 or player == null or not is_instance_valid(player) or not player.visible:
		queue_free()
		return
	position = Vector2(player.position.x, player.position.y - 40.0)

	if glow != null:
		var gs := 52.0 + 10.0 * sin(age * 22.0)
		glow.scale = Vector2(gs / 64.0, gs / 64.0)
		glow.position = Vector2(0, 12)

	# fade in/out
	var a := 1.0
	if age < 0.12:
		a = age / 0.12
	elif life < 0.35:
		a = maxf(0.0, life / 0.35)
	modulate.a = a
	queue_redraw()


func _draw() -> void:
	if not tem_alvo:
		alvo = Vector2(0, -620)

	# ---- monta os 3 caminhos uma vez e reaproveita pra todas as camadas
	var caminhos: Array = []
	for i in 3:
		var pts := PackedVector2Array()
		for s in range(SEG + 1):
			pts.append(_ponto(i, float(s) / float(SEG)))
		caminhos.append(pts)

	for i in 3:
		var pts: PackedVector2Array = caminhos[i]
		var fase := float(i) * 1.9
		var pulsa: float = 0.85 + 0.15 * sin(age * 13.0 + fase)

		# --- 5 camadas: da mais larga/fraca pra mais fina/quente
		draw_polyline(pts, Color(0.05, 0.60, 0.18, 0.12 * pulsa), 42.0, true)
		draw_polyline(pts, Color(0.08, 0.90, 0.26, 0.24 * pulsa), 26.0, true)
		draw_polyline(pts, Color(0.18, 1.00, 0.34, 0.55 * pulsa), 15.0, true)
		draw_polyline(pts, Color(0.45, 1.00, 0.52, 0.85 * pulsa), 7.0, true)
		draw_polyline(pts, Color(0.88, 1.00, 0.80, 0.95 * pulsa), 2.6, true)

		# --- helicitos electricos saltando em volta do raio
		var rng := RandomNumberGenerator.new()
		var passo := int(age / 0.05) + i * 37
		rng.seed = passo * 977
		for k in 5:
			var f: float = fmod(age * 0.85 + float(k) * 0.2 + float(i) * 0.33, 1.0)
			var idx: int = clampi(int(f * float(SEG)), 0, SEG)
			var p: Vector2 = pts[idx]
			var pulso2: float = sin(f * PI)
			var r: float = 6.0 + 10.0 * rng.randf()
			var nv := PackedVector2Array()
			for e in 5:
				var ang := rng.randf_range(0.0, TAU)
				var rr := r * (0.4 + 0.6 * float(e) / 4.0)
				nv.append(p + Vector2(cos(ang), sin(ang)) * rr)
			draw_polyline(nv, Color(0.55, 1.0, 0.62, 0.55 * pulso2), 1.8, true)

		# --- nos de energia correndo pelo raio ate o alvo
		for n in 3:
			var f2: float = fmod(age * 1.15 + float(n) * 0.33 + float(i) * 0.15, 1.0)
			var idx2: int = clampi(int(f2 * float(SEG)), 0, SEG)
			var p2: Vector2 = pts[idx2]
			var bal := sin(f2 * PI)
			draw_circle(p2, 7.0 * bal + 2.0, Color(0.20, 1.0, 0.34, 0.22 * bal))
			draw_circle(p2, 3.0 * bal + 1.0, Color(0.85, 1.0, 0.85, 0.70 * bal))

		# --- faiscas orbitando o raio
		rng.seed = passo * 613 + 11
		for s in 6:
			var f3: float = rng.randf()
			var idx3: int = clampi(int(f3 * float(SEG)), 0, SEG)
			var p3: Vector2 = pts[idx3]
			var ang2 := age * 6.0 + float(s) * 1.1 + float(i)
			var off := Vector2(cos(ang2), sin(ang2)) * (10.0 + 6.0 * sin(age * 9.0 + float(s)))
			var cc := Color(0.70, 1.0, 0.72, 0.75) if s % 2 == 0 else Color(0.20, 1.0, 0.36, 0.75)
			var tam := 1.4 + 1.4 * sin(age * 12.0 + float(s))
			draw_circle(p3 + off, tam * 2.4, Color(cc.r, cc.g, cc.b, 0.14))
			draw_circle(p3 + off, tam, cc)

		# --- a ponta sai do topo da tela: some em vez de "bater" em algo
		var ponta: Vector2 = pts[SEG]
		for e2 in 4:
			var t: float = 0.35 + 0.22 * float(e2)
			var idx: int = clampi(int((1.0 - t) * float(SEG)), 0, SEG)
			var pp: Vector2 = pts[idx]
			var ap: float = (1.0 - t) * 0.35 * pulsa
			draw_circle(pp, (5.0 + 3.0 * t) * pulsa, Color(0.35, 1.0, 0.45, ap))
		# faiscas se abrindo na saida
		for r2 in 6:
			var a3 := age * 2.4 + float(r2) * 1.05 + float(i)
			var d3 := 14.0 + 10.0 * sin(age * 11.0 + float(r2))
			draw_line(ponta, ponta + Vector2(cos(a3), sin(a3)) * d3,
				Color(0.60, 1.0, 0.62, 0.28 * pulsa), 2.0, true)

	# ---- boca do canhao: UM so ponto no nucleo da nave, de onde saem os 3
	var b := Vector2(0, 0)
	var fl: float = 0.7 + 0.3 * sin(age * 29.0)
	draw_circle(b, 46.0 * fl, Color(0.06, 0.70, 0.20, 0.13))
	draw_circle(b, 28.0 * fl, Color(0.12, 0.92, 0.28, 0.20))
	draw_circle(b, 14.0 * fl, Color(0.35, 1.0, 0.42, 0.34))
	draw_circle(b, 6.0 * fl, Color(0.90, 1.0, 0.88, 0.75))
	# dois aneis girando em sentidos opostos
	var r1 := age * 4.0
	var r2 := -age * 3.1 + 1.4
	draw_arc(b, 17.0, r1, r1 + 2.6, 18, Color(0.60, 1.0, 0.58, 0.60), 2.0, true)
	draw_arc(b, 27.0, r2, r2 + 1.9, 16, Color(0.25, 1.0, 0.40, 0.45), 1.6, true)
	# faiscas girando na boca
	for k in 6:
		var a := age * 5.0 + float(k) * 1.05
		var d := 20.0 + 7.0 * sin(age * 8.0 + float(k))
		draw_circle(b + Vector2(cos(a), sin(a)) * d, 2.0,
			Color(0.70, 1.0, 0.72, 0.65))
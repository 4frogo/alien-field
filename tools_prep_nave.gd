extends SceneTree

# Prepara uma arte de nave como sprite solido.
#
# Por que precisa disso: as imagens chegam como 24bpp (sem alfa) com fundo
# preto chapado. Um flood fill direto so quebra porque ele DESCE pelas
# frestas escuras entre as placas do casco (elas tocam o exterior) e leva o
# detalhe interno junto. No tamanho de jogo (minificacao de ~8x) a nave
# inteira vira uma mistura de cor e vazio e parece transparente.
#
# A correcao e o closing morfologico ANTES do flood: sela as frestas de
# ate ~2*RAIO pixels reais, sem tocar nos vaos largos entre as pontas.
#
# Uso: -- <entrada> <saida>

const DIV := 2           # reducao da mascara de trabalho
const RAIO := 6          # raio do closing na mascara (= 12px reais cada lado)
const PRETO := 60        # abaixo disso o pixel conta como fundo
const BORDA_LO := 20.0
const BORDA_HI := 60.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	var img := Image.load_from_file(args[0])
	if img == null:
		print("ERRO: nao abriu ", args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var W: int = img.get_width()
	var H: int = img.get_height()
	var total: int = W * H
	var buf := img.get_data()
	var mw: int = W / DIV
	var mh: int = H / DIV

	# ---- 1. mascara da arte -------------------------------------------
	var casco := PackedByteArray()
	casco.resize(mw * mh)
	for my in mh:
		var y0: int = my * DIV
		for mx in mw:
			var v := 0
			for dy in DIV:
				var b: int = (y0 + dy) * W * 4 + (mx * DIV) * 4
				for dx in DIV:
					if maxi(maxi(int(buf[b + dx * 4]), int(buf[b + dx * 4 + 1])),
							int(buf[b + dx * 4 + 2])) >= PRETO:
						v = 1
						break
				if v == 1:
					break
			casco[my * mw + mx] = v

	# ---- 2. closing separavel (dilata + erode) -> veda as frestas -----
	var selo := _dilata_v(_dilata_h(casco, mw, mh, RAIO), mw, mh, RAIO)
	selo = _erode_v(_erode_h(selo, mw, mh, RAIO), mw, mh, RAIO)

	# ---- 3. flood do fundo a partir da borda --------------------------
	var fora := PackedByteArray()
	fora.resize(mw * mh)
	var pilha := PackedInt32Array()
	for mx in mw:
		pilha.append(mx)
		pilha.append((mh - 1) * mw + mx)
	for my in mh:
		pilha.append(my * mw)
		pilha.append(my * mw + mw - 1)

	var visitados := 0
	while not pilha.is_empty():
		var i: int = pilha[pilha.size() - 1]
		pilha.remove_at(pilha.size() - 1)
		if fora[i] == 1:
			continue
		if selo[i] == 1:
			continue                      # casco selado: a flood para
		fora[i] = 1
		visitados += 1
		var x: int = i % mw
		var y: int = i / mw
		if x > 0:
			pilha.append(i - 1)
		if x < mw - 1:
			pilha.append(i + 1)
		if y > 0:
			pilha.append(i - mw)
		if y < mh - 1:
			pilha.append(i + mw)

	# ---- 4. escrever o alpha ------------------------------------------
	var solidos := 0
	var borda := 0
	for y in H:
		var linha: int = (y / DIV) * mw
		var base: int = y * W * 4
		for x in W:
			var i: int = linha + x / DIV
			var b: int = base + x * 4
			if fora[i] == 0:
				buf[b + 3] = 255
				solidos += 1
			else:
				var mx2: float = maxf(maxf(float(buf[b]), float(buf[b + 1])),
						float(buf[b + 2]))
				var t := clampf((mx2 - BORDA_LO) / (BORDA_HI - BORDA_LO), 0.0, 1.0)
				var v2 := t * t * (3.0 - 2.0 * t)
				buf[b + 3] = int(v2 * 255.0)
				if v2 > 0.001:
					borda += 1

	img.set_data(W, H, false, Image.FORMAT_RGBA8, buf)
	img.save_png(args[1])
	print("tamanho        : ", W, "x", H)
	print("fundo removido : ", snappedf(100.0 * float(visitados) / float(total), 1), "%")
	print("casco solido   : ", snappedf(100.0 * float(solidos) / float(total), 1), "%")
	print("borda suave    : ", snappedf(100.0 * float(borda) / float(total), 2), "%")
	print("levou          : ", snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 1), "s")
	print("salvo: ", args[1])
	quit()


# ---- morfologia separavel: um passe horizontal + um vertical ------------
# equivale ao quadrado 2D, mas custa 2*(2r+1) em vez de (2r+1)^2

func _dilata_h(s: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(w * h)
	for y in h:
		var b := y * w
		for x in w:
			var v := 0
			var x0: int = maxi(0, x - r)
			var x1: int = mini(w - 1, x + r)
			for xx in range(x0, x1 + 1):
				if s[b + xx] == 1:
					v = 1
					break
			o[b + x] = v
	return o


func _dilata_v(s: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(w * h)
	for x in w:
		for y in h:
			var v := 0
			var y0: int = maxi(0, y - r)
			var y1: int = mini(h - 1, y + r)
			for yy in range(y0, y1 + 1):
				if s[yy * w + x] == 1:
					v = 1
					break
			o[y * w + x] = v
	return o


func _erode_h(s: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(w * h)
	for y in h:
		var b := y * w
		for x in w:
			var v := 1
			var x0: int = maxi(0, x - r)
			var x1: int = mini(w - 1, x + r)
			for xx in range(x0, x1 + 1):
				if s[b + xx] == 0:
					v = 0
					break
			o[b + x] = v
	return o


func _erode_v(s: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(w * h)
	for x in w:
		for y in h:
			var v := 1
			var y0: int = maxi(0, y - r)
			var y1: int = mini(h - 1, y + r)
			for yy in range(y0, y1 + 1):
				if s[yy * w + x] == 0:
					v = 0
					break
			o[y * w + x] = v
	return o

extends Node
# Psytrance simples - baixo rolante + kick 4x4 em loop
# Se colocar assets/musica.ogg/.mp3/.wav ele usa seu arquivo

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = -10.0
	add_child(player)
	for p in ["res://assets/musica.ogg", "res://assets/musica.mp3", "res://assets/musica.wav"]:
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s != null:
				player.stream = s
				player.play()
				return
	player.stream = _gerar_psy()
	player.play()

func trocar_para_transicao() -> void:
	if player == null:
		return
	for p in ["res://assets/Starship Interceptorv1.mp3", "res://assets/Starship Interceptorv1.ogg", "res://assets/Starship Interceptorv1.wav"]:
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s != null:
				player.stream = s
				player.play()
				return

func trocar_para_boss() -> void:
	if player == null:
		return
	for p in ["res://assets/musica_boss.ogg", "res://assets/musica_boss.mp3", "res://assets/boss_music.wav"]:
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s != null:
				player.stream = s
				player.play()
				return
	player.stream = _gerar_tempestade()
	player.play()

func trocar_para_normal() -> void:
	if player == null:
		return
	for p in ["res://assets/musica.ogg", "res://assets/musica.mp3", "res://assets/musica.wav"]:
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s != null:
				player.stream = s
				player.play()
				return
	player.stream = _gerar_psy()
	player.play()

func set_pausado(p: bool) -> void:
	if player != null:
		player.stream_paused = p

func _gerar_tempestade() -> AudioStreamWAV:
	# tempestuoso: 152bpm, menor frigio, kick pesado, baixo dobrado, acido rapido
	var rate := 22050
	var bpm := 152.0
	var beat := 60.0 / bpm
	var s16 := beat / 4.0
	var roots := [33, 32, 31, 30] # A1 Ab1 G1 Gb1 descendo
	var total := 64
	var n := int(s16 * float(total) * float(rate))
	var mix := PackedFloat32Array()
	mix.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var pads_boss := [
		[57, 60, 64],
		[56, 60, 63],
		[55, 59, 62],
		[54, 58, 61],
	]
	for st in total:
		var a := int(float(st) * s16 * float(rate))
		var bar := st / 16
		var root: int = int(roots[bar % 4])
		var pos16 := st % 16
		if pos16 % 4 == 0:
			_kick(mix, a, 0, 1.0, rate)
		else:
			_bass(mix, a, 0, midi(root + 12 + (12 if pos16 % 2 == 0 else 0)), 0.42, rate)
		# hats 16ths corridos
		_hat(mix, a, 0, 0.12 if pos16 % 2 == 1 else 0.06, rng, rate)
		# lead tempestade polifonico: principal + terca + oitava
		var seq := [69, 70, 72, 74, 76, 74, 72, 70, 69, 70, 72, 76, 79, 76, 74, 70]
		var nl: int = int(seq[st % 16])
		_acid(mix, a, 0, midi(nl + 12), 0.15, rate, st)
		_acid(mix, a, 0, midi(nl + 8), 0.08, rate, st + 55)
		if pos16 % 4 == 2:
			_acid(mix, a, 0, midi(nl + 5), 0.05, rate, st + 21)
		if pos16 == 0:
			var chord: Array = pads_boss[bar % 4]
			var bar_len := int(s16 * 16.0 * float(rate))
			for ni in chord:
				_pad(mix, a, mini(n, a + bar_len), midi(int(ni)), 0.06, rate)
		if pos16 == 12:
			_snare(mix, a, 0, 0.25, rng, rate)
	var peak := 0.01
	for i in n:
		peak = maxf(peak, absf(mix[i]))
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		data[i] = int(clampf(mix[i] / peak * 0.88 * 127.0 + 128.0, 0, 255))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func midi(m: int) -> float:
	return 440.0 * pow(2.0, float(m - 69) / 12.0)

func _gerar_psy() -> AudioStreamWAV:
	var rate := 22050
	var bpm := 138.0
	var beat := 60.0 / bpm
	var s16 := beat / 4.0
	# 4 compassos x 16 = 64 passos
	var roots := [33, 33, 29, 31] # A1 A1 F1 G1 - psy escuro
	var total := 64
	var n := int(s16 * float(total) * float(rate))
	var mix := PackedFloat32Array()
	mix.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# pad polifonico por compasso (3 vozes sustentadas)
	var pads := [
		[57, 60, 64], # Am
		[53, 57, 60], # F
		[55, 60, 64], # C/G
		[55, 59, 62], # G
	]
	for st in total:
		var a := int(float(st) * s16 * float(rate))
		var b := mini(n, a + int(s16 * float(rate)))
		var bar := st / 16
		var root: int = int(roots[bar % 4])
		var pos16 := st % 16
		# kick 4x4
		if pos16 % 4 == 0:
			_kick(mix, a, b, 0.85, rate)
		else:
			# baixo rolante psy - serra curta, oitava alternada
			var oct := 12 if (pos16 % 4 == 3 or pos16 % 8 == 6) else 0
			_bass(mix, a, b, midi(root + 12 + oct), 0.34, rate)
		# hat fechado offbeat
		if pos16 % 2 == 1:
			_hat(mix, a, b, 0.10, rng, rate)
		# hat aberto no fim do compasso
		if pos16 == 14:
			_hat_long(mix, a, b, 0.14, rng, rate)
		# lead acido + harmonia em terca (polifonia a 2 vozes)
		if bar == 3 and pos16 % 2 == 0:
			var seq := [69, 72, 76, 79, 76, 72, 69, 67]
			var nl: int = int(seq[(pos16 / 2) % 8])
			_acid(mix, a, b, midi(nl), 0.13, rate, st)
			_acid(mix, a, b, midi(nl - 4), 0.07, rate, st + 99)
		elif pos16 == 0:
			_acid(mix, a, b, midi(root + 36), 0.09, rate, st)
			_acid(mix, a, b, midi(root + 36 - 3), 0.05, rate, st + 99)
		elif pos16 == 8:
			_acid(mix, a, b, midi(root + 36 + 3), 0.09, rate, st)
			_acid(mix, a, b, midi(root + 36), 0.05, rate, st + 99)
		# contra-arpejo suave nas 16ths (3a voz)
		if pos16 % 4 == 2:
			_acid(mix, a, b, midi(root + 36 + [0, 3, 7, 12][(pos16 / 4) % 4]), 0.045, rate, st + 7)
		# pad do compasso (acorde sustentado = 3 vozes juntas)
		if pos16 == 0:
			var chord: Array = pads[bar % 4]
			var bar_len := int(s16 * 16.0 * float(rate))
			for ni in chord:
				_pad(mix, a, mini(n, a + bar_len), midi(int(ni)), 0.05, rate)
		# snare/riser no ultimo passo
		if st == total - 1:
			_snare(mix, a, b, 0.2, rng, rate)
	var peak := 0.01
	for i in n:
		peak = maxf(peak, absf(mix[i]))
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var v := mix[i] / peak * 0.85
		data[i] = int(clampf(v * 127.0 + 128.0, 0, 255))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _pad(mix: PackedFloat32Array, a: int, b: int, freq: float, vol: float, rate: int) -> void:
	for i in range(a, b):
		var t := float(i) / float(rate)
		var k := float(i - a) / float(maxi(1, b - a))
		var env := sin(PI * clampf(k, 0.0, 1.0)) # swell
		mix[i] += (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.2) * vol * env

func _bass(mix: PackedFloat32Array, a: int, b: int, freq: float, vol: float, rate: int) -> void:
	for i in range(a, b):
		var t := float(i - a) / float(rate)
		var ph := fmod(freq * t, 1.0)
		var saw := ph * 2.0 - 1.0
		# filtro simples: atenua ataque
		var k := float(i - a) / float(maxi(1, b - a))
		var env := 1.0 - k * 0.7
		mix[i] += saw * vol * env * 0.7

func _acid(mix: PackedFloat32Array, a: int, b: int, freq: float, vol: float, rate: int, st: int) -> void:
	for i in range(a, b):
		var t := float(i) / float(rate)
		var wob := 1.0 + 0.02 * sin(TAU * 8.0 * t)
		var ph := fmod(freq * wob * t, 1.0)
		var saw := ph * 2.0 - 1.0
		var sq := 1.0 if ph < 0.5 else -1.0
		var s := saw * 0.7 + sq * 0.3
		var k := float(i - a) / float(maxi(1, b - a))
		mix[i] += s * vol * (1.0 - k * 0.5)

func _kick(mix: PackedFloat32Array, a: int, b: int, vol: float, rate: int) -> void:
	var fim := mini(mix.size(), a + int(float(rate) * 0.14))
	for i in range(a, fim):
		var k := float(i - a) / float(maxi(1, fim - a))
		var f := lerpf(150.0, 40.0, k)
		var t := float(i - a) / float(rate)
		mix[i] += sin(TAU * f * t) * vol * (1.0 - k * 0.8)

func _hat(mix: PackedFloat32Array, a: int, b: int, vol: float, rng: RandomNumberGenerator, rate: int) -> void:
	var fim := mini(mix.size(), a + int(float(rate) * 0.03))
	for i in range(a, fim):
		var k := 1.0 - float(i - a) / float(maxi(1, fim - a))
		mix[i] += rng.randf_range(-1.0, 1.0) * vol * k * 0.5

func _hat_long(mix: PackedFloat32Array, a: int, b: int, vol: float, rng: RandomNumberGenerator, rate: int) -> void:
	var fim := mini(mix.size(), a + int(float(rate) * 0.09))
	for i in range(a, fim):
		var k := 1.0 - float(i - a) / float(maxi(1, fim - a))
		mix[i] += rng.randf_range(-1.0, 1.0) * vol * k * 0.5

func _snare(mix: PackedFloat32Array, a: int, b: int, vol: float, rng: RandomNumberGenerator, rate: int) -> void:
	var fim := mini(mix.size(), a + int(float(rate) * 0.12))
	for i in range(a, fim):
		var k := 1.0 - float(i - a) / float(maxi(1, fim - a))
		mix[i] += rng.randf_range(-1.0, 1.0) * vol * k

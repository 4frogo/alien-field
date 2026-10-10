extends Node
# SFX procedural - sem precisar de arquivos, mas usa assets/*.wav se voce colocar

var players: Array = []
var idx := 0

var s_tiro: AudioStream = null
var s_tiro_ini: AudioStream = null
var s_boom: AudioStream = null
var s_hit: AudioStream = null
var s_boss: AudioStream = null
var s_carga1: AudioStream = null
var s_carga2: AudioStream = null
var s_pronta: AudioStream = null

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -6.0
		add_child(p)
		players.append(p)
	# tenta arquivos custom, senao gera procedural
	# tiro suave: 520->180Hz curto e baixo volume
	s_tiro = _carregar_ou_gerar("res://assets/tiro.wav", 520.0, 180.0, 0.09, 0.15)
	s_tiro_ini = _carregar_ou_gerar("res://assets/tiro_inimigo.wav", 280.0, 130.0, 0.15, 0.10)
	s_boom = _carregar_ou_gerar_noise("res://assets/explosao.wav", 0.6, 0.25)
	s_hit = _carregar_ou_gerar("res://assets/hit.wav", 200.0, 80.0, 0.25, 0.6)
	s_boss = _carregar_ou_gerar("res://assets/boss.wav", 110.0, 55.0, 0.8, 0.6)
	# energia carregando: subidas cada vez mais agudas + estouro de pronta
	s_carga1 = _gerar_subida(160.0, 480.0, 0.45, 0.30)
	s_carga2 = _gerar_subida(280.0, 760.0, 0.45, 0.32)
	s_pronta = _gerar_subida(220.0, 1250.0, 0.7, 0.36)

func _carregar_ou_gerar(path: String, f0: float, f1: float, dur: float, vol: float) -> AudioStream:
	if ResourceLoader.exists(path):
		var s := load(path) as AudioStream
		if s != null:
			return s
	return _gerar_tom(f0, f1, dur, vol)

func _carregar_ou_gerar_noise(path: String, dur: float, vol: float) -> AudioStream:
	if ResourceLoader.exists(path):
		var s := load(path) as AudioStream
		if s != null:
			return s
	return _gerar_noise(dur, vol)

func _gerar_tom(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var f := lerpf(f0, f1, float(i) / float(n))
		var k := float(i) / float(n)
		# ataque suave 8ms + decay exponencial = menos estridente
		var attack := minf(1.0, float(i) / (float(rate) * 0.008))
		var env := attack * pow(1.0 - k, 1.6)
		var v := sin(TAU * f * t) * vol * env
		data[i] = int(clampf(v * 127.0 + 128.0, 0, 255))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _gerar_subida(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	# energia sendo carregada: varredura subindo com crescendo e tremor
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var k := float(i) / float(n)
		var f := lerpf(f0, f1, pow(k, 1.4))
		var t := float(i) / float(rate)
		var attack := minf(1.0, float(i) / (float(rate) * 0.02))
		var env := attack * (0.25 + 0.75 * k)
		var v := sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.2 + sin(TAU * f * 0.5 * t) * 0.3
		v *= vol * env * (1.0 + 0.15 * sin(TAU * 9.0 * t))
		data[i] = int(clampf(v * 127.0 + 128.0, 0, 255))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _gerar_noise(dur: float, vol: float) -> AudioStreamWAV:
	# explosao realista: corpo grave + rumble filtrado, sem agudo estridente
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var lp := 0.0
	for i in n:
		var k := float(i) / float(n)
		var decay := pow(1.0 - k, 1.8)
		var attack := minf(1.0, float(i) / (float(rate) * 0.006))
		var env := attack * decay
		# corpo: seno caindo 105Hz -> 34Hz
		var f := lerpf(105.0, 34.0, pow(k, 0.6))
		var corpo := sin(TAU * f * float(i) / float(rate)) * 0.85
		# rumble: ruido passa-baixa (sem chiado)
		var ruid := rng.randf_range(-1.0, 1.0)
		lp += 0.12 * (ruid - lp)
		var v := (corpo + lp * 1.4) * vol * env
		data[i] = int(clampf(v * 127.0 + 128.0, 0, 255))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _tocar(s: AudioStream, pitch: float = 1.0) -> void:
	if s == null:
		return
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = s
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()

func tiro() -> void:
	_tocar(s_tiro, 1.0)

func tiro_inimigo() -> void:
	_tocar(s_tiro_ini, 1.0)

func explosao() -> void:
	_tocar(s_boom, 1.0)

func hit() -> void:
	_tocar(s_hit, 1.0)

func boss() -> void:
	_tocar(s_boss, 1.0)

func carga(nivel: int) -> void:
	# energia subindo: 1s e 2s de carga
	if nivel <= 1:
		_tocar(s_carga1, 1.0)
	else:
		_tocar(s_carga2, 1.0)

func pronta() -> void:
	_tocar(s_pronta, 1.0)

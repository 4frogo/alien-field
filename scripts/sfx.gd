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
var s_kill: AudioStream = null
var s_pickup: AudioStream = null
var s_stinger: AudioStream = null
var s_ui: AudioStream = null

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -14.0   # som dos efeitos (SFX) abaixado pra ~20%
		add_child(p)
		players.append(p)
	# tenta arquivos custom, senao gera procedural
	# tiro suave: 520->180Hz curto e baixo volume
	s_tiro = _carregar_ou_gerar("res://assets/tiro.wav", 520.0, 180.0, 0.09, 0.15)
	s_tiro_ini = _carregar_ou_gerar("res://assets/tiro_inimigo.wav", 280.0, 130.0, 0.15, 0.10)
	s_boom = _carregar_ou_gerar_explosao("res://assets/explosao.wav", 0.34, 0.30)
	s_hit = _carregar_ou_gerar("res://assets/hit.wav", 200.0, 80.0, 0.25, 0.6)
	s_boss = _carregar_ou_gerar("res://assets/boss.wav", 110.0, 55.0, 0.8, 0.6)
	# energia carregando: subidas cada vez mais agudas + estouro de pronta
	s_carga1 = _gerar_subida(160.0, 480.0, 0.45, 0.30)
	s_carga2 = _gerar_subida(280.0, 760.0, 0.45, 0.32)
	s_pronta = _gerar_subida(220.0, 1250.0, 0.7, 0.36)
	# impacto: kill seco, pickup subindo, stinger de morte, blip de ui
	s_kill = _gerar_blip(720.0, 0.09, 0.30)
	s_pickup = _gerar_pickup()
	s_stinger = _gerar_subida(420.0, 55.0, 0.9, 0.4)
	s_ui = _gerar_blip(980.0, 0.05, 0.16)

func _carregar_ou_gerar(path: String, f0: float, f1: float, dur: float, vol: float) -> AudioStream:
	if ResourceLoader.exists(path):
		var s := load(path) as AudioStream
		if s != null:
			return s
	return _gerar_tom(f0, f1, dur, vol)

func _carregar_ou_gerar_explosao(path: String, dur: float, vol: float) -> AudioStream:
	# usa o wav custom se existir, senao gera procedural
	if ResourceLoader.exists(path):
		var r := load(path) as AudioStream
		if r != null:
			return r
	return _gerar_explosao(dur, vol)

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

func _gerar_explosao(dur: float, vol: float) -> AudioStreamWAV:
	# EXPLOSAO curta e com presenca, sem virar lama grave.
	#
	# O som antigo caia em 34 Hz, abaixo do que alto-falante de celular
	# reproduz — no celular virava um "estrondo" sem definicao. Aqui o
	# grao para em 70 Hz (limite de quase todo celular) e ganha 4 camadas:
	#   - transiente: estouro agudo de ruido (o "estalo" que da precisao)
	#   - corpo: varredura de 200 -> 70 Hz (peso, mas audivel)
	#   - areia: ruido passa-banda medio (o "estalar")
	#   - sub: 78 Hz curto, so no comeco (sensacao de impacto)
	# 16 bits e 44.1 kHz: o de 8 bits soava sujo.
	var rate := 44100
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)   # 16 bits = 2 bytes por amostra
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240

	var lp_bruta := 0.0   # passa-baixa do estrondo
	var lp_areia := 0.0   # passa-baixa da "areia"
	var fase_corpo := 0.0 # fase acumulada da varredura (evita estalo)

	for i in n:
		var t := float(i) / float(rate)
		var k := float(i) / float(n)           # 0..1 no tempo
		var ruido := rng.randf_range(-1.0, 1.0)
		# ataque curtinho (2ms) pra nao comecar por cima
		var atk := minf(1.0, t / 0.002)

		# ---------- 1. TRANSIENTE (ate ~45ms): o estalo inicial
		# passa-alta: sinal - versao filtrada, e some rapido
		lp_bruta += 0.45 * (ruido - lp_bruta)
		var hp := ruido - lp_bruta
		var env_tr := pow(maxf(0.0, 1.0 - t / 0.045), 2.6)
		var transiente := hp * env_tr * 0.55

		# ---------- 2. CORPO: varredura 200 -> 70 Hz
		# pow no k faz a queda comecar rapida e terminar suave
		var f := lerpf(200.0, 70.0, pow(k, 0.75))
		fase_corpo += TAU * f / float(rate)
		var corpo := sin(fase_corpo) * pow(1.0 - k, 2.4) * atk * 0.80

		# ---------- 3. AREIA: ruido passa-banda medio, o "estalar"
		lp_areia += 0.22 * (ruido - lp_areia)
		var areia := (lp_areia * 2.0) * pow(1.0 - k, 3.4) * atk * 0.42

		# ---------- 4. SUB: 78 Hz, so no primeiro terco
		var sub := sin(TAU * 78.0 * t) * pow(maxf(0.0, 1.0 - k / 0.34), 3.0) * atk * 0.34

		# ---------- corte seco no fim: sem cauda comprida
		var fim := 1.0 - smoothstep(0.82, 1.0, k)

		var v := clampf((transiente + corpo + areia + sub) * vol * fim, -1.0, 1.0)
		var s16 := int(v * 32767.0)
		data[i * 2] = int(s16 & 0xFF)
		data[i * 2 + 1] = int((s16 >> 8) & 0xFF)

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _gerar_blip(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	# blip curto com ataque suave (kill confirm / ui)
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var attack := minf(1.0, float(i) / (float(rate) * 0.004))
		var env := attack * pow(1.0 - float(i) / float(n), 1.4)
		var v := (sin(TAU * freq * t) * 0.8 + sin(TAU * freq * 2.0 * t) * 0.2) * vol * env
		data[i] = int(clampf(v * 127.0 + 128.0, 0, 255))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _gerar_pickup() -> AudioStreamWAV:
	# duas notas subindo (power-up!)
	var rate := 22050
	var seq := [523.0, 784.0]
	var nota_dur := 0.09
	var passo := int(rate * nota_dur)
	var n := passo * 2 + 200
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var idx := mini(1, i / passo)
		var f: float = seq[idx]
		var t := float(i) / float(rate)
		var attack := minf(1.0, float(i - idx * passo) / (float(rate) * 0.005))
		var v := sin(TAU * f * t) * 0.32 * attack
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
	# DESLIGADO: esse estrondo grave (110->55Hz) era alto demais e aparecia
	# no portal, no super tiro e no game over. O usuario pediu para tirar.
	# Para reativar, descomente a linha abaixo.
	# _tocar(s_boss, 1.0)
	return

func carga(nivel: int) -> void:
	# energia subindo: 1s e 2s de carga
	if nivel <= 1:
		_tocar(s_carga1, 1.0)
	else:
		_tocar(s_carga2, 1.0)

func pronta() -> void:
	_tocar(s_pronta, 1.0)

func kill(combo: int = 0) -> void:
	# confirmacao de abate: sobe o tom com o combo
	_tocar(s_kill, 1.0 + minf(combo, 8) * 0.06)

func pickup() -> void:
	_tocar(s_pickup, 1.0)

func stinger() -> void:
	_tocar(s_stinger, 1.0)

func ui() -> void:
	_tocar(s_ui, 1.0)

extends Node2D

# Sequencia de explosao em 4 frames (tileset fatiado e chaveado).
#
# Cada frame tem sua propria duracao: o estouro e rapido, a bola de fogo
# segura um pouco, os cacos voam e o ultimo frame dissipa.
#
# Camadas:
#   - sprite principal (frames trocados manualmente, tempo nao uniforme)
#   - camada aditiva com o frame 0, que da o estouro de luz no comeco
#   - leve giro e escala de entrada

const TEMPOS := [0.075, 0.095, 0.105, 0.16]

var frames: Array = []
var idx := 0
var t_frame := 0.0
var t_total := 0.0
var forte := false
var tam := 300.0
var _tempo_alvo := 0.1

var _spr: Sprite2D
var _glow: Sprite2D
var _base := 1.0


func setup(p: Vector2, p_frames: Array, p_tam: float, p_forte: bool = false) -> void:
	position = p
	frames = p_frames
	tam = p_tam
	forte = p_forte

	_glow = Sprite2D.new()
	_glow.texture = frames[0] if frames.size() > 0 else null
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)

	_spr = Sprite2D.new()
	_spr.texture = _glow.texture
	add_child(_spr)

	_base = p_tam / 576.0
	var s0: float = 0.55 if not forte else 0.62
	_spr.scale = Vector2.ONE * (_base * s0)
	_glow.scale = Vector2.ONE * (_base * s0 * 1.15)
	rotation = randf_range(-0.05, 0.05)
	_aplica_branco()


func _aplica_branco() -> void:
	_tempo_alvo = TEMPOS[idx] * (1.3 if forte else 1.0)
	t_frame = 0.0
	_spr.texture = frames[idx]
	# no primeiro frame, estouro branco
	if idx == 0:
		_spr.modulate = Color(1.7, 1.6, 1.5, 1.0)
	else:
		_spr.modulate = Color(1, 1, 1, 1)


func _process(delta: float) -> void:
	if frames.is_empty() or _spr == null:
		queue_free()
		return

	t_frame += delta
	t_total += delta

	# avanca de frame quando o tempo deste acabar
	if t_frame >= _tempo_alvo:
		idx += 1
		if idx >= frames.size():
			queue_free()
			return
		_aplica_branco()

	# ---- escala: entra rapido, depois cresce leve enquanto dissipa
	var entrada: float = clampf(t_total / 0.09, 0.0, 1.0)
	var s: float = lerpf(0.55 if not forte else 0.62, 1.0, entrada)
	s = lerpf(s, 1.12, clampf((t_total - 0.24) / 0.24, 0.0, 1.0))
	_spr.scale = Vector2.ONE * (_base * s)

	# ---- alpha: so no ultimo frame
	if idx == frames.size() - 1:
		var k: float = clampf(t_frame / maxf(0.01, _tempo_alvo), 0.0, 1.0)
		_spr.modulate.a = 1.0 - k
	elif idx == 0:
		_spr.modulate = _spr.modulate.lerp(Color(1, 1, 1, 1), clampf(delta * 12.0, 0.0, 1.0))

	# ---- brilho aditivo: forte no comeco, some rapido
	var brilho: float = clampf(1.0 - t_total / 0.14, 0.0, 1.0)
	_glow.scale = Vector2.ONE * (_base * s * 1.18)
	_glow.modulate = Color(1.0, 0.55, 0.22, brilho * 0.85)
	_glow.rotation = -rotation * 0.5

	# ---- deriva e giro
	position.y -= 12.0 * delta
	rotation += 0.35 * delta
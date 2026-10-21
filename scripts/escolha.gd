extends Node
# Escolha de nave — singleton (autoload "Escolha").
# Guarda qual nave o jogador selecionou no menu, pra valer na partida:
#   0 = VERDE001 (a verde de sempre)
#   1 = roxa nova (assets/roxa sem fundo.png)

const NAVES: Array[String] = [
	"res://assets/nave_verde001.png",
	"res://assets/roxa sem fundo.png",
]

# banner com o nome de cada nave (mesma ordem de NAVES)
const ICONES: Array[String] = [
	"res://assets/poison.png",
	"res://assets/violet.png",
]

# arte de "nave escolhida": tela cheia com zoom antes da partida
const ARTES: Array[String] = [
	"res://assets/escolhida verde.png",
	"res://assets/escolhida roxa.png",
]

var indice := 0


func total() -> int:
	return NAVES.size()


func trocar(passo: int) -> void:
	indice = wrapi(indice + passo, 0, NAVES.size())


func textura(i: int = -1) -> Texture2D:
	var idx := indice if i < 0 else clampi(i, 0, NAVES.size() - 1)
	if ResourceLoader.exists(NAVES[idx]):
		var t := load(NAVES[idx]) as Texture2D
		if t != null:
			return t
	# se algo faltar, cai na verde de sempre (nao quebra o jogo)
	if ResourceLoader.exists(NAVES[0]):
		return load(NAVES[0]) as Texture2D
	return null


func e_roxa() -> bool:
	return indice == 1


func escolher(i: int) -> void:
	indice = clampi(i, 0, NAVES.size() - 1)


func icone(i: int = -1) -> Texture2D:
	var idx := indice if i < 0 else clampi(i, 0, ICONES.size() - 1)
	if ResourceLoader.exists(ICONES[idx]):
		var t := load(ICONES[idx]) as Texture2D
		if t != null:
			return t
	return null


# caminho da arte de transição da nave escolhida (vazio se nao existir)
func arte(i: int = -1) -> String:
	if ARTES.is_empty():
		return ""
	var idx := indice if i < 0 else clampi(i, 0, ARTES.size() - 1)
	return ARTES[idx]

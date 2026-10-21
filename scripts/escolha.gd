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

var indice := 0


# log de depuracao em arquivo (o stdout do Godot e bufferizado e morre no kill)
func dbg(txt: String) -> void:
	var f := FileAccess.open("user://dbg_nave.txt", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("user://dbg_nave.txt", FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(txt)
		f.close()


func total() -> int:
	return NAVES.size()


func trocar(passo: int) -> void:
	indice = wrapi(indice + passo, 0, NAVES.size())
	dbg("trocar(%d) -> indice=%d" % [passo, indice])


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
	dbg("escolher(%d) -> indice=%d" % [i, indice])


func icone(i: int = -1) -> Texture2D:
	var idx := indice if i < 0 else clampi(i, 0, ICONES.size() - 1)
	if ResourceLoader.exists(ICONES[idx]):
		var t := load(ICONES[idx]) as Texture2D
		if t != null:
			return t
	return null

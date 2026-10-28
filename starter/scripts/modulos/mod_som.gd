extends "res://scripts/nucleo/modulo.gd"
## Som (biblioteca do kit): efeitos 8-bit sintetizados na hora, sem arquivo de áudio nem licença.
## Toque emitindo "som" {nome}. Nomes: tiro, explosao, pulo, moeda, dano, power, fase, inicio, fim, toque, linha.
## Cada som = [onda, freq inicial, freq final, duração s, volume, repetir arpejo]. Crie os seus em SONS.

const TAXA := 22050
const SONS := {
	"tiro": ["quadrada", 880.0, 220.0, 0.12, 0.35, 0],
	"explosao": ["ruido", 400.0, 60.0, 0.35, 0.5, 0],
	"pulo": ["quadrada", 300.0, 700.0, 0.14, 0.3, 0],
	"moeda": ["quadrada", 988.0, 1319.0, 0.12, 0.3, 2],
	"dano": ["serra", 300.0, 80.0, 0.3, 0.45, 0],
	"power": ["triangulo", 440.0, 1320.0, 0.35, 0.4, 3],
	"fase": ["quadrada", 523.0, 1046.0, 0.45, 0.35, 4],
	"inicio": ["triangulo", 330.0, 990.0, 0.25, 0.35, 2],
	"fim": ["serra", 440.0, 110.0, 0.8, 0.4, 0],
	"toque": ["quadrada", 660.0, 660.0, 0.05, 0.25, 0],
	"linha": ["triangulo", 660.0, 1760.0, 0.25, 0.4, 2],
}

var streams := {}
var players: Array = []
var prox := 0


func _ready() -> void:
	for n in SONS:
		streams[n] = gerar(SONS[n])
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -9.0
		add_child(p)
		players.append(p)


static func gerar(s: Array) -> AudioStreamWAV:
	var onda: String = s[0]
	var f0: float = s[1]
	var f1: float = s[2]
	var dur: float = s[3]
	var vol: float = s[4]
	var arp: int = s[5]
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var fase := 0.0
	var ruido := 0.0
	var semente := 22222
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		if arp > 0:  # arpejo de fliperama: a nota pula em degraus
			f = f0 * pow(f1 / f0, floor(k * (arp + 1)) / arp)
		fase = fmod(fase + f / TAXA, 1.0)
		var v := 0.0
		match onda:
			"quadrada": v = 1.0 if fase < 0.5 else -1.0
			"triangulo": v = 4.0 * absf(fase - 0.5) - 1.0
			"serra": v = 2.0 * fase - 1.0
			"ruido":
				if fase < f / TAXA:  # troca o valor do ruído na frequência pedida
					semente = (semente * 1103515245 + 12345) & 0x7fffffff
					ruido = float(semente % 2000) / 1000.0 - 1.0
				v = ruido
		var env := (1.0 - k) * minf(1.0, i / 60.0)  # ataque curto, cai até o fim
		dados.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w


func evento(nome: String, d: Dictionary) -> void:
	if nome != "som" or Nucleo.em_teste or players.is_empty():
		return
	var s = streams.get(String(d.get("nome", "")))
	if s == null:
		return
	var p: AudioStreamPlayer = players[prox]
	prox = (prox + 1) % players.size()
	p.stream = s
	p.play()


func teste(t) -> void:
	var ok := true
	for n in SONS:
		var w := gerar(SONS[n])
		ok = ok and w.data.size() == int(TAXA * SONS[n][3]) * 2
	t.ok(ok, "todos os %d sons são gerados com o tamanho certo" % SONS.size())
	var alto := 0
	var w := gerar(SONS["explosao"])
	for i in range(0, w.data.size(), 2):
		alto = maxi(alto, absi(w.data.decode_s16(i)))
	t.ok(alto > 3000 and alto < 32767, "a explosão tem volume e não estoura (pico %d)" % alto)

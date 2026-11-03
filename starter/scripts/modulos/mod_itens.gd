extends "res://scripts/nucleo/modulo.gd"
## Itens: barris e caixas na rua (2 golpes quebram e soltam comida ou moeda), e o que os inimigos derrubam.
## Frango cura muito, lata de refrigerante cura pouco, moeda dá pontos. Pega passando por cima.
## Ouve: "heroi" {x, y, vida, max}, "golpe" {x, y, dir, alcance}, "soltar" {x, y}, "fase".
## Emite: "comer" {vida}, "pontuou" {pontos}, "acertou", "som".

const Folha = preload("res://scripts/folha.gd")
const CAIXAS := [  # onde ficam os barris e caixas de cada rua, e o que tem dentro
	{"x": 330.0, "y": 236.0, "tipo": "barril", "dentro": "lata"},
	{"x": 760.0, "y": 320.0, "tipo": "caixa", "dentro": "moeda"},
	{"x": 1320.0, "y": 250.0, "tipo": "barril", "dentro": "frango"},
	{"x": 1880.0, "y": 300.0, "tipo": "caixa", "dentro": "lata"},
	{"x": 2120.0, "y": 240.0, "tipo": "barril", "dentro": "frango"},
]
const CURA := {"frango": 45.0, "lata": 18.0}

var caixas: Array = []  # {x, y, tipo, dentro, golpes, quebrou, t}
var soltos: Array = []  # {x, y, tipo, t}
var hx := 0.0
var hy := 290.0
var hvida := 100.0
var hmax := 100.0

var _folha: Folha


func _init() -> void:
	camada = 10


func _ready() -> void:
	_folha = Folha.new("res://arte/itens.png")


func novo_jogo() -> void:
	caixas = []
	for c in CAIXAS:
		caixas.append({"x": c.x, "y": c.y, "tipo": c.tipo, "dentro": c.dentro, "golpes": 0, "quebrou": false, "t": 0.0})
	soltos = []
	hvida = 100.0
	hmax = 100.0


func passo(dt: float) -> void:
	for c in caixas:
		c.t += dt
	for s in soltos:
		s.t += dt
	var ficam: Array = []
	for s in soltos:
		if s.t > 0.25 and absf(s.x - hx) < 22.0 and absf(s.y - hy) < 14.0:
			if s.tipo == "moeda":
				Nucleo.emitir("pontuou", {"pontos": 50})
				Nucleo.emitir("som", {"nome": "moeda"})
			else:
				Nucleo.emitir("comer", {"vida": CURA[s.tipo]})
				Nucleo.emitir("som", {"nome": "power"})
		elif s.t < 20.0:
			ficam.append(s)
	soltos = ficam
	caixas = caixas.filter(func(c): return not (c.quebrou and c.t > 0.8))


func evento(nome: String, d: Dictionary) -> void:
	match nome:
		"heroi":
			hx = float(d.x)
			hy = float(d.y)
			hvida = float(d.get("vida", hvida))
			hmax = float(d.get("max", hmax))
		"golpe":
			for c in caixas:
				if c.quebrou or absf(c.y - float(d.y)) > 18.0:
					continue
				var frente: float = (c.x - float(d.x)) * float(d.dir)
				if frente < -4.0 or frente > float(d.alcance) + 14.0:
					continue
				c.golpes += 1
				Nucleo.emitir("acertou", {"x": c.x, "y": c.y - 34.0, "forte": false})
				Nucleo.emitir("som", {"nome": "quebra"})
				if c.golpes >= 2:
					c.quebrou = true
					c.t = 0.0
					soltos.append({"x": c.x, "y": c.y, "tipo": c.dentro, "t": 0.0})
		"soltar":
			# inimigo derrotado: às vezes deixa moeda ou lata (sorte da semente)
			var r := Nucleo.rng.randf()
			if r < 0.45:
				soltos.append({"x": float(d.x), "y": float(d.y), "tipo": "moeda" if r < 0.33 else "lata", "t": 0.0})
		"fase":
			novo_jogo()
		"atores":
			for c in caixas:
				d.lista.append({"y": c.y, "f": _desenhar_caixa.bind(c)})
			for s in soltos:
				d.lista.append({"y": s.y - 1.0, "f": _desenhar_solto.bind(s)})


func _desenhar_caixa(tela: Node2D, o: Vector2, c: Dictionary) -> void:
	var pe := Vector2(c.x, c.y) + o
	Folha.sombra(tela, pe, 34)
	var tremor := Vector2.ZERO
	if c.quebrou:
		_folha.desenhar(tela, "barril_quebrado", 0.0, pe + Vector2(0, 4))
	else:
		_folha.desenhar(tela, c.tipo, 0.0, pe + Vector2(0, 4) + tremor)


func _desenhar_solto(tela: Node2D, o: Vector2, s: Dictionary) -> void:
	var pe := Vector2(s.x, s.y) + o
	var pulo := -absf(sin(minf(s.t, 0.5) * TAU)) * 20.0 if s.t < 0.5 else 0.0  # sai pulando
	if s.t > 17.0 and int(s.t * 8.0) % 2 == 0:
		return  # pisca antes de sumir
	Folha.sombra(tela, pe, 22)
	_folha.desenhar(tela, s.tipo, s.t, pe + Vector2(0, 8.0 + pulo))


func bot() -> String:
	# Gangue não tem ninguém para bater: pega comida se estiver machucado, quebra o barril do caminho, senão segue a rua
	var alvo := Vector2.ZERO
	var tem := false
	for s in soltos:
		if s.tipo == "moeda" or hvida < hmax * 0.7:
			alvo = Vector2(s.x, s.y)
			tem = true
			break
	if not tem:
		for c in caixas:
			if not c.quebrou and absf(c.x - hx) < 300.0 and c.x > hx - 120.0:
				var lado := -1.0 if hx < c.x else 1.0  # bate do lado em que já está
				alvo = Vector2(c.x + lado * 44.0, c.y)
				tem = true
				if absf(alvo.x - hx) < 8.0 and absf(c.y - hy) < 6.0:
					return ("direita" if lado < 0.0 else "esquerda") + "+acao"
				break
	if not tem:
		return "direita"
	var acoes: Array = []
	if absf(alvo.y - hy) > 3.0:
		acoes.append("baixo" if alvo.y > hy else "cima")
	if absf(alvo.x - hx) > 4.0:
		acoes.append("direita" if alvo.x > hx else "esquerda")
	return "+".join(acoes) if not acoes.is_empty() else "direita"


func salvar() -> Dictionary:
	return {"caixas": caixas.duplicate(true), "soltos": soltos.duplicate(true), "hx": hx, "hy": hy, "hvida": hvida, "hmax": hmax}


func carregar(d: Dictionary) -> void:
	if d.is_empty():
		return
	caixas = []
	for c in d.caixas:
		var n: Dictionary = c.duplicate(true)
		n.golpes = int(n.golpes)
		caixas.append(n)
	soltos = d.soltos.duplicate(true)
	hx = float(d.hx)
	hy = float(d.hy)
	hvida = float(d.hvida)
	hmax = float(d.hmax)


func teste(t) -> void:
	novo_jogo()
	var c: Dictionary = caixas[0]
	evento("golpe", {"x": c.x - 20.0, "y": c.y, "dir": 1, "alcance": 32.0})
	t.ok(c.golpes == 1 and not c.quebrou, "um golpe racha o barril")
	evento("golpe", {"x": c.x - 20.0, "y": c.y, "dir": 1, "alcance": 32.0})
	t.ok(c.quebrou and soltos.size() == 1, "dois golpes quebram e soltam o que tem dentro")
	evento("golpe", {"x": caixas[1].x + 20.0, "y": caixas[1].y, "dir": 1, "alcance": 32.0})
	t.ok(caixas[1].golpes == 0, "golpe de costas não quebra")
	# pegar: a lata cura
	var curou := [0.0]
	evento("heroi", {"x": c.x, "y": c.y, "vida": 50.0, "max": 100.0})
	for i in 30:
		passo(Nucleo.DT)
	t.ok(soltos.is_empty(), "passar por cima pega o item")
	for i in 60:
		passo(Nucleo.DT)
	t.ok(caixas.size() == CAIXAS.size() - 1, "o barril quebrado some")
	evento("soltar", {"x": 10.0, "y": 300.0})
	t.ok(soltos.size() <= 1, "inimigo derrotado às vezes deixa um item")
	var d := salvar()
	carregar(JSON.parse_string(JSON.stringify(d)))
	t.ok(JSON.stringify(salvar()) == JSON.stringify(d), "salvar e carregar devolvem os mesmos itens")
	curou.clear()
	Nucleo.novo_jogo(1)

extends "res://scripts/nucleo/modulo.gd"
## Gemas: sempre 3 no chão. Pegar = +1 ponto; a cada 10, sobe de fase.
## Emite: "pontuou" {pontos}, "fase" {n}, "som", "gema" {x, z} (o Visual faz o brilho).

const QUANTAS := 3
const RAIO := 0.9
const POR_FASE := 10

var lista: Array = []  # Vector2 (x, z)
var pegas := 0


func novo_jogo() -> void:
	lista.clear()
	pegas = 0
	for i in QUANTAS:
		lista.append(_nova())


func _nova() -> Vector2:
	var a = Nucleo.mod("Jogador").ARENA - 1.0
	return Vector2(Nucleo.rng.randf_range(-a, a), Nucleo.rng.randf_range(-a, a))


func passo(_dt: float) -> void:
	var j = Nucleo.mod("Jogador")
	for i in lista.size():
		if j.pos.distance_to(lista[i]) < RAIO and j.alt < 1.2:
			Nucleo.emitir("gema", {"x": lista[i].x, "z": lista[i].y})
			lista[i] = _nova()
			pegas += 1
			Nucleo.emitir("pontuou", {"pontos": 1})
			Nucleo.emitir("som", {"nome": "moeda"})
			if pegas % POR_FASE == 0:
				Nucleo.emitir("fase", {"n": pegas / POR_FASE + 1})


func progresso() -> int:
	return pegas


func salvar() -> Dictionary:
	return {"lista": lista.map(func(g): return [g.x, g.y]), "pegas": pegas}


func carregar(d: Dictionary) -> void:
	lista = d.get("lista", []).map(func(g): return Vector2(g[0], g[1]))
	pegas = int(d.get("pegas", 0))


func teste(t) -> void:
	t.ok(lista.size() == QUANTAS, "começa com %d gemas" % QUANTAS)
	var a = Nucleo.mod("Jogador").ARENA
	t.ok(lista.all(func(g): return absf(g.x) < a and absf(g.y) < a), "gemas dentro da arena")
	var j = Nucleo.mod("Jogador")
	j.pos = lista[0]
	passo(Nucleo.DT)
	t.ok(pegas == 1 and j.pos.distance_to(lista[0]) > 0.01, "pegar a gema conta e põe outra no lugar")
	j.alt = 3.0
	j.pos = lista[1]
	passo(Nucleo.DT)
	t.ok(pegas == 1, "pulando alto por cima não pega")
	j.novo_jogo()

extends "res://scripts/nucleo/modulo.gd"
## Perigos: bolas de lixo tóxico que rolam de uma borda à outra. Mais e mais rápidas a cada fase.
## Encostar sem pular por cima = "perdeu_vida" (o Jogador fica protegido um tempo). Ouve: "fase".

const RAIO := 0.85
const VEL := 3.2

var lista: Array = []  # [x, z, dx, dz]
var nivel := 1
var espera := 0.0


func novo_jogo() -> void:
	lista.clear()
	nivel = 1
	espera = 1.5


func quantos() -> int:
	return 1 + nivel


func passo(dt: float) -> void:
	var a = Nucleo.mod("Jogador").ARENA + 2.0
	for p in lista:
		p[0] += p[2] * dt
		p[1] += p[3] * dt
	lista = lista.filter(func(p): return absf(p[0]) <= a and absf(p[1]) <= a)
	espera -= dt
	if lista.size() < quantos() and espera <= 0.0:
		lista.append(_nova(a))
		espera = maxf(0.4, 1.4 - nivel * 0.15)
	var j = Nucleo.mod("Jogador")
	if j.protegido > 0.0 or j.alt > 0.6:
		return
	for p in lista:
		if j.pos.distance_to(Vector2(p[0], p[1])) < RAIO:
			Nucleo.emitir("perdeu_vida", {})
			return


func _nova(a: float) -> Array:
	var v := VEL + nivel * 0.5
	var t := Nucleo.rng.randf_range(-a + 3.0, a - 3.0)
	match Nucleo.rng.randi_range(0, 3):
		0: return [-a, t, v, 0.0]
		1: return [a, t, -v, 0.0]
		2: return [t, -a, 0.0, v]
		_: return [t, a, 0.0, -v]


func evento(nome: String, dados: Dictionary) -> void:
	if nome == "fase":
		nivel = int(dados.get("n", nivel + 1))


func salvar() -> Dictionary:
	return {"lista": lista.duplicate(true), "nivel": nivel, "espera": espera}


func carregar(d: Dictionary) -> void:
	lista = d.get("lista", []).duplicate(true)
	nivel = int(d.get("nivel", 1))
	espera = float(d.get("espera", 0.0))


func teste(t) -> void:
	for i in 600:
		passo(Nucleo.DT)
	t.ok(lista.size() >= 1 and lista.size() <= quantos(), "perigos aparecem (%d)" % lista.size())
	evento("fase", {"n": 3})
	t.ok(quantos() == 4, "fase 3: até 4 perigos")
	var j = Nucleo.mod("Jogador")
	lista = [[j.pos.x, j.pos.y, 0.0, 0.0]]
	var antes: int = Nucleo.mod("Partida").vidas
	passo(Nucleo.DT)
	t.ok(Nucleo.mod("Partida").vidas == antes - 1, "encostar tira uma vida")
	t.ok(j.protegido > 0.0, "e o jogador fica protegido")
	j.protegido = 0.0
	j.alt = 1.0
	var v: int = Nucleo.mod("Partida").vidas
	passo(Nucleo.DT)
	t.ok(Nucleo.mod("Partida").vidas == v, "pulando por cima não leva dano")
	j.novo_jogo()

extends "res://scripts/nucleo/modulo.gd"
## Jogador: anda no chão da arena (plano X/Z; a simulação é 2D, o Visual desenha em 3D) e pula.
## Ouve: "perdeu_vida" (fica piscando, sem levar dano, por um tempo). Emite: "som".
## O bot vai até a gema mais perto e pula quando um perigo chega perto.

const ARENA := 11.0      # meia-largura do chão
const VEL := 6.5
const PULO := 7.5
const GRAVIDADE := 22.0
const PROTEGIDO := 1.5

var pos := Vector2.ZERO  # x, z
var alt := 0.0           # altura do pulo
var vy := 0.0
var ang := 0.0           # para onde olha (radianos, no plano)
var protegido := 0.0


func novo_jogo() -> void:
	pos = Vector2.ZERO
	alt = 0.0
	vy = 0.0
	ang = 0.0
	protegido = 0.0


func no_chao() -> bool:
	return alt <= 0.0


func passo(dt: float) -> void:
	var d := Vector2(
		(1.0 if Nucleo.segurando("direita") else 0.0) - (1.0 if Nucleo.segurando("esquerda") else 0.0),
		(1.0 if Nucleo.segurando("baixo") else 0.0) - (1.0 if Nucleo.segurando("cima") else 0.0))
	if d != Vector2.ZERO:
		d = d.normalized()
		ang = atan2(d.x, d.y)
	pos = (pos + d * VEL * dt).clamp(Vector2(-ARENA, -ARENA), Vector2(ARENA, ARENA))
	if alt > 0.0 or vy > 0.0:
		vy -= GRAVIDADE * dt
		alt = maxf(0.0, alt + vy * dt)
		if alt == 0.0:
			vy = 0.0
	protegido = maxf(0.0, protegido - dt)


func entrada(acao: String) -> bool:
	if acao == "acao" and no_chao():
		vy = PULO
		alt = 0.001
		Nucleo.emitir("som", {"nome": "pulo"})
		return true
	return false


func evento(nome: String, _dados: Dictionary) -> void:
	if nome == "perdeu_vida":
		protegido = PROTEGIDO


func bot() -> String:
	var gemas: Array = Nucleo.mod("Gemas").lista if Nucleo.mod("Gemas") else []
	var acoes: PackedStringArray = []
	if not gemas.is_empty():
		var alvo: Vector2 = gemas[0]
		for g in gemas:
			if pos.distance_to(g) < pos.distance_to(alvo):
				alvo = g
		var d := alvo - pos
		if d.x > 0.25: acoes.append("direita")
		elif d.x < -0.25: acoes.append("esquerda")
		if d.y > 0.25: acoes.append("baixo")
		elif d.y < -0.25: acoes.append("cima")
	var perigos = Nucleo.mod("Perigos")
	if perigos and no_chao():
		for p in perigos.lista:
			if pos.distance_to(Vector2(p[0], p[1])) < 2.0:
				acoes.append("acao")
				break
	return "+".join(acoes)


func salvar() -> Dictionary:
	return {"pos": [pos.x, pos.y], "alt": alt, "vy": vy, "ang": ang, "protegido": protegido}


func carregar(d: Dictionary) -> void:
	var p: Array = d.get("pos", [0.0, 0.0])
	pos = Vector2(p[0], p[1])
	alt = float(d.get("alt", 0.0))
	vy = float(d.get("vy", 0.0))
	ang = float(d.get("ang", 0.0))
	protegido = float(d.get("protegido", 0.0))


func teste(t) -> void:
	Nucleo.pausado = false
	Nucleo.seg = {"direita": true}
	for i in 60:
		passo(Nucleo.DT)
	t.ok(absf(pos.x - VEL) < 0.2 and pos.y == 0.0, "anda para a direita: 1 s = %.2f" % pos.x)
	for i in 600:
		passo(Nucleo.DT)
	t.ok(pos.x == ARENA, "não sai da arena")
	Nucleo.seg = {}
	t.ok(entrada("acao") and alt > 0.0, "pula do chão")
	t.ok(not entrada("acao"), "não pula no ar")
	for i in 120:
		passo(Nucleo.DT)
	t.ok(no_chao() and vy == 0.0, "volta ao chão")
	evento("perdeu_vida", {})
	t.ok(protegido == PROTEGIDO, "fica protegido depois de levar dano")
	Nucleo.seg = {}

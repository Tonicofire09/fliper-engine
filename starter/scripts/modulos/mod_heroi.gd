extends "res://scripts/nucleo/modulo.gd"
## Herói: anda em 4 direções pela rua (cima/baixo = profundidade) e briga com um combo de 3 golpes no espaço:
## jab, direto e chute (o chute derruba). Apertar de novo durante um golpe emenda o próximo.
## Ouve: "camera" {x}, "golpe_inimigo" {x, y, dir, alcance, dano, forte}, "comer" {vida}, "fase".
## Emite: "heroi" {x, y, vida, max} todo passo, "golpe" {x, y, dir, alcance, dano, forte}, "acertou",
##        "perdeu_vida" (quando a vida zera: a Partida tira 1 das 3), "som", "poeira".

const Folha = preload("res://scripts/folha.gd")
const VIDA := 100.0
const VEL := Vector2(130, 74)  # px/s: anda mais rápido de lado do que em profundidade (como nos clássicos)
const INICIO := Vector2(90, 290)
# golpe: animação, duração (s), quando o golpe pega (s), dano, alcance (px à frente), derruba?
const GOLPES := [
	{"anim": "soco", "dur": 0.26, "ativo": 0.07, "dano": 7.0, "alcance": 58.0, "forte": false},
	{"anim": "soco2", "dur": 0.28, "ativo": 0.07, "dano": 9.0, "alcance": 62.0, "forte": false},
	{"anim": "chute", "dur": 0.42, "ativo": 0.09, "dano": 15.0, "alcance": 70.0, "forte": true},
]
const EMENDA := 0.32  # depois de um golpe, quanto tempo o próximo aperto continua o combo

var pos := INICIO
var dir := 1
var vida := VIDA
var estado := "livre"  # livre | golpe | dano | caido
var golpe := -1  # índice em GOLPES do golpe atual (ou do último)
var t_est := 0.0  # tempo no estado atual
var fila := false  # apertou durante o golpe: emenda o próximo
var bateu := false  # o golpe atual já pegou
var desde_golpe := 9.0
var invul := 0.0
var cam := 0.0
var t_anim := 0.0
var anim := "parado"

var _folha: Folha
var _retrato: Texture2D


func _init() -> void:
	camada = 10


func _ready() -> void:
	_folha = Folha.new("res://arte/heroi.png")
	_retrato = Nucleo.textura("res://arte/retratos.png")


func novo_jogo() -> void:
	pos = INICIO
	dir = 1
	vida = VIDA
	estado = "livre"
	golpe = -1
	t_est = 0.0
	fila = false
	bateu = false
	desde_golpe = 9.0
	invul = 0.0
	cam = 0.0
	t_anim = 0.0
	anim = "parado"


func entrada(acao: String) -> bool:
	if acao != "acao":
		return false
	if estado == "livre":
		# virar e bater no mesmo aperto: segurando um lado, o golpe sai para aquele lado
		if Nucleo.segurando("direita") != Nucleo.segurando("esquerda"):
			dir = 1 if Nucleo.segurando("direita") else -1
		_golpear(golpe + 1 if desde_golpe < EMENDA and golpe < GOLPES.size() - 1 else 0)
		return true
	if estado == "golpe" and golpe < GOLPES.size() - 1:
		fila = true
		return true
	return false


func _golpear(i: int) -> void:
	estado = "golpe"
	golpe = i
	t_est = 0.0
	fila = false
	bateu = false
	_animar(GOLPES[i].anim)


func _animar(a: String) -> void:
	if a != anim:
		anim = a
		t_anim = 0.0


func passo(dt: float) -> void:
	invul = maxf(0.0, invul - dt)
	t_est += dt
	t_anim += dt
	match estado:
		"livre":
			desde_golpe += dt
			var mv := Vector2(
				(1.0 if Nucleo.segurando("direita") else 0.0) - (1.0 if Nucleo.segurando("esquerda") else 0.0),
				(1.0 if Nucleo.segurando("baixo") else 0.0) - (1.0 if Nucleo.segurando("cima") else 0.0))
			if mv.x != 0.0:
				dir = 1 if mv.x > 0.0 else -1
			pos += mv * VEL * dt
			_animar("andar" if mv != Vector2.ZERO else "parado")
			if mv != Vector2.ZERO and int(t_anim * 10.0) % 6 == 0 and int((t_anim - dt) * 10.0) % 6 != 0:
				Nucleo.emitir("poeira", {"x": pos.x - dir * 12.0, "y": pos.y - 16.0})
		"golpe":
			var g: Dictionary = GOLPES[golpe]
			if not bateu and t_est >= g.ativo:
				bateu = true
				Nucleo.emitir("som", {"nome": "golpe"})
				Nucleo.emitir("golpe", {"x": pos.x, "y": pos.y, "dir": dir, "alcance": g.alcance, "dano": g.dano, "forte": g.forte})
			if t_est >= g.dur:
				if fila and golpe < GOLPES.size() - 1:
					_golpear(golpe + 1)
				else:
					estado = "livre"
					desde_golpe = 0.0 if golpe < GOLPES.size() - 1 else 9.0
					t_est = 0.0
		"dano":
			if t_est >= 0.3:
				estado = "livre"
				t_est = 0.0
		"caido":
			_animar("cair")
			if t_est >= 1.1:
				if vida <= 0.0:
					vida = VIDA  # a Partida já tirou uma vida: levanta inteiro
				estado = "livre"
				t_est = 0.0
				invul = 1.6
	pos.x = clampf(pos.x, maxf(16.0, cam + 16.0), minf(2544.0, cam + 624.0))
	pos.y = clampf(pos.y, 214.0, 348.0)
	Nucleo.emitir("heroi", {"x": pos.x, "y": pos.y, "vida": vida, "max": VIDA})


func evento(nome: String, d: Dictionary) -> void:
	match nome:
		"camera":
			cam = float(d.x)
		"golpe_inimigo":
			_apanhar(d)
		"comer":
			vida = minf(VIDA, vida + float(d.get("vida", 20.0)))
		"fase":
			pos = INICIO
			vida = VIDA
			estado = "livre"
			cam = 0.0
		"atores":
			d.lista.append({"y": pos.y, "f": _desenhar})


func _apanhar(d: Dictionary) -> void:
	if invul > 0.0 or estado == "caido":
		return
	if absf(float(d.y) - pos.y) > 18.0:
		return
	var frente := (pos.x - float(d.x)) * float(d.dir)
	if frente < -6.0 or frente > float(d.alcance):
		return
	vida = maxf(0.0, vida - float(d.dano))
	dir = -int(d.dir)
	pos.x += float(d.dir) * (26.0 if d.get("forte", false) else 8.0)
	Nucleo.emitir("acertou", {"x": pos.x - float(d.dir) * 4.0, "y": pos.y - 60.0, "forte": d.get("forte", false)})
	Nucleo.emitir("som", {"nome": "dano"})
	t_est = 0.0
	if vida <= 0.0 or d.get("forte", false):
		estado = "caido"
		_animar("cair")
		Nucleo.emitir("poeira", {"x": pos.x, "y": pos.y - 16.0})
		if vida <= 0.0:
			Nucleo.emitir("perdeu_vida")
	else:
		estado = "dano"
		_animar("dano")


func _desenhar(tela: Node2D, o: Vector2) -> void:
	if invul > 0.0 and estado != "caido" and int(invul * 12.0) % 2 == 0:
		return  # pisca enquanto está invencível
	var deitado := estado == "caido" and t_est > 0.2
	Folha.sombra(tela, pos + o + Vector2(dir * 8.0 if deitado else 0.0, 0), 54.0 if deitado else 34.0)
	_folha.desenhar(tela, anim, t_anim, pos + o + Vector2(0, 4), dir)


func desenhar_hud(tela: Node2D) -> void:
	if _retrato != null:
		tela.draw_rect(Rect2(7, 25, 26, 26), Color("#0b0715"))
		tela.draw_texture_rect_region(_retrato, Rect2(8, 26, 24, 24), Rect2(0, 0, 24, 24))
	tela.draw_rect(Rect2(36, 30, 124, 10), Color("#0b0715"))
	tela.draw_rect(Rect2(38, 32, 120.0 * vida / VIDA, 6), Color("#9bff3a") if vida > 35.0 else Color("#ff2e88"))
	tela.draw_rect(Rect2(38, 32, 120.0 * vida / VIDA, 2), Color(1, 1, 1, 0.35))


func bot() -> String:
	return ""


func salvar() -> Dictionary:
	return {"pos": [pos.x, pos.y], "dir": dir, "vida": vida, "estado": estado, "golpe": golpe, "t_est": t_est, "fila": fila,
		"bateu": bateu, "desde_golpe": desde_golpe, "invul": invul, "cam": cam, "t_anim": t_anim, "anim": anim}


func carregar(d: Dictionary) -> void:
	if d.is_empty():
		return
	pos = Vector2(float(d.pos[0]), float(d.pos[1]))
	dir = int(d.dir)
	vida = float(d.vida)
	estado = String(d.estado)
	golpe = int(d.golpe)
	t_est = float(d.t_est)
	fila = bool(d.fila)
	bateu = bool(d.bateu)
	desde_golpe = float(d.desde_golpe)
	invul = float(d.invul)
	cam = float(d.cam)
	t_anim = float(d.t_anim)
	anim = String(d.anim)


func _correr(t_seg: float) -> void:
	for i in int(t_seg / Nucleo.DT):
		passo(Nucleo.DT)


func teste(t) -> void:
	novo_jogo()
	Nucleo.seg = {"direita": true}
	_correr(0.5)
	Nucleo.seg = {}
	t.ok(pos.x > INICIO.x + 40.0 and dir == 1, "anda para a direita (x %d)" % pos.x)
	Nucleo.seg = {"cima": true}
	_correr(3.0)
	Nucleo.seg = {}
	t.ok(is_equal_approx(pos.y, 214.0), "não sobe além da calçada")
	# combo: 3 apertos seguidos = jab, direto, chute
	entrada("acao")
	_correr(0.1)
	entrada("acao")
	_correr(0.3)
	entrada("acao")
	_correr(0.8)
	t.ok(estado == "livre" and golpe == 2, "três apertos fazem o combo inteiro (último golpe %d)" % golpe)
	# apanhar: golpe de frente tira vida, forte derruba
	novo_jogo()
	_apanhar({"x": pos.x + 20.0, "y": pos.y, "dir": -1, "alcance": 30.0, "dano": 10.0, "forte": false})
	t.ok(vida == VIDA - 10.0 and estado == "dano", "apanha de frente e perde vida")
	_correr(0.4)
	_apanhar({"x": pos.x + 20.0, "y": pos.y + 40.0, "dir": -1, "alcance": 30.0, "dano": 10.0, "forte": false})
	t.ok(vida == VIDA - 10.0, "golpe em outra profundidade não pega")
	_apanhar({"x": pos.x + 20.0, "y": pos.y, "dir": -1, "alcance": 30.0, "dano": 10.0, "forte": true})
	t.ok(estado == "caido", "golpe forte derruba")
	_correr(1.2)
	t.ok(estado == "livre" and invul > 0.0, "levanta e fica invencível um instante")
	_apanhar({"x": pos.x + 20.0, "y": pos.y, "dir": -1, "alcance": 30.0, "dano": 10.0, "forte": false})
	t.ok(vida == VIDA - 20.0, "invencível não apanha")
	# vida zera: perde uma vida da Partida e levanta inteiro
	invul = 0.0
	_apanhar({"x": pos.x + 20.0, "y": pos.y, "dir": -1, "alcance": 30.0, "dano": 999.0, "forte": false})
	t.ok(estado == "caido" and vida == 0.0, "sem vida cai")
	_correr(1.2)
	t.ok(vida == VIDA, "levanta com a vida cheia")
	evento("comer", {"vida": 30.0})
	t.ok(vida == VIDA, "comida não passa do máximo")
	var d := salvar()
	novo_jogo()
	carregar(d)
	t.ok(JSON.stringify(salvar()) == JSON.stringify(d), "salvar e carregar devolvem o mesmo herói")
	Nucleo.novo_jogo(1)

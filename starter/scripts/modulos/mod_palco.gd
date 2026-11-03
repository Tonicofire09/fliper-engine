extends "res://scripts/nucleo/modulo.gd"
## Palco: a rua à noite (céu, cidade ao longe com paralaxe, fachadas, calçada e asfalto), a câmera que só anda
## para a frente e para nas brigas, o tremor de tela e os efeitos de impacto. Desenha os bonecos de todos os
## módulos na ordem da profundidade: quem está mais embaixo na tela fica na frente.
## Ouve: "heroi" {x}, "trava" {x}, "tremer" {forca}, "acertou" {x, y, forte}, "poeira" {x, y}, "fase".
## Emite: "camera" {x} (todo passo) e "atores" {lista} (cada módulo põe {y, f: Callable(tela, origem)} na lista).

const Folha = preload("res://scripts/folha.gd")
const FIM := 2560.0  # comprimento da rua (px de mundo)
const TOPO := 214.0  # faixa onde os pés pisam: da calçada...
const BASE := 348.0  # ...até a beira da tela
const TELA := Vector2(640, 360)

var cam := 0.0
var trava := FIM - TELA.x
var hx := 0.0
var trauma := 0.0
var efeitos: Array = []  # {tipo, x, y, t}

var _fx: Folha
var _tex := {}


func _init() -> void:
	camada = 0


func _ready() -> void:
	for n in ["fundo_ceu", "fundo_cidade", "fundo_rua", "chao", "objetos"]:
		_tex[n] = Nucleo.textura("res://arte/%s.png" % n)
	_fx = Folha.new("res://arte/efeitos.png")


func novo_jogo() -> void:
	cam = 0.0
	trava = FIM - TELA.x
	hx = 0.0
	trauma = 0.0
	efeitos = []


func passo(dt: float) -> void:
	# a câmera segue o herói um pouco à frente, nunca volta e não passa da trava (a briga da vez)
	var alvo := clampf(hx - 260.0, cam, minf(trava, FIM - TELA.x))
	cam = minf(alvo, cam + 4.0)
	Nucleo.emitir("camera", {"x": cam})
	trauma = maxf(0.0, trauma - dt * 3.0)
	for e in efeitos:
		e.t += dt
	efeitos = efeitos.filter(func(e): return e.t < 0.45)


func evento(nome: String, d: Dictionary) -> void:
	match nome:
		"heroi":
			hx = float(d.x)
		"trava":
			trava = float(d.x)
		"tremer":
			trauma = minf(1.0, trauma + float(d.get("forca", 4.0)) / 12.0)
		"acertou":
			var forte := bool(d.get("forte", false))
			efeitos.append({"tipo": "forte" if forte else "faisca", "x": float(d.x), "y": float(d.y), "t": 0.0})
			trauma = minf(1.0, trauma + (0.5 if forte else 0.18))
			if forte:
				Nucleo.congelar(0.08)  # hit-stop: o golpe "pega"
			else:
				Nucleo.congelar(0.035)
		"poeira":
			efeitos.append({"tipo": "poeira", "x": float(d.x), "y": float(d.y), "t": 0.0})
		"fase":
			novo_jogo()


## Ponto de mundo → tela (com tremor). Os outros módulos recebem a origem pronta no Callable dos atores.
func desenhar(tela: Node2D) -> void:
	var tremor := Vector2.ZERO
	if trauma > 0.0:  # visual: usa randf (nunca Nucleo.rng, que é da simulação)
		tremor = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * trauma * trauma * 6.0
	var o := Vector2(-cam, 0) + tremor
	tela.draw_texture(_tex.fundo_ceu, Vector2.ZERO)
	var cx := -fmod(cam * 0.3, 640.0)  # paralaxe: a cidade anda a 30%
	tela.draw_texture(_tex.fundo_cidade, Vector2(cx, 0) + tremor * 0.3)
	tela.draw_texture(_tex.fundo_cidade, Vector2(cx + 640, 0) + tremor * 0.3)
	var rx := -fmod(cam, 640.0)
	tela.draw_texture(_tex.fundo_rua, Vector2(rx, 0) + tremor)
	tela.draw_texture(_tex.fundo_rua, Vector2(rx + 640, 0) + tremor)
	var chx := -fmod(cam, 64.0)
	for i in 12:
		tela.draw_texture(_tex.chao, Vector2(chx + i * 64, 200) + tremor)
	# postes, lixeiras e hidrantes na calçada (fixos no mundo)
	var x0 := floorf(cam / 320.0) * 320.0
	for k in 4:
		var wx := x0 + k * 320.0
		_objeto(tela, o, 0, wx + 150.0, 214.0)
		_objeto(tela, o, 1 + (int(wx / 320.0) % 2), wx + 40.0, 216.0)
	# bonecos e itens de todos os módulos, por profundidade
	var lista: Array = []
	Nucleo.emitir("atores", {"lista": lista})
	lista.sort_custom(func(a, b): return a.y < b.y)
	for a in lista:
		a.f.call(tela, o)
	for e in efeitos:
		_fx.desenhar(tela, e.tipo, e.t, Vector2(e.x, e.y + 32) + o)
	# saída da rua: a placa no fim avisa onde acaba a fase
	if FIM - cam < TELA.x + 40:
		var px := FIM - 40.0 + o.x
		tela.draw_rect(Rect2(px, 120, 4, 96), Color("#3a3a4a"))
		tela.draw_rect(Rect2(px - 18, 112, 40, 18), Color("#1c7a3a"))
		tela.draw_rect(Rect2(px - 16, 114, 36, 14), Color("#2aa050"), false)


func _objeto(tela: Node2D, o: Vector2, qual: int, x: float, pe: float) -> void:
	var tx: Texture2D = _tex.objetos
	if tx == null or x + o.x < -40 or x + o.x > TELA.x + 40:
		return
	Folha.sombra(tela, Vector2(x, pe) + o, 14)
	tela.draw_texture_rect_region(tx, Rect2(x - 16 + o.x, pe - 96 + o.y, 32, 96), Rect2(qual * 32, 0, 32, 96))


func salvar() -> Dictionary:
	return {"cam": cam, "trava": trava, "hx": hx}


func carregar(d: Dictionary) -> void:
	cam = float(d.get("cam", cam))
	trava = float(d.get("trava", trava))
	hx = float(d.get("hx", hx))


func teste(t) -> void:
	novo_jogo()
	evento("heroi", {"x": 800.0})
	for i in 300:
		passo(Nucleo.DT)
	t.ok(cam > 400.0 and cam <= 540.0, "a câmera segue o herói (%d)" % cam)
	evento("heroi", {"x": 100.0})
	passo(Nucleo.DT)
	t.ok(cam > 400.0, "a câmera nunca volta")
	evento("trava", {"x": 600.0})
	evento("heroi", {"x": 2000.0})
	for i in 300:
		passo(Nucleo.DT)
	t.ok(is_equal_approx(cam, 600.0), "a câmera para na trava da briga")
	evento("acertou", {"x": 10.0, "y": 10.0, "forte": true})
	t.ok(efeitos.size() == 1 and trauma > 0.0, "golpe forte faz estouro e treme a tela")
	for i in 60:
		passo(Nucleo.DT)
	t.ok(efeitos.is_empty(), "o efeito some sozinho")
	var lista: Array = []
	Nucleo.emitir("atores", {"lista": lista})
	t.ok(lista.size() >= 1, "os bonecos entram na fila de desenho (%d)" % lista.size())
	Nucleo.novo_jogo(1)

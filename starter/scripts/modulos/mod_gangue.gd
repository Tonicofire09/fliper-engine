extends "res://scripts/nucleo/modulo.gd"
## Gangue: as brigas da rua. Em cada ponto da rua a câmera trava e entra uma onda (punks rápidos, brutamontes que
## derrubam, e o chefe no fim, que também investe de ombro). Inimigo sempre AVISA antes de bater (pose de preparo
## longa): é o que deixa a briga justa. Só 2 atacam por vez; os outros rondam esperando a vez.
## Ouve: "heroi" {x, y}, "camera" {x}, "golpe" {x, y, dir, alcance, dano, forte}.
## Emite: "trava" {x}, "golpe_inimigo", "acertou", "pontuou" {pontos}, "soltar" {x, y}, "fase" {n}, "som", "poeira".

const Folha = preload("res://scripts/folha.gd")
const TIPOS := {
	"punk": {"vida": 22.0, "vel": 100.0, "dano": 8.0, "alcance": 54.0, "preparar": 0.5, "golpe": 0.22, "recarga": 1.1, "pontos": 100, "q": 48, "larg": 34.0},
	"bruto": {"vida": 48.0, "vel": 64.0, "dano": 16.0, "alcance": 64.0, "preparar": 0.75, "golpe": 0.3, "recarga": 1.6, "pontos": 250, "q": 64, "larg": 50.0, "forte": true},
	"chefe": {"vida": 130.0, "vel": 78.0, "dano": 14.0, "alcance": 64.0, "preparar": 0.55, "golpe": 0.26, "recarga": 0.9, "pontos": 1000, "q": 64, "larg": 50.0, "chefe": true},
}
# onde a briga acontece (x do herói que dispara) e quem entra
const ONDAS := [
	{"x": 480.0, "quem": ["punk", "punk"]},
	{"x": 1040.0, "quem": ["punk", "bruto", "punk"]},
	{"x": 1600.0, "quem": ["punk", "punk", "bruto", "punk"]},
	{"x": 2240.0, "quem": ["chefe", "punk", "punk"]},
]
const ATACAM := 2  # quantos podem ir para cima do herói ao mesmo tempo

var inimigos: Array = []  # {tipo, x, y, dir, vida, max, estado, t, recarga, t_anim, anim, golpeou}
var onda := 0
var brigando := false  # a onda da vez já entrou (câmera travada)
var nivel := 1
var hx := 0.0
var hy := 290.0
var cam := 0.0
var ultimo := -1  # o último que apanhou (barra de vida no canto)
var ultimo_t := 0.0

var _folhas := {}
var _retrato: Texture2D


func _init() -> void:
	camada = 10


func _ready() -> void:
	for n in TIPOS:
		_folhas[n] = Folha.new("res://arte/%s.png" % n)
	_folhas["itens"] = Folha.new("res://arte/itens.png")
	_retrato = Nucleo.textura("res://arte/retratos.png")


func novo_jogo() -> void:
	nivel = 1
	_rua_nova()


func _rua_nova() -> void:
	inimigos = []
	onda = 0
	brigando = false
	ultimo = -1
	ultimo_t = 0.0
	hx = 0.0
	cam = 0.0
	Nucleo.emitir("trava", {"x": ONDAS[0].x - 320.0})


func _forca() -> float:
	return 1.0 + (nivel - 1) * 0.25  # cada rua repetida: inimigos 25% mais duros


func _entrar_onda() -> void:
	brigando = true
	var lado := 1.0
	var atraso := 0.0
	for tipo in ONDAS[onda].quem:
		var tp: Dictionary = TIPOS[tipo]
		var x := cam + (700.0 if lado > 0.0 else -60.0)
		inimigos.append({"tipo": tipo, "x": x, "y": Nucleo.rng.randf_range(230.0, 340.0), "dir": -int(lado),
			"vida": tp.vida * _forca(), "max": tp.vida * _forca(), "estado": "entrar", "t": -atraso, "recarga": 0.6 + atraso,
			"t_anim": 0.0, "anim": "andar", "golpeou": false})
		lado = -lado
		atraso += 0.7
	if TIPOS[ONDAS[onda].quem[0]].get("chefe", false):
		Nucleo.emitir("som", {"nome": "chefe"})


func passo(dt: float) -> void:
	ultimo_t = maxf(0.0, ultimo_t - dt)
	if not brigando and onda < ONDAS.size() and hx >= ONDAS[onda].x:
		_entrar_onda()
	# quem pode atacar agora: os 2 mais perto
	var vivos: Array = []
	for i in inimigos.size():
		if inimigos[i].estado in ["andar", "rondar"]:
			vivos.append(i)
	vivos.sort_custom(func(a, b): return absf(inimigos[a].x - hx) < absf(inimigos[b].x - hx))
	for k in vivos.size():
		inimigos[vivos[k]].estado = "andar" if k < ATACAM else "rondar"
	for e in inimigos:
		_pensar(e, dt)
	# os que caíram de vez somem
	inimigos = inimigos.filter(func(e): return not (e.estado == "morto" and e.t > 1.4))
	if brigando and inimigos.is_empty():
		brigando = false
		onda += 1
		if onda >= ONDAS.size():
			nivel += 1
			Nucleo.emitir("fase", {"n": nivel})
			_rua_nova()
		else:
			Nucleo.emitir("trava", {"x": ONDAS[onda].x - 320.0})
			Nucleo.emitir("som", {"nome": "fase"})


func _pensar(e: Dictionary, dt: float) -> void:
	var tp: Dictionary = TIPOS[e.tipo]
	e.t += dt
	e.t_anim += dt
	e.recarga = maxf(0.0, e.recarga - dt)
	match e.estado:
		"entrar":
			if e.t < 0.0:
				return  # ainda não entrou (cada um entra um pouco depois do outro)
			_ir(e, Vector2(clampf(e.x, cam + 70.0, cam + 570.0), e.y), tp.vel * 2.0, dt)
			if e.x > cam + 30.0 and e.x < cam + 610.0:
				_mudar(e, "andar")
		"andar", "rondar":
			var lado := 1.0 if e.x >= hx else -1.0
			var perto: float = tp.alcance - 12.0 if e.estado == "andar" else 150.0
			var alvo := Vector2(hx + lado * perto, hy if e.estado == "andar" else e.y)
			_ir(e, alvo, tp.vel * (1.0 if e.estado == "andar" else 0.6), dt)
			e.dir = -1 if e.x > hx else 1
			var no_alcance: bool = absf(e.x - hx) <= tp.alcance and absf(e.y - hy) < 10.0
			if e.estado == "andar" and no_alcance and e.recarga <= 0.0:
				if tp.get("chefe", false) and Nucleo.rng.randf() < 0.35:
					_mudar(e, "agachar")
				else:
					_mudar(e, "preparar")
		"preparar":
			if e.t >= tp.preparar:
				_mudar(e, "golpe")
				Nucleo.emitir("golpe_inimigo", {"x": e.x, "y": e.y, "dir": e.dir, "alcance": tp.alcance, "dano": tp.dano * _forca(), "forte": tp.get("forte", false)})
		"golpe":
			if e.t >= tp.golpe:
				_mudar(e, "andar")
				e.recarga = tp.recarga
		"agachar":  # chefe avisando a investida
			if e.t >= 0.6:
				_mudar(e, "investida")
		"investida":
			e.x += e.dir * 300.0 * dt
			Nucleo.emitir("golpe_inimigo", {"x": e.x, "y": e.y, "dir": e.dir, "alcance": 40.0, "dano": 18.0 * _forca(), "forte": true})
			if e.t >= 0.9 or e.x < cam + 20.0 or e.x > cam + 620.0:
				_mudar(e, "andar")
				e.recarga = tp.recarga * 1.5
		"dano":
			if e.t >= 0.32:
				_mudar(e, "andar")
				e.recarga = maxf(e.recarga, 0.35)
		"caido":
			if e.t >= 1.1:
				_mudar(e, "andar")
				e.recarga = 0.8
	e.x = clampf(e.x, cam - 80.0, cam + 720.0)
	e.y = clampf(e.y, 214.0, 348.0)


func _ir(e: Dictionary, alvo: Vector2, vel: float, dt: float) -> void:
	var p := Vector2(e.x, e.y)
	var d := alvo - p
	if d.length() > 2.0:
		p += d.normalized() * minf(vel * dt, d.length()) * Vector2(1.0, 0.7)
		e.x = p.x
		e.y = p.y
		e.anim = "andar"
	else:
		e.anim = "parado"


func _mudar(e: Dictionary, estado: String) -> void:
	e.estado = estado
	e.t = 0.0
	var a: String = {"entrar": "andar", "andar": "andar", "rondar": "andar", "preparar": "preparar", "golpe": "golpe",
		"agachar": "agachar", "investida": "investida", "dano": "dano", "caido": "cair", "morto": "cair"}[estado]
	if a != e.anim:
		e.anim = a
		e.t_anim = 0.0


func evento(nome: String, d: Dictionary) -> void:
	match nome:
		"heroi":
			hx = float(d.x)
			hy = float(d.y)
		"camera":
			cam = float(d.x)
		"golpe":
			_apanhar(d)
		"atores":
			for e in inimigos:
				d.lista.append({"y": e.y, "f": _desenhar.bind(e)})


func _apanhar(d: Dictionary) -> void:
	for i in inimigos.size():
		var e: Dictionary = inimigos[i]
		if e.estado in ["caido", "morto", "entrar"]:
			continue
		var tp: Dictionary = TIPOS[e.tipo]
		if absf(e.y - float(d.y)) > 18.0:
			continue
		var frente: float = (e.x - float(d.x)) * float(d.dir)
		if frente < -4.0 or frente > float(d.alcance) + tp.larg * 0.3:
			continue
		var forte := bool(d.get("forte", false))
		e.vida = maxf(0.0, e.vida - float(d.dano))
		e.dir = -int(d.dir)
		e.x += float(d.dir) * (30.0 if forte else 6.0)
		ultimo = i
		ultimo_t = 2.5
		Nucleo.emitir("acertou", {"x": e.x - float(d.dir) * 10.0, "y": e.y - tp.q * 0.55, "forte": forte})
		Nucleo.emitir("som", {"nome": "forte" if forte else "soco"})
		Nucleo.emitir("pontuou", {"pontos": 10})
		if e.vida <= 0.0:
			_mudar(e, "morto")
			Nucleo.emitir("pontuou", {"pontos": tp.pontos})
			Nucleo.emitir("poeira", {"x": e.x, "y": e.y - 16.0})
			Nucleo.emitir("soltar", {"x": e.x, "y": e.y})
			if tp.get("chefe", false):
				Nucleo.emitir("tremer", {"forca": 10.0})
		elif forte and not tp.get("chefe", false):
			_mudar(e, "caido")  # o chefe aguenta o chute em pé
			Nucleo.emitir("poeira", {"x": e.x, "y": e.y - 16.0})
		else:
			_mudar(e, "dano")


func _desenhar(tela: Node2D, o: Vector2, e: Dictionary) -> void:
	var tp: Dictionary = TIPOS[e.tipo]
	var pe := Vector2(e.x, e.y) + o
	if e.estado == "morto" and e.t > 0.7 and int(e.t * 14.0) % 2 == 0:
		return  # pisca e some
	var deitado: bool = e.estado in ["caido", "morto"] and e.t > 0.2
	Folha.sombra(tela, pe + Vector2(e.dir * 8.0 if deitado else 0.0, 0), tp.larg * (1.6 if deitado else 1.0))
	var cor := Color.WHITE
	if e.estado == "preparar" or e.estado == "agachar":
		cor = Color(1.0, 0.75, 0.75).lerp(Color(1.6, 1.2, 1.2), absf(sin(e.t * 18.0)))  # aviso: brilha antes de bater
	_folhas[e.tipo].desenhar(tela, e.anim, e.t_anim, pe + Vector2(0, 4), e.dir, cor)
	if e.estado == "caido" and e.t > 0.35:
		_folhas.itens.desenhar(tela, "tontura", e.t, pe + Vector2(e.dir * -26.0, -10.0))


func desenhar_hud(tela: Node2D) -> void:
	var f := ThemeDB.fallback_font
	var pt := OS.get_locale_language() == "pt"
	if ultimo_t > 0.0 and ultimo >= 0 and ultimo < inimigos.size():
		var e: Dictionary = inimigos[ultimo]
		var qual := ["punk", "bruto", "chefe"].find(e.tipo) + 1
		if _retrato != null:
			tela.draw_rect(Rect2(607, 25, 26, 26), Color("#0b0715"))
			tela.draw_texture_rect_region(_retrato, Rect2(608, 26, 24, 24), Rect2(qual * 24, 0, 24, 24))
		var nome: String = {"punk": "PUNK", "bruto": "BRUTO" if pt else "BRUTE", "chefe": "CHEFE" if pt else "BOSS"}[e.tipo]
		tela.draw_rect(Rect2(480, 30, 124, 10), Color("#0b0715"))
		tela.draw_rect(Rect2(482 + 120.0 * (1.0 - e.vida / e.max), 32, 120.0 * e.vida / e.max, 6), Color("#ffc531"))
		tela.draw_string(f, Vector2(480, 54), nome, HORIZONTAL_ALIGNMENT_RIGHT, 124, 11, Color("#f2f2f2"))
	# rua livre: a seta pisca mandando seguir
	if not brigando and inimigos.is_empty() and Nucleo.quadro % 40 < 26 and hx > 60.0:
		var vai := "VAI!" if pt else "GO!"
		tela.draw_string(f, Vector2(540, 120), vai, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ffc531"))
		tela.draw_colored_polygon(PackedVector2Array([Vector2(596, 102), Vector2(612, 112), Vector2(596, 122)]), Color("#ffc531"))


func bot() -> String:
	# vai no inimigo mais perto que já entrou, fica na mesma profundidade e bate de frente
	var alvo := {}
	var melhor := 1e9
	for e in inimigos:
		if e.estado in ["morto", "entrar"]:
			continue
		var dist := absf(e.x - hx) + absf(e.y - hy) * 2.0
		if dist < melhor:
			melhor = dist
			alvo = e
	if alvo.is_empty():
		return ""
	var lado := 1.0 if alvo.x >= hx else -1.0
	var dx: float = alvo.x - hx
	var dy: float = alvo.y - hy
	var acoes: Array = []
	if absf(dy) > 5.0:
		acoes.append("baixo" if dy > 0.0 else "cima")
	if absf(dx) > 48.0:
		acoes.append("direita" if lado > 0.0 else "esquerda")
	elif absf(dx) < 20.0:
		acoes.append("esquerda" if lado > 0.0 else "direita")  # perto demais: dá um passo para trás
	var heroi := Nucleo.mod("Heroi")
	var olhando_certo: bool = heroi == null or int(heroi.dir) == int(lado)
	if absf(dy) < 10.0 and absf(dx) <= 58.0:
		if not olhando_certo:
			acoes.append("direita" if lado > 0.0 else "esquerda")
		acoes.append("acao")
	return "+".join(acoes)


func progresso() -> int:
	return (nivel - 1) * ONDAS.size() + onda


func salvar() -> Dictionary:
	return {"inimigos": inimigos.duplicate(true), "onda": onda, "brigando": brigando, "nivel": nivel, "hx": hx, "hy": hy,
		"cam": cam, "ultimo": ultimo, "ultimo_t": ultimo_t}


func carregar(d: Dictionary) -> void:
	if d.is_empty():
		return
	inimigos = []
	for e in d.inimigos:
		var n: Dictionary = e.duplicate(true)
		n.dir = int(n.dir)  # o JSON devolve número como float
		inimigos.append(n)
	onda = int(d.onda)
	brigando = bool(d.brigando)
	nivel = int(d.nivel)
	hx = float(d.hx)
	hy = float(d.hy)
	cam = float(d.cam)
	ultimo = int(d.ultimo)
	ultimo_t = float(d.ultimo_t)


func _correr(seg: float) -> void:
	for i in int(seg / Nucleo.DT):
		passo(Nucleo.DT)


func teste(t) -> void:
	novo_jogo()
	evento("heroi", {"x": 100.0, "y": 290.0})
	_correr(1.0)
	t.ok(inimigos.is_empty() and not brigando, "antes do ponto da briga a rua está vazia")
	evento("camera", {"x": ONDAS[0].x - 320.0})
	evento("heroi", {"x": ONDAS[0].x, "y": 290.0})
	passo(Nucleo.DT)
	t.ok(brigando and inimigos.size() == ONDAS[0].quem.size(), "no ponto da briga entra a onda (%d)" % inimigos.size())
	_correr(6.0)
	var entraram := inimigos.all(func(e): return e.estado != "entrar")
	t.ok(entraram, "todos entram na tela")
	var chegaram: Array = inimigos.filter(func(e): return absf(e.x - hx) < 60.0)
	t.ok(chegaram.size() >= 1, "eles vêm para cima do herói")
	var avisou := false
	var bateu := false
	for e in inimigos:
		_mudar(e, "andar")
		e.recarga = 0.0
	for i in 300:
		passo(Nucleo.DT)
		for e in inimigos:
			avisou = avisou or e.estado == "preparar"
			bateu = bateu or (e.estado == "golpe")
		if bateu:
			break
	t.ok(avisou and bateu, "o inimigo avisa (prepara) antes de bater")
	var atacando := inimigos.filter(func(e): return e.estado in ["andar", "preparar", "golpe"]).size()
	t.ok(atacando <= ATACAM, "no máximo %d vão para cima ao mesmo tempo (%d)" % [ATACAM, atacando])
	# o herói bate: tira vida, chute derruba, vida zero = some e dá pontos
	var e: Dictionary = inimigos[0]
	_mudar(e, "andar")
	e.x = hx + 20.0
	e.y = hy
	var antes: float = e.vida
	_apanhar({"x": hx, "y": hy, "dir": 1, "alcance": 32.0, "dano": 7.0, "forte": false})
	t.ok(e.vida == antes - 7.0 and e.estado == "dano", "soco de frente tira vida")
	e.x = hx + 20.0
	_mudar(e, "andar")
	_apanhar({"x": hx, "y": hy, "dir": -1, "alcance": 32.0, "dano": 7.0, "forte": false})
	t.ok(e.vida == antes - 7.0, "soco virado para o outro lado não pega")
	e.x = hx + 20.0
	_apanhar({"x": hx, "y": hy, "dir": 1, "alcance": 38.0, "dano": 1.0, "forte": true})
	t.ok(e.estado == "caido", "chute derruba")
	_apanhar({"x": hx, "y": hy, "dir": 1, "alcance": 60.0, "dano": 1.0, "forte": true})
	t.ok(e.vida == antes - 8.0, "caído não apanha")
	# limpar todas as ondas termina a rua e começa a próxima, mais dura
	for k in ONDAS.size():
		for x in inimigos:
			x.vida = 0.0
			_mudar(x, "morto")
		_correr(1.6)
		t.ok(onda == (k + 1) % ONDAS.size() and not brigando, "onda %d limpa libera a rua" % (k + 1))
		if k < ONDAS.size() - 1:
			evento("camera", {"x": ONDAS[onda].x - 320.0})
			evento("heroi", {"x": ONDAS[onda].x, "y": 290.0})
			passo(Nucleo.DT)
	t.ok(nivel == 2 and _forca() > 1.0, "depois do chefe vem a rua 2, mais dura")
	var d := salvar()
	carregar(JSON.parse_string(JSON.stringify(d)))
	t.ok(JSON.stringify(salvar()) == JSON.stringify(d), "salvar e carregar devolvem a mesma briga")
	Nucleo.novo_jogo(1)

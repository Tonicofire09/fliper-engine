extends "res://scripts/nucleo/modulo.gd"
## Partida (biblioteca do kit): pontos, vidas, recorde salvo e as telas de início, pausa e fim.
## Ouve: "pontuou" {pontos}, "perdeu_vida", "vida_extra", "fim_de_jogo", "fase" {n}.
## Emite: "tremer", "som", "texto". Ajuste as constantes abaixo para o seu jogo.

const VIDAS := 3
const DICA := "WASD / setas anda  ·  espaço pula"
const BRANCO := Color("#f2f2f2")
const OURO := Color("#ffc531")
const ROSA := Color("#ff2e88")
const CINZA := Color("#a8a8a8")

var pontos := 0
var recorde := 0
var vidas := VIDAS
var nivel := 1
var fase := "inicio"  # inicio | jogando | pausa | fim
var aviso := ""
var aviso_t := 0.0


func _init() -> void:
	camada = 100


func titulo() -> String:
	return String(ProjectSettings.get_setting("application/config/name", "FLIPER")).to_upper()


func novo_jogo() -> void:
	pontos = 0
	vidas = VIDAS
	nivel = 1
	fase = "inicio"
	aviso = ""
	Nucleo.pausado = true


func passo(dt: float) -> void:
	aviso_t = maxf(0.0, aviso_t - dt)


func entrada(acao: String) -> bool:
	if acao == "acao" and fase in ["inicio", "pausa"]:
		fase = "jogando"
		Nucleo.pausado = false
		Nucleo.emitir("som", {"nome": "inicio"})
		return true
	if acao == "acao" and fase == "fim":
		Nucleo.reiniciar()  # novo_jogo de todos → volta para "inicio"
		entrada("acao")
		return true
	if acao == "pausa" and fase == "jogando":
		fase = "pausa"
		Nucleo.pausado = true
		return true
	return fase != "jogando"  # fora do jogo as teclas não mexem em nada


func evento(nome: String, dados: Dictionary) -> void:
	match nome:
		"pontuou":
			pontos += int(dados.get("pontos", 0))
			recorde = maxi(recorde, pontos)
		"perdeu_vida":
			vidas -= 1
			Nucleo.emitir("tremer", {"forca": 7.0})
			Nucleo.emitir("som", {"nome": "dano"})
			if vidas <= 0:
				_acabou()
		"vida_extra":
			vidas += 1
			_avisar("+1 VIDA")
			Nucleo.emitir("som", {"nome": "power"})
		"fim_de_jogo":
			_acabou()
		"fase":
			nivel = int(dados.get("n", nivel + 1))
			_avisar("FASE %d" % nivel)
			Nucleo.emitir("som", {"nome": "fase"})


func _avisar(txt: String) -> void:
	aviso = txt
	aviso_t = 1.6


func _acabou() -> void:
	if fase == "fim":
		return
	fase = "fim"
	Nucleo.pausado = true
	Nucleo.emitir("som", {"nome": "fim"})
	Nucleo.salvar()  # o recorde não se perde se o jogo fechar à força


func bot() -> String:
	return "acao" if fase in ["inicio", "fim"] else ""


func progresso() -> int:
	return pontos


func desenhar_hud(tela: Node2D) -> void:
	var f := ThemeDB.fallback_font
	tela.draw_rect(Rect2(0, 0, 640, 22), Color(0.02, 0.01, 0.05, 0.85))
	tela.draw_string(f, Vector2(10, 16), "%06d" % pontos, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BRANCO)
	tela.draw_string(f, Vector2(0, 16), titulo(), HORIZONTAL_ALIGNMENT_CENTER, 640, 12, ROSA)
	tela.draw_string(f, Vector2(0, 16), "HI %06d" % recorde, HORIZONTAL_ALIGNMENT_RIGHT, 630, 13, OURO)
	for i in mini(vidas, 8):
		tela.draw_rect(Rect2(96 + i * 12, 7, 8, 8), ROSA)
	if aviso_t > 0.0 and fase == "jogando":
		tela.draw_string(f, Vector2(0, 190), aviso, HORIZONTAL_ALIGNMENT_CENTER, 640, 30, OURO)
	if fase == "jogando":
		return
	tela.draw_rect(Rect2(0, 22, 640, 338), Color(0.02, 0.01, 0.05, 0.74))
	var t: String = {"inicio": titulo(), "pausa": "PAUSA", "fim": "GAME OVER"}[fase]
	var sub: String = {"inicio": DICA, "pausa": "Esc pausa", "fim": "%d pontos%s" % [pontos, "  ·  NOVO RECORDE!" if pontos > 0 and pontos >= recorde else ""]}[fase]
	tela.draw_string(f, Vector2(3, 173), t, HORIZONTAL_ALIGNMENT_CENTER, 640, 40, ROSA.darkened(0.5))
	tela.draw_string(f, Vector2(0, 170), t, HORIZONTAL_ALIGNMENT_CENTER, 640, 40, ROSA if fase == "fim" else BRANCO)
	tela.draw_string(f, Vector2(0, 204), sub, HORIZONTAL_ALIGNMENT_CENTER, 640, 14, CINZA)
	tela.draw_string(f, Vector2(0, 256), "ESPAÇO para %s" % ("voltar" if fase == "pausa" else "jogar"), HORIZONTAL_ALIGNMENT_CENTER, 640, 15, OURO)


func salvar() -> Dictionary:
	return {"pontos": pontos, "recorde": recorde, "vidas": vidas, "nivel": nivel, "fase": fase}


func carregar(d: Dictionary) -> void:
	recorde = int(d.get("recorde", recorde))
	pontos = int(d.get("pontos", pontos))
	vidas = int(d.get("vidas", vidas))
	nivel = int(d.get("nivel", nivel))
	fase = String(d.get("fase", fase))


func teste(t) -> void:
	recorde = 0
	novo_jogo()
	t.ok(fase == "inicio" and Nucleo.pausado, "começa na tela de início, parado")
	t.ok(entrada("cima") and fase == "inicio", "na tela de início as teclas não mexem no jogo")
	entrada("acao")
	t.ok(fase == "jogando" and not Nucleo.pausado, "espaço começa a partida")
	evento("pontuou", {"pontos": 30})
	t.ok(pontos == 30 and recorde == 30, "pontuar soma e bate o recorde")
	entrada("pausa")
	t.ok(fase == "pausa" and Nucleo.pausado, "Esc pausa")
	entrada("acao")
	for i in VIDAS - 1:
		evento("perdeu_vida", {})
	t.ok(fase == "jogando" and vidas == 1, "perder %d vidas ainda deixa jogar" % (VIDAS - 1))
	evento("vida_extra", {})
	t.ok(vidas == 2, "vida extra soma uma vida")
	evento("perdeu_vida", {})
	evento("perdeu_vida", {})
	t.ok(fase == "fim" and Nucleo.pausado, "sem vidas é game over")
	entrada("acao")
	t.ok(fase == "jogando" and pontos == 0 and recorde == 30 and vidas == VIDAS, "espaço recomeça zerado e mantém o recorde")
	var d := salvar()
	recorde = 0
	carregar(d)
	t.ok(recorde == 30, "o recorde volta do save")
	Nucleo.novo_jogo(1)

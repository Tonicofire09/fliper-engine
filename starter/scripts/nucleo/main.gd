extends Node2D
## Cena principal: roda o jogo de verdade ou um cenário de teste, conforme os argumentos depois do "--".
##   (sem --cena)                              jogo normal
##   --cena=regras                             checks do núcleo (todos os módulos se comportam como módulo)
##   --cena=modulo --modulo=Nome               checks do módulo (teste(t))
##   --cena=jogar --passos=N [--semente=S]     o bot joga N passos sozinho; falha se der erro ou não pontuar
##   --cena=print --shot=arq.png [--passos=N]  joga N passos com o bot e grava a tela (precisa de janela: xvfb-run)
##                                             --shot=- imprime o print em base64 (FLIPER_TELA:...) para o Fliper Studio
## Saída dos testes sempre na forma "== N ok, M falhas ==" (é o que ferramentas/testar_tudo.sh lê).

const Checagem = preload("res://scripts/nucleo/checagem.gd")
const ACOES := {
	"cima": [KEY_W, KEY_UP], "baixo": [KEY_S, KEY_DOWN], "esquerda": [KEY_A, KEY_LEFT],
	"direita": [KEY_D, KEY_RIGHT], "acao": [KEY_SPACE, KEY_ENTER], "pausa": [KEY_ESCAPE, KEY_P],
}

var args := {}
var acumulado := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_mapear_controles()
	if args.has("cena"):
		Nucleo.em_teste = true
		_cenario.call_deferred(String(args.cena))
		return
	Nucleo.carregar()
	Nucleo.novo_jogo()


func _mapear_controles() -> void:
	for acao in ACOES:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
		for k in ACOES[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)


func _unhandled_input(ev: InputEvent) -> void:
	if args.has("cena"):
		return
	for acao in ACOES:
		if ev.is_action_pressed(acao, false):
			Nucleo.seg[acao] = true
			Nucleo.entrada(acao)
			get_viewport().set_input_as_handled()
			return
		if ev.is_action_released(acao):
			Nucleo.seg[acao] = false


func _process(delta: float) -> void:
	if args.has("cena"):
		return
	acumulado = minf(acumulado + delta, 0.25)
	while acumulado >= Nucleo.DT:
		acumulado -= Nucleo.DT
		Nucleo.passo()
	queue_redraw()


func _draw() -> void:
	Nucleo.desenhar(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not args.has("cena"):
		Nucleo.salvar()


# ---- cenários de teste
func _cenario(cena: String) -> void:
	var t = Checagem.new()
	match cena:
		"regras":
			_regras(t)
		"modulo":
			var m := Nucleo.mod(String(args.get("modulo", "")))
			t.ok(m != null, "módulo existe: " + String(args.get("modulo", "")))
			if m != null:
				Nucleo.novo_jogo(1)
				m.teste(t)
		"jogar":
			_jogar(t, int(args.get("passos", "3600")), int(args.get("semente", "1")))
		"print":
			await _print(t)
		_:
			t.ok(false, "cena desconhecida: " + cena)
	print("== %d ok, %d falhas ==" % [t.oks, t.falhas])
	get_tree().quit(1 if t.falhas > 0 else 0)


func _regras(t) -> void:
	t.ok(Nucleo.mods.size() == Nucleo.MODULOS.size(), "todo nome de MODULOS tem autoload")
	var base := load("res://scripts/nucleo/modulo.gd")
	for m in Nucleo.mods:
		t.ok(m.get_script() != null and _herda(m.get_script(), base), "%s herda de modulo.gd" % m.name)
	# a mesma semente dá a mesma partida (sem isso o bot e os testes não se repetem)
	var a := _rodar(1, 600)
	var b := _rodar(1, 600)
	t.ok(JSON.stringify(a) == JSON.stringify(b), "mesma semente, mesmo jogo")
	# save e load devolvem o mesmo estado
	Nucleo.novo_jogo(2)
	for i in 300:
		_um_passo_do_bot()
	var antes := JSON.stringify(Nucleo.estado())
	Nucleo.aplicar(JSON.parse_string(antes))
	t.ok(JSON.stringify(Nucleo.estado()) == antes, "salvar e carregar não mudam nada")


func _herda(s: Script, base: Script) -> bool:
	while s != null:
		if s == base:
			return true
		s = s.get_base_script()
	return false


func _rodar(semente: int, passos: int) -> Dictionary:
	Nucleo.novo_jogo(semente)
	for i in passos:
		_um_passo_do_bot()
	return Nucleo.estado()


func _um_passo_do_bot() -> void:
	Nucleo.seg.clear()
	var a := Nucleo.bot()
	if a != "":
		for parte in a.split("+", false):
			Nucleo.seg[parte] = true
			Nucleo.entrada(parte)
	Nucleo.passo()


func _jogar(t, passos: int, semente: int) -> void:
	var r := 0
	var mudou := 0
	var melhor := 0
	Nucleo.novo_jogo(semente)
	var ultimo := JSON.stringify(Nucleo.estado())
	for i in passos:
		_um_passo_do_bot()
		melhor = maxi(melhor, Nucleo.progresso())
		if i % 60 == 0:
			var agora := JSON.stringify(Nucleo.estado())
			if agora != ultimo:
				mudou += 1
			ultimo = agora
		r = i
	t.ok(r == passos - 1, "o bot jogou %d passos sem travar" % passos)
	t.ok(mudou > 0, "o jogo andou (o estado mudou enquanto o bot jogava)")
	# cada jogo diz o que é avançar pelo gancho progresso() (pontos, fase, área limpa...)
	print("bot: melhor progresso %d em %d passos (semente %d)" % [melhor, passos, semente])
	t.ok(melhor > 0, "o bot avançou no jogo (melhor progresso %d em %d passos)" % [melhor, passos])

func _print(t) -> void:
	Nucleo.novo_jogo(int(args.get("semente", "1")))
	for i in int(args.get("passos", "240")):
		_um_passo_do_bot()
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var arq := String(args.get("shot", "print.png"))
	if arq == "-":
		# Fliper Studio no navegador: o print sai na saída (base64), e o estúdio pega de lá
		if img != null and img.get_width() > 960:
			img.resize(960, int(img.get_height() * 960.0 / img.get_width()), Image.INTERPOLATE_NEAREST)
		t.ok(img != null, "print tirado")
		if img != null:
			print("FLIPER_TELA:" + Marshalls.raw_to_base64(img.save_png_to_buffer()))
		return
	t.ok(img != null and img.save_png(arq) == OK, "print gravado em " + arq)

extends Node
## Autoload "Nucleo": guarda a lista de módulos e repassa os ganchos de modulo.gd para todos eles.
## A lista MODULOS é mantida por ferramentas/novo_modulo.py (não precisa editar à mão).

const MODULOS := ["Partida", "Som", "Jogador", "Gemas", "Perigos", "Visual"]  # gerenciado por novo_modulo.py
const DT := 1.0 / 60.0
const SAVE := "user://save.json"

var mods: Array = []
var rng := RandomNumberGenerator.new()
var quadro := 0  # passos simulados desde novo_jogo()
var pausado := false  # true = passo() não anda (tela de início, pausa, fim)
var em_teste := false  # main.gd liga nos cenários de teste: aí o save real nunca é tocado
var iniciado := false  # vira true no 1º novo_jogo(); antes disso nada é desenhado
var seg := {}  # ações seguradas agora (teclado ou bot): use segurando("esquerda") para movimento contínuo


func _ready() -> void:
	for n in MODULOS:
		var m = get_node_or_null("/root/" + n)
		if m == null:
			push_error("módulo %s está em MODULOS mas não no [autoload] do project.godot" % n)
			continue
		mods.append(m)


func mod(nome: String) -> Node:
	return get_node_or_null("/root/" + nome)


var _texturas := {}


## Textura de um PNG do projeto. Funciona no editor, no jogo exportado e no Fliper Studio do navegador
## (lá o projeto roda sem o "import" do editor: carrega a imagem direto do arquivo).
func textura(caminho: String) -> Texture2D:
	if _texturas.has(caminho):
		return _texturas[caminho]
	var t: Texture2D = null
	if ResourceLoader.exists(caminho):
		t = load(caminho)
	if t == null:
		var img := Image.load_from_file(caminho)
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	if t == null:
		push_error("textura não encontrada: " + caminho)
	_texturas[caminho] = t
	return t


## Animações (SpriteFrames) a partir da folha PNG e do mapa .json que criar_personagem / animar_sprite gravam
## ao lado dela (mesmo nome). Funciona no editor, exportado e no Fliper Studio do navegador.
func animacoes(caminho_png: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var tex := textura(caminho_png)
	var mapa = JSON.parse_string(FileAccess.get_file_as_string(caminho_png.get_basename() + ".json"))
	if tex == null or not mapa is Dictionary:
		push_error("animação sem folha ou sem mapa: " + caminho_png)
		return sf
	var q: Dictionary = mapa.quadro
	for nome in mapa.animacoes:
		var a: Dictionary = mapa.animacoes[nome]
		sf.add_animation(nome)
		sf.set_animation_speed(nome, float(a.fps))
		sf.set_animation_loop(nome, bool(a.loop))
		for i in int(a.quadros):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * float(q.largura), float(a.linha) * float(q.altura), float(q.largura), float(q.altura))
			sf.add_frame(nome, at)
	return sf


func novo_jogo(semente := -1) -> void:
	if semente >= 0:
		rng.seed = semente
	else:
		rng.randomize()
	quadro = 0
	iniciado = true
	reiniciar()


func reiniciar() -> void:
	# partida nova sem trocar a semente (o bot e os testes continuam repetíveis)
	pausado = false
	for m in mods:
		m.novo_jogo()


func passo(dt := DT) -> void:
	if pausado:
		return
	quadro += 1
	for m in mods:
		m.passo(dt)


func segurando(acao: String) -> bool:
	return seg.get(acao, false)


func entrada(acao: String) -> bool:
	for m in mods:
		if m.entrada(acao):
			return true
	return false


func emitir(nome: String, dados := {}) -> void:
	for m in mods:
		m.evento(nome, dados)


func desenhar(tela: Node2D) -> void:
	if not iniciado:
		return
	var ordem := mods.duplicate()
	ordem.sort_custom(func(a, b): return a.camada < b.camada)
	for m in ordem:
		m.desenhar(tela)
	# interface por cima de tudo e fora do tremor de tela (placar, vidas, telas de início e fim)
	tela.draw_set_transform(Vector2.ZERO)
	for m in ordem:
		m.desenhar_hud(tela)


func bot() -> String:
	# a 1ª sugestão não vazia ganha; pode juntar ações com "+" ("esquerda+acao")
	for m in mods:
		var a: String = m.bot()
		if a != "":
			return a
	return ""


func progresso() -> int:
	var n := 0
	for m in mods:
		n += int(m.progresso())
	return n


# ---- save: um dicionário por módulo, pelo nome do autoload
func estado() -> Dictionary:
	var d := {}
	for m in mods:
		d[String(m.name)] = m.salvar()
	return d


func aplicar(d: Dictionary) -> void:
	for m in mods:
		m.carregar(d.get(String(m.name), {}))


func salvar(caminho := SAVE) -> bool:
	if em_teste and caminho == SAVE:
		return false
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(estado()))
	return true


func carregar(caminho := SAVE) -> bool:
	if em_teste and caminho == SAVE:
		return false
	if not FileAccess.file_exists(caminho):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not d is Dictionary:
		return false
	aplicar(d)
	return true

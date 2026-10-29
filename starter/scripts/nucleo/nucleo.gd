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
			# duração por quadro (antecipação curta, impacto segurado): vem de animar_acoes
			sf.add_frame(nome, at, float(a.duracoes[i]) if a.has("duracoes") else 1.0)
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


# ---------- game feel (receita "animacao"): só visual, nunca mexe na simulação nem nos testes ----------
var _trauma := 0.0
var _camera_tremendo: Node = null


func _sem_tela() -> bool:
	return em_teste or DisplayServer.get_name() == "headless"


## Congela o jogo por um instante no impacto (0,05 a 0,1 s em golpe forte; menos que isso ninguém sente).
func congelar(segundos := 0.07) -> void:
	if _sem_tela() or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(segundos, true, false, true).timeout
	Engine.time_scale = 1.0


## Treme a câmera (Camera2D ou Camera3D). forca 0..1 soma no trauma, que decai sozinho em ~0,3 s.
func tremer(camera: Node, forca := 0.4) -> void:
	if _sem_tela() or camera == null:
		return
	_trauma = minf(1.0, _trauma + forca)
	_camera_tremendo = camera


## Amassa/estica um sprite ou malha e volta com mola. 2D: (x, y). 3D: x vale para x e z.
func amassar(no: Node, x := 1.3, y := 0.7, volta := 0.25) -> void:
	if _sem_tela() or no == null or not ("scale" in no):
		return
	var normal = Vector2.ONE if no is Node2D or no is Control else Vector3.ONE
	no.scale = Vector2(x, y) if normal is Vector2 else Vector3(x, y, x)
	var tw := no.create_tween()
	tw.tween_property(no, "scale", normal, volta).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Clarão branco rápido (dano): modulate sobe e volta.
func piscar(no: CanvasItem, vezes := 2) -> void:
	if _sem_tela() or no == null:
		return
	var tw := no.create_tween()
	for i in vezes:
		tw.tween_property(no, "modulate", Color(3, 3, 3), 0.04)
		tw.tween_property(no, "modulate", Color.WHITE, 0.06)


func _process(dt: float) -> void:
	if _camera_tremendo == null or not is_instance_valid(_camera_tremendo):
		return
	_trauma = maxf(0.0, _trauma - dt * 3.0)
	var t := _trauma * _trauma  # quadrado: tremor pequeno some rápido, grande pesa
	var dx := randf_range(-1, 1) * t
	var dy := randf_range(-1, 1) * t
	if _camera_tremendo is Camera2D:
		_camera_tremendo.offset = Vector2(dx, dy) * 12.0
	elif _camera_tremendo is Camera3D:
		_camera_tremendo.h_offset = dx * 0.3
		_camera_tremendo.v_offset = dy * 0.3
	if _trauma == 0.0:
		_camera_tremendo = null

@tool
extends VBoxContainer
## O painel da Fliper no editor: conversa com a IA, que mexe no projeto aberto.
## A chave fica nas configurações do editor deste computador (nunca dentro do projeto).

const MAGENTA := Color("#ff2e88")
const DOURADO := Color("#ffc531")
const AgenteFliper := preload("res://addons/fliper/agente.gd")
const FerramentasFliper := preload("res://addons/fliper/ferramentas.gd")
const TEXTOS := {
	"pt": {"sub": "IA do estúdio", "novo": "Novo", "ola": "Oi! Eu sou a Fliper.", "conte": "Conte o jogo que você quer: eu programo, desenho, testo e abro para você jogar.",
		"chave": "sua chave Fliper (flp_…) ou sk-or-…", "modelo": "modelo (vazio = padrão)", "pegar": "Pegar a sua chave Fliper grátis (fliperstudio.com/account)", "entrada": "Diga o que você quer no jogo…",
		"entrar": "Entrar com a Fliper", "plano_sem": "Sem conta conectada", "plano_dono": "Dono · IA sem limite", "plano_gratis": "Fliper Free · %d de %d restam (volta a cada 5 h)", "plano_pago": "Fliper %s · ≈%.1f h de IA restam · semana %d%%", "comprar": "Assinar o Pro", "subir": "Ir para o Max", "vivo": "Ao vivo", "vivo_dica": "Abre no editor o que a IA mexe e roda o jogo depois de cada teste", "codigo": "Seu código: [b]%s[/b]. Confirme no navegador que abriu (o mesmo código).", "entrou": "Pronto: conectado como [b]%s[/b]. A IA da Fliper é grátis todo dia.", "expirou": "O código expirou ou falhou. Clique em Entrar de novo.", "sem_conta": "Para a IA funcionar: [url=entrar]Entrar com a Fliper[/url] (grátis).",
		"enviar": "Enviar  (Ctrl+Enter)", "parar": "Parar", "voce": "Você",
		"sugestoes": ["Faz um jogo de plataforma com moedas", "Coloca um inimigo que persegue o jogador", "Deixa o jogo mais bonito", "Por que o meu jogo dá erro?"]},
	"en": {"sub": "studio AI", "novo": "New", "ola": "Hi! I'm Fliper.", "conte": "Tell me the game you want: I code it, draw it, test it and open it for you to play.",
		"chave": "your Fliper key (flp_…) or sk-or-…", "modelo": "model (empty = default)", "pegar": "Get your free Fliper key (fliperstudio.com/account)", "entrada": "Tell me what you want in the game…",
		"entrar": "Sign in with Fliper", "plano_sem": "Not signed in", "plano_dono": "Owner · unlimited AI", "plano_gratis": "Fliper Free · %d of %d left (refills every 5 h)", "plano_pago": "Fliper %s · ≈%.1f h of AI left · week %d%%", "comprar": "Get Pro", "subir": "Upgrade to Max", "vivo": "Live", "vivo_dica": "Opens what the AI edits and runs the game after each passing test", "codigo": "Your code: [b]%s[/b]. Approve it in the browser that just opened (same code).", "entrou": "Done: signed in as [b]%s[/b]. The Fliper AI is free every day.", "expirou": "The code expired or failed. Press Sign in again.", "sem_conta": "To use the AI: [url=entrar]Sign in with Fliper[/url] (free).",
		"enviar": "Send  (Ctrl+Enter)", "parar": "Stop", "voce": "You",
		"sugestoes": ["Make a platformer with coins", "Add an enemy that chases the player", "Make the game prettier", "Why does my game crash?"]},
}
var T: Dictionary = TEXTOS.en

var editor: EditorInterface
var agente
var conversa: RichTextLabel
var entrada: TextEdit
var botao: Button
var config: VBoxContainer
var escolha: OptionButton
var campo_chave: LineEdit
var campo_modelo: LineEdit
var botao_entrar: Button
var plano: Label
var comprar: LinkButton
## modelo do plano (fliper-pro / fliper-max): usado quando o campo de modelo está vazio
var plano_modelo := ""
var site := "https://fliperstudio.com"  # os testes trocam por um servidor falso


func _ready() -> void:
	var lingua := str(editor.get_editor_settings().get_setting("interface/editor/editor_language"))
	T = TEXTOS.pt if lingua.begins_with("pt") else TEXTOS.en
	custom_minimum_size = Vector2(280, 0)
	add_theme_constant_override("separation", 6)
	var ferr = FerramentasFliper.new()
	ferr.editor = editor
	ferr.dono = self
	agente = AgenteFliper.new()
	agente.ferramentas = ferr
	agente.dono = self
	agente.falou.connect(_falou)
	agente.agiu.connect(func(r): conversa.append_text("[color=#8a8a8a]  › %s[/color]\n" % r))
	agente.terminou.connect(_livre)
	agente.terminou.connect(_atualizar_plano)
	_montar()
	_carregar_config()
	_boas_vindas()
	_atualizar_plano()


func _montar() -> void:
	var topo := HBoxContainer.new()
	var marca := Label.new()
	marca.text = "FLIPER"
	marca.add_theme_color_override("font_color", MAGENTA)
	marca.add_theme_font_size_override("font_size", 18)
	topo.add_child(marca)
	var sub := Label.new()
	sub.text = T.sub
	sub.modulate = Color(1, 1, 1, 0.55)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(sub)
	topo.add_child(_botao(T.novo, T.novo, func(): agente.novo(); conversa.clear(); _boas_vindas()))
	var vivo := CheckButton.new()
	vivo.text = T.vivo
	vivo.tooltip_text = T.vivo_dica
	vivo.button_pressed = true
	vivo.toggled.connect(func(on): if agente and agente.ferramentas: agente.ferramentas.ao_vivo = on)
	topo.add_child(vivo)
	topo.add_child(_botao("⚙", "Escolher a IA e a chave", func(): config.visible = not config.visible))
	add_child(topo)

	config = VBoxContainer.new()
	config.visible = false
	botao_entrar = Button.new()
	botao_entrar.text = T.entrar
	botao_entrar.add_theme_color_override("font_color", MAGENTA)
	botao_entrar.pressed.connect(_entrar)
	config.add_child(botao_entrar)
	escolha = OptionButton.new()
	for id in AgenteFliper.PROVEDORES:
		escolha.add_item(AgenteFliper.PROVEDORES[id].nome)
		escolha.set_item_metadata(escolha.item_count - 1, id)
	escolha.item_selected.connect(func(_i): _salvar_config())
	config.add_child(escolha)
	campo_chave = LineEdit.new()
	campo_chave.secret = true
	campo_chave.placeholder_text = T.chave
	campo_chave.text_changed.connect(func(_t): _salvar_config())
	config.add_child(campo_chave)
	campo_modelo = LineEdit.new()
	campo_modelo.placeholder_text = T.modelo
	campo_modelo.text_changed.connect(func(_t): _salvar_config())
	config.add_child(campo_modelo)
	var ajuda := LinkButton.new()
	ajuda.text = T.pegar
	ajuda.uri = "https://fliperstudio.com/account#ia"
	config.add_child(ajuda)
	add_child(config)
	# o plano da pessoa, sempre à vista: grátis (quanto sobra hoje), pago (créditos) ou dono
	var linha := HBoxContainer.new()
	plano = Label.new()
	plano.text = T.plano_sem
	plano.modulate = Color(1, 1, 1, 0.7)
	plano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plano.clip_text = true
	linha.add_child(plano)
	comprar = LinkButton.new()
	comprar.text = T.comprar
	comprar.uri = "https://fliperstudio.com/pricing?ref=engine"
	comprar.add_theme_color_override("font_color", DOURADO)
	comprar.visible = false
	linha.add_child(comprar)
	add_child(linha)

	conversa = RichTextLabel.new()
	conversa.bbcode_enabled = true
	conversa.scroll_following = true
	conversa.selection_enabled = true
	conversa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conversa.custom_minimum_size = Vector2(0, 240)
	conversa.meta_clicked.connect(_link)
	add_child(conversa)

	entrada = TextEdit.new()
	entrada.placeholder_text = T.entrada
	entrada.custom_minimum_size = Vector2(0, 70)
	entrada.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	entrada.gui_input.connect(_tecla)
	add_child(entrada)

	botao = Button.new()
	botao.text = T.enviar
	botao.pressed.connect(_enviar)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = MAGENTA
	estilo.set_content_margin_all(8)
	botao.add_theme_stylebox_override("normal", estilo)
	botao.add_theme_color_override("font_color", Color.WHITE)
	add_child(botao)


func _botao(texto: String, dica: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.flat = true
	b.pressed.connect(acao)
	return b


func _link(m) -> void:
	if str(m) == "entrar":
		_entrar()
	elif str(m).begins_with("pedir:"):
		entrada.text = str(m).trim_prefix("pedir:")
		_enviar()


## "Sign in with Fliper": pede um código ao site, abre o navegador e espera a pessoa aprovar (até 10 min).
func _entrar() -> void:
	botao_entrar.disabled = true
	var app := "engine/" + str(Engine.get_version_info().get("string", "?"))
	var r := await _postar(site + "/api/conectar", {"acao": "iniciar", "app": app})
	if not r.get("ok", false):
		conversa.append_text("[color=#ff7b7b]%s[/color]\n" % T.expirou)
		botao_entrar.disabled = false
		return
	conversa.append_text((T.codigo % r.codigo) + "\n")
	OS.shell_open(str(r.url))
	for i in 240:
		await get_tree().create_timer(2.5).timeout
		var e := await _postar(site + "/api/conectar", {"acao": "esperar", "segredo": r.segredo})
		if e.get("estado", "") == "pronto":
			for k in escolha.item_count:
				if escolha.get_item_metadata(k) == "fliper":
					escolha.select(k)
			campo_chave.text = str(e.chave)
			campo_modelo.text = ""
			_salvar_config()
			config.visible = false
			conversa.append_text("[color=#9bff3a]%s[/color]\n\n" % (T.entrou % str(e.get("email", ""))))
			_atualizar_plano()
			botao_entrar.disabled = false
			return
		if e.get("estado", "") == "expirou":
			break
	conversa.append_text("[color=#ff7b7b]%s[/color]\n" % T.expirou)
	botao_entrar.disabled = false


## Mostra o plano (GET /ia/v1/saldo com a chave da conta). Fora da IA Fliper (chave própria), some.
func _atualizar_plano() -> void:
	if plano == null:
		return
	var chave := campo_chave.text.strip_edges() if campo_chave else ""
	var fliper := str(escolha.get_item_metadata(escolha.selected)) == "fliper" if escolha and escolha.item_count > 0 else true
	if not fliper:
		plano.text = ""
		comprar.visible = false
		return
	if not chave.begins_with("flp_"):
		plano.text = T.plano_sem
		comprar.visible = false
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request(site + "/ia/v1/saldo", ["Authorization: Bearer " + chave])
	var r = await http.request_completed
	http.queue_free()
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()) if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200 else null
	if not d is Dictionary:
		plano.text = T.plano_sem
		comprar.visible = false
		return
	if d.get("dono", false):
		plano.text = T.plano_dono
		comprar.visible = false
	elif str(d.get("plano", "")) in ["pro", "max"]:
		var p := str(d.get("plano"))
		plano.text = T.plano_pago % [str(d.get("plano_nome", p)), float(d.get("janela_horas", 0)), int(d.get("semana_pct", 0))]
		var links = d.get("assinar", {})
		comprar.visible = p == "pro"
		comprar.text = T.subir
		if links is Dictionary and links.get("max"):
			comprar.uri = str(links.get("max"))
		plano_modelo = "fliper-" + p
	else:
		plano.text = T.plano_gratis % [int(d.get("gratis_hoje", 0)), int(d.get("gratis_limite", 0))]
		var links = d.get("assinar", {})
		comprar.visible = true
		comprar.text = T.comprar
		if links is Dictionary and links.get("pro"):
			comprar.uri = str(links.get("pro"))
		plano_modelo = ""
	# com plano, a IA da Fliper usa o modelo do plano (a não ser que a pessoa tenha escrito outro)
	if campo_modelo and campo_modelo.text.strip_edges() == "" and agente.provedor == "fliper":
		agente.modelo = plano_modelo
	plano.tooltip_text = str(d.get("email", ""))


func _postar(url: String, corpo: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(corpo))
	var r = await http.request_completed
	http.queue_free()
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()) if r[0] == HTTPRequest.RESULT_SUCCESS else null
	return d if d is Dictionary else {}


func _boas_vindas() -> void:
	conversa.append_text("[color=#ff2e88][b]%s[/b][/color]\n%s\n\n" % [T.ola, T.conte])
	if campo_chave and campo_chave.text.strip_edges() == "":
		conversa.append_text(T.sem_conta + "\n\n")
	for s in T.sugestoes:
		conversa.append_text("[color=#ffc531]›[/color] [url=pedir:%s]%s[/url]\n" % [s, s])
	conversa.append_text("\n")


func _tecla(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ENTER and (e.ctrl_pressed or e.meta_pressed):
		accept_event()
		_enviar()


func _enviar() -> void:
	if agente.ocupado:
		agente.parar = true
		return
	var t := entrada.text.strip_edges()
	if t == "":
		return
	entrada.text = ""
	conversa.append_text("[b]%s:[/b] %s\n" % [T.voce, t.replace("[", "[lb]")])
	botao.text = T.parar
	agente.pedir(t)


func _falou(texto: String) -> void:
	conversa.append_text("[color=#ff2e88][b]Fliper:[/b][/color] %s\n\n" % texto)


func _livre() -> void:
	botao.text = T.enviar


func _carregar_config() -> void:
	var es := editor.get_editor_settings()
	var prov := str(es.get_setting("fliper/provedor")) if es.has_setting("fliper/provedor") else "fliper"
	for i in escolha.item_count:
		if escolha.get_item_metadata(i) == prov:
			escolha.select(i)
	campo_chave.text = str(es.get_setting("fliper/chave")) if es.has_setting("fliper/chave") else ""
	campo_modelo.text = str(es.get_setting("fliper/modelo")) if es.has_setting("fliper/modelo") else ""
	_aplicar()
	if campo_chave.text == "":
		config.visible = true


func _salvar_config() -> void:
	if editor == null:  # teste fora do editor
		_aplicar()
		return
	var es := editor.get_editor_settings()
	es.set_setting("fliper/provedor", escolha.get_item_metadata(escolha.selected))
	es.set_setting("fliper/chave", campo_chave.text.strip_edges())
	es.set_setting("fliper/modelo", campo_modelo.text.strip_edges())
	_aplicar()


func _aplicar() -> void:
	if campo_chave and campo_chave.text.strip_edges().length() == 36 and campo_chave.text.begins_with("flp_"):
		_atualizar_plano.call_deferred()
	agente.provedor = str(escolha.get_item_metadata(escolha.selected))
	agente.chave = campo_chave.text.strip_edges()
	agente.modelo = campo_modelo.text.strip_edges() if campo_modelo.text.strip_edges() != "" else plano_modelo

@tool
extends RefCounted
## O laço do agente: manda a conversa para a IA (API compatível com OpenAI), executa as ferramentas que ela pedir
## e repete até ela responder em texto. Funciona com os Modelos Fliper, OpenRouter ou OpenAI (chave da pessoa).

signal falou(texto: String)
signal agiu(resumo: String)
signal terminou

const PROVEDORES := {
	"fliper": {"nome": "Fliper AI (free every day)", "url": "https://fliperstudio.com/ia/v1", "modelo": "fliper-gratis"},
	"openrouter": {"nome": "My OpenRouter key", "url": "https://openrouter.ai/api/v1", "modelo": "poolside/laguna-s-2.1:free"},
	"openai": {"nome": "OpenAI", "url": "https://api.openai.com/v1", "modelo": "gpt-5-mini"},
}
const MAX_PASSOS := 30

const SISTEMA := """Você é a Fliper, um estúdio de jogos inteiro dentro da Fliper Engine (Godot 4.7, GDScript 4).
A pessoa é a DIRETORA do jogo: ela decide o gosto; você planeja, programa, desenha e testa.
Regras:
- Responda na língua da pessoa, curto e sem jargão.
- Antes de mexer, olhe o projeto (listar, ler). Faça passos pequenos.
- GDScript 4 com tipos. Nada de APIs do Godot 3 (yield, KinematicBody2D, export var sem @).
- Depois de cada mudança, use testar. Se der erro, conserte antes de seguir.
- Para arte rápida, use feira_baixar (sprites CC0 no mesmo estilo).
- No fim, diga em 1 ou 2 linhas o que mudou e chame rodar para a pessoa jogar."""

var ferramentas
var dono: Node
var provedor := "fliper"
var chave := ""
var modelo := ""
var url := ""  # vazio = a do provedor (os testes apontam para um servidor falso)
var mensagens: Array = []
var parar := false
var ocupado := false


var sessao := ""  # uma por conversa: a OpenRouter agrupa os passos (session_id)


func _nova_sessao() -> void:
	sessao = "engine-" + str(Time.get_unix_time_from_system()) + "-" + str(randi() % 100000)


func novo() -> void:
	_nova_sessao()
	mensagens = [{"role": "system", "content": SISTEMA}]


func pedir(texto: String) -> void:
	if ocupado:
		return
	if mensagens.is_empty():
		novo()
	ocupado = true
	parar = false
	mensagens.append({"role": "user", "content": texto})
	for passo in MAX_PASSOS:
		if parar:
			falou.emit("(parado)")
			break
		var r := await _chamar()
		if r.has("erro"):
			falou.emit("[color=#ff6b8b]%s[/color]" % r.erro)
			break
		var msg: Dictionary = r.msg
		mensagens.append(msg)
		var chamadas: Array = msg.get("tool_calls", []) if msg.get("tool_calls") is Array else []
		if str(msg.get("content", "")) != "" and msg.get("content") != null:
			falou.emit(str(msg.content))
		if chamadas.is_empty():
			break
		var prints: Array[String] = []
		for ch in chamadas:
			var nome := str(ch.function.name)
			var args = JSON.parse_string(str(ch.function.get("arguments", "{}")))
			if not args is Dictionary:
				args = {}
			agiu.emit(_resumo(nome, args))
			var saida: String
			if nome == "feira_baixar":
				saida = await ferramentas.feira_baixar(str(args.get("id", "")))
			else:
				saida = ferramentas.executar(nome, args)
			if nome == "ver_tela" and ferramentas.ultima_tela != "":
				prints.append(ferramentas.ultima_tela)
				ferramentas.ultima_tela = ""
			mensagens.append({"role": "tool", "tool_call_id": str(ch.id), "content": saida})
		for p in prints:  # imagem não vai em resposta de ferramenta: vai como mensagem da pessoa
			mensagens.append({"role": "user", "content": [{"type": "text", "text": "Print da tela:"},
				{"type": "image_url", "image_url": {"url": "data:image/png;base64," + p}}]})
	ocupado = false
	terminou.emit()


func _resumo(nome: String, a: Dictionary) -> String:
	match nome:
		"ler", "escrever", "editar":
			return "%s %s" % [nome, str(a.get("caminho", ""))]
		"listar":
			return "olhando o projeto"
		"testar":
			return "testando o jogo"
		"rodar":
			return "abrindo o jogo"
		"ver_tela":
			return "olhando a tela"
		"feira_baixar":
			return "Feira: " + str(a.get("id", ""))
	return nome


func _chamar() -> Dictionary:
	var p: Dictionary = PROVEDORES.get(provedor, PROVEDORES.fliper)
	if chave == "":
		return {"erro": "Missing key / Falta a chave: ⚙ → openrouter.ai/keys (free)."}
	var http := HTTPRequest.new()
	http.timeout = 180
	dono.add_child(http)
	if sessao == "":
		_nova_sessao()
	var corpo_d := {"model": modelo if modelo != "" else p.modelo, "messages": mensagens,
		"tools": ferramentas.definicoes(), "max_tokens": 6000}
	if provedor != "openai":  # a OpenAI direta recusa campo que não conhece
		corpo_d["session_id"] = sessao
	var corpo := JSON.stringify(corpo_d)
	var cab := ["Content-Type: application/json", "Authorization: Bearer " + chave,
		"HTTP-Referer: https://fliperstudio.com", "X-Title: Fliper Engine",
		"X-Fliper-Cliente: engine/" + Engine.get_version_info().get("string", "?")]
	http.request((url if url != "" else str(p.url)) + "/chat/completions", cab, HTTPClient.METHOD_POST, corpo)
	var r = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return {"erro": "Sem conexão com a IA (%s)." % r[0]}
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if r[1] == 401:
		return {"erro": "Chave recusada. Confira em ⚙."}
	if r[1] == 402:
		return {"erro": "Créditos acabaram. Recarregue em fliperstudio.com/account ou use a sua chave."}
	if r[1] != 200 or not d is Dictionary or not d.has("choices"):
		var m := ""
		if d is Dictionary and d.get("error") is Dictionary:
			m = str(d.error.get("message", ""))
		elif d is Dictionary:
			m = str(d.get("mensagem", d.get("error", "")))
		return {"erro": "A IA respondeu %d. %s" % [r[1], m]}
	return {"msg": d.choices[0].message}

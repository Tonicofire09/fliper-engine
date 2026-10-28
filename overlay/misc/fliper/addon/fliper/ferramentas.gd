@tool
extends RefCounted
## As mãos da IA dentro do editor: ler, escrever e editar arquivos do projeto, rodar e testar o jogo,
## olhar a tela e trazer sprites da Feira. Tudo restrito a res:// (o projeto aberto).

const SITE := "https://fliperstudio.com"
const LIMITE_LEITURA := 40000

var editor: EditorInterface
var dono: Node  # quem segura os HTTPRequest
var ultima_tela: String = ""  # base64 do último print, para a IA ver
var ao_vivo := true  # "Live": abre no editor o que a IA mexe e roda o jogo depois de cada teste sem erro
var _ultimo_jogo := 0


func definicoes() -> Array:
	return [
		_def("listar", "Lista os arquivos do projeto (até 300). pasta vazia = res://", {"pasta": "string"}),
		_def("ler", "Lê um arquivo de texto do projeto (res://...).", {"caminho": "string"}),
		_def("escrever", "Cria ou troca um arquivo inteiro do projeto (res://...). Use para scripts .gd, cenas .tscn e textos.", {"caminho": "string", "conteudo": "string"}),
		_def("editar", "Troca um trecho EXATO (que aparece uma vez só) de um arquivo do projeto.", {"caminho": "string", "de": "string", "para": "string"}),
		_def("testar", "Roda o jogo sem janela por alguns segundos e devolve os erros e o que ele imprimiu. Use depois de cada mudança.", {"segundos": "integer"}),
		_def("rodar", "Abre o jogo para a pessoa jogar (cena principal, ou a cena informada).", {"cena": "string"}),
		_def("ver_tela", "Tira um print do editor (com o jogo, se estiver rodando dentro dele) para você olhar.", {}),
		_def("feira_baixar", "Baixa um sprite grátis (CC0) da Fliper Feira para res://arte/. ids: " + ", ".join(FEIRA), {"id": "string"}),
	]


const FEIRA := ["moeda", "coracao", "bau", "arvore", "arvore-outono", "arvore-inverno", "pedra", "pedra-cobre", "pedra-cristal",
	"broto", "cenoura", "gosma", "gosma-verde", "gosma-vermelha", "pocao", "pocao-vida", "pocao-energia", "espada",
	"pessoa", "pessoa-vermelha", "pessoa-verde", "pessoa-loira"]


func _def(nome: String, descricao: String, campos: Dictionary) -> Dictionary:
	var props := {}
	for c in campos:
		props[c] = {"type": campos[c]}
	return {"type": "function", "function": {"name": nome, "description": descricao,
		"parameters": {"type": "object", "properties": props, "required": campos.keys()}}}


func _dentro(caminho: String) -> String:
	var c := caminho.strip_edges()
	if not c.begins_with("res://"):
		c = "res://" + c.trim_prefix("/")
	if ".." in c or c.begins_with("res://.godot"):
		return ""
	return c


func executar(nome: String, a: Dictionary) -> String:
	match nome:
		"listar":
			var lista: Array[String] = []
			_andar(_dentro(str(a.get("pasta", ""))) if str(a.get("pasta", "")) != "" else "res://", lista)
			return "\n".join(lista) if lista.size() > 0 else "(vazio)"
		"ler":
			var c := _dentro(str(a.get("caminho", "")))
			if c == "" or not FileAccess.file_exists(c):
				return "ERRO: arquivo não existe: " + str(a.get("caminho", ""))
			var t := FileAccess.get_file_as_string(c)
			return t.substr(0, LIMITE_LEITURA) + ("\n…(cortado)" if t.length() > LIMITE_LEITURA else "")
		"escrever":
			var c := _dentro(str(a.get("caminho", "")))
			if c == "":
				return "ERRO: caminho fora do projeto"
			DirAccess.make_dir_recursive_absolute(c.get_base_dir())
			var f := FileAccess.open(c, FileAccess.WRITE)
			if f == null:
				return "ERRO: não consegui gravar " + c
			f.store_string(str(a.get("conteudo", "")))
			f.close()
			_atualizar(c)
			return "gravado " + c
		"editar":
			var c := _dentro(str(a.get("caminho", "")))
			if c == "" or not FileAccess.file_exists(c):
				return "ERRO: arquivo não existe"
			var t := FileAccess.get_file_as_string(c)
			var de := str(a.get("de", ""))
			var n := t.count(de)
			if de == "" or n != 1:
				return "ERRO: o trecho aparece %d vezes (precisa ser exatamente 1). Leia o arquivo de novo." % n
			var f := FileAccess.open(c, FileAccess.WRITE)
			f.store_string(t.replace(de, str(a.get("para", ""))))
			f.close()
			_atualizar(c)
			return "editado " + c
		"testar":
			var r := _testar(clampi(int(a.get("segundos", 4)), 2, 20))
			# ao vivo: passou sem erro → a pessoa vê o jogo de agora rodando (no máximo a cada 20 s)
			if ao_vivo and editor != null and r.begins_with("SEM ERROS") and Time.get_ticks_msec() - _ultimo_jogo > 20000:
				_ultimo_jogo = Time.get_ticks_msec()
				if editor.is_playing_scene():
					editor.stop_playing_scene()
				editor.play_main_scene()
				r += "\n(o jogo abriu para a pessoa ver ao vivo)"
			return r
		"rodar":
			if editor == null:
				return "ERRO: rodar só funciona dentro do editor"
			var cena := str(a.get("cena", ""))
			if cena != "":
				editor.play_custom_scene(_dentro(cena))
			else:
				editor.play_main_scene()
			return "jogo aberto para a pessoa jogar"
		"ver_tela":
			if editor == null:
				return "ERRO: ver_tela só funciona dentro do editor"
			var img := editor.get_base_control().get_viewport().get_texture().get_image()
			if img.get_width() > 1280:
				img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()))
			ultima_tela = Marshalls.raw_to_base64(img.save_png_to_buffer())
			return "print tirado (%dx%d): está na próxima mensagem" % [img.get_width(), img.get_height()]
	return "ERRO: ferramenta desconhecida " + nome


func _andar(pasta: String, lista: Array[String]) -> void:
	var d := DirAccess.open(pasta)
	if d == null or lista.size() >= 300:
		return
	for arq in d.get_files():
		if not arq.ends_with(".import") and not arq.ends_with(".uid"):
			lista.append(pasta.path_join(arq))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_andar(pasta.path_join(sub), lista)


func _atualizar(caminho: String) -> void:
	if editor == null:  # fora do editor (testes): nada a atualizar
		return
	var fs := editor.get_resource_filesystem()
	fs.update_file(caminho)
	fs.scan()
	if caminho.ends_with(".gd"):
		var s = load(caminho)
		if s is Script:
			s.reload(true)
			if ao_vivo:
				editor.edit_script(s)  # a pessoa vê o código que a IA acabou de escrever
	elif ao_vivo and caminho.ends_with(".tscn"):
		editor.open_scene_from_path(caminho)


func _testar(segundos: int) -> String:
	var saida: Array = []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after", str(segundos * 60)]
	var codigo := OS.execute(OS.get_executable_path(), args, saida, true)
	var texto := "\n".join(saida).strip_edges()
	var linhas: Array[String] = []
	for l in texto.split("\n"):
		if l.strip_edges() != "" and not l.begins_with("Godot Engine") and not l.begins_with("Fliper Engine"):
			linhas.append(l)
	var t := "\n".join(linhas)
	var erros := t.count("ERROR") + t.count("SCRIPT ERROR") + t.count("Parse Error")
	return ("SEM ERROS" if erros == 0 else "%d ERRO(S)" % erros) + " (código %d)\n" % codigo + t.right(6000)


## A Feira é rede: devolve o texto da resposta quando o download acaba.
func feira_baixar(id: String) -> String:
	if not id in FEIRA:
		return "ERRO: id desconhecido. Use um destes: " + ", ".join(FEIRA)
	var http := HTTPRequest.new()
	dono.add_child(http)
	var destino := "res://arte/%s.png" % id
	DirAccess.make_dir_recursive_absolute("res://arte")
	http.download_file = ProjectSettings.globalize_path(destino)
	http.request(SITE + "/feira/sprites/%s.png" % id)
	var r = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return "ERRO: não consegui baixar (%s, HTTP %s)" % [r[0], r[1]]
	_atualizar(destino)
	return "baixado %s (CC0, paleta Fliper 16). Use com load(\"%s\")." % [destino, destino]

extends Node
## Base de todo módulo. O núcleo (nucleo.gd) chama estes ganchos em TODOS os módulos de Nucleo.MODULOS,
## na ordem da lista. Cada módulo sobrescreve só o que precisa. Retorno vazio / false = "não é comigo".
## Regra de ouro (vem do Vale Tóxico): o núcleo não conhece nenhum módulo; módulo novo não mexe no núcleo.

var camada := 0  # ordem de desenho: menor desenha primeiro (fundo < jogo < interface)


# ---- ciclo de vida
func novo_jogo() -> void:
	# começo de uma partida (Nucleo.novo_jogo ou Nucleo.reiniciar): zera o estado da partida;
	# o que é permanente entre partidas (recorde) não zera aqui
	pass


func salvar() -> Dictionary:
	# o estado do módulo, para continuar depois (e para os testes compararem). Só tipos de JSON:
	# Vector2i vira [x, y]. carregar(salvar()) tem que devolver o mesmo estado (o teste de regras cobra).
	return {}


func carregar(_d: Dictionary) -> void:
	pass


# ---- jogo
func passo(_dt: float) -> void:
	# um passo fixo de simulação (Nucleo.DT). Nada de tempo real aqui: os testes andam passo a passo.
	pass


func entrada(_acao: String) -> bool:
	# o jogador apertou uma ação (cima, baixo, esquerda, direita, acao, pausa). true = tratado, para a fila.
	# movimento contínuo: em passo(), pergunte Nucleo.segurando("esquerda").
	return false


func evento(_nome: String, _dados: Dictionary) -> void:
	# barramento: um módulo avisa (Nucleo.emitir) e os outros reagem sem se conhecer.
	pass


func desenhar(_tela: Node2D) -> void:
	# o mundo, dentro do _draw da tela: use _tela.draw_rect, _tela.draw_string... (pode tremer)
	pass


func desenhar_hud(_tela: Node2D) -> void:
	# interface por cima de tudo, sem tremor (placar, vidas, telas)
	pass


# ---- automação (é o que deixa o agente jogar e testar sozinho)
func bot() -> String:
	# sugestão de ação para o jogador automático (--cena=jogar). "" = sem opinião.
	# a ação vale como apertada E segurada neste passo; junte várias com "+" ("esquerda+acao").
	return ""


func progresso() -> int:
	# quanto o jogador avançou desde novo_jogo() (pontos, fases, área limpa). O bot tem que fazer subir.
	return 0


func teste(_t) -> void:
	# checks do módulo: _t.ok(condicao, "o que devia acontecer"). Rode: --cena=modulo --modulo=Nome
	pass

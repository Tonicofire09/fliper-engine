extends RefCounted
## Contador dos testes: t.ok(condicao, "descrição"). Só imprime o que falhou, para o agente ler rápido.

var oks := 0
var falhas := 0


func ok(cond: bool, nome: String) -> void:
	if cond:
		oks += 1
	else:
		falhas += 1
		print("FALHOU: ", nome)

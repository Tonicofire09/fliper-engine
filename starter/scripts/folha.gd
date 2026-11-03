extends RefCounted
## Folha de sprites + o mapa .json ao lado dela (formato de ferramentas/gerar_sprites.py, criar_personagem e
## animar_acoes). Desenha um quadro dentro do _draw da tela, com os pés no ponto dado, virado para dir (1 ou -1).
## Só visual: a simulação nunca depende da folha (os testes rodam sem placa de vídeo).

var tex: Texture2D
var q := Vector2(32, 32)
var anims := {}


func _init(caminho_png: String) -> void:
	tex = Nucleo.textura(caminho_png)
	var mapa = JSON.parse_string(FileAccess.get_file_as_string(caminho_png.get_basename() + ".json"))
	if mapa is Dictionary:
		q = Vector2(float(mapa.quadro.largura), float(mapa.quadro.altura))
		anims = mapa.animacoes


func _dur(a: Dictionary, i: int) -> float:
	var d: Array = a.get("duracoes", [])
	return float(d[i]) if i < d.size() else 1.0


## Qual quadro mostrar depois de t segundos de animação (respeita a duração de cada quadro e o loop).
func indice(anim: String, t: float) -> int:
	var a: Dictionary = anims.get(anim, {})
	var n := int(a.get("quadros", 1))
	if n <= 1:
		return 0
	var total := 0.0
	for i in n:
		total += _dur(a, i)
	var u := t * float(a.get("fps", 8))
	if bool(a.get("loop", true)):
		u = fmod(u, total)
	elif u >= total:
		return n - 1
	for i in n:
		u -= _dur(a, i)
		if u < 0.0:
			return i
	return n - 1


func desenhar(tela: Node2D, anim: String, t: float, pe: Vector2, dir := 1, cor := Color.WHITE) -> void:
	if tex == null or not anims.has(anim):
		return
	var a: Dictionary = anims[anim]
	var col := int(a.get("coluna", indice(anim, t)))
	var reg := Rect2(col * q.x, float(a.get("linha", 0)) * q.y, q.x, q.y)
	var r := Rect2(pe.x - q.x / 2.0, pe.y - q.y, q.x, q.y)
	if dir < 0:  # largura negativa = espelhado
		r = Rect2(pe.x + q.x / 2.0, pe.y - q.y, -q.x, q.y)
	tela.draw_texture_rect_region(tex, r, reg, cor)


## Sombra no chão (oval em pixel) embaixo dos pés.
static func sombra(tela: Node2D, pe: Vector2, larg: float) -> void:
	var m := larg / 2.0
	tela.draw_colored_polygon(PackedVector2Array([
		pe + Vector2(-m, 0), pe + Vector2(-m + 3, -2), pe + Vector2(m - 3, -2), pe + Vector2(m, 0),
		pe + Vector2(m - 3, 2), pe + Vector2(-m + 3, 2)]), Color(0.03, 0.0, 0.08, 0.45))

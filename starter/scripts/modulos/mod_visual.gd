extends "res://scripts/nucleo/modulo.gd"
## Visual 3D: monta o mundo (luz, céu, chão, câmera) e a cada quadro copia o estado dos módulos para os nós 3D.
## Só desenha: não muda nada do jogo (por isso os testes rodam sem placa de vídeo). Ouve: "tremer", "gema".
## Trocar a cara do jogo = mexer só aqui (cores, malhas, ou carregar um .glb da Feira no lugar das formas).

const ROSA := Color("#ff2e88")
const CIANO := Color("#3fe0ff")
const OURO := Color("#ffc531")
const VERDE := Color("#9bff3a")
const FUNDO := Color("#0b0715")

var mundo: Node3D
var camera: Camera3D
var heroi: Node3D
var gemas: Array = []
var perigos: Array = []
var brilhos: Array = []  # [nó, tempo]
var tremor := 0.0
var pendentes: Array = []  # brilhos pedidos pela simulação; só os recentes viram nó (o bot pode simular muitos passos de uma vez)
var _t := 0.0


func _init() -> void:
	camada = -10


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return  # testes: nada para desenhar
	_montar.call_deferred()


func _mat(cor: Color, brilho := 0.0, rugosidade := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


func _malha(mesh: Mesh, mat: Material, pai: Node3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	pai.add_child(n)
	return n


func _montar() -> void:
	mundo = Node3D.new()
	mundo.name = "Mundo3D"
	get_tree().root.add_child(mundo)
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = FUNDO
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color("#6a5a9a")
	amb.ambient_light_energy = 0.6
	amb.fog_enabled = true
	amb.fog_light_color = Color("#2a1440")
	amb.fog_density = 0.02
	amb.glow_enabled = true
	amb.glow_intensity = 0.45
	amb.glow_hdr_threshold = 1.2
	amb.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = amb
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, -35, 0)
	sol.light_color = Color("#ffd9b0")
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	mundo.add_child(sol)
	var a: float = Nucleo.mod("Jogador").ARENA
	# chão em xadrez (duas cores) e bordas neon
	var chao := Node3D.new()
	mundo.add_child(chao)
	var claro := _mat(Color("#2b2140"))
	var escuro := _mat(Color("#221a33"))
	var lado := 2.0
	var n := int(ceil(a * 2.0 / lado)) + 1
	for i in n:
		for k in n:
			var c := _malha(BoxMesh.new(), claro if (i + k) % 2 == 0 else escuro, chao)
			c.mesh.size = Vector3(lado, 0.4, lado)
			c.position = Vector3(-a - 1.0 + i * lado + 1.0, -0.2, -a - 1.0 + k * lado + 1.0)
	for s in [-1.0, 1.0]:
		for eixo in [0, 1]:
			var b := _malha(BoxMesh.new(), _mat(CIANO, 1.3), mundo)
			b.mesh.size = Vector3(a * 2.0 + 2.6, 0.25, 0.25) if eixo == 0 else Vector3(0.25, 0.25, a * 2.0 + 2.6)
			b.position = Vector3(0, 0.12, s * (a + 1.2)) if eixo == 0 else Vector3(s * (a + 1.2), 0.12, 0)
	# herói: corpo em cápsula + viseira (mostra para onde olha)
	heroi = Node3D.new()
	mundo.add_child(heroi)
	var corpo := _malha(CapsuleMesh.new(), _mat(Color("#f2f2f2"), 0.0, 0.4), heroi)
	corpo.mesh.radius = 0.4
	corpo.mesh.height = 1.3
	corpo.position.y = 0.65
	var viseira := _malha(BoxMesh.new(), _mat(ROSA, 1.6), heroi)
	viseira.mesh.size = Vector3(0.5, 0.18, 0.2)
	viseira.position = Vector3(0, 0.95, 0.35)
	var sombra := _malha(CylinderMesh.new(), _mat(Color(0, 0, 0, 0.45)), mundo)
	sombra.mesh.top_radius = 0.45
	sombra.mesh.bottom_radius = 0.45
	sombra.mesh.height = 0.02
	sombra.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sombra.name = "Sombra"
	camera = Camera3D.new()
	camera.fov = 55
	mundo.add_child(camera)
	camera.make_current()


func _process(dt: float) -> void:
	if mundo == null:
		return
	_t += dt
	var j = Nucleo.mod("Jogador")
	heroi.position = Vector3(j.pos.x, j.alt, j.pos.y)
	heroi.rotation.y = lerp_angle(heroi.rotation.y, j.ang, 0.25)
	heroi.visible = j.protegido <= 0.0 or int(_t * 12.0) % 2 == 0
	var sombra := mundo.get_node("Sombra") as Node3D
	sombra.position = Vector3(j.pos.x, 0.02, j.pos.y)
	sombra.scale = Vector3.ONE * clampf(1.0 - j.alt * 0.2, 0.4, 1.0)
	# gemas: octaedros dourados girando
	var lista: Array = Nucleo.mod("Gemas").lista
	while gemas.size() < lista.size():
		var g := _malha(SphereMesh.new(), _mat(OURO, 1.4, 0.2), mundo)
		g.mesh.radial_segments = 4
		g.mesh.rings = 2
		g.mesh.radius = 0.45
		g.mesh.height = 1.1
		gemas.append(g)
	for i in gemas.size():
		gemas[i].visible = i < lista.size()
		if i < lista.size():
			gemas[i].position = Vector3(lista[i].x, 0.7 + sin(_t * 3.0 + i) * 0.15, lista[i].y)
			gemas[i].rotation.y = _t * 2.0 + i
	# perigos: bolas rolando
	var pl: Array = Nucleo.mod("Perigos").lista
	while perigos.size() < pl.size():
		var p := _malha(SphereMesh.new(), _mat(VERDE.darkened(0.3), 1.2, 0.5), mundo)
		p.mesh.radius = 0.55
		p.mesh.height = 1.1
		perigos.append(p)
	for i in perigos.size():
		perigos[i].visible = i < pl.size()
		if i < pl.size():
			var q: Array = pl[i]
			perigos[i].position = Vector3(q[0], 0.55, q[1])
			perigos[i].rotation = Vector3(q[1], 0, -q[0]) * 1.6
	# brilho ao pegar gema
	for q in pendentes:
		if Nucleo.quadro - int(q[2]) < 20:
			var nb := _malha(SphereMesh.new(), _mat(OURO, 1.5), mundo)
			nb.position = Vector3(q[0], 0.7, q[1])
			brilhos.append([nb, 0.5])
	pendentes.clear()
	for b in brilhos.duplicate():
		b[1] -= dt
		b[0].scale = Vector3.ONE * (1.0 + (0.5 - b[1]) * 4.0)
		b[0].transparency = 1.0 - b[1] * 2.0
		if b[1] <= 0.0:
			b[0].queue_free()
			brilhos.erase(b)
	# câmera atrás e acima, seguindo macio, com tremor
	tremor = maxf(0.0, tremor - dt * 12.0)
	var alvo := Vector3(j.pos.x * 0.8, 9.5, j.pos.y * 0.8 + 10.5)
	if _t <= dt * 1.5:
		camera.position = alvo  # 1º quadro: já no lugar (sem voo da origem)
	camera.position = camera.position.lerp(alvo, 0.08) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * tremor * 0.03
	camera.look_at(Vector3(j.pos.x * 0.85, 0.5, j.pos.y * 0.85 - 0.5))


func evento(nome: String, d: Dictionary) -> void:
	if mundo == null:
		return
	if nome == "tremer":
		tremor = float(d.get("forca", 5.0))
	elif nome == "gema":
		pendentes.append([float(d.x), float(d.z), Nucleo.quadro])


func teste(t) -> void:
	# sem tela (headless) o Visual não monta nada e não quebra o jogo
	t.ok(mundo == null or mundo.is_inside_tree(), "Visual não atrapalha os testes")
	t.ok(Nucleo.mod("Jogador") != null and Nucleo.mod("Gemas") != null and Nucleo.mod("Perigos") != null, "tem o que desenhar")

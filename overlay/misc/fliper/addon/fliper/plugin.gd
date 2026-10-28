@tool
extends EditorPlugin
## Liga o painel da Fliper na lateral direita do editor.

var painel: Control


func _enter_tree() -> void:
	painel = preload("res://addons/fliper/painel.gd").new()
	painel.name = "Fliper"
	painel.editor = get_editor_interface()
	# coluna própria à direita do Inspetor: a conversa fica sempre à vista
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, painel)
	_mostrar.call_deferred()


func _mostrar() -> void:
	# o editor restaura o layout salvo depois que o plugin entra: espera ele terminar e traz a aba da Fliper para a frente
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(painel):
		return
	var abas := painel.get_parent()
	if abas is TabContainer:
		abas.current_tab = painel.get_index()
	# primeiro jogo da Engine: na 1ª vez que abre, já roda o jogo (o mundo 3D é montado ao rodar; parado só aparece a grade)
	if ProjectSettings.get_setting("fliper/abrir_jogando", false):
		ProjectSettings.set_setting("fliper/abrir_jogando", false)
		ProjectSettings.save()
		get_editor_interface().play_main_scene()


func _exit_tree() -> void:
	if painel:
		remove_control_from_docks(painel)
		painel.queue_free()

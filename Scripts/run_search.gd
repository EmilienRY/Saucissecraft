extends Node
@export var xml_path: String = "res://xml/blockWorld.xml"
@export var auto_start_search: bool = true

func _ready() -> void:
	if not auto_start_search:
		return
	var ctrl: Controller = Controller.from_xml(xml_path)
	if ctrl == null:
		print("[run_search] Échec du chargement du XML : %s" % xml_path)
		return
	print("[run_search] XML chargé. Lancement de la recherche...")

	var actions: Array = ctrl.search()
	if actions.size() == 0:
		print("[run_search] Aucune solution trouvée (ou recherche incomplète).")
	else:
		print("[run_search] Solution trouvée avec %d étapes:" % actions.size())
		for a in actions:
			print("    ", a)

	set_meta("last_controller", ctrl)

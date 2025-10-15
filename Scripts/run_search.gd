extends Node
@export var xml_path: String = "res://xml/blockWorld.xml"
@export var auto_start_search: bool = true
@export var hand_node_path: NodePath
@export var pos_middle_path: NodePath
@export var pos_top_left_path: NodePath
@export var pos_top_right_path: NodePath
@export var pos_bottom_left_path: NodePath
@export var pos_bottom_right_path: NodePath
@export var move_duration: float = 0.5
@export var lift_height: float = 1.2
@export var drop_height: float = 1.0

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

	# Affiche des stats supplémentaires (noeuds/arêtes explorées)
	# Utilise get() pour tester la présence des champs ajoutés dynamiquement
	if ctrl.get("last_search_edge_count") == null or ctrl.get("last_search_node_count") == null:
		print("[run_search] Pas de statistiques d'arêtes disponibles sur ce Controller")
	else:
		print("[run_search] Noeuds explorés: %d" % ctrl.last_search_node_count)
		print("[run_search] Arrêtes explorées: %d" % ctrl.last_search_edge_count)

	set_meta("last_controller", ctrl)

	# Après recherche, s'il y a des actions, lance l'animation dans la scène
	if actions.size() > 0:
		# Construire une table d'association id -> Node3D (si possible)
		var node_map = _build_block_node_map(ctrl)
		await animate_solution(actions, node_map)


func _build_block_node_map(ctrl: Controller) -> Dictionary:
	# Essaie plusieurs heuristiques pour trouver les nodes correspondants aux blocks:
	#  - node nommé "Block_<id>"
	#  - node dont le nom contient l'id
	#  - node avec meta "block_id" égal à l'id
	# Parcours récursif de l'arbre de scènes depuis ce Node
	var map: Dictionary = {}
	for b in ctrl.start_state.blocks:
		var id = b.m_id
		var found = null
		# 1) exact name
		found = _search_node_by_exact_name(self, "Block_%d" % id)
		if found == null:
			# 2) name contains id
			found = _search_node_by_name_contains(self, str(id))
		if found == null:
			# 3) meta field
			found = _search_node_by_meta(self, "block_id", id)
		if found != null:
			map[id] = found
		else:
			print("[run_search] Warning: no scene node found for block id=%d" % id)
	return map


func _search_node_by_name_contains(node: Node, substr: String) -> Node:
	if node.name.findn(substr) != -1:
		# avoid returning the root node if it matches unintentionally
		if node != self:
			return node
	for c in node.get_children():
		if typeof(c) == TYPE_OBJECT and c is Node:
			var res = _search_node_by_name_contains(c, substr)
			if res != null:
				return res
	return null


func _search_node_by_meta(node: Node, key: String, value) -> Node:
	if node.has_meta(key) and node.get_meta(key) == value:
		return node
	for c in node.get_children():
		if typeof(c) == TYPE_OBJECT and c is Node:
			var res = _search_node_by_meta(c, key, value)
			if res != null:
				return res
	return null


func _pos_node_for_name(pos_name: String) -> Node:
	match pos_name:
		"MIDDLE":
			if pos_middle_path != null and pos_middle_path != NodePath(""):
				return get_node_or_null(pos_middle_path)
			return null
		"TOP_LEFT":
			if pos_top_left_path != null and pos_top_left_path != NodePath(""):
				return get_node_or_null(pos_top_left_path)
			return null
		"TOP_RIGHT":
			if pos_top_right_path != null and pos_top_right_path != NodePath(""):
				return get_node_or_null(pos_top_right_path)
			return null
		"BOTTOM_LEFT":
			if pos_bottom_left_path != null and pos_bottom_left_path != NodePath(""):
				return get_node_or_null(pos_bottom_left_path)
			return null
		"BOTTOM_RIGHT":
			if pos_bottom_right_path != null and pos_bottom_right_path != NodePath(""):
				return get_node_or_null(pos_bottom_right_path)
			return null
		_: return null


func _search_node_by_exact_name(node: Node, target_name: String) -> Node:
	if node != self and node.name == target_name:
		return node
	for c in node.get_children():
		if typeof(c) == TYPE_OBJECT and c is Node:
			var res = _search_node_by_exact_name(c, target_name)
			if res != null:
				return res
	return null


func _get_hand_node() -> Node:
	if hand_node_path == null or hand_node_path == NodePath(""):
		return null
	return get_node_or_null(hand_node_path)


func animate_solution(actions: Array, node_map: Dictionary) -> void:
	# Joue les actions l'une après l'autre avec des tweens simples
	var hand = _get_hand_node()
	var world_parent = null
	if has_node("WorldEnvironment"):
		world_parent = get_node("WorldEnvironment")
	else:
		world_parent = get_parent()

	# map pour restaurer parent après pickup: id -> parent
	var held_parent_map: Dictionary = {}

	for a in actions:
		var parts = a.split(" ")
		var cmd = parts[0]
		if cmd == "pickup":
			var id = int(parts[1])
			var node = null
			if node_map.has(id):
				node = node_map[id]
			if node == null:
				print("[run_search] animate: pickup - node for id %d not found" % id)
				continue
			# If we have a hand, move the hand to the block, attach it and lift the hand.
			var saved_parent = node.get_parent()
			held_parent_map[id] = saved_parent
			var saved_global = node.global_transform
			if hand != null:
				# move hand above block
				var hand_target = node.global_position + Vector3(0, lift_height * 0.4, 0)
				await _tween_move(hand, hand_target)
				# attach block to hand, preserving global transform
				saved_parent.remove_child(node)
				hand.add_child(node)
				node.global_transform = saved_global
				# lift the hand (and block)
				var hand_lift = hand.global_position + Vector3(0, lift_height * 0.6, 0)
				await _tween_move(hand, hand_lift)
			else:
				# no hand available: simple lift
				var start_pos = node.global_position
				var lift_pos = start_pos + Vector3(0, lift_height, 0)
				var t = create_tween()
				t.tween_property(node, "global_position", lift_pos, move_duration * 0.5)
				await t.finished
		elif cmd == "drop_on_position":
			var posname = parts[1]
			# the previous pickup should have left a block at hand; we try to find the last moved node by searching for nearest to hand
			var mover = _find_node_closest_to_hand(node_map)
			if mover == null:
				print("[run_search] animate: drop_on_position - no mover found")
				continue
			var posnode = _pos_node_for_name(posname)
			if posnode == null:
				print("[run_search] animate: position node for %s not set" % posname)
				continue
			var target = posnode.global_position
			# find mover id
			var mover_id = -1
			for k in node_map.keys():
				if node_map[k] == mover:
					mover_id = k
					break
			# If mover was attached to hand, move hand to target then detach
			if mover_id != -1 and held_parent_map.has(mover_id) and hand != null:
				var target_hand_pos = target + Vector3(0, lift_height * 0.6, 0)
				await _tween_move(hand, target_hand_pos)
				# detach mover back to world_parent
				var saved_g2 = mover.global_transform
				mover.get_parent().remove_child(mover)
				world_parent.add_child(mover)
				mover.global_transform = saved_g2
				held_parent_map.erase(mover_id)
			else:
				var tt = create_tween()
				tt.tween_property(mover, "global_position", target, move_duration)
				await tt.finished
		elif cmd == "drop_on_block":
			var dest_id = int(parts[1])
			var mover = _find_node_closest_to_hand(node_map)
			var dest = null
			if node_map.has(dest_id):
				dest = node_map[dest_id]
			if mover == null or dest == null:
				print("[run_search] animate: drop_on_block - missing nodes mover=%s dest=%s" % [mover, dest])
				continue
			# place above dest
			var target_pos = dest.global_position + Vector3(0, drop_height, 0)
			# find mover id
			var mover_id2 = -1
			for k2 in node_map.keys():
				if node_map[k2] == mover:
					mover_id2 = k2
					break
			if mover_id2 != -1 and held_parent_map.has(mover_id2) and hand != null:
				var target_hand_pos2 = target_pos + Vector3(0, lift_height * 0.6, 0)
				await _tween_move(hand, target_hand_pos2)
				var saved_g3 = mover.global_transform
				mover.get_parent().remove_child(mover)
				world_parent.add_child(mover)
				mover.global_transform = saved_g3
				held_parent_map.erase(mover_id2)
			else:
				var tdrop = create_tween()
				tdrop.tween_property(mover, "global_position", target_pos, move_duration)
				await tdrop.finished

			# move hand slightly away so it's not overlapping
			if hand != null:
				var hand_idle = hand.global_position + Vector3(0, 0.2, -0.2)
				await _tween_move(hand, hand_idle)
		elif cmd == "lay":
			# find last mover and rotate to lie (rotate 90deg on X)
			var mover2 = _find_node_closest_to_hand(node_map)
			if mover2 == null:
				print("[run_search] animate: lay - mover not found")
				continue
			var cur_rot = mover2.rotation_degrees
			var target_rot = Vector3(cur_rot.x + 90, cur_rot.y, cur_rot.z)
			var tween_rot = create_tween()
			tween_rot.tween_property(mover2, "rotation_degrees", target_rot, move_duration)
			await tween_rot.finished
		elif cmd == "stand":
			var mover3 = _find_node_closest_to_hand(node_map)
			if mover3 == null:
				print("[run_search] animate: stand - mover not found")
				continue
			var cur_r = mover3.rotation_degrees
			var targ = Vector3(cur_r.x - 90, cur_r.y, cur_r.z)
			var tween_rot2 = create_tween()
			tween_rot2.tween_property(mover3, "rotation_degrees", targ, move_duration)
			await tween_rot2.finished
		else:
			print("[run_search] animate: unknown action %s" % a)

	print("[run_search] Animation terminée")


func _find_node_closest_to_hand(node_map: Dictionary) -> Node:
	var hand = _get_hand_node()
	if hand == null:
		# fallback: return any node in map (last one)
		for k in node_map.keys():
			return node_map[k]
		return null
	var best = null
	var bestd = 1e12
	for k in node_map.keys():
		var n = node_map[k]
		if n == null: continue
		var d = n.global_position.distance_to(hand.global_position)
		if d < bestd:
			bestd = d
			best = n
	return best


func _tween_move(node: Node, target_pos: Vector3) -> void:
	# Simple helper: tween node.global_position to target_pos and await completion
	var tw = create_tween()
	tw.tween_property(node, "global_position", target_pos, move_duration)
	await tw.finished

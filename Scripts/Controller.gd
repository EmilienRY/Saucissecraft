extends RefCounted
class_name Controller

const POSITIONS = {
	"MIDDLE": Vector3(0, 0, 0),
	"TOP_LEFT": Vector3(-1, 1, 0),
	"TOP_RIGHT": Vector3(1, 1, 0),
	"BOTTOM_LEFT": Vector3(-1, -1, 0),
	"BOTTOM_RIGHT": Vector3(1, -1, 0)
}

var start_state: State
var goal_state: State
var visited: Array[State] = []
var queue: Array[StateNode] = []
var last_search_node_count: int = 0
var last_search_edge_count: int = 0

# Helpers for bidirectional search
func _state_hash(s: State) -> String:
	# Create a compact canonical representation of a state for hashing/lookup
	var parts: Array = []
	# sort blocks by id to make canonical
	var ids: Array = []
	for b in s.blocks:
		ids.append(b.m_id)
	ids.sort()
	for id in ids:
		var b = null
		for bb in s.blocks:
			if bb.m_id == id:
				b = bb
				break
		var below_id = -1
		if b.m_block_below != null:
			below_id = b.m_block_below.m_id
		parts.append(str(id) + ":" + str(b.m_position) + "," + str(below_id) + "," + str(b.m_lay))
	var hold_part = "-"
	if s.hold_block != null:
		hold_part = str(s.hold_block.m_id) + "," + str(s.hold_block.m_lay)
	# join parts manually (Array.join may not be available depending on Godot version)
	var joined = ""
	for i in range(parts.size()):
		if i > 0:
			joined += "|"
		joined += parts[i]
	return joined + "|H:" + hold_part

func _queue_has_hash(q: Array, h: String) -> bool:
	for n in q:
		if _state_hash(n.state) == h:
			return true
	return false

func _reconstruct_meeting_path(node_from_start: StateNode, node_from_goal: StateNode) -> Array[String]:
	# path from start -> meeting
	var path_start: Array[String] = reconstruct_path(node_from_start)
	# build node chain from goal root -> meeting
	var nodes: Array = []
	var n = node_from_goal
	while n != null:
		nodes.insert(0, n)
		n = n.parent
	# nodes[0] is goal root, nodes[-1] is meeting
	# Collect inverted actions: iterate from meeting down to root and invert each action
	var inv_actions: Array[String] = []
	for i in range(nodes.size() - 1, 0, -1):
		var before_state: State = nodes[i - 1].state
		var after_state: State = nodes[i].state
		var action = nodes[i].action
		var inv = invert_action(action, before_state, after_state)
		if inv == null:
			return []
		inv_actions.append(inv)
	return path_start + inv_actions

func invert_action(action: String, before_state: State, _after_state: State) -> Variant:
	var parts = action.split(" ")
	var cmd = parts[0]
	if cmd == "pickup":
		var id = int(parts[1])
		# before_state had block in blocks; place depends on where it was
		var b_before = null
		for bb in before_state.blocks:
			if bb.m_id == id:
				b_before = bb
				break
		if b_before == null:
			return null
		if b_before.m_block_below == null:
			return "drop_on_position " + str(b_before.m_position)
		return "drop_on_block " + str(b_before.m_block_below.m_id)
	elif cmd == "drop_on_position":
		# inverse is pickup of the block that was held in before_state
		if before_state.hold_block == null:
			return null
		return "pickup " + str(before_state.hold_block.m_id)
	elif cmd == "drop_on_block":
		if before_state.hold_block == null:
			return null
		return "pickup " + str(before_state.hold_block.m_id)
	elif cmd == "lay":
		return "stand"
	elif cmd == "stand":
		return "lay"
	else:
		return null

func _init(start: State, goal: State) -> void:
	start_state = start
	goal_state = goal
	visited.clear()
	queue.clear()
	if start_state != null:
		queue.append(StateNode.new(start_state))



# -----------------------------
# XML loading helpers
# -----------------------------
func translate_position(pos_raw: String) -> String:
	# map french xml names to POSITIONS keys
	var m = {
		"milieu": "MIDDLE",
		"hautGauche": "TOP_LEFT",
		"hautDroite": "TOP_RIGHT",
		"basGauche": "BOTTOM_LEFT",
		"basDroite": "BOTTOM_RIGHT"
	}
	if m.has(pos_raw):
		return m[pos_raw]
	return pos_raw

func color_from_name(name: String) -> Color:
	var cmap = {
		"gris": Color(0.5, 0.5, 0.5),
		"rouge": Color(1, 0, 0),
		"violet": Color(0.6, 0.2, 0.6)
	}
	if cmap.has(name):
		return cmap[name]
	return Color(1,1,1)

func load_states_from_xml(path: String) -> Dictionary:
	var parser = XMLParser.new()
	var err = parser.open(path)
	if err != OK:
		push_error("Cannot open XML: %s" % path)
		return {}

	var current_section = ""
	var initial_entries: Array = []
	var goal_entries: Array = []

	while parser.read() == OK:
		var nt = parser.get_node_type()
		if nt == XMLParser.NODE_ELEMENT:
			var name = parser.get_node_name()
			if name == "Initial":
				current_section = "Initial"
			elif name == "Goal":
				current_section = "Goal"
			elif name == "Block":
				var attr_map = {}
				for ai in range(parser.get_attribute_count()):
					var aname = parser.get_attribute_name(ai)
					var aval = parser.get_attribute_value(ai)
					attr_map[aname] = aval
				var id = int(attr_map.get("id", "0"))
				var shape = attr_map.get("forme", "")
				var weight = float(attr_map.get("poids", "0"))
				var couleur = attr_map.get("couleur", "")
				var position_raw = attr_map.get("position", "")
				var position = translate_position(position_raw)
				var sur = attr_map.get("sur", "table")
				var color = color_from_name(couleur)
				var couche = attr_map.get("couche", )

				var log_line = "Loaded block id=%d shape=%s weight=%f color=%s position=%s sur=%s couche=%s" % [id, shape, weight, str(color), position, sur, couche]
				print(log_line)

				var b = Block.new(id, shape, weight, color, null, position,couche, null)
				if current_section == "Initial":
					initial_entries.append({"block": b, "sur": sur})
				elif current_section == "Goal":
					goal_entries.append({"block": b, "sur": sur})

	var start_blocks = _resolve_entries(initial_entries)
	var goal_blocks = _resolve_entries(goal_entries)

	var start_state_local: State = State.new()
	for sb in start_blocks:
		start_state_local.add_block(sb)
	var goal_state_local: State = State.new()
	for gb in goal_blocks:
		goal_state_local.add_block(gb)
	return {"start": start_state_local, "goal": goal_state_local}

static func from_xml(path: String) -> Controller:
	var temp = Controller.new(null, null)
	var loaded = temp.load_states_from_xml(path)
	if typeof(loaded) != TYPE_DICTIONARY or loaded.size() == 0:
		return null
	if not loaded.has("start") or not loaded.has("goal"):
		return null
	return Controller.new(loaded["start"], loaded["goal"])

func _resolve_entries(entries: Array) -> Array:
	var blocks_arr: Array = []
	for e in entries:
		blocks_arr.append(e["block"]) 

	for e in entries:
		var sur = e["sur"]
		if sur != "table":
			var sur_id = int(sur)
			for b in blocks_arr:
				if b.m_id == sur_id:
					e["block"].m_block_below = b
					break
	return blocks_arr


# actions

func pickup(state: State, block_idx: int) -> State:
	if state.hold_block != null:
		return null
	if block_idx < 0 or block_idx >= state.blocks.size():
		return null
	var target: Block = state.blocks[block_idx]
	for b in state.blocks:
		if b.m_block_below == target:
			return null
	var ns: State = state.clone()

	var idx = ns.find_block_index_by_id(target.m_id)
	if idx == -1:
		return null
	ns.hold_block = ns.blocks[idx]
	ns.blocks.remove_at(idx)
	return ns

func drop_on_position(state: State, position_name: String) -> State:
	if state.hold_block == null:
		return null
	if not POSITIONS.has(position_name):
		return null
	for b in state.blocks:
		if b.m_position == position_name and b.m_block_below == null:
			return null 
	var ns: State = state.clone()
	var hb: Block = ns.hold_block
	hb.m_position = position_name
	hb.m_block_below = null
	ns.blocks.append(hb)
	ns.hold_block = null
	return ns

func drop_on_block(state: State, dest_block_id: int) -> State:
	if state.hold_block == null:
		return null
	var ns: State = state.clone()
	var dest_idx = ns.find_block_index_by_id(dest_block_id)
	if dest_idx == -1:
		return null
	var dest_block: Block = ns.blocks[dest_idx]

	if dest_block.m_shape == "donut saucisse" and dest_block.m_lay != "oui":
		return null

	for b in ns.blocks:
		if b.m_block_below == dest_block:
			return null
	var hb: Block = ns.hold_block
	hb.m_block_below = dest_block
	hb.m_position = dest_block.m_position
	ns.blocks.append(hb)
	ns.hold_block = null
	return ns



func can_lay(state: State) -> bool:
	if state.hold_block == null:
		return false
	var f= state.hold_block.m_shape
	if (f == "cylindre" or f == "donut saucisse") and state.hold_block.m_lay=="non":
		return true
	return false


func lay(state: State) -> State:
	if not can_lay(state):
		return null
	var ns: State = state.clone()
	ns.hold_block.m_lay = "oui"
	return ns


func can_stand(state: State) -> bool:
	if state.hold_block == null:
		return false
	var f= state.hold_block.m_shape
	if (f == "cube" or f == "donut saucisse") and state.hold_block.m_lay=="oui":
		return true
	return false

func stand(state: State) -> State:
	if not can_stand(state):
		return null
	var ns: State = state.clone()
	ns.hold_block.m_lay = "non"
	return ns


# lancement de la recherche

func search() -> Array[String]:
	# Bidirectional breadth-first search (BFS)
	var t0 = Time.get_ticks_msec()
	var node_explored = 0
	var edge_count = 0

	if start_state == null or goal_state == null:
		return []

	# Quick equality check
	if equals_state(start_state, goal_state):
		return []

	# Frontiers and visited maps keyed by state hash -> StateNode
	var front_f: Dictionary = {} # forward frontier queue (hash -> StateNode)
	var front_b: Dictionary = {} # backward frontier
	var q_f: Array = []
	var q_b: Array = []

	var seen_f: Dictionary = {} # hash -> StateNode (visited)
	var seen_b: Dictionary = {}

	var start_node = StateNode.new(start_state)
	var goal_node = StateNode.new(goal_state)
	q_f.append(start_node)
	front_f[_state_hash(start_state)] = start_node
	seen_f[_state_hash(start_state)] = start_node

	q_b.append(goal_node)
	front_b[_state_hash(goal_state)] = goal_node
	seen_b[_state_hash(goal_state)] = goal_node

	var _meeting_hash: String = ""

	# Alternate expansion between forward and backward frontiers
	var expand_forward = true
	while q_f.size() > 0 and q_b.size() > 0:
		# Choose which side to expand (simple alternation)
		var current_queue: Array
		var current_seen: Dictionary
		var other_seen: Dictionary
		if expand_forward:
			current_queue = q_f
			current_seen = seen_f
			other_seen = seen_b
		else:
			current_queue = q_b
			current_seen = seen_b
			other_seen = seen_f

		var current_node: StateNode = current_queue.pop_front()
		var curr_state = current_node.state

		# Check meeting
		var h = _state_hash(curr_state)
		if other_seen.has(h):
			_meeting_hash = h
			# Build path by connecting current_node and the node from other side
			var other_node: StateNode = other_seen[h]
			var path: Array[String] = []
			if expand_forward:
				path = _reconstruct_meeting_path(current_node, other_node)
			else:
				path = _reconstruct_meeting_path(other_node, current_node)

			var t1 = Time.get_ticks_msec()
			print("[search] Solution trouvée (bidirectional) en %d ms" % [t1 - t0])
			print("[search] Taille de l'arbre exploré: %d noeuds" % node_explored)
			print("[search] Nombre d'arrêtes explorées: %d" % edge_count)
			last_search_node_count = node_explored
			last_search_edge_count = edge_count
			return path

		# mark visited
		current_seen[h] = current_node
		node_explored += 1

		var neighbors = generate_neighbors(current_node)
		for neighbor_node in neighbors:
			edge_count += 1
			var nh = _state_hash(neighbor_node.state)
			if not current_seen.has(nh) and not _queue_has_hash(current_queue, nh):
				# if neighbor seen by other side -> meeting
				if other_seen.has(nh):
					var other_node2: StateNode = other_seen[nh]
					var path2: Array[String] = []
					if expand_forward:
						path2 = _reconstruct_meeting_path(neighbor_node, other_node2)
					else:
						path2 = _reconstruct_meeting_path(other_node2, neighbor_node)
					var t2 = Time.get_ticks_msec()
					print("[search] Solution trouvée (bidirectional on neighbor) en %d ms" % [t2 - t0])
					print("[search] Taille de l'arbre exploré: %d noeuds" % node_explored)
					print("[search] Nombre d'arrêtes explorées: %d" % edge_count)
					last_search_node_count = node_explored
					last_search_edge_count = edge_count
					return path2
				
		# otherwise enqueue
				current_queue.append(neighbor_node)
				current_seen[nh] = neighbor_node
		

		expand_forward = not expand_forward
	
	var t_end = Time.get_ticks_msec()
	print("[search] Aucune solution trouvée en %d ms" % [t_end - t0])
	print("[search] Taille de l'arbre exploré: %d noeuds" % node_explored)
	print("[search] Nombre d'arrêtes explorées: %d" % edge_count)
	last_search_node_count = node_explored
	last_search_edge_count = edge_count
	return []


func generate_neighbors(node: StateNode) -> Array[StateNode]:
	var results: Array[StateNode] = []
	var state = node.state

	for i in range(state.blocks.size()):
		var new_state = pickup(state, i)
		if new_state != null:
			results.append(StateNode.new(new_state, node, "pickup " + str(state.blocks[i].m_id)))

	if state.hold_block != null:
		# drop on table positions
		for pos_name in POSITIONS.keys():
			var new_state2 = drop_on_position(state, pos_name)
			if new_state2 != null:
				results.append(StateNode.new(new_state2, node, "drop_on_position " + pos_name))
		# drop on other blocks
		for b in state.blocks:
			var new_state3 = drop_on_block(state, b.m_id)
			if new_state3 != null:
				results.append(StateNode.new(new_state3, node, "drop_on_block " + str(b.m_id)))
		# lay
		if can_lay(state):
			var new_state4 = lay(state)
			if new_state4 != null:
				results.append(StateNode.new(new_state4, node, "lay"))
		# stand
		if can_stand(state):
			var new_state5 = stand(state)
			if new_state5 != null:
				results.append(StateNode.new(new_state5, node, "stand"))

	return results

func contains_state(array: Array[State], target: State) -> bool:
	for s in array:
		if equals_state(s, target):
			return true
	return false

func contains_state_node(array: Array[StateNode], target_node: StateNode) -> bool:
	for n in array:
		if equals_state(n.state, target_node.state):
			return true
	return false

func equals_state(a: State, b: State) -> bool:
	if a.blocks.size() != b.blocks.size():
		return false
	var map_a = {}
	for block in a.blocks:
		map_a[block.m_id] = {"pos": block.m_position, "below": (block.m_block_below.m_id if block.m_block_below != null else -1), "lay": block.m_lay}
	for block_b in b.blocks:
		if not map_a.has(block_b.m_id):
			return false
		var entry = map_a[block_b.m_id]
		var below_id = -1
		if block_b.m_block_below != null:
			below_id = block_b.m_block_below.m_id
		if entry["pos"] != block_b.m_position or entry["below"] != below_id or entry["lay"] != block_b.m_lay:
			return false
	var hold_a = a.hold_block
	var hold_b = b.hold_block
	if hold_a == null and hold_b == null:
		return true
	if (hold_a == null) != (hold_b == null):
		return false
	return hold_a.m_id == hold_b.m_id and hold_a.m_lay == hold_b.m_lay

# -----------------------------
# Reconstruction du chemin
# -----------------------------
func reconstruct_path(node: StateNode) -> Array[String]:
	var path: Array[String] = []
	while node.parent != null:
		path.insert(0, node.action)
		node = node.parent
	return path

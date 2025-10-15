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
	var t0 = Time.get_ticks_msec()
	var sizeTree = 0
	var edge_count = 0
	if queue.size() > 0:
		while queue.size() > 0:
			var current_node: StateNode = queue.pop_front()
			var current_state = current_node.state

			if equals_state(current_state, goal_state):
				var t1 = Time.get_ticks_msec()
				print("[search] Solution trouvée en %d ms" % [t1 - t0])
				print("[search] Taille de l'arbre exploré: %d noeuds" % sizeTree)
				print("[search] Nombre d'arrêtes explorées: %d" % edge_count)
				last_search_node_count = sizeTree
				last_search_edge_count = edge_count
				return reconstruct_path(current_node)

			visited.append(current_state)

			var neighbors = generate_neighbors(current_node)
			for neighbor_node in neighbors:
				if not contains_state(visited, neighbor_node.state) and not contains_state_node(queue, neighbor_node):
						sizeTree += 1
						edge_count += 1
						queue.append(neighbor_node)

	var t_end = Time.get_ticks_msec()
	print("[search] Aucune solution trouvée en %d ms" % [t_end - t0])
	print("[search] Taille de l'arbre exploré: %d noeuds" % sizeTree)
	print("[search] Nombre d'arrêtes explorées: %d" % edge_count)
	last_search_node_count = sizeTree
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

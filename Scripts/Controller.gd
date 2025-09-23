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

func _init(start: State, goal: State) -> void:
	start_state = start
	goal_state = goal
	visited.clear()
	queue.clear()
	queue.append(StateNode.new(start_state))

# -----------------------------
# Grab / Release
# -----------------------------
func grab(state: State, block_idx: int) -> bool:
	if state.hold_block != null:
		return false
	if block_idx < 0 or block_idx >= state.blocks.size():
		return false
	state.hold_block = state.blocks[block_idx]
	state.blocks.remove_at(block_idx)
	return true

func release(state: State, position_name: String) -> bool:
	if state.hold_block == null:
		return false
	if not POSITIONS.has(position_name):
		return false
	var released_block = state.hold_block
	released_block.m_position = POSITIONS[position_name]
	state.blocks.append(released_block)
	state.hold_block = null
	return true

# -----------------------------
# BFS pour atteindre la state finale
# -----------------------------
func search() -> Array[String]:
	while queue.size() > 0:
		var current_node: StateNode = queue.pop_front()
		var current_state = current_node.state

		if equals_state(current_state, goal_state):
			return reconstruct_path(current_node)

		visited.append(current_state)

		var neighbors = generate_neighbors(current_node)
		for neighbor_node in neighbors:
			if not contains_state(visited, neighbor_node.state) and not contains_state_node(queue, neighbor_node):
				queue.append(neighbor_node)

	return [] # pas trouvé

# -----------------------------
# Génération de voisins (StateNode)
# -----------------------------
func generate_neighbors(node: StateNode) -> Array[StateNode]:
	var results: Array[StateNode] = []
	var state = node.state

	# Essayer de grab chaque bloc
	for i in range(state.blocks.size()):
		var new_state = state.clone()
		if grab(new_state, i):
			results.append(StateNode.new(new_state, node, "grab " + str(i)))

	# Essayer de release à chaque position prédéfinie
	if state.hold_block != null:
		for pos_name in POSITIONS.keys():
			var new_state2 = state.clone()
			if release(new_state2, pos_name):
				results.append(StateNode.new(new_state2, node, "release " + pos_name))

	return results

# -----------------------------
# Vérification d'un état dans un array
# -----------------------------
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
	for i in range(a.blocks.size()):
		if a.blocks[i].m_id != b.blocks[i].m_id or a.blocks[i].m_position != b.blocks[i].m_position:
			return false
	return a.hold_block == b.hold_block

# -----------------------------
# Reconstruction du chemin
# -----------------------------
func reconstruct_path(node: StateNode) -> Array[String]:
	var path: Array[String] = []
	while node.parent != null:
		path.insert(0, node.action)
		node = node.parent
	return path

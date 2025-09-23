extends RefCounted
class_name State

var blocks: Array[Block] = []
var hold_block: Block = null

func _init(initial_blocks: Array[Block] = []) -> void:
	blocks = initial_blocks.duplicate(true)

func add_block(block: Block) -> void:
	blocks.append(block)

func remove_block(block: Block) -> void:
	blocks.erase(block)

func copy_from(other: State) -> void:
	blocks = other.blocks.duplicate(true)

func clone() -> State:
	# Deep copy blocks while preserving m_block_below relationships
	var old_to_new = {}
	var new_blocks: Array[Block] = []
	for b in blocks:
		var nb: Block = Block.new(b.m_id, b.m_shape, b.m_weight, b.m_color, b.m_material, b.m_position, null)
		new_blocks.append(nb)
		old_to_new[b] = nb

	# Fix references for block_below
	for i in range(blocks.size()):
		var ob: Block = blocks[i]
		var nb: Block = new_blocks[i]
		if ob.m_block_below != null and old_to_new.has(ob.m_block_below):
			nb.m_block_below = old_to_new[ob.m_block_below]

	# If hold_block is not in blocks (picked up), ensure it's copied too
	if hold_block != null and not old_to_new.has(hold_block):
		var hb_copy: Block = Block.new(hold_block.m_id, hold_block.m_shape, hold_block.m_weight, hold_block.m_color, hold_block.m_material, hold_block.m_position, null)
		old_to_new[hold_block] = hb_copy

	# Build new state (use add_block to avoid typed-array mismatches)
	var s: State = State.new()
	for nb in new_blocks:
		s.add_block(nb)
	if hold_block != null and old_to_new.has(hold_block):
		s.hold_block = old_to_new[hold_block]
	return s

func find_block_index_by_id(id: int) -> int:
	for i in range(blocks.size()):
		if blocks[i].m_id == id:
			return i
	return -1

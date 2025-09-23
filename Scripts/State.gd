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

extends RefCounted
class_name Block

var m_id: int
var m_shape: String
var m_weight: float
var m_color: Color
var m_material: Material
var m_position: String
var m_block_below: Block

func _init(id: int, shape: String, weight: float, color: Color, material: Material, position: String, block_below: Block = null) -> void:
	m_id = id
	m_shape = shape
	m_weight = weight
	m_color = color
	m_material = material
	m_position = position
	m_block_below = block_below

func copy_from(other: Block) -> void:
	m_id = other.m_id
	m_shape = other.m_shape
	m_weight = other.m_weight
	m_color = other.m_color
	m_material = other.m_material
	m_position = other.m_position
	m_block_below = other.m_block_below

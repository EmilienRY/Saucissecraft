extends RefCounted
class_name StateNode

var state: State
var parent: StateNode = null
var action: String = ""

func _init(state: State, parent: StateNode = null, action: String = "") -> void:
	self.state = state
	self.parent = parent
	self.action = action

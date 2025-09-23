extends RefCounted

class BaseAction:
    func precondition(_state):
        return false

    func apply(state):
        return state

class PickupAction:
    var block_id

    func _init(_block_id):
        block_id = _block_id

    func precondition(state):
        return state.holding == null and state.is_accessible(block_id)

    func apply(state):
        var new_state = state.duplicate()
        new_state.pickup(block_id)
        return new_state

# Action Drop
class DropAction:
    var block_id
    var destination

    func _init(_block_id, _destination):
        block_id = _block_id
        destination = _destination

    func precondition(state):
        return state.holding == block_id and state.is_destination_free(destination)

    func apply(state):
        var new_state = state.duplicate()
        new_state.drop(block_id, destination)
        return new_state

class ActionPickup:

    var block_id

    func _init(_block_id):
        block_id = _block_id

    func precondition(state):
        return state.arm_is_empty() and state.is_accessible(block_id)

    func apply(state):
        var new_state = state.duplicate()
        new_state.pickup(block_id)
        return new_state
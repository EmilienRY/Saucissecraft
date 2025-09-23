extends RefCounted
class_name BlockWorld


class Block:
    var id
    var forme
    var poids
    var couleur
    var material
    var position
    var sur

    func _init(id, forme, poids, couleur, material, position, sur):
        self.id = id
        self.forme = forme
        self.poids = poids
        self.couleur = couleur
        self.material = material
        self.position = position
        self.sur = sur

    func duplicate():
        return Block.new(id, forme, poids, couleur, material, position, sur)


class State:
    var blocks = []
    var holding = null 

    func _init(blocks):
        self.blocks = blocks.duplicate(true)

    func is_accessible(block_id):
        for block in blocks:
                if block.sur == block_id:
                    return false
        return true

extends Node3D
class_name GridNodeFeature

var _node: GridNode:
    get():
        if _node == null && !_inited:
            _node = GridNode.find_node_parent(self)
            _inited = true

        return _node

var anchor: GridAnchor

var _inited: bool

func get_level() -> GridLevelCore:
    if _node != null:
        return _node.get_level()

    return GridLevelCore.find_level_parent(self, false)

func get_grid_node() -> GridNode:
    if anchor != null:
        return anchor.get_grid_node()

    return _node

func set_grid_node(node: GridNode, _deferred: bool = false) -> void:
    if anchor != null:
        anchor = null
    _node = node

    print_debug("Entity %s is now at %s in the air" % [name, coordinates()])

    if !_inited:
        _inited = true

    __SignalBus.on_change_anchor.emit(self)
    __SignalBus.on_change_node.emit(self)

func get_grid_anchor() -> GridAnchor:
    return anchor

func get_grid_anchor_direction() -> CardinalDirections.CardinalDirection:
    if anchor == null:
        return CardinalDirections.CardinalDirection.NONE
    return anchor.direction

func set_grid_anchor(new_anchor: GridAnchor, _deferred: bool = false) -> void:
    if new_anchor == null:
        push_warning("%s attempted to anchor to null" % self)
        return

    anchor = new_anchor
    _node = anchor.get_grid_node()

    print_debug("Entity %s is now at %s %s" % [name, coordinates(), CardinalDirections.name(anchor.direction)])

    if !_inited:
        _inited = true

    __SignalBus.on_change_anchor.emit(self)
    __SignalBus.on_change_node.emit(self)

func coordinates() -> Vector3i:
    if _node == null:
        push_error("Entity %s isn't at a node, accessing its coordinates makes no sense" % name)
        print_stack()
        return Vector3i.ZERO

    return _node.coordinates

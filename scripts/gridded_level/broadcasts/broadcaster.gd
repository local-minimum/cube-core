extends Node
class_name Broadcaster

enum BroadcasterType { NONE, PRESSURE_PLATE }

static func name(type: BroadcasterType) -> String:
    return BroadcasterType.find_key(type)

@export var sender: Node

func configure(contract: BroadcastContract) -> BroadcasterType:
    if sender is PressurePlate:
        var plate: PressurePlate = sender
        if plate.register_broadcasts(contract):
            print_debug("[Broadcaster] Configured pressure plates %s to send boradcast %s" % [plate.name, contract])
        else:
            push_error("[Broadcaster] Failed to register contract %s to %s" % [contract, plate.name])

        return BroadcasterType.PRESSURE_PLATE

    return BroadcasterType.NONE

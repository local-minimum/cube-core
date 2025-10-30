extends GridDoorCore
class_name GridDoorMultiLocks

@export var locks: Array[int] = []

@export var positive_side_interactions: Array[GridDoorInteraction]
@export var negative_side_interactions: Array[GridDoorInteraction]

var _locks_opened: Array[int]

func get_lock_state(_interaction: GridDoorInteraction) -> LockState:
    var idx: int = _get_interaction_index(_interaction)
    if idx < 0:
        # print_debug("[Multi Lock Door] Lock %s index is %s so pretend open" % [self, idx])
        return GridDoorCore.LockState.OPEN

    if lock_state == GridDoorCore.LockState.LOCKED:
        if _locks_opened.has(idx):
            # print_debug("[Multi Lock Door] Lock %s index listed as opened is %s so pretend door open" % [self, idx])
            return GridDoorCore.LockState.OPEN

    # print_debug("[Multi Lock Door] Lock %s not opened (%s of %s) so using door lock state %s so pretend door open" % [self, idx, _locks_opened, GridDoorCore.lock_state_name(lock_state)])
    return lock_state

func _get_interaction_index(interaction: GridDoorInteraction) -> int:
    var idx: int = -1
    if interaction.is_negative_side:
        idx = negative_side_interactions.find(interaction)
    else:
        idx = positive_side_interactions.find(interaction)

    # print_debug("[Multi Lock Door] lock %s has index %s and should be used %s" % [
    #    self,
    #    idx,
    #    locks.has(idx),
    #])

    if locks.has(idx):
        return idx

    return -1

func attempt_door_unlock(interaction: GridDoorInteraction, _puller: CameraPuller) -> bool:
    if lock_state != LockState.LOCKED || _locks_opened.has(_get_interaction_index(interaction)):
        return false

    if !_check_key_and_consume():
        return false

    _locks_opened.append(_get_interaction_index(interaction))

    print_debug("[Multi Lock Door] %s locks out of %s opened" % [_locks_opened.size(), locks.size()])

    if _locks_opened.size() == locks.size():
        _do_unlock()

    return true

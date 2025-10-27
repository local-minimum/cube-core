extends Node
class_name BroadcastReceiver
@export var receiver: Node

func configure(contract: BroadcastContract, broadcaster_type: Broadcaster.BroadcasterType) -> void:
    if receiver is Crusher:
        var crusher: Crusher = receiver
        crusher.register_receiver_contract(contract, broadcaster_type)
        return


    push_error("Receiver doesn't know how to configure %s for unhandled type on %s, ignoring message id '%s'" % [
        Broadcaster.name(broadcaster_type),
        receiver.name,
        contract.message_id,
    ])

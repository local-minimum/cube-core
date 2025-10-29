extends Node
class_name BroadcastContract

@export var _broadcaster: Node
@export var _receivers: Array[Node]
@export var _messages: Array[String]


class Broadcast:
    var message_idx: int
    var receiver: Node
    var callback: Callable

    @warning_ignore_start("shadowed_variable")
    func _init(message_idx: int, receiver: Node, callback: Callable) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.message_idx = message_idx
        self.receiver = receiver
        self.callback = callback

var _casts: Array[Broadcast]

var messages: Array[String]:
    get():
        return _messages

func _ready() -> void:
    var type: Broadcaster.BroadcasterType = Broadcaster.BroadcasterType.NONE


    var caster: Broadcaster = get_broadcaster(self)
    if caster != null:
        type = caster.configure(self)

    if type == Broadcaster.BroadcasterType.NONE:
        push_error("No broadcast was configured for contract %s with broadcaster %s" % [name, _broadcaster])

    for reciever: BroadcastReceiver in get_receivers(self):
        if reciever != null:
            reciever.configure(self, type)

func register_receiver(message_idx: int, receiver: Node, callback: Callable) -> void:
    _casts.append(Broadcast.new(message_idx, receiver, callback))

func broadcast(message_idx: int) -> void:
    if message_idx >= 0 || message_idx < messages.size():
        for cast: Broadcast in _casts:
            if cast.message_idx == message_idx && cast.receiver != null:
                cast.callback.call()

static func get_broadcaster_name(contract: BroadcastContract) -> String:
    if contract._broadcaster != null:
        return contract._broadcaster.name

    return "[NO BROADCASTER]"

static func get_reciever_count(contract: BroadcastContract) -> int:
    return contract._receivers.size()

static func get_broadcaster(contract: BroadcastContract) -> Broadcaster:
    if contract._broadcaster == null:
        return null

    if contract._broadcaster is Broadcaster:
        return contract._broadcaster

    for node: Node in contract._broadcaster.find_children("", "Broadcaster"):
        if node is Broadcaster:
            return node
    return null

static func get_receivers(contract: BroadcastContract) -> Array[BroadcastReceiver]:
    var receivers: Array[BroadcastReceiver]

    for node: Node in contract._receivers:
        if node is BroadcastReceiver:
            receivers.append(node)

        for child: Node in node.find_children("", "BroadcastReceiver"):
            if child is BroadcastReceiver:
                receivers.append(child)

    return receivers

static func get_orphan_receivers(contract: BroadcastContract) -> Array[Node]:
    var orphans: Array[Node]

    for node: Node in contract._receivers:
        if node is BroadcastReceiver:
            continue

        if node.find_children("", "BroadcastReceiver").is_empty():
            orphans.append(node)

    return orphans

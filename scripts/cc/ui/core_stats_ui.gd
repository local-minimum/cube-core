extends Node

@export var health: CensoringLabel
@export var keys: CensoringLabel

func _enter_tree() -> void:
    if __SignalBus.on_gain_key.connect(_handle_gain_key) != OK:
        push_error("Failed to connect gain key")

    if __SignalBus.on_consume_key.connect(_handle_consume_key) != OK:
        push_error("Failed to connect consume key")

    if __SignalBus.on_sync_keys.connect(_handle_sync_keys) != OK:
        push_error("Failed to connect sync keys")


func _handle_gain_key(_key: String, _amount: int, total: int) -> void:
    keys.text = "%s" % total

func _handle_consume_key(_key: String, total: int) -> void:
    keys.text = "%s" % total

func _handle_sync_keys(synced_keys: Dictionary[String, int]) -> void:
    if synced_keys.is_empty():
        keys.text = "0"
    else:
        keys.text = "%s" % synced_keys[synced_keys.values()[0]]
